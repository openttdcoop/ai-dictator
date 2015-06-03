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

function cBuilder::EvalDistanceProduction(tilelist, srcplace, dstplace)
// This set a new AIList with a ratio distance/value of the given tilelist list
// The list should be the tiles to check, and their value already set to something of value ;  like AITile.GetCargoProduction
{
	local n_list = AIList();
	local origin_dir = cDirection.GetDirection(srcplace, dstplace);
	foreach (tile, value in tilelist)
		{
		local distance = cDirection.GetDistanceChebyshevToTile(tile, dstplace);
		local points = 300 + (value * 1.2); // a bonus by prod
		points -= distance; // a malus by distance
        local cur_dir = cDirection.GetDirection(srcplace, tile);
        switch (origin_dir)
			{
			case	DIR_NE:
					if (cur_dir == DIR_NE)	points *= 2;	// 2x bonus going the right direction
					if (cur_dir == DIR_SW)	points *= 0.5;	// 2x malus going opposite direction
					break;
			case	DIR_NW:
					if (cur_dir == DIR_NW)	points *= 2;
					if (cur_dir == DIR_SE)	points *= 0.5;
					break;
			case	DIR_SE:
					if (cur_dir == DIR_SE)	points *= 2;
					if (cur_dir == DIR_NW)	points *= 0.5;
					break;
			case	DIR_SW:
					if (cur_dir == DIR_SW)	points *= 2;
					if (cur_dir == DIR_NE)	points *= 0.5;
					break;
			}
		points = points.tointeger();
        n_list.AddItem(tile, points);
        }
	n_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
	return n_list;
}

function cBuilder::CheckStationPositionFrontIsClear(tile, depth, direction)
// check if front tile of station will be ok to build, return true if it's ok
{
	local left;
	if (direction == DIR_SE || direction == DIR_NW) left = cDirection.GetLeftRelativeFromDirection(DIR_NW);
											else	left = cDirection.GetLeftRelativeFromDirection(DIR_SW);
	local forward = cDirection.GetForwardRelativeFromDirection(direction);
//	if (direction == DIR_SE || direction == DIR_SW)	tile += forward * (depth -1);
//	local zone = cTileTools.GetRectangle(tile, tile + left + (forward * 4), null);
AISign.BuildSign(tile,"X");
print("frontisclear at "+cMisc.Locate(tile));
	local startzone, endzone;
	startzone = tile;
	endzone = tile + left + (forward * 4) + (forward * (depth -1));
	if (direction == DIR_NE || direction == DIR_NW) { startzone = tile - (forward * 4); endzone = tile + left + (forward * (depth -1)); }
	print("startzone ="+cMisc.Locate(startzone));
	print("endzoen = "+cMisc.Locate(endzone));
	local zone = cTileTools.GetRectangle(startzone, endzone, null);
	cDebug.showLogic(zone);
	local cost = cTerraform.IsAreaClear(zone, true, true);
	if (cost == -1 || !cBanker.CanBuyThat(cost))	return false;
    cTerraform.IsAreaClear(zone, true, false); // now clear it
    if (INSTANCE.terraform)	cTerraform.TerraformLevelTiles(zone, null);
    return cTerraform.IsAreaBuildableAndFlat(zone, 0);
}

function cBuilder::BuildTrainStation(start)
// It's where we find a spot for our train station
// Unlike classic stations that need best spot where to get cargo, train stations best spot
// is the one that can do its task while still provide most space to futher allow station upgrading
	{
	// for industry: to grab goods: best is near where it produce and closest to target
	// to drop goods: best is farest target while still accept goods
	// train station best direction is | when left or right the industry
	// and -- when up or down the industry location, this offer best upgrade chance
	// for town, saddly it's contrary, station is best -- when left/right and | when up/down
	// because that configuration will almost always cut entry or exit point of station, but offer higher
	// chance to enlarge the station without going too much into the city
	local dir, otherplace, sourceplace, tile_NE_SW, tile_NW_SE;
	local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
	local istown=false;
	local platnum = 2;
	local checkit = -1;
	if (start)
			{
			dir = cDirection.GetDirection(INSTANCE.main.route.SourceProcess.Location, INSTANCE.main.route.TargetProcess.Location);
			print("dir source="+cDirection.DirectionToString(dir));
			if (INSTANCE.main.route.SourceProcess.IsTown)
					{
					tile_NE_SW = cTileTools.GetTilesAroundTown(INSTANCE.main.route.SourceProcess.ID);
                    tile_NE_SW.Valuate(AITile.IsBuildable);
                    tile_NE_SW.KeepValue(1);
                    tile_NW_SE = AIList();
                    tile_NW_SE.AddList(tile_NE_SW);
					tile_NE_SW.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.CargoID, INSTANCE.main.carrier.train_length, platnum, rad);
					tile_NE_SW.KeepAboveValue(0);
					tile_NW_SE.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.CargoID, platnum, INSTANCE.main.carrier.train_length, rad);
					tile_NW_SE.KeepAboveValue(0);

                    istown=true;
					}
			else
					{
					tile_NE_SW = cTileTools.GetTilesAroundPlace(INSTANCE.main.route.SourceProcess.Location, 15);
					tile_NE_SW.Valuate(AITile.IsBuildable);
                    tile_NE_SW.KeepValue(1);
                    tile_NW_SE = AIList();
                    tile_NW_SE.AddList(tile_NE_SW);
					tile_NE_SW.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.CargoID, INSTANCE.main.carrier.train_length, platnum, rad);
					tile_NE_SW.KeepAboveValue(0);
					tile_NW_SE.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.CargoID, platnum, INSTANCE.main.carrier.train_length, rad);
					tile_NW_SE.KeepAboveValue(0);
                    istown=false;
					}
			sourceplace=INSTANCE.main.route.SourceProcess.Location;
			otherplace=INSTANCE.main.route.TargetProcess.Location;
			}
	else
			{
			dir = cDirection.GetDirection(INSTANCE.main.route.TargetProcess.Location, INSTANCE.main.route.SourceProcess.Location);
			print("dir target="+cDirection.DirectionToString(dir));
			if (INSTANCE.main.route.TargetProcess.IsTown)
					{
					tile_NE_SW = cTileTools.GetTilesAroundTown(INSTANCE.main.route.TargetProcess.ID);
                    tile_NE_SW.Valuate(AITile.IsBuildable);
                    tile_NE_SW.KeepValue(1);
                    tile_NW_SE = AIList();
                    tile_NW_SE.AddList(tile_NE_SW);
					tile_NE_SW.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.CargoID, INSTANCE.main.carrier.train_length, platnum, rad);
					tile_NE_SW.KeepAboveValue(7);
					tile_NW_SE.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.CargoID, platnum, INSTANCE.main.carrier.train_length, rad);
					tile_NW_SE.KeepAboveValue(7);
                    istown=true;
					}
			else
					{
					tile_NE_SW = cTileTools.GetTilesAroundPlace(INSTANCE.main.route.TargetProcess.Location, 15);
					tile_NE_SW.Valuate(AITile.IsBuildable);
                    tile_NE_SW.KeepValue(1);
                    tile_NW_SE = AIList();
                    tile_NW_SE.AddList(tile_NE_SW);
					tile_NE_SW.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.CargoID, INSTANCE.main.carrier.train_length, platnum, rad);
					tile_NE_SW.KeepAboveValue(7);
					tile_NW_SE.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.CargoID, platnum, INSTANCE.main.carrier.train_length, rad);
					tile_NW_SE.KeepAboveValue(7);
					istown=false;
					}
			sourceplace=INSTANCE.main.route.TargetProcess.Location;
           	otherplace=INSTANCE.main.route.SourceProcess.Location;
			}
	tile_NE_SW = cBuilder.EvalDistanceProduction(tile_NE_SW, sourceplace, otherplace);
	tile_NW_SE = cBuilder.EvalDistanceProduction(tile_NW_SE, sourceplace, otherplace);
	cTileTools.PurgeBlackListTiles(tile_NE_SW, true);
	cTileTools.PurgeBlackListTiles(tile_NW_SE, true);
	local success = false;
	local buildmode = 0;
	local cost = 10 * AIRail.GetBuildCost(AIRail.GetCurrentRailType(),AIRail.BT_STATION);
	DInfo("Rail station cost: "+cost+" byinflat"+(cost*cBanker.GetInflationRate().tointeger()),2);
	cBanker.GetMoney(cost*2);
	//local ssize= INSTANCE.main.carrier.train_length;
	/* 2 build mode:
	- try find a place with cheap (a place that can hold it without terraforming)
	- try again with terraforming enable
	*/
	local dir_NE_SW = AIRail.RAILTRACK_NE_SW;
	local dir_NW_SE = AIRail.RAILTRACK_NW_SE;
	local station_direction, fav_station_direction, alt_station_direction, goingdir;
	if (dir == DIR_NW || dir == DIR_SE)	{ fav_station_direction = dir_NW_SE; alt_station_direction = dir_NE_SW; }
								else	{ fav_station_direction = dir_NE_SW; alt_station_direction = dir_NW_SE; }
	local swidth, slength;
	local tilelist = AIList();
	do		{
			if (buildmode > 1)	station_direction = alt_station_direction;
						else	station_direction = fav_station_direction;
			if (station_direction == dir_NW_SE)
						{
						// platnum is the width when NW_SE
						swidth = platnum;
						slength = INSTANCE.main.carrier.train_length;
						tilelist.Clear();
						tilelist.AddList(tile_NW_SE);
						}
				else	{
						swidth = INSTANCE.main.carrier.train_length;
						slength = platnum;
						tilelist.Clear();
						tilelist.AddList(tile_NE_SW);
						}
			goingdir = cDirection.GetDirectionFromStationDirection(sourceplace, otherplace, station_direction);
			print("buildmode = "+buildmode+" direction = "+cDirection.DirectionToString(dir)+" list="+tilelist.Count()+" stationdir = "+station_direction+" goingdir = "+ goingdir);
			foreach (tile, _ in tilelist)
				{
				local result = null;
				switch (buildmode)
						{
						case	0:
						case	2:
							result = cTerraform.IsRectangleBuildableAndFlat(tile, swidth, slength, 2);
							if (result)	result = cBuilder.CheckStationPositionFrontIsClear(tile, slength, goingdir);
							if (result)	checkit = tile;
								else	checkit = -1;
							break;
						case	1:
						case	3:
							result = cTerraform.CheckRectangleForConstruction(tile, swidth, slength, true, 3, true);
                            print("money to terraform: "+result);
							if (result != -1)	{ if (!cBuilder.CheckStationPositionFrontIsClear(tile, slength, goingdir))	result = -1; }
							if (result != -1 && cBanker.CanBuyThat(result))
										{
										local z = null;
										z = cTileTools.GetRectangle(tile, swidth, slength);
										//if (station_direction == AIRail.RAILTRACK_NW_SE)	z = cTileTools.GetRectangle(tile, platnum, ssize);
											//										else	z = cTileTools.GetRectangle(tile, ssize, platnum);
										checkit = -1;
										cTerraform.IsAreaClear(z, true, false);
										if (cTerraform.TerraformLevelTiles(z, null))	checkit = tile;
										print("terraform say "+checkit);
										}
								else	checkit = -1;
							break;
						}
				if (checkit != -1)
						{
						print("Station could be built at "+cMisc.Locate(tile));
						local newGRF = [];
						newGRF.push(AIStation.STATION_NEW);
						newGRF.push(INSTANCE.main.route.CargoID);
						newGRF.push(INSTANCE.main.route.SourceProcess.UID);
						newGRF.push(INSTANCE.main.route.TargetProcess.UID);
						newGRF.push(start);
/*						local entry_part = INSTANCE.main.route.Source_RailEntry;
						if (!start)	entry_part = INSTANCE.main.route.Target_RailEntry;*/
						goingdir = cDirection.GetDirectionFromStationDirection(sourceplace, otherplace, station_direction);
						print("dir = "+cDirection.DirectionToString(dir) + " real_dir = "+cDirection.DirectionToString(goingdir));
						local entry_part = (goingdir == DIR_NE || goingdir == DIR_NW);
						success = cStationRail.CreateAndBuildTrainStation(checkit, station_direction, platnum, entry_part, newGRF);
						print("success? "+success);
						if (!success)
									{
									if (cError.IsError())	cTileTools.BlackListTile(checkit, -100);
													else	return false;
									}
							else	break;
						}
				}
			buildmode++;
			}
	while (buildmode < 4 && !success);
	if (!success)
			{
			DInfo("Can't find a good place to build the train station ! "+tilelist.Count(),1);
			if (tilelist.IsEmpty())	{ cError.RaiseError(); }
			return false;
			}
	// here, so we success to build one
	local staID = AIStation.GetStationID(checkit);
	print("staID ="+staID+" statile="+checkit+" start="+start);
	if (start)	{ INSTANCE.main.route.SourceStation = staID; }
		else	{ INSTANCE.main.route.TargetStation = staID; }
//	INSTANCE.main.route.CreateNewStation(start);
	return true;
	}

function cBuilder::EasyError(error)
// Just return if the error is something really simple we could handle with few time or bucks
// 0 no error
// -1 a temp easy solvable error
// -2 a big error
	{
	print("easy error: "+error+" "+AIError.GetLastErrorString());
	switch (error)
			{
			case	AIError.ERR_NONE:
				return 0;
			case	AIError.ERR_NOT_ENOUGH_CASH :
				return -1;
			case	AIError.ERR_ALREADY_BUILT:
				return 0;
			case	AIError.ERR_VEHICLE_IN_THE_WAY:
				return -1;
			case	AIError.ERR_OWNED_BY_ANOTHER_COMPANY:
				return -2;
			}
	return -2;
	}

function cBuilder::BuildPath_RAIL(head1, head2, stationID, primary, useEntry)
{
	local status = cPathfinder.GetStatus(head1, head2, stationID, primary, useEntry);
	local mytask = cPathfinder.GetPathfinderObject(cPathfinder.GetUID(head1, head2));
	if (mytask == null)	return -3;
    local Destroy = (status == -2);
	if (status == 2) // success
		{
		DInfo("Pathfinder task "+mytask.UID+" succeed !",1);
		local verifypath = RailFollower.GetRailPathing(mytask.source, mytask.target);
		if (verifypath.IsEmpty())	{ DInfo("Pathfinder task "+mytask.UID+" fail checks.",1); Destroy = true; }
							else	{
									DInfo("Pathfinder task "+mytask.UID+" pass checks.",2);
									INSTANCE.buildDelay = 0;
									//if (!primary)	cBuilder.RailStationPathfindAltTrack(uid_obj);
									return 0;
									}
		}
	if (Destroy)
		{
		mytask.status = -2;
		DError("Pathfinder task "+mytask.UID+" fails when checking the path.",1);
		local badtiles=AIList();
		badtiles.AddList(cTileTools.TilesBlackList); // keep blacklisted tiles for -stationID
		badtiles.KeepValue(0 - (100000 + mytask.stationID));
		cTrack.RailCleaner(badtiles); // remove all rail we've built
		cTileTools.TilesBlackList.RemoveList(badtiles); // and release them for others
		cError.RaiseError();
		//if (!primary)	cBuilder.RailStationPathfindAltTrack(uid_obj);
		return -2;
		}

	local smallerror = 0;
	if (status == -1 || status == -2)	smallerror = -2; // failure, we have nothing to do if status is already set to failure
	local path = cPathfinder.GetSolve(head1, head2);
	if (path == null)	{ smallerror = -2; } // if we couldn't get a valid solve here, there's something wrong then
	cBuilder.Path_Optimizer(path);
	cBanker.RaiseFundsBigTime();
	local prev = null;
	local prevprev = null;
	local pp1, pp2, pp3 = null;
	local walked=[];
	cTrack.SetRailType(AIRail.GetRailType(AIStation.GetLocation(stationID)));
	while (path != null && smallerror == 0)
			{
			if (prevprev != null)
					{
					if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1)
							{
							if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile())
									{
									if (!AITunnel.BuildTunnel(AIVehicle.VT_RAIL, prev))
											{
											DInfo("An error occured while I was building the tunnel: " + AIError.GetLastErrorString(),2);
											smallerror=cBuilder.EasyError(AIError.GetLastError());
											if (smallerror==-1)
													{
													DInfo("That tunnel would be too expensive. Construction aborted.",2);
													return -1;
													}
											if (smallerror==-2)	{ break; }
											}
									else
											{
											cTileTools.BlackListTile(prev, 0 -(100000+stationID));
											// i mark them as blacklist and assign to -stationID, so i could recover them later
											cTileTools.BlackListTile(path.GetTile(), 0 - (100000+stationID));
											}
									}
							else
									{
									local bridgeID = cBridge.GetCheapBridgeID(AIVehicle.VT_RAIL, AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
									if (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridgeID, prev, path.GetTile()))
											{
											DInfo("An error occured while I was building the bridge: " + AIError.GetLastErrorString(),2);
											smallerror=cBuilder.EasyError(AIError.GetLastError());
											if (smallerror==-1)
													{
													DInfo("That bridge would be too expensive. Construction aborted.",2);
													return -1;
													}
											if (smallerror==-2)	{ break; }
											}
									else
											{
											cTileTools.BlackListTile(prev, 0 - (100000+stationID));
											cTileTools.BlackListTile(path.GetTile(), 0 -(100000+stationID));
											}
									cBridge.IsBridgeTile(prev); // force bridge check
									}
							pp3 = pp2;
							pp2 = pp1;
							pp1 = prevprev;
							prevprev = prev;
							prev = path.GetTile();
							path = path.GetParent();
							walked.push(prev);
							}
					else
							{
							local targetTile=path.GetTile();
                            /*local slope_c = AITile.GetSlope(prev);
                            local slope_a = AITile.GetSlope(targetTile);
                            local slope_add = slope_a + slope_c;
							if (slope_c != AITile.SLOPE_FLAT && slope_a != AITile.SLOPE_FLAT && ((slope_add == AITile.SLOPE_NW || slope_add == AITile.SLOPE_NW || slope_add == AITile.SLOPE_SE || slope_add == AITile.SLOPE_NE) || (AITile.IsSteepSlope(prev) && AITile.IsSteepSlope(targetTile)) || ((slope_c ^ slope_a) == 15 && (slope_c == AITile.SLOPE_NW || slope_c == AITile.SLOPE_SW || slope_c == AITile.SLOPE_SE || slope_c == AITile.SLOPE_NE))))
								{ // kill small climb/down we could avoid
								cTerraform.TerraformLevelTiles(prevprev, targetTile);
								}*/
							if (!AIRail.BuildRail(prevprev, prev, targetTile))
									{
									smallerror = cBuilder.EasyError(AIError.GetLastError());
									if (smallerror == -1)
											{
											DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
											return -1;
											}
									if (smallerror==-2)	{ break; }
									}
							else
									{
									cTileTools.BlackListTile(prev, 0 - (100000+stationID));
									cTileTools.BlackListTile(path.GetTile(), 0 -(100000+stationID));
									}
							}
					}
			if (path != null)
					{
					pp3 = pp2;
					pp2 = pp1;
					pp1 = prevprev;
					prevprev = prev;
					prev = path.GetTile();
					path = path.GetParent();
					walked.push(prev);
					}
			}
	if (smallerror == -2)
			{
			DError("Pathfinder has detect a failure with "+mytask.UID,1);
			if (walked.len() < 4)
					{
					DInfo("Pathfinder cannot do more",1);
					DInfo("Pathfinder task "+mytask.UID+" failure !",1);
					local badtiles = AIList();
					badtiles.AddList(cTileTools.TilesBlackList); // keep blacklisted tiles for -stationID
					badtiles.KeepValue(0 - (100000+ mytask.stationID));
					cTrack.RailCleaner(badtiles); // remove all rail we've built
					cTileTools.TilesBlackList.RemoveList(badtiles); // and release them for others
					cError.RaiseError();
					//if (!primary)	cBuilder.RailStationPathfindAltTrack(uid_obj);
					return -2;
					}
			else
					{
					local maxstepback=10;
					walked.pop(); // dismiss last one, it's the failure
					if (walked.len() < maxstepback)	{ maxstepback=walked.len()-1; }
					local alist=AIList();
					for (local ii=1; ii < maxstepback; ii++)
							{
							prev=walked.pop();
							alist.AddItem(prev, 0);
							}
					prevprev=walked.pop();
					cTrack.RailCleaner(alist);
					cTileTools.TilesBlackList.RemoveList(alist);
					local newtarget=[prev, prevprev];
					DInfo("Pathfinder is calling an helper task",1);
					cPathfinder.CreateSubTask(mytask.UID, head1, newtarget);
					return -1;
					}
			}
	return 0; // success
}


function cBuilder::GetRailBitMask(rails)
// Return a nibble bitmask with each NE,SW,NW,SE direction set to 1
	{
	local   NE = 1; // we will use them as bitmask
	local	SW = 2;
	local	NW = 4;
	local	SE = 8;
	local trackMap=AIList();
	trackMap.AddItem(AIRail.RAILTRACK_NE_SW,	NE + SW);	// AIRail.RAILTRACK_NE_SW
	trackMap.AddItem(AIRail.RAILTRACK_NW_SE,	NW + SE);	// AIRail.RAILTRACK_NW_SE
	trackMap.AddItem(AIRail.RAILTRACK_NW_NE,	NW + NE);	// AIRail.RAILTRACK_NW_NE
	trackMap.AddItem(AIRail.RAILTRACK_SW_SE,	SW + SE);	// AIRail.RAILTRACK_SW_SE
	trackMap.AddItem(AIRail.RAILTRACK_NW_SW,	NW + SW);	// AIRail.RAILTRACK_NW_SW
	trackMap.AddItem(AIRail.RAILTRACK_NE_SE,	NE + SE);	// AIRail.RAILTRACK_NE_SE
	if (rails==255)	{ return 0; } // invalid rail
	local railmask=0;
	foreach (tracks, value in trackMap)
		{
		if ((rails & tracks)==tracks)	{ railmask=railmask | value; }
		if (railmask==(NE+SW+NW+SE))	{ return railmask; } // no need to test more tracks
		}
	return railmask;
	}

function cBuilder::AreRailTilesConnected(tilefrom, tileto, stricttype=true)
// Look at tilefront and build rails to connect that tile to its neightbourg tiles that are us with rails
// tilefrom, tileto : tiles to check
// return true if you can walk from tilefrom to tileto
// stricttype : true to only allow walking same railtype, false allow walking on different railtype
	{
	local atemp=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
	if (AITile.GetOwner(tilefrom) != atemp)	{ return false; } // not own by us
	if (AITile.GetOwner(tileto) != atemp) { return false; } // not own by us
	atemp=AIRail.GetRailType(tilefrom);
	if (AIRail.GetRailType(tileto) != atemp && stricttype)	{ return false; } // not same railtype
	local NE = 1; // we will use them as bitmask
	local	SW = 2;
	local	NW = 4;
	local	SE = 8;
	local direction=cDirection.GetDirection(tilefrom, tileto);
	local tilefrom_mask=cBuilder.GetRailBitMask(AIRail.GetRailTracks(tilefrom));
	local tileto_mask=cBuilder.GetRailBitMask(AIRail.GetRailTracks(tileto));
	local tilefrom_need, tileto_need=0;
	switch (direction)
			{
			case	0: // SE-NW, it's easy, if we want go SE->N
				tilefrom_need=NW;
				tileto_need=SE;
				break;
			case	1: // NW-SE
				tilefrom_need=SE;
				tileto_need=NW;
				break;
			case	2: // SW-NE
				tilefrom_need=NE;
				tileto_need=SW;
				break;
			case	3: // NE-SW
				tilefrom_need=SW;
				tileto_need=NE;
				break;
			}
	if (AIRail.IsRailDepotTile(tileto) && AIRail.GetRailDepotFrontTile(tileto)==tilefrom)	{ tileto_mask=tileto_need; }
	if (AIRail.IsRailDepotTile(tilefrom) && AIRail.GetRailDepotFrontTile(tilefrom)==tileto)	{ tilefrom_mask=tilefrom_need; }
	// if we have a depot, make it act like it is a classic rail if its entry match where we going or come from
	if (cBridge.IsBridgeTile(tileto) || AITunnel.IsTunnelTile(tileto))
			{
			local endat=null;
			endat=cBridge.IsBridgeTile(tileto) ? AIBridge.GetOtherBridgeEnd(tileto) : AITunnel.GetOtherTunnelEnd(tileto);
			local jumpdir=cDirection.GetDirection(tileto, endat);
			if (jumpdir == direction) // if the bridge/tunnel goes the same direction, then consider it a plain rail
					{
					tileto_mask=tileto_need;
					}
			}
	if (cBridge.IsBridgeTile(tilefrom) || AITunnel.IsTunnelTile(tilefrom))
			{
			local endat=null;
			endat=cBridge.IsBridgeTile(tilefrom) ? AIBridge.GetOtherBridgeEnd(tilefrom) : AITunnel.GetOtherTunnelEnd(tilefrom);
			local jumpdir=cDirection.GetDirection(endat, tilefrom); // reverse direction to find the proper one
			if (jumpdir == direction) // if the bridge/tunnel goes the same direction, then consider it a plain rail
					{
					tilefrom_mask=tilefrom_need;
					}
			}
	if ( (tilefrom_mask & tilefrom_need)==tilefrom_need && (tileto_mask & tileto_need)==tileto_need)	{ return true; }
	return false;
	}

function cBuilder::GetRailTracks(tile)
// Return the rail tracks as AIRail.GetRailTracks, except it convert depot, tunnel and bridge to a railtrack
	{
	local trackinfo = AIRail.GetRailTracks(tile);
	if (trackinfo==255)
			{
			// maybe a tunnel, depot or bridge that "could" also be valid entries
			local testdir=null;
			local test = null;
			if (AIRail.IsRailDepotTile(tile))
					{
					test=AIRail.GetRailDepotFrontTile(tile);
					testdir=cDirection.GetDirection(tile, test);
					DInfo("Rail depot found",2);
					trackinfo= (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
					}
			if (AITunnel.IsTunnelTile(tile))
					{
					test=AITunnel.GetOtherTunnelEnd(tile);
					testdir=cDirection.GetDirection(tile, test);
					DInfo("Tunnel found",2);
					trackinfo = (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
					}
			if (cBridge.IsBridgeTile(tile))
					{
					test=AIBridge.GetOtherBridgeEnd(tile);
					testdir=cDirection.GetDirection(tile, test);
					DInfo("Bridge found",2);
					trackinfo = (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
					}
			}
	return trackinfo;
	}

function cBuilder::RailConnectorSolver(tile_link, tile_target, everything=true)
// Look at tile_target and build rails to connect that tile to tile_link
// Tiles must be direct neighbor (distance = 1) and same rail type (or no rails at tile_target)
// tile_link : the tile to connect tile_target with
// tile_target : tile we will work on (build rails)
// everything: if true we will connect tile_target to all its neighbors and not only to tile_link
// only return false if we fail to build all tracks need at tile_target (and raise critical error)
	{
	if (AITile.GetDistanceManhattanToTile(tile_link,tile_target) != 1)
			{ DError("We must use two tiles close to each other ! tile_link="+tile_link+" tile_target="+tile_target,1); return false; }
	local track_orig = cBuilder.GetRailTracks(tile_link);
	if (track_orig == 255)	{ DWarn("No tracks found at "+tile_link,1); return false; }
	local track_dest = cBuilder.GetRailTracks(tile_target);
	local voisin=[AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0,-1), AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)]; // SE, NW, SW, NE
	local   NE = 1; // we will use them as bitmask
	local	SW = 2;
	local	NW = 4;
	local	SE = 8;
	local WorkTiles = AIList();
	local type_orig = AIRail.GetRailType(tile_link);
	local track_dest = cBuilder.GetRailTracks(tile_target);
	if (track_dest != 255 && AIRail.GetRailType(tile_target) != type_orig)
            { DWarn("Cannot connect rail tiles because railtype aren't the same",1); return false; }
    local z = 3;
	for (local i=0; i < 4; i++)
			{
			if (tile_target+voisin[i] == tile_link)	{ continue; } // we will add it later, see allTiles()
			if (AIRail.GetRailType(tile_target+voisin[i]) != type_orig)	{ continue;}
			if (!AICompany.IsMine(AITile.GetOwner(tile_target+voisin[i])))	{ continue; }
			WorkTiles.AddItem(tile_target+voisin[i],z);
			z++;
			}
	local trackMap = AIList(); // item=two points added, value=the track need to link 1st point with 2nd point
	local edges = [];
	edges.push(NE); edges.push(SW); edges.push(NW); edges.push(SE);
	local tracks = [];
	trackMap.AddItem(NE + SW, AIRail.RAILTRACK_NE_SW);
	trackMap.AddItem(NW + SE, AIRail.RAILTRACK_NW_SE);
	trackMap.AddItem(NW + NE, AIRail.RAILTRACK_SW_SE);
	trackMap.AddItem(SW + SE, AIRail.RAILTRACK_NW_NE);
	trackMap.AddItem(NW + SW, AIRail.RAILTRACK_NE_SE);
	trackMap.AddItem(NE + SE, AIRail.RAILTRACK_NW_SW);
	local directionmap= AIList();
	directionmap.AddItem(0, SE); // for SE->NW
	directionmap.AddItem(1, NW); // for NW->SE
	directionmap.AddItem(2, SW); // for SW->NE
	directionmap.AddItem(3, NE); // for NE->SW
	local addtrack = [];
	local seek_search = null;
	local mask_seek = null;
	local mask_voisin = null;
	local allTiles = AIList();
	local filter = AIList();
	allTiles.AddItem(tile_link,2); // add the link tile
	for (local i = 2; i < 6; i++)   filter.AddItem(i*i, 0); // filter duplicates
	if (everything)	{
                    foreach (tile, index in WorkTiles)
                            {
                            allTiles.AddItem(tile, index); // would have been easier to tile*tile but squirrel overflow fast
                            }
                    }
	foreach (tile_seek, seek_index in allTiles)
		{
		mask_seek = cBuilder.GetRailBitMask(cBuilder.GetRailTracks(tile_seek));
		foreach (dest, dest_index in WorkTiles)
			{
            if (filter.HasItem(seek_index*dest_index))  { continue; }
                                                else    { filter.AddItem(seek_index*dest_index,0); }
            mask_voisin = cBuilder.GetRailBitMask(cBuilder.GetRailTracks(dest));
            seek_search = directionmap.GetValue(cDirection.GetDirection(tile_target, tile_seek));
			// we ask direction target->seek to find what point tile_seek need set, so SW-SE = SW
            local dest_search = directionmap.GetValue(cDirection.GetDirection(tile_target, dest));
			if ( (dest_search & mask_voisin) == dest_search && (seek_search & mask_seek) == seek_search )
					{
                  	addtrack.push(dest_search + seek_search);
					}
			} //foreach WorkTiles
		} // foreach allTiles
   	if (addtrack.len()>0)
		foreach (pair in addtrack)
			{
   			local track = trackMap.GetValue(pair);
   			if (!cTrack.DropRailHere(track, tile_target))
					{
					cError.IsCriticalError();
					if (cError.IsError())	{ return false; }
					}
			}
	return true;
	}

function cBuilder::SignalBuilder(source, target)
// Follow all directions to walk through the path starting at source, ending at target
// return true if we build all signals
	{
	local max_signals_distance=5;
	local spacecounter=0;
	local signdir=0;
	local railpath=AIList();
	local directions=[AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(1, 0)];
	local dir=null;
	local sourcedir=null;
	local targetdir=null;
	cDebug.PutSign(source,"S");
	cDebug.PutSign(target,"T");
	local sourcecheck=null;
	local targetcheck=null;
	foreach (voisin in directions)
		{
		if (AIRail.GetSignalType(source, source+voisin) == AIRail.SIGNALTYPE_PBS)
				{
				sourcedir=cDirection.GetDirection(source+voisin, source);
				DInfo("Found source signal at "+source+" facing "+sourcedir+" voisin="+(source+voisin),2);
				sourcecheck=source+voisin; // to feed pathfinder with a tile without the signal on it
				cDebug.PutSign(sourcecheck,"s");
				}
		}
	if (sourcedir == null)	{ DError("Cannot find source signal at "+source,2); cError.RaiseError(); return false; }
	foreach (voisin in directions)
		{
		if (AIRail.GetSignalType(target, target+voisin) == AIRail.SIGNALTYPE_PBS)
				{
				targetdir=cDirection.GetDirection(target+voisin, target);
				DInfo("Found target signal at "+target+" facing "+targetdir+" voisin="+(target+voisin),2);
				targetcheck=target+voisin;
				cDebug.PutSign(targetcheck,"t");
				}
		}
	if (targetdir == null)	{ DError("Cannot find target signal at "+target,2); cError.RaiseError(); return false; }
	local pathwalker = RailFollower();
	pathwalker.InitializePath([[source, sourcecheck]], [[targetcheck, target]]);// start beforestart    end afterend
	local path = pathwalker.FindPath(20000);
	if (path == null)	{ DError("Pathwalking failure.",2); cError.RaiseError(); return false; }
	local cc=0;
	local prev = path.GetTile();
	local allsuccess=true;
	local tilesource, tilefront = null;
	while (path != null)
			{
			local tile = path.GetTile();
			switch (targetdir) // target cause the path is record from target->source
					{
					case	0: // SE-NW
						tilesource=prev;
						tilefront=tile;
						break;
					case	1: // NW-SE
						tilesource=prev;//*
						tilefront=tile;
						break;
					case	2: // SW-NE
						tilesource=prev;
						tilefront=tile;
						break;
					case	3: // NE-SW //*
						tilesource=prev;
						tilefront=tile;
						break;
					}
			if (cc >= max_signals_distance)
					{
					local ignoreit=false;
					if (AIRail.GetSignalType(tilesource,tilefront) != AIRail.SIGNALTYPE_NONE)	{ ignoreit=true; }
					if (cBridge.IsBridgeTile(tilesource) || AITunnel.IsTunnelTile(tilesource))	{ ignoreit=true; }
					if (ignoreit)	{ cc=0; prev=tile; continue; }
					if (AIRail.BuildSignal(tilesource,tilefront, AIRail.SIGNALTYPE_NORMAL))	{ cc=0; }
					else	{
							cDebug.PutSign(tile,"!");
							local smallerror=cBuilder.EasyError(AIError.GetLastError());
							DError("Error building signal ",1);
							//max_signals_distance++;
							if (smallerror == -1)	{ return false; }
													{ cError.RaiseError(); return false; }
							}
					}
			cc++;
			prev=tile;
			path = path.GetParent();
			}
	return allsuccess;
	}
