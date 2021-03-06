/* -*- Mode: C++; tab-width: 4 -*- */
/**
 *    This file is part of DictatorAI
 *    (c) krinn@chez.com
 *
 *    It's free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 2 of the License, or
 *    any later version.
 *
 *    You should have received a copy of the GNU General Public License
 *    with it.  If not, see <http://www.gnu.org/licenses/>.
 *
**/

class cTrack extends cClass
	{
	//constructor() {}
	}

function cTrack::SetRailType(rtype = -1)
/** @brief Set the current railtype
 *
 * @param rtype The railtype need, if -1 return the current best railtype
 * @return True if railtype was set
 *
 */
{
	if (rtype == -1)
			{
			local railtypes = AIRailTypeList();
			if (railtypes.IsEmpty())	{ DError("There's no railtype avaiable !",1); return false; }
			rtype = cEngineLib.RailTypeGetFastestType();
			}
	if (!AIRail.IsRailTypeAvailable(rtype))	{ DError("Railtype "+rtype+" is not available !",1); return false; }
	AIRail.SetCurrentRailType(rtype);
	return true; // assuming it has done it
}

function cTrack::BuildTrack_Road(tilefrom, tileto, stationID = -1, full = false)
/** @brief Build a road track from tilefrom to tileto
 *
 * @param tilefrom The source tile
 * @param tileto The target tile
 * @param full If true use AIRoad.BuildRoadFull else we use AIRoad.BuildRoad
 * @param the stationID to assign the track too, set the track as compatible type with the station roadtype
 * @return true if track was built or if a compatible track exist already (must have stationID set to find that)
 *
 */
{
	if (stationID != -1)
		{
		local roadtype = AIRoad.ROADTYPE_ROAD;
		local loc = AIStation.GetLocation(stationID);
		if (AIRoad.HasRoadType(loc, AIRoad.ROADTYPE_TRAM))	{ roadtype = AIRoad.ROADTYPE_TRAM; }
		AIRoad.SetCurrentRoadType(roadtype);
		}
	local api = AIRoad.BuildRoad;
	if (full)	{ api = AIRoad.BuildRoadFull; }
	local success = cError.ForceAction(api, tilefrom, tileto);
	local tiles = AIList();
	tiles.AddItem(tileto, 0);
	tiles.AddItem(tilefrom, 0);
	if (success && stationID != -1)	{ cStation.StationClaimTile(tiles, stationID); }
	return success;
}

function cTrack::RoadCleaner(targetTile, stationID = -1)
/** @brief Clean a tile or AIList of tiles from any roadtype structure, except station
 *
 * @param targetTile A tile or an AIList of tiles to clean
 * @param stationID the stationID
 * @return true if all tiles have been removed. targetTile: an AIList with tiles that were removed in it.
 *
 */
	{
	local many=AIList();
	if (cMisc.IsAIList(targetTile))	{ many.AddList(targetTile); targetTile.Clear(); }
							else	{ many.AddItem(targetTile, 0); targetTile = AIList(); }
	if (many.IsEmpty())	{ return true; }
	if (!DictatorAI.GetSetting("keep_road"))	{ return false; }
	local success = true;
	local voisin = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0,-1), AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)]; // SE, NW, SW, NE
	foreach (tile, dummy in many)
		{
		local looper = cLooper();
		cDebug.PutSign(tile,"Z");
		if (AITile.GetOwner(tile) != AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))	{ success = false; continue; }
		if (AIRoad.IsRoadStationTile(tile))	{ success = false; continue; } // protect station
		if (AIRoad.IsRoadDepotTile(tile))
				{
				if (cTrack.DestroyDepot(tile, -1))	{ targetTile.AddItem(tile, 0); }
											else	{ success= false; }
				continue;
				}
		if (AITile.HasTransportType(tile, AITile.TRANSPORT_ROAD) && (AIBridge.IsBridgeTile(tile) || AITunnel.IsTunnelTile(tile)) )
				{
				if (cError.ForceAction(AITile.DemolishTile, tile))	{ targetTile.AddItem(tile, 0); }
															else	{ success = false; }
				continue;
				}
		foreach (near in voisin)
			{
			cError.ForceAction(AIRoad.RemoveRoadFull, tile, tile + near);
			}
		if (AIRoad.IsRoadTile(tile))	{ success = false; }
								else	{ targetTile.AddItem(tile, 0); }
		}
	if (stationID != -1)	{ cStation.StationReleaseTile(many, stationID); }
	return success;
	}

function cTrack::DestroyDepot(tile, stationID = -1)
/** @brief Remove a depot at tile, sold vehicles in it that might prevent us doing it
 *
 * @param tile The depot tile location
 * @param stationID the station affect by the operation
 * @return true if depot was removed
 *
 */
{
	if (!cEngineLib.IsDepotTile(tile))	{ return false; }
	if (!cCarrier.FreeDepotOfVehicle(tile))	{ return false; }
	if (!cError.ForceAction(AITile.DemolishTile, tile))	{ return false; }
	if (stationID != -1)	{ cStation.SetStationDepot(stationID, -1); cStation.StationReleaseTile(tile, stationID); }
	return true;
}

function cTrack::DropRailHere(railneed, pos, stationID = -1)
/** @brief Add a railtrack at position
 *
 * @param railneed The rail track to build. If < 0 (railneed+1) the rail track to clear.
 * @param pos The tile to work at
 * @param stationID the station to assign the track with
 * @param useEntry The entry/exit of the stationID
 * @return True on success
 *
 */
{
	local lasterr = -1;
	if (railneed < 0)
			{
			if (!AIRail.IsRailTile(pos))	{ return true; }
									else	{ return cError.ForceAction(AIRail.RemoveRailTrack, pos, abs(railneed+1)); }
			}
	local count = 100;
	local success = AIRail.BuildRailTrack(pos, railneed);
	while (!success && count > 0)
			{
			success = AIRail.BuildRailTrack(pos, railneed);
			count--;
			lasterr=AIError.GetLastError();
			switch (lasterr)
					{
					case	AIError.ERR_AREA_NOT_CLEAR:
						if (!cTileTools.DemolishTile(pos))	{ return false; }
						break;
					case	AIError.ERR_VEHICLE_IN_THE_WAY:
							AIController.Sleep(10);
						break;
					case AIError.ERR_ALREADY_BUILT:
						return true;
					default:
						DError("Cannot build rail track at "+pos,1);
						return false;
					}
			}
	if (success && stationID != -1)	{ cStation.StationClaimTile(pos, stationID); }
	return true;
}

function cTrack::RailCleaner(targetTile, stationID = -1)
/** @brief Clean a tile from any rails structure, except station
 *
 * @param targetTile A tile or an AIList of tiles to clean
 * @param stationID the stationID
 * @return true if all tiles have been removed. targetTile: an AIList with tiles that were removed in it.
 *
 */
{
	local many=AIList();
	local success = true;
	if (cMisc.IsAIList(targetTile))	{ many.AddList(targetTile); targetTile.Clear(); }
							else	{ many.AddItem(targetTile, 0); targetTile = AIList(); }
	if (many.IsEmpty())	{ return true; }
	local voisin=[AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0,-1), AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)]; // SE, NW, SW, NE
	local trackMap=AIList();
	local seek=null;
	trackMap.AddItem(AIRail.RAILTRACK_NE_SW,	0);
	trackMap.AddItem(AIRail.RAILTRACK_NW_SE,	0);
	trackMap.AddItem(AIRail.RAILTRACK_NW_NE,	0);
	trackMap.AddItem(AIRail.RAILTRACK_SW_SE,	0);
	trackMap.AddItem(AIRail.RAILTRACK_NW_SW,	0);
	trackMap.AddItem(AIRail.RAILTRACK_NE_SE,	0);
	foreach (tile, dummy in many)
		{
		cDebug.PutSign(tile,"Z");
		local loop = cLooper();
		if (AIRail.IsRailStationTile(tile))	{ success = false; continue; } // protect station
		if (AIRail.IsRailDepotTile(tile))
				{
				if (cTrack.DestroyDepot(tile, -1))	{ targetTile.AddItem(tile, 0); }
											else	{ success = false; }
				continue;
				}
		if (AITile.HasTransportType(tile, AITile.TRANSPORT_RAIL) && (AIBridge.IsBridgeTile(tile) || AITunnel.IsTunnelTile(tile)) )
				{
				if (cError.ForceAction(AITile.DemolishTile, tile))	{ targetTile.AddItem(tile, 0); }
															else	{ success = false; }
				continue;
				}
		foreach (near in voisin)
			{
			if (AIRail.GetSignalType(tile, tile+near) != AIRail.SIGNALTYPE_NONE)	{ cError.ForceAction(AIRail.RemoveSignal, tile, tile+near); }
			}
		seek=AIRail.GetRailTracks(tile);
		if (seek != 255)
				{
				foreach (railtype, dummy in trackMap)
					if ((seek & railtype) == railtype)	{ cError.ForceAction(AIRail.RemoveRailTrack, tile, railtype); }
				}
		if (AIRail.GetRailTracks(tile) == 255)	{ targetTile.AddItem(tile, 0); }
										else	{ success = false; }
		}
	if (stationID != -1)	{ cStation.StationReleaseTile(many, stationID); }
	return success;
}

function cTrack::StationKillRailDepot(tile, stationID = -1)
// Just because we need to remove the depot at tile, and retry to make sure we can
	{
	if (!AIRail.IsRailDepotTile(tile))	{ return; }
	local vehlist=AIVehicleList();
	vehlist.Valuate(AIVehicle.GetState);
	vehlist.KeepValue(AIVehicle.VS_IN_DEPOT);
	vehlist.Valuate(AIVehicle.GetLocation);
	vehlist.KeepValue(tile);
	if (!vehlist.IsEmpty())	{ DInfo("Restarting trains at depot "+tile+" so we can remove it",1); }
	foreach (veh, dummy in vehlist)
		{
		DInfo("Starting "+cCarrier.GetVehicleName(veh)+"...",0);
		cTrain.SetDepotVisit(veh);
		cCarrier.StartVehicle(veh);
		}
	local removed = cError.ForceAction(AITile.DemolishTile, tile);
	if (!removed)	{ return false; }
	if (stationID == -1)	{ return true; }
	cStation.StationReleaseTile(tile, stationID);
	}

function cTrack::CheckCrossingRoad(tracklist, newtracktype)
// Check the railtrack list to see if we will have problem with crossing road tile, fixing it if we can
// return true if it's ok, false if we will get in trouble
{
	local tile_list = AIList();
	tile_list.AddList(tracklist);
	tile_list.Valuate(AITile.HasTransportType, AITile.TRANSPORT_ROAD);
	tile_list.KeepValue(1);
	if (tile_list.IsEmpty())	return true;
	// while we found crossing, they might not all bug us
	tile_list.Valuate(AIRail.GetRailType);
	tile_list.RemoveValue(newtracktype);
    local test_list = AIList();
    test_list.AddList(tile_list);
    local test_mode = AITestMode();
    foreach (tile, _ in test_list)
		{
		local test = AITestMode();
		if (AIRail.ConvertRailType(tile, tile, newtracktype))	tile_list.RemoveItem(tile);
		}
	test_mode = null;
	if (tile_list.IsEmpty())	return true;
	local voisin = [AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, 1)];
	foreach (tile, _ in tile_list)
		// if we at least remove enough of the road it will not be seen by HasTransportType anymore, and rail convertion works on non full road
		foreach (voisins in voisin)	AIRoad.RemoveRoad(tile, tile+voisins); // try to remove them
	tile_list.Valuate(AITile.HasTransportType, AITile.TRANSPORT_ROAD);
	tile_list.KeepValue(1);
	return tile_list.IsEmpty();
}

function cTrack::ConvertRailType(tile, newrt)
// return 1 ok, -1 not ok, 0 not ok but can retry
	{
    if (!AIMap.IsValidTile) { return 1; }
    if (tile == -1) { return 1; }
    if (AIRail.GetRailType(tile) == newrt)	{ return 1; }

	if (!cError.ForceAction(AIRail.ConvertRailType, tile, tile, newrt))
		{
		local error = AIError.GetLastError();
		if (error == AIError.ERR_NONE)	{ return 1; }
		if (error == AIError.ERR_NOT_ENOUGH_CASH)	{ return 0; }
		if (error == AIRail.ERR_RAILTYPE_DISALLOWS_CROSSING)	{ return 0; }
		DError("ConvertRailType fail with error="+error,1);
		AISign.BuildSign(tile, "EE");
		return -1;
		}
	return 1;
	}

function cTrack::GetRailTrackFromDirection(railtrack, direction)
// Change the railtrack to the railtrack need when direction is not SW->NE
{
	if (direction == DIR_NE)	return railtrack; // we assume build were done with SW->NE direction
	switch(direction)
		{
		case	DIR_SW: // NE -> SW
			if (railtrack == AIRail.RAILTRACK_NE_SW)	return AIRail.RAILTRACK_NE_SW;
			if (railtrack == AIRail.RAILTRACK_NW_SE)	return AIRail.RAILTRACK_NW_SE;
			if (railtrack == AIRail.RAILTRACK_NW_NE)	return AIRail.RAILTRACK_SW_SE; // upper left
			if (railtrack == AIRail.RAILTRACK_SW_SE)	return AIRail.RAILTRACK_NW_NE; // right
			if (railtrack == AIRail.RAILTRACK_NW_SW)	return AIRail.RAILTRACK_NE_SE; // left
			if (railtrack == AIRail.RAILTRACK_NE_SE)	return AIRail.RAILTRACK_NW_SW; // upper right
		break;
		case	DIR_SE: // NW -> SE
			if (railtrack == AIRail.RAILTRACK_NE_SW)	return AIRail.RAILTRACK_NW_SE;
			if (railtrack == AIRail.RAILTRACK_NW_SE)	return AIRail.RAILTRACK_NE_SW;
			if (railtrack == AIRail.RAILTRACK_NW_NE)	return AIRail.RAILTRACK_NE_SE;
			if (railtrack == AIRail.RAILTRACK_SW_SE)	return AIRail.RAILTRACK_NW_SW;
			if (railtrack == AIRail.RAILTRACK_NW_SW)	return AIRail.RAILTRACK_NW_NE;
			if (railtrack == AIRail.RAILTRACK_NE_SE)	return AIRail.RAILTRACK_SW_SE;

		break;
		case	DIR_NW: // SE -> NW
			if (railtrack == AIRail.RAILTRACK_NE_SW)	return AIRail.RAILTRACK_NW_SE;
			if (railtrack == AIRail.RAILTRACK_NW_SE)	return AIRail.RAILTRACK_NE_SW;
			if (railtrack == AIRail.RAILTRACK_NW_NE)	return AIRail.RAILTRACK_NW_SW;
			if (railtrack == AIRail.RAILTRACK_SW_SE)	return AIRail.RAILTRACK_NE_SE;
			if (railtrack == AIRail.RAILTRACK_NW_SW)	return AIRail.RAILTRACK_SW_SE;
			if (railtrack == AIRail.RAILTRACK_NE_SE)	return AIRail.RAILTRACK_NW_NE;
		break;
		}
	return railtrack;
}

function cTrack::GetRailTrackFromStationDirection(railtrack, station_direction)
// Again we assume the station direction is SW->NE
{
	if (station_direction == DIR_NE)	return railtrack;
	switch(station_direction)
		{
		case	DIR_SW: // NE -> SW
			if (railtrack == AIRail.RAILTRACK_NE_SW)	return AIRail.RAILTRACK_NE_SW;
			if (railtrack == AIRail.RAILTRACK_NW_SE)	return AIRail.RAILTRACK_NW_SE;
			if (railtrack == AIRail.RAILTRACK_NW_NE)	return AIRail.RAILTRACK_NW_SW;
			if (railtrack == AIRail.RAILTRACK_SW_SE)	return AIRail.RAILTRACK_NE_SE;
			if (railtrack == AIRail.RAILTRACK_NW_SW)	return AIRail.RAILTRACK_NW_NE;
			if (railtrack == AIRail.RAILTRACK_NE_SE)	return AIRail.RAILTRACK_SW_SE;
		break;
		case	DIR_SE: // NW -> SE
			if (railtrack == AIRail.RAILTRACK_NE_SW)	return AIRail.RAILTRACK_NW_SE;
			if (railtrack == AIRail.RAILTRACK_NW_SE)	return AIRail.RAILTRACK_NE_SW;
			if (railtrack == AIRail.RAILTRACK_NW_NE)	return AIRail.RAILTRACK_SW_SE;
			if (railtrack == AIRail.RAILTRACK_SW_SE)	return AIRail.RAILTRACK_NW_NE;
			if (railtrack == AIRail.RAILTRACK_NW_SW)	return AIRail.RAILTRACK_NW_SW;
			if (railtrack == AIRail.RAILTRACK_NE_SE)	return AIRail.RAILTRACK_NE_SE;
		break;
		case	DIR_NW: // SE -> NW
			if (railtrack == AIRail.RAILTRACK_NE_SW)	return AIRail.RAILTRACK_NW_SE;
			if (railtrack == AIRail.RAILTRACK_NW_SE)	return AIRail.RAILTRACK_NE_SW;
			if (railtrack == AIRail.RAILTRACK_NW_NE)	return AIRail.RAILTRACK_NW_SW;
			if (railtrack == AIRail.RAILTRACK_SW_SE)	return AIRail.RAILTRACK_NE_SE;
			if (railtrack == AIRail.RAILTRACK_NW_SW)	return AIRail.RAILTRACK_SW_SE;
			if (railtrack == AIRail.RAILTRACK_NE_SE)	return AIRail.RAILTRACK_NW_NE;
		break;
		}
	return railtrack;

/*	if (direction == AIRail.RAILTRACK_NW_SE)
			{
			railFront=AIRail.RAILTRACK_NW_SE;
			railCross=AIRail.RAILTRACK_NE_SW;
			if (useEntry)	  // going NW->SE
					{
					railLeft=AIRail.RAILTRACK_SW_SE;
					railRight=AIRail.RAILTRACK_NE_SE;
					railUpLeft=AIRail.RAILTRACK_NW_SW;
					railUpRight=AIRail.RAILTRACK_NW_NE;
					}
			else	  // going SE->NW
					{
					railLeft=AIRail.RAILTRACK_NW_NE;
					railRight=AIRail.RAILTRACK_NW_SW;
					railUpLeft=AIRail.RAILTRACK_NE_SE;
					railUpRight=AIRail.RAILTRACK_SW_SE;
					}
			goal=AIMap.GetTileIndex(AIMap.GetTileX(frontTile),AIMap.GetTileY(crossing));
			}
	else	  // NE_SW
			{
			railFront=AIRail.RAILTRACK_NE_SW;
			railCross=AIRail.RAILTRACK_NW_SE;
			if (useEntry)	  // going NE->SW
					{
					railLeft=AIRail.RAILTRACK_NW_SW;
					railRight=AIRail.RAILTRACK_SW_SE;
					railUpLeft=AIRail.RAILTRACK_NW_NE;
					railUpRight=AIRail.RAILTRACK_NE_SE;
					}
			else	  // going SW->NE
					{
					railLeft=AIRail.RAILTRACK_NE_SE;
					railRight=AIRail.RAILTRACK_NW_NE;
					railUpLeft=AIRail.RAILTRACK_SW_SE;
					railUpRight=AIRail.RAILTRACK_NW_SW;
					}
			goal=AIMap.GetTileIndex(AIMap.GetTileX(crossing),AIMap.GetTileY(frontTile));
			}   */
}

function cTrack::BuildRailAtTile(railneed, pos, create, stationID = -1)
/** @brief Add a railtrack at position
 *
 * @param railneed The rail track to build.
 * @param pos The tile to work at
 * @param create true to create a track, false to remove it
 * @param stationID the station to assign the track with
 * @param useEntry The entry/exit of the stationID
 * @return True on success
 *
 */
{
	local lasterr = -1;
	if (!create)
			{
			if (!AIRail.IsRailTile(pos))	{ return true; }
									else	{ return cError.ForceAction(AIRail.RemoveRailTrack, pos, railneed); }
			}
	local count = 100;
	local success = AIRail.BuildRailTrack(pos, railneed);
	while (!success && count > 0)
			{
			success = AIRail.BuildRailTrack(pos, railneed);
			count--;
			lasterr = AIError.GetLastError();
			switch (lasterr)
					{
					case	AIError.ERR_AREA_NOT_CLEAR:
						if (!cTileTools.DemolishTile(pos))	{ cError.RaiseError(); return false; }
						break;
					case	AIError.ERR_VEHICLE_IN_THE_WAY:
							AIController.Sleep(10);
						break;
					case AIError.ERR_ALREADY_BUILT:
						return true;
					default:
						DError("Cannot build rail track at " + cMisc.Locate(pos),1);
						cError.RaiseError();
						return false;
					}
			}
	if (success && stationID != -1)	{ cStation.StationClaimTile(pos, stationID); }
	return true;
}
