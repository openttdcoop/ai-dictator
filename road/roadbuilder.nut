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

function cBuilder::BuildAndStickToRoad(tile, stationtype, stalink = -1)
// Find a road near tile and build a road depot or station connected to that road
//
// @param tile tile where to put the structure
// @param stationtype if AIRoad.ROADVEHTYPE_BUS+100000 build a depot, else build a station of stationtype type
// @param stalink the stationID to link too
// @return -1 on error, tile position on success, CriticalError is set
//
	{
	local directions=[AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)];
	// ok we know we are close to a road, let's find where the road is
	local direction=-1;
	local tooclose=false;
	foreach (voisin in directions)
		{
		if (AIRoad.IsRoadTile(tile+voisin)) { direction=tile+voisin; break; }
		}
	if (direction == -1)	{ DWarn("Can't find a road to stick our structure ???",2); return -1; }
	if (stationtype != (AIRoad.ROADVEHTYPE_BUS+100000) && stalink == -1) // not a depot = truck or bus station need
			{
			foreach (voisin in directions) // find if the place isn't too close from another station
				{
				tooclose=AITile.IsStationTile(tile+voisin);
				if (!tooclose)	{ tooclose=AITile.IsStationTile(tile+voisin+voisin); }
				if (tooclose)
						{
						DWarn("Road station would be too close from another station",2);
						cError.RaiseError(); // force a critical error
						return -1;
						}
				}
			}
	// now build the structure, function is in stationbuilder.nut
	return cBuilder.BuildRoadStationOrDepotAtTile(tile, direction, stationtype, stalink);
	}

function cBuilder::BuildRoadDepotAtTile(tile, stationID)
// Try to build a road depot at tile and nearer
	{
	local reusedepot=cTileTools.GetTilesAroundPlace(tile,24);
	reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
	reusedepot.Sort(AIList.SORT_BY_VALUE, true);
	reusedepot.RemoveAboveValue(8);
	reusedepot.Valuate(AITile.IsWaterTile);
	reusedepot.KeepValue(0);
	reusedepot.Valuate(AITile.IsStationTile);
	reusedepot.KeepValue(0);
	reusedepot.Valuate(AIRail.IsRailTile);
	reusedepot.KeepValue(0);
	reusedepot.Valuate(AIRail.IsRailDepotTile);
	reusedepot.KeepValue(0);
	reusedepot.Valuate(AIRoad.IsRoadDepotTile);
	reusedepot.KeepValue(0);
	reusedepot.Valuate(AITile.GetSlope);
	reusedepot.KeepValue(AITile.SLOPE_FLAT); // only flat tile filtering
	reusedepot.Valuate(AIRoad.GetNeighbourRoadCount); // now only keep places stick to a road
	reusedepot.KeepAboveValue(0);
	reusedepot.Valuate(AIRoad.IsRoadTile);
	reusedepot.KeepValue(0);
	reusedepot.Valuate(AIBridge.IsBridgeTile);
	reusedepot.KeepValue(0); // road or tunnel bridge don't answer to IsRoadTile, making tunnel/bridge destroy as result
	reusedepot.Valuate(AITunnel.IsTunnelTile);
	reusedepot.KeepValue(0);
	reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
	reusedepot.Sort(AIList.SORT_BY_VALUE, true);
	local newpos=-1;
	foreach (tile, dummy in reusedepot)
		{
		newpos=cBuilder.BuildAndStickToRoad(tile, AIRoad.ROADVEHTYPE_BUS+100000, stationID);
		if (newpos != -1)	{ return newpos; }
		}
	return -1;
	}

function cBuilder::BuildRoadStation(start)
// Build a road station for a route
// @param start true to build at source, false at destination
// @return true or false
	{
	cBanker.RaiseFundsBigTime();
	local stationtype = null;
	local rad=null;
	if (AICargo.GetTownEffect(INSTANCE.main.route.CargoID) == AICargo.TE_PASSENGERS)
			{
			rad= AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
			stationtype = AIRoad.ROADVEHTYPE_BUS;
			}
	else
			{
			rad= AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
			stationtype = AIRoad.ROADVEHTYPE_TRUCK;
			}
	local dir, tilelist, checklist, otherplace, istown, isneartown=null;
	if (start)
			{
			dir = cBuilder.GetDirection(INSTANCE.main.route.SourceProcess.Location, INSTANCE.main.route.TargetProcess.Location);
			if (INSTANCE.main.route.SourceProcess.IsTown)
					{
					tilelist = cTileTools.GetTilesAroundTown(INSTANCE.main.route.SourceProcess.ID);
					checklist= cTileTools.GetTilesAroundTown(INSTANCE.main.route.SourceProcess.ID);
					isneartown=true; istown=true;
					if (!cTileTools.SeduceTown(INSTANCE.main.route.SourceProcess.ID))
							{
							DInfo("Our rating with "+AITown.GetName(INSTANCE.main.route.SourceProcess.ID)+" is too poor",1);
							return false;
							}
					}
			else
					{
					tilelist = AITileList_IndustryProducing(INSTANCE.main.route.SourceProcess.ID, rad);
					checklist = AITileList_IndustryProducing(INSTANCE.main.route.SourceProcess.ID, rad);
					isneartown=true; // fake it's a town, it produce, it might be within a town (like a bank)
					istown=false;
					}
			otherplace=INSTANCE.main.route.TargetProcess.Location;
			}
	else
			{
			dir = cBuilder.GetDirection(INSTANCE.main.route.TargetProcess.Location, INSTANCE.main.route.SourceProcess.Location);
			if (INSTANCE.main.route.TargetProcess.IsTown)
					{
					tilelist = cTileTools.GetTilesAroundTown(INSTANCE.main.route.TargetProcess.ID);
					checklist= cTileTools.GetTilesAroundTown(INSTANCE.main.route.TargetProcess.ID);
					isneartown=true; istown=true;
					if (!cTileTools.SeduceTown(INSTANCE.main.route.TargetProcess.ID))
							{
							DInfo("Our rating with "+AITown.GetName(INSTANCE.main.route.TargetProcess.ID)+" is too poor",1);
							return false;
							}
					}
			else
					{
					tilelist = AITileList_IndustryAccepting(INSTANCE.main.route.TargetProcess.ID, rad);
					checklist = AITileList_IndustryAccepting(INSTANCE.main.route.TargetProcess.ID, rad);
					isneartown=true; istown=false;
					}
			otherplace=INSTANCE.main.route.SourceProcess.Location;
			}
	// let's see if we can stick to a road
	tilelist.Sort(AIList.SORT_BY_VALUE, false); // highest values first
	checklist.Valuate(AIRoad.IsRoadTile);
	checklist.KeepValue(1);
	if (checklist.IsEmpty())
			{
			DInfo("Cannot stick our station to a road, building classic",2);
			isneartown=false;
			}
	else
			{
			DInfo("Sticking station & depot to the road",2);
			}
	checklist.AddList(tilelist); // re-put tiles in it in case we fail building later
	if (isneartown)
			{
			// first, removing most of the unbuildable cases
			tilelist.Valuate(AITile.IsWaterTile);
			tilelist.KeepValue(0);
			tilelist.Valuate(AITile.IsStationTile);
			tilelist.KeepValue(0);
			tilelist.Valuate(AIRail.IsRailTile);
			tilelist.KeepValue(0);
			tilelist.Valuate(AIRail.IsRailDepotTile);
			tilelist.KeepValue(0);
			tilelist.Valuate(AIRoad.IsRoadDepotTile);
			tilelist.KeepValue(0);
			tilelist.Valuate(AITile.GetSlope);
			tilelist.KeepValue(AITile.SLOPE_FLAT); // only flat tile filtering
			tilelist.Valuate(AIRoad.GetNeighbourRoadCount); // now only keep places stick to a road
			tilelist.KeepAboveValue(0);
			tilelist.Valuate(AIRoad.IsRoadTile);
			tilelist.KeepValue(0);
			if (!istown && !start)	// not a town, and not start = only industry as destination
					{
					tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
					tilelist.Sort(AIList.SORT_BY_VALUE,true); // little distance first
					}
			else	  // town or (industry at start)
					{
					if (!istown)
							{
							tilelist.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.CargoID, 1, 1, rad);
							}
					else
							{
							tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.CargoID, 1, 1, rad);
							tilelist.KeepAboveValue(7);
							}
					tilelist.Sort(AIList.SORT_BY_VALUE, false);
					}
			}
	else
			{
			if (!istown)
					{
					tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
					}
			tilelist.Sort(AIList.SORT_BY_VALUE,true);
			}
	DInfo("Tilelist set to "+tilelist.Count(),2);
	local success = false;
	local depotbuild=false;
	local stationbuild=false;
	local deptile = -1;
	local statile = -1;
	local stafront = -1;
	local staid = -1;

	if (isneartown)
			{
			foreach (tile, dummy in tilelist)
				{
				statile=cBuilder.BuildAndStickToRoad(tile, stationtype);
				if (statile >= 0)	{ stationbuild = true; break; }
				}
			if (stationbuild)
					{
					staid = AIStation.GetStationID(statile);
					}
			}
	success = (stationbuild);
	if (statile == -1 && !istown && isneartown)
			{
			// We fail to build the station, but it's because we force build station close to roads and there is no roads
			isneartown=false;
			tilelist.AddList(checklist); // restore the list of original tiles
			tilelist.Valuate(AITile.IsBuildable);
			tilelist.KeepValue(1);
			tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
			tilelist.Sort(AIList.SORT_BY_VALUE, true);
			}
	local s_front = cDirection.GetForwardRelativeFromDirection(dir);
	if (!isneartown)
			{
			foreach (tile, dummy in tilelist)
				{
				if (cTerraform.CheckLandForConstruction(tile, 1, 3))
						{
						if (!stationbuild)
							{
							statile = cBuilder.BuildRoadStationOrDepotAtTile(tile, tile+s_front, stationtype, AIStation.STATION_NEW);
							stationbuild = (statile > 0);
							if (stationbuild)	{ staid = AIStation.GetStationID(statile); success = true; }
							}
						if (success)	{ break; }
						}
				}
			}

	if (start)	{ INSTANCE.main.route.SourceStation = staid; }
		else	{ INSTANCE.main.route.TargetStation = staid; }
	print("station at "+cMisc.Locate(statile)+" ID="+AIStation.GetStationID(statile));
	local newStation = INSTANCE.main.route.CreateNewStation(start);
	if (newStation == null)	{ return false; }
	local stadir = cBuilder.GetDirection(statile, AIRoad.GetRoadStationFrontTile(statile));
	local tileFrom= statile + cDirection.GetRightRelativeFromDirection(stadir);
	local tileTo= statile + cDirection.GetLeftRelativeFromDirection(stadir);
	cTerraform.TerraformLevelTiles(tileFrom, tileTo); // try levels mainstation and its neighbourg
	tileTo=statile+cDirection.GetLeftRelativeFromDirection(stadir)+cDirection.GetForwardRelativeFromDirection(stadir)+cDirection.GetForwardRelativeFromDirection(stadir);
	cTerraform.TerraformLevelTiles(tileFrom, tileTo); // try levels all tiles a station could use to grow
	cTerraform.TerraformLevelTiles(tileFrom+cDirection.GetLeftRelativeFromDirection(stadir), tileTo+cDirection.GetRightRelativeFromDirection(stadir));
	cTerraform.TerraformLevelTiles(tileFrom+cDirection.GetLeftRelativeFromDirection(stadir), tileTo+cDirection.GetRightRelativeFromDirection(stadir)+cDirection.GetForwardRelativeFromDirection(stadir));
	return true;
	}

function cBuilder::BuildRoadFrontTile(tile, targettile, stationID)
	{
	if (!AIRoad.IsRoadTile(targettile))
			{
			cTileTools.DemolishTile(targettile);
			cTrack.BuildTrack_Road(tile, targettile, stationID, false);
			}
	return AIRoad.AreRoadTilesConnected(tile, targettile);
	}

function cBuilder::CheckRoadHealth(routeUID)
// we check a route for trouble & try to solve them
// return true if no problems were found
	{
	local repair=cRoute.Load(routeUID);
	if (!repair)	{ DInfo("Cannot load that route for a repair, switching to current route.",1); repair=INSTANCE.main.route; }
	if (typeof(repair.SourceStation) != "instance" || typeof(repair.TargetStation) != "instance")
			{ DInfo("Cannot repair that route as stations aren't setup.",1); return false; }
	if (repair.VehicleType != AIVehicle.VT_ROAD)	{ return false; } // only check road type
	if (!cBuilder.CheckRouteStationStatus(repair.SourceStation.s_ID) || !cBuilder.CheckRouteStationStatus(repair.TargetStation.s_ID))	{ return true; }
	// the route itself will get destroy by CheckRouteStationStatus returning false, so we return the route is ok.
	local good=true;
	repair.Status=RouteStatus.DAMAGE; // on hold
	local space="        ";
	local correction=false;
	local temp=null;
	local minGood=false;
	local srcEntries=AIList();
	local dstEntries=AIList();
	DInfo("Checking route health of "+repair.Name,1);
	// check stations for trouble
	// source station
	correction=false;
	local msg="";
	local error_repair="Fixed !";
	local error_error="Fail to fix it";
	temp=repair.SourceStation;
	if (!AIStation.IsValidStation(temp.s_ID))	{ DInfo(space+" Source Station is invalid !",1); return false; } // critical issue
										else	{ DInfo(space+"Source station "+temp.s_Name+" is valid",1); }
	if (good)
			{
			DInfo(space+space+"Station size : "+temp.s_Tiles.Count(),1);
			foreach (tile, front in temp.s_Tiles)
				{
				cDebug.PutSign(tile, "S");
				srcEntries.AddItem(tile, 0);
				msg=space+space+"Entry "+tile+" is ";
				if (!AIRoad.AreRoadTilesConnected(tile, front))
						{
						msg+="NOT usable. ";
						correction=cBuilder.BuildRoadFrontTile(tile, front, temp.s_ID);
						if (correction)	{ msg+=error_repair; srcEntries.SetValue(tile, 1); }
						else	{ msg+=error_error; good=false; srcEntries.SetValue(tile, -1); }
						}
				else	{ msg+="usable"; srcEntries.SetValue(tile, -1); }
				DInfo(msg,1);
				}
			}
	cDebug.ClearSigns();
	// target station
	correction=false;
	temp=repair.TargetStation;
	if (!AIStation.IsValidStation(temp.s_ID))	{ DInfo(space+" Destination Station is invalid !",1); return false; } // critical issue
										else	{ DInfo(space+"Destination station "+temp.s_Name+" is valid",1); }
	if (good)
			{
			DInfo(space+space+"Station size : "+temp.s_Tiles.Count(),1);
			foreach (tile, front in temp.s_Tiles)
				{
				cDebug.PutSign(tile, "S");
				dstEntries.AddItem(tile, 0);
				msg=space+space+"Entry "+tile+" is ";
				if (!AIRoad.AreRoadTilesConnected(tile, front))
						{
						msg+="NOT usable. ";
						correction=cBuilder.BuildRoadFrontTile(tile, front, temp.s_ID);
						if (correction)	{ msg+=error_repair; dstEntries.SetValue(tile, 1); }
						else	{ msg+=error_error; good=false; dstEntries.SetValue(tile, -1); }
						}
				else	{ msg+="usable"; dstEntries.SetValue(tile, -1); }
				DInfo(msg,1);
				}
			}
	cDebug.ClearSigns();
	// check the road itself from source to destination
	msg=space+"Connection from source station to target station : "
		foreach (stile, sfront in repair.SourceStation.s_Tiles)
		{
		foreach (dtile, dfront in repair.TargetStation.s_Tiles)
			{
			msg=space+"Connnection from "+repair.SourceStation.s_Name+" Entry #"+stile+" to "+repair.TargetStation.s_Name+" Entry #"+dtile+" : ";
			if (!cBuilder.RoadRunner(sfront, dfront, AIVehicle.VT_ROAD))
					{
					// Removing depots that might prevents us from reaching our target
					cTrack.DestroyDepot(repair.TargetStation.s_Depot);
					cTrack.DestroyDepot(repair.SourceStation.s_Depot);
					msg+="Damage & ";
					cBuilder.BuildRoadROAD(sfront, dfront, repair.SourceStation.s_ID, false);
					if (!cBuilder.RoadRunner(sfront, dfront, AIVehicle.VT_ROAD))
							{ msg+=error_error; good=false; }
					else	{ msg+=error_repair; minGood=true; break; }
					DInfo(msg,1);
					}
			else	{ DInfo(msg+"Working",1); minGood=true; break; }
			}
		if (minGood)	{ break; }
		cDebug.ClearSigns();
		}
	// the source depot
	msg=space+"Source Depot "+repair.SourceStation.s_Depot+" is ";
	if (!AIRoad.IsRoadDepotTile(repair.SourceStation.s_Depot) || !cTileTools.TileIsOur(repair.SourceStation.s_Depot))
			{
			msg+="invalid. ";
			repair.SourceStation.s_Depot = cBuilder.BuildRoadDepotAtTile(repair.SourceStation.GetRoadStationEntry(), repair.SourceStation.s_ID);
			if (AIRoad.IsRoadDepotTile(repair.SourceStation.s_Depot))	{ msg+=error_repair; }
																else	{ msg+=error_error; good=false; }
			}
	else	{ msg+="valid"; }
	DInfo(msg,1);
	local depotfront=AIRoad.GetRoadDepotFrontTile(repair.SourceStation.s_Depot);
	if (good)
			{
			msg=space+space+"Depot entry is ";
			if (!AIRoad.AreRoadTilesConnected(repair.SourceStation.s_Depot, depotfront))
					{
					msg+="not usable. ";
					correction=cBuilder.BuildRoadFrontTile(repair.SourceStation.s_Depot, depotfront, repair.SourceStation.s_ID);
					if (correction)	{ msg+=error_repair; }
							else	{ msg+=error_error; good=false; }
					}
			else	{ msg+="usable"; }
			DInfo(msg,1);
			}
	// the destination depot
	msg=space+"Destination Depot "+repair.TargetStation.s_Depot+" is ";
	if (!AIRoad.IsRoadDepotTile(repair.TargetStation.s_Depot) || !cTileTools.TileIsOur(repair.TargetStation.s_Depot))
			{
			msg+="invalid. ";
			repair.TargetStation.s_Depot = cBuilder.BuildRoadDepotAtTile(repair.TargetStation.GetRoadStationEntry(), repair.TargetStation.s_ID);
			if (AIRoad.IsRoadDepotTile(repair.TargetStation.s_Depot))	{ msg+=error_repair; }
			else	{ msg+=error_error; good=false; }
			}
	else	{ msg+="valid"; }
	DInfo(msg,1);
	local depotfront=AIRoad.GetRoadDepotFrontTile(repair.TargetStation.s_Depot);
	if (good)
			{
			msg=space+space+"Depot entry is ";
			if (!AIRoad.AreRoadTilesConnected(repair.TargetStation.s_Depot, depotfront))
					{
					msg+="not usable. ";
					correction = cBuilder.BuildRoadFrontTile(repair.TargetStation.s_Depot, depotfront, repair.TargetStation.s_ID);
					if (correction)	{ msg+=error_repair; }
							else	{ msg+=error_error; good=false; }
					}
			else	{ msg+="usable"; }
			DInfo(msg,1);
			}
	if (good)
			{
			// if we are still here, both depots are working as they should
			local src_depot_front=AIRoad.GetRoadDepotFrontTile(repair.SourceStation.s_Depot);
			local tgt_depot_front=AIRoad.GetRoadDepotFrontTile(repair.TargetStation.s_Depot);
			// source station validity with its own depot
			foreach (tile, front in repair.SourceStation.s_Tiles)
				{
				msg=space+"Connnection from source station -> Entry "+tile+" to its depot : ";
				if (!cBuilder.RoadRunner(front, src_depot_front, AIVehicle.VT_ROAD))
						{
						msg+="Damage & ";
						cBuilder.BuildRoadROAD(front, src_depot_front, repair.SourceStation.s_ID, false);
						if (!cBuilder.RoadRunner(front, src_depot_front, AIVehicle.VT_ROAD)) // source depot cannot be reach
								{
								msg+=error_error; good=false;
								local other_depot = -1;
								if (cBuilder.RoadRunner(front, tgt_depot_front, AIVehicle.VT_ROAD))	{ other_depot = 1; }
								// but target depot could be reach
								srcEntries.SetValue(tile, other_depot);
								}
						else	{ msg+=error_repair; srcEntries.SetValue(tile, 1); }
						DInfo(msg,1);
						}
				else	{ DInfo(msg+"Working",1); srcEntries.SetValue(tile, 1); }
				cDebug.ClearSigns();
				}
			// target station validity with its own depot
			foreach (tile, front in repair.TargetStation.s_Tiles)
				{
				msg=space+"Connnection from destination station -> Entry "+tile+" to its depot : ";
				if (!cBuilder.RoadRunner(front, tgt_depot_front, AIVehicle.VT_ROAD))
						{
						msg+="Damage & ";
						cBuilder.BuildRoadROAD(front, tgt_depot_front, repair.TargetStation.s_ID, false);
						if (!cBuilder.RoadRunner(front, tgt_depot_front, AIVehicle.VT_ROAD))
								{
								msg+=error_error; good=false;
								local other_depot = -1;
								if (cBuilder.RoadRunner(front, src_depot_front, AIVehicle.VT_ROAD))	{ other_depot = 1; }
								dstEntries.SetValue(tile, other_depot);
								}
						else	{ msg+=error_repair; dstEntries.SetValue(tile, 1); }
						DInfo(msg,1);
						}
				else	{ DInfo(msg+"Working",1); dstEntries.SetValue(tile, 1); }
				cDebug.ClearSigns();
				}
			}
	// Now clear out dead station entries
	srcEntries.KeepValue(-1);
	DInfo("Source station entries : "+repair.SourceStation.s_Tiles.Count()+" working "+srcEntries.Count()+" dead",1);
	foreach (tile, _ in srcEntries)
		{
		DInfo(space+"Removing dead source station -> Entry "+tile,1);
		if (cTileTools.DemolishTile(tile))	{ repair.SourceStation.s_Tiles.RemoveItem(tile); }
		}
	dstEntries.KeepValue(-1);
	DInfo("Destination station entries : "+repair.TargetStation.s_Tiles.Count()+" working "+dstEntries.Count()+" dead",1);
	foreach (tile, _ in dstEntries)
		{
		DInfo(space+"Removing dead destination station -> Entry "+tile,1);
		if (cTileTools.DemolishTile(tile))	{ repair.TargetStation.s_Tiles.RemoveItem(tile); }
		}
	repair.SourceStation.s_Location = AIStation.GetLocation(repair.SourceStation.s_ID);
	repair.TargetStation.s_Location = AIStation.GetLocation(repair.TargetStation.s_ID);
	cDebug.ClearSigns();
	if (minGood || good)	{ repair.Status=RouteStatus.WORKING; }
	return minGood;
	}

function cBuilder::RoadFindCompatibleDepot(tile)
// Try to find an existing road depot near tile and reuse it
//
// @param tile the tile to search the depot
// @return -1 on failure, depot location on success
	{
	local reusedepot=cTileTools.GetTilesAroundPlace(tile,24);
	reusedepot.Valuate(AIRoad.IsRoadDepotTile);
	reusedepot.KeepValue(1);
	reusedepot.Valuate(AITile.GetOwner);
	local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
	reusedepot.KeepValue(weare);
	reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
	reusedepot.Sort(AIList.SORT_BY_VALUE, true);
	reusedepot.RemoveAboveValue(10);
	local newdeploc=-1;
	if (!reusedepot.IsEmpty())
			{
			newdeploc=reusedepot.Begin();
			}
	return newdeploc;
	}

function cBuilder::RoadStationNeedUpgrade(roadidx,start)
// Upgrade a road station.
// @param roadidx index of the route to upgrade
// @param start true to upgrade source station, false for destination station
// @return true or false
	{
	local road=cRoute.Load(roadidx);
	if (!road)	{ return false; }
	if (road.Status != RouteStatus.WORKING)	{ return false; }
	cBanker.RaiseFundsBigTime();
	local work=null;
	if (start)	{ work=road.SourceStation; }
	else	{ work=road.TargetStation; }
	local in_town = false;
	if (start)	{ in_town = road.SourceProcess.IsTown; }
	else	{ in_town = road.TargetProcess.IsTown; }
	DInfo("Upgrading road station "+work.s_Name,0);
	work.s_DateLastUpgrade = AIDate.GetCurrentDate(); // setup the date in case of failure
	local depot_id=work.s_Depot;
	DInfo("Road depot is at "+cMisc.Locate(depot_id),2);
	// first lookout where is the station, where is its entry, where is the depot, where is the depot entry
	local sta_pos=work.s_Location;
	local sta_front=AIRoad.GetRoadStationFrontTile(sta_pos);
	local dep_pos=depot_id;
	local dep_front=AIRoad.GetRoadDepotFrontTile(depot_id);
	local depotdead=false;
	local statype= AIRoad.ROADVEHTYPE_BUS;
	if (work.s_Type == AIStation.STATION_TRUCK_STOP)	{ statype=AIRoad.ROADVEHTYPE_TRUCK; }
	local deptype=AIRoad.ROADVEHTYPE_BUS+100000; // we add 100000
	local new_sta_pos=-1;
	local new_dep_pos=-1;
	local success=false;
	local upgradepos=[];
	local facing=cBuilder.GetDirection(sta_pos, sta_front);
	local p_left = cTileTools.GetPosRelativeFromDirection(0, facing);
	local p_right = cTileTools.GetPosRelativeFromDirection(1, facing);
	local p_forward = cTileTools.GetPosRelativeFromDirection(2, facing);
	local p_backward = cTileTools.GetPosRelativeFromDirection(3, facing);
	cDebug.PutSign(sta_pos+p_left,"L");
	cDebug.PutSign(sta_pos+p_right,"R");
	cDebug.PutSign(sta_pos+p_backward,"B");
	cDebug.PutSign(sta_pos+p_forward+p_forward,"F");
	DInfo("Size :"+work.s_Size,2);
	INSTANCE.NeedDelay(20);
	// 1st tile of station, 2nd tile to face
	upgradepos.push(sta_pos+p_left);				// left of station, same facing
	upgradepos.push(sta_pos+p_left+p_forward);
	upgradepos.push(sta_pos+p_right);				// right of station, same facing
	upgradepos.push(sta_pos+p_right+p_forward);
	upgradepos.push(sta_pos+p_left); 				// left of station, facing left
	upgradepos.push(sta_pos+p_left+p_left);
	upgradepos.push(sta_pos+p_right);				// right of station, facing right
	upgradepos.push(sta_pos+p_right+p_right);
	upgradepos.push(sta_pos+p_forward+p_forward);		// front station, facing opposite
	upgradepos.push(sta_pos+p_forward);
	upgradepos.push(sta_pos+p_forward+p_forward+p_left);	// front station, left, facing opposite
	upgradepos.push(sta_pos+p_forward+p_left);
	upgradepos.push(sta_pos+p_forward+p_forward+p_right);	// front station, right, facing opposite
	upgradepos.push(sta_pos+p_forward+p_right);
	upgradepos.push(sta_pos+p_forward+p_forward+p_right);	// front right of station, facing right
	upgradepos.push(sta_pos+p_forward+p_forward+p_right+p_right);
	upgradepos.push(sta_pos+p_forward+p_forward+p_left);	// front left of station, facing left
	upgradepos.push(sta_pos+p_forward+p_forward+p_left+p_left);
	upgradepos.push(sta_pos+p_backward);				// behind station, facing opposite
	upgradepos.push(sta_pos+p_backward+p_backward);
	upgradepos.push(sta_pos+p_backward+p_left);		// behind station, left, facing opposite
	upgradepos.push(sta_pos+p_backward+p_left+p_backward);
	upgradepos.push(sta_pos+p_backward+p_right);		// behind station, right, facing opposite
	upgradepos.push(sta_pos+p_backward+p_right+p_backward);
	upgradepos.push(sta_pos+p_backward+p_left);		// behind station, left, facing left
	upgradepos.push(sta_pos+p_backward+p_left+p_left);
	upgradepos.push(sta_pos+p_backward+p_right);		// behind station, right, facing right
	upgradepos.push(sta_pos+p_backward+p_right+p_right);
	local allfail=true;
	for (local i=0; i < upgradepos.len()-1; i++)
			{
			local tile=upgradepos[i];
			local direction=upgradepos[i+1];
			if (AIRoad.IsRoadStationTile(tile) || AIRoad.IsRoadStationTile(direction))	{ i++; continue; } // don't build on a station
			if (tile == dep_pos || direction == dep_pos)	{ depotdead = cTrack.DestroyDepot(dep_pos); }
			// kill our depot if it is about to bug us building
			if (AIRoad.IsRoadTile(tile))	{ i++; continue; } // don't build on a road if we could avoid it
			cDebug.PutSign(tile, "S");
			cDebug.PutSign(direction, "o");
			new_sta_pos=cBuilder.BuildRoadStationOrDepotAtTile(tile, direction, statype, work.s_ID);
			if (!cError.IsError())	{ allfail=false; } // if we have only critical errors we're doom
			cError.ClearError(); // discard it
			if (new_sta_pos != -1)	{ break; }
			local pause = cLooper();
			INSTANCE.NeedDelay(10);
			cDebug.ClearSigns();
			i++;
			}
	DInfo("2nd try don't care roads",2);
	// same as upper but destructive
	if (new_sta_pos == -1 && !in_town)
			{
			for (local i=0; i < upgradepos.len()-1; i++)
					{
					local tile=upgradepos[i];
					local direction=upgradepos[i+1];
					if (AIRoad.IsRoadStationTile(tile) || AIRoad.IsRoadStationTile(direction))	{ i++; continue; } // don't build on a station
					cDebug.PutSign(tile, "S");
					cDebug.PutSign(direction, "o");
					if (tile == dep_pos || direction == dep_pos)	{ depotdead = cTrack.DestroyDepot(dep_pos); }
					// kill our depot if it is about to bug us building
					if (!cTileTools.DemolishTile(tile))	{ DInfo("Cannot clean the place for the new station at "+tile,1); }
					new_sta_pos=cBuilder.BuildRoadStationOrDepotAtTile(tile, direction, statype, work.s_ID);
					if (!cError.IsError())	{ allfail=false; } // if we have only critical errors we're doom
					cError.ClearError(); // discard it
					if (new_sta_pos != -1)	{ break; }
					INSTANCE.NeedDelay(50);
					cDebug.ClearSigns();
					i++;
					}
			}
	if (new_sta_pos == dep_front && !depotdead)
			{
			depotdead=true; // the depot entry is now block by the station
			cTrack.DestroyDepot(dep_pos);
			}
	if (depotdead)
			{
			DWarn("Road depot was destroy while upgrading",1);
			new_dep_pos = cBuilder.BuildRoadDepotAtTile(new_sta_pos, work.s_ID);
			work.s_Depot = new_dep_pos;
			cError.ClearError();
			// Should be more than enough
			}
	if (new_sta_pos > -1)
			{
			DInfo("Station "+work.s_Name+" has been upgrade",0);
			work.s_Tiles = cTileTools.FindStationTiles(work.s_Location);
			work.s_Tiles.Valuate(AIRoad.GetRoadStationFrontTile);
			work.s_Size=work.s_Tiles.Count();
			DInfo("New station size: "+work.s_Size+"/"+work.s_MaxSize,2);
			// Retry connect depot if it was rebuilt
			if (depotdead)
				{
				local dep_front = AIRoad.GetRoadDepotFrontTile(work.s_Depot);
				foreach (tile, front in work.s_Tiles)
					{
					if (!cBuilder.RoadRunner(front, dep_front, AIVehicle.VT_ROAD))
						{
						cBuilder.BuildRoadROAD(front, dep_front, work.s_ID, false);
						}
					}
				}
			}
	else	  // fail to upgrade station
			{
			DInfo("Failure to upgrade "+work.s_Name,1);
			if (allfail)
					{
					work.s_MaxSize = work.s_Size;
					DInfo("Cannot upgrade "+work.s_Name+" anymore !",1);
					}
			success=false;
			}
	if (!work.s_Owner.IsEmpty())	{ cBuilder.RouteIsDamage(work.s_Owner.Begin()); }
	// ask ourselves a check for one route that own that station
	if (success)	{ work.s_MoneyUpgrade = 0; work.s_DateLastUpgrade = null; }
	return success;
	}

function cBuilder::BuildRoadStationOrDepotAtTile(tile, direction, stationtype, stationnew)
// Build a road depot or station, add tile to blacklist on critical failure
// Also build the entry tile with road if need. Try also to find a compatible depot near the wanted position and re-use it
//
// @param tile the tile where to put the structure
// @param direction the tile where the structure will be connected
// @param stationtype if AIRoad.ROADVEHTYPE_BUS+100000 build a depot, else build a station of stationtype type
// @param stationnew invalid station id to build a new station, else joint the station with stationid
// @return tile position on success. -1 on error, set CriticalError

	{
	// before spending money on a "will fail" structure, check the structure could be connected to a road
	if (AITile.IsStationTile(tile))	{ return -1; } // don't destroy a station, might even not be our
	local claimTile = AIList();
	cBanker.RaiseFundsBigTime();
	if (!AIRoad.IsRoadTile(direction))
			{
			if (!cTileTools.DemolishTile(direction))
					{
					DWarn("Can't remove the tile front structure to build a road at "+cMisc.Locate(direction),2);
					cError.IsCriticalError();
					return -1;
					}
			}
	cError.ClearError();
	if (!cTileTools.DemolishTile(tile))
			{
			DWarn("Can't remove the structure tile position at "+cMisc.Locate(tile),2);
			cError.IsCriticalError();
			return -1;
			}
	local success=false;
	local newstation=0;
	if (AIStation.IsValidStation(stationnew))	{ newstation=stationnew; }
										else	{ newstation=AIStation.STATION_NEW; }
	if (stationtype == (AIRoad.ROADVEHTYPE_BUS+100000))
			{
			cBanker.RaiseFundsBigTime();
			// first let's hack another depot if we can
			local hackdepot = cBuilder.RoadFindCompatibleDepot(tile);
			if (hackdepot == -1)	{ success = AIRoad.BuildRoadDepot(tile, direction); }
			else
					{
					tile=hackdepot;
					direction=AIRoad.GetRoadDepotFrontTile(tile);
					success=true;
					}
			if (!success)
					{
					DWarn("Can't built a road depot at "+cMisc.Locate(tile),2);
					cError.IsCriticalError();
					}
			else
					{
					if (hackdepot == -1)	{ DInfo("Built a road depot at "+cMisc.Locate(tile),0); }
									else	{ DInfo("Found a road depot near "+cMisc.Locate(tile)+", reusing that one",0); }
					}
			}
	else
			{
			cBanker.RaiseFundsBigTime(); cDebug.ClearSigns();
			DInfo("Road info: "+tile+" direction"+direction+" type="+stationtype+" mod="+newstation,2);
			//cDebug.PutSign(tile,"s"); cDebug.PutSign(direction,"c");
			success=AIRoad.BuildRoadStation(tile, direction, stationtype, newstation);
			if (!success)
					{
					DWarn("Can't built the road station at "+cMisc.Locate(tile),2);
					cError.IsCriticalError();
					}
			else	{
					DInfo("Built a road station at "+cMisc.Locate(tile),0);
					}
			}
	if (!success)
			{
			return -1;
			}
	else
			{
			if (!AIRoad.AreRoadTilesConnected(tile, direction))
				if (!cTrack.BuildTrack_Road(tile, direction, -1, false))
						{
						DWarn("Fail to connect the road structure with the road in front of it",2);
						cError.IsCriticalError();
						if (!cTileTools.DemolishTile(tile))
								{
								DWarn("Can't remove bad road structure !",2);
								}
						return -1;
						}
			local tlist = AIList();
			tlist.AddItem(tile, 0);
			tlist.AddItem(direction, 0);
			return tile;
			}
	}

function cBuilder::RoadRunnerHelper(source, target, road_type, walkedtiles=null, origin=null)
// Follow all directions to walk through the path starting at source, ending at target
// check if the path is valid by using road_type (railtype, road)
// return solve in an AIList() if we reach target by running the path
	{
	local Distance = AITile.GetDistanceManhattanToTile;
	if (road_type == AIVehicle.VT_WATER) { Distance = cDirection.GetDistanceChebyshevToTile; }
	local max_wrong_direction=15;
	if (origin == null)	{ origin = Distance(source, target); }
	if (walkedtiles == null)	{ walkedtiles=AIList(); }
	local valid=false;
	local direction=null;
	local found=false;
	local solve= AIList();
	if (source == target)	{ found = true; }
	local dirswap = AIList();
	if (cBridge.IsBridgeTile(source) || AITunnel.IsTunnelTile(source))
			{
			local endat = cBridge.IsBridgeTile(source) ? AIBridge.GetOtherBridgeEnd(source) : AITunnel.GetOtherTunnelEnd(source);
			if (AIMap.IsValidTile(endat))   { source = endat }
			}
	dirswap.AddItem(source+AIMap.GetTileIndex(0, 1), 0);
	dirswap.AddItem(source+AIMap.GetTileIndex(1, 0), 0);
	dirswap.AddItem(source+AIMap.GetTileIndex(-1, 0), 0);
	dirswap.AddItem(source+AIMap.GetTileIndex(0, -1), 0);
	dirswap.Valuate(Distance, target);
	dirswap.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
	foreach (direction, voisin in dirswap)
		{
		if (road_type==AIVehicle.VT_ROAD)	{ valid = AIRoad.AreRoadTilesConnected(source, direction); }
		if (road_type==AIVehicle.VT_RAIL)	{ valid = cBuilder.AreRailTilesConnected(source, direction); }
		if (road_type==AIVehicle.VT_WATER) { valid = (AITile.IsWaterTile(direction) || AIMarine.IsDockTile(direction)); }
		if (road_type==666) { valid = (AITile.IsBuildable(direction) || AITile.IsWaterTile(direction)); }
		local currdistance = Distance(direction, target);
		if (currdistance > origin+max_wrong_direction)	{ valid=false; }
		if (walkedtiles.HasItem(direction))	{ valid=false; }
		if (valid)	{ walkedtiles.AddItem(direction,0); }
		//if (valid && INSTANCE.debug)	cDebug.PutSign(direction, currdistance);
		//if (INSTANCE.debug) DInfo("Valid="+valid+" curdist="+currdistance+" origindist="+origin+" source="+source+" dir="+direction+" target="+target,2);
		if (!found && valid)	{ solve = cBuilder.RoadRunnerHelper(direction, target, road_type, walkedtiles, origin); }
		if (!found)	{ found = !solve.IsEmpty(); }
		if (found) { solve.AddItem(source,walkedtiles.Count()); return solve; }
		}
	return solve;
	}

function cBuilder::RoadRunner(source, target, road_type, distance = null)
	{
	cDebug.ClearSigns();
	cDebug.PutSign(source, "S");
	cDebug.PutSign(target, "T");
	local solve = cBuilder.RoadRunnerHelper(source, target, road_type);
	cDebug.ClearSigns();
	local result = !solve.IsEmpty();
	if (result && distance != null && solve.Count() > distance*2)	{ result=false; }
	cDebug.ClearSigns();
	//cDebug.showLogic(solve);
	return result;
	}

function cBuilder::BuildRoadROAD(head1, head2, stationID, primarylane)
// Pathfind and building the road.
// cPathfinder will callback us when primarylane is false
	{
	local trys = 0;
	local result = null;
	while (trys < 20)
			{
			// As we are the new callback for building road with primarylane == false, we must call ourselves the cBuilder.BuildPath_ROAD to build the road
			result = cBuilder.BuildPath_ROAD(head1, head2, stationID, primarylane);
			//result = cPathfinder.GetStatus(head1, head2, stationID, false, null);
			if (result == -2)	{ cPathfinder.CloseTask(head1, head2); cError.RaiseError(); return false; }
			if (result == 2)	{ cPathfinder.CloseTask(head1, head2); return true; }
			trys++;
			// If result == 1 pathfinder is trying to build the route but if it stays at 1 it is because we lack money
			// We couldn't wait it forever to get money it may never get
			cPathfinder.AdvanceAllTasks();
			}
	return false;
	}

function cBuilder::BuildPath_ROAD(src, dst, stationID, primarylane)
// this construct (build) the road we get from path
{
	local status = cPathfinder.GetStatus(src, dst, stationID, primarylane, null);
	local mytask = cPathfinder.GetPathfinderObject(cPathfinder.GetUID(src, dst));
	if (mytask == null)	return -2;
	if (status == 2) // success
		{
		DInfo("Pathfinder task "+mytask.UID+" succeed !",1);
		INSTANCE.buildDelay = 0;
		local bltiles=AIList();
		bltiles.AddList(cTileTools.TilesBlackList);
		bltiles.KeepValue(-stationID);
		local sta = cStation.Load(stationID);
		if (cMisc.ValidInstance(sta))	{ sta.s_TilesOther.AddList(bltiles); }
		return 0;
		}
	local smallerror = 0;
	if (status == -2)	smallerror = -2; // failure, we have nothing to do if status is already set to failure
	local path = cPathfinder.GetSolve(src, dst);
	if (path == null)	{ smallerror = -2; } // if we couldn't get a valid solve here, there's something wrong then
	cBanker.RaiseFundsBigTime();
	DInfo("Building road structure",0);
	local prev = null;
	local prevprev = null;
	local prevprevprev = null;
	local counter=0;
	local walked=[];
	while (path != null)
			{
			local par = path.GetParent();
			if (par != null)
					{
					if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1)
							{
							if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile()))
									{
									smallerror=cBuilder.EasyError(AIError.GetLastError());
									if (smallerror==-1)
											{
											DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),2);
											return -1;
											}
									if (smallerror==-2)	{ break; }
									}
							else
									{
									cTileTools.BlackListTile(par.GetTile(), -stationID);
									}
							} // aimap
					else
							{
							if (!cBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile()))
									{
									if (AIRoad.IsRoadTile(path.GetTile())) { cTileTools.DemolishTile(path.GetTile()); }
									if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile())
											{
											if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile()))
													{
													smallerror=cBuilder.EasyError(AIError.GetLastError());
													if (smallerror==-1)
															{
															DInfo("An error occured while I was building the tunnel: " + AIError.GetLastErrorString(),2);
															return -1;
															}
													if (smallerror==-2)	{ break; }
													}
											else
													{
													cTileTools.BlackListTile(par.GetTile(), -stationID);
													}
											} // aitunnel
									else
											{
											local bridgeID = cBridge.GetCheapBridgeID(AIVehicle.VT_ROAD, AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
											if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridgeID, path.GetTile(), par.GetTile()))
													{
													smallerror=cBuilder.EasyError(AIError.GetLastError());
													if (smallerror==-1)
															{
															DInfo("An error occured while I was building the bridge: " + AIError.GetLastErrorString(),2);
															return -1;
															}
													if (smallerror==-2)	{ break; }
													}
											else
													{
													cTileTools.BlackListTile(par.GetTile(), -stationID);
													}
											}//else ai tunnel
									}//if cBrigde
							}// else aimap
					} //ifpar
			prev = path;
			path = par;
			}
	if (smallerror == -2)
			{
			DError("Pathfinder has detect a failure.",1);
			if (walked.len() < 4)
					{
					DInfo("Pathfinder cannot do more",1);
					DInfo("Pathfinder task "+mytask.UID+" failure !",1);
					local badtiles=AIList();
					badtiles.AddList(cTileTools.TilesBlackList); // keep blacklisted tiles for -stationID
					badtiles.KeepValue(-mytask.stationID);
					foreach (tiles, dummy in badtiles)	cTileTools.UnBlackListTile(tiles); // and release them for others
					cError.RaiseError();
					return -2;
					}
			else
					{
					local maxstepback=10;
					local curr=walked.pop(); // dismiss last one, it's the failure
					if (walked.len() < maxstepback)	{ maxstepback=walked.len()-1; }
					local alist=AIList();
					for (local ii=1; ii < maxstepback; ii++)
							{
							prev=walked.pop();
							alist.AddItem(prev, 0);
							AIRoad.RemoveRoad(prev, curr);
							curr=prev;
							}
					local newtarget=[0, prev];
					DInfo("Pathfinder is calling an helper task",1);
					cPathfinder.CreateSubTask(mytask.UID, src, newtarget);
					return -1;
					}
			}
	return 0; // success
}
