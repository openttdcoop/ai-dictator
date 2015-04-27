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
	local dir, tilelist, otherplace = null;
	local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
	local istown=false;
	local srcpoint=null;
	local sourceplace=null;
	local statile=null;
	local platnum = 1;
	if (start)
			{
			dir = INSTANCE.main.builder.GetDirection(INSTANCE.main.route.SourceProcess.Location, INSTANCE.main.route.TargetProcess.Location);
			print("dir source="+cBuilder.DirectionToString(dir));
			if (INSTANCE.main.route.SourceProcess.IsTown)
					{
                    otherplace=INSTANCE.main.route.TargetProcess.Location; sourceplace=INSTANCE.main.route.SourceProcess.Location;
					tilelist = cTileTools.GetTilesAroundTown(INSTANCE.main.route.SourceProcess.ID);
                    tilelist.Valuate(AITile.IsBuildable);
                    tilelist.KeepValue(1);
					tilelist.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.CargoID, 1, 1, rad);
					tilelist.KeepAboveValue(0);
                    istown=true;
					}
			else
					{
                    otherplace=INSTANCE.main.route.TargetProcess.Location; sourceplace=INSTANCE.main.route.SourceProcess.Location;
					tilelist = AITileList_IndustryProducing(INSTANCE.main.route.SourceProcess.ID, rad);
					tilelist.Valuate(AITile.IsBuildable);
                    tilelist.KeepValue(1);
                    istown=false;
//                    tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
//                    tilelist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
					}
			}
	else
			{
			dir = INSTANCE.main.builder.GetDirection(INSTANCE.main.route.TargetProcess.Location, INSTANCE.main.route.SourceProcess.Location);
			print("dir target="+cBuilder.DirectionToString(dir));
			if (INSTANCE.main.route.TargetProcess.IsTown)
					{
                    otherplace=INSTANCE.main.route.SourceProcess.Location; sourceplace=INSTANCE.main.route.TargetProcess.Location;
					tilelist = cTileTools.GetTilesAroundTown(INSTANCE.main.route.TargetProcess.ID);
                    tilelist.Valuate(AITile.IsBuildable);
                    tilelist.KeepValue(1);
					tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.CargoID, 1, 1, rad);
					tilelist.KeepAboveValue(8);
//                    tilelist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
                    istown=true;
					}
			else
					{
           			otherplace=INSTANCE.main.route.SourceProcess.Location; sourceplace=INSTANCE.main.route.TargetProcess.Location;
					tilelist = AITileList_IndustryAccepting(INSTANCE.main.route.TargetProcess.ID, rad);
					tilelist.Valuate(AITile.IsBuildable);
                    tilelist.KeepValue(1);
                    //tilelist.Valuate(AIMap.DistanceSquare, otherplace);
                    //tilelist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
					istown=false;
					}
			}
	tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
    tilelist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    if (istown)	platnum = 2;
	local success = false;
	local buildmode=0;
	local cost=5*AIRail.GetBuildCost(AIRail.GetCurrentRailType(),AIRail.BT_STATION);
	DInfo("Rail station cost: "+cost+" byinflat"+(cost*cBanker.GetInflationRate().tointeger()),2);
	INSTANCE.main.bank.RaiseFundsBy(cost*4);
	local ssize=6+INSTANCE.main.carrier.train_length;
	/* 3 build mode:
	- try find a place with stationsize+11 tiles flatten and buildable
	- try find a place with stationsize+11 tiles maybe not flat and buildable
	- try find a place with stationsize+11 tiles maybe not flat and buildable even on water
	*/
	do
			{
			foreach (tile, _ in tilelist)
				{
				cDebug.PutSign(tile, buildmode);
				if (start)	{ dir = cBuilder.GetDirection(tile, INSTANCE.main.route.SourceProcess.Location); }
					else	{ dir = cBuilder.GetDirection(tile, INSTANCE.main.route.TargetProcess.Location); }
				switch (dir)
						{
						case DIR_NW: //0 south
							if (istown)	{ dir=AIRail.RAILTRACK_NW_SE; }
							else	{ dir=AIRail.RAILTRACK_NE_SW; }
							break;
						case DIR_SE: //1 north
							if (istown)	{ dir=AIRail.RAILTRACK_NW_SE; }
							else	{ dir=AIRail.RAILTRACK_NE_SW; }
							break;
						case DIR_SW: //3 est/droite
							if (istown)	{ dir=AIRail.RAILTRACK_NE_SW; }
							else	{ dir=AIRail.RAILTRACK_NW_SE; }
							break;
						case DIR_NE: //2 west/gauche
							if (istown)	{ dir=AIRail.RAILTRACK_NE_SW; }
							else	{ dir=AIRail.RAILTRACK_NW_SE; }
							break;
						}
				local checkit = false;
				switch (buildmode)
						{
						case	0:
							if (dir == AIRail.RAILTRACK_NW_SE)	{ checkit = cTileTools.IsBuildableRectangleFlat(tile, 2, ssize); }
							else	{ checkit = cTileTools.IsBuildableRectangleFlat(tile, ssize, 2); }
							if (checkit)	{ checkit = tile; }
							break;
						case	1:
							if (dir == AIRail.RAILTRACK_NW_SE)	{ checkit = AITile.IsBuildableRectangle(tile, 2, ssize); }
							else	{ checkit = AITile.IsBuildableRectangle(tile, ssize, 2); }
							if (checkit)	{ checkit = tile; }
							break;
						case	2:
							if (dir == AIRail.RAILTRACK_NW_SE)	{ checkit = cTileTools.CheckLandForConstruction(tile, 2, ssize); }
							else	{ checkit = cTileTools.CheckLandForConstruction(tile, ssize, 2); }
							break;
						}
				if (checkit != false)
						{
						success = cBuilder.CreateAndBuildTrainStation(checkit, dir, platnum);
						if (!success && cError.IsCriticalError())	{ break; }
						statile = tile;
						break;
						}
				}
			buildmode++;
			}
	while (buildmode != 4 && !success);
	if (!success)
			{
			DInfo("Can't find a good place to build the train station ! "+tilelist.Count(),1);
			if (tilelist.IsEmpty())	{ cError.RaiseError(); }
			return false;
			}
	// here, so we success to build one
	local staID = AIStation.GetStationID(statile);
	if (start)	{ INSTANCE.main.route.SourceStation = staID; }
	else	{ INSTANCE.main.route.TargetStation = staID; }
	INSTANCE.main.route.CreateNewStation(start);
	return true;
	}

function cBuilder::EasyError(error)
// Just return if the error is something really simple we could handle with few time or bucks
// 0 no error
// -1 a temp easy solvable error
// -2 a big error
	{
	switch (error)
			{
			case	AIError.ERR_NOT_ENOUGH_CASH :
				return -1;
			case	AIError.ERR_ALREADY_BUILT:
				return 0;
			case	AIError.ERR_VEHICLE_IN_THE_WAY:
				return -1;
			case	AIError.ERR_OWNED_BY_ANOTHER_COMPANY:
				return 0;
			}
	return -2;
	}

function cBuilder::BuildPath_RAIL(head1, head2, useEntry, stationID)
{
	local status = cPathfinder.GetStatus(head1, head2, stationID, useEntry);
	local mytask = cPathfinder.GetPathfinderObject(cPathfinder.GetUID(head1, head2));
	if (mytask == null)	return -2;
	if (status == 2) // success
		{
		DInfo("Pathfinder task "+mytask.UID+" succeed !",1);
		local verifypath = RailFollower.GetRailPathing(mytask.source, mytask.target);
		if (verifypath.IsEmpty())
					{
					mytask.status = -1;
					DError("Pathfinder task "+mytask.UID+" fails when checking the path.",1);
					local badtiles=AIList();
					badtiles.AddList(cTileTools.TilesBlackList); // keep blacklisted tiles for -stationID
					badtiles.KeepValue(0 - (100000 + mytask.stationID));
					cTrack.RailCleaner(badtiles); // remove all rail we've built
					cTileTools.TilesBlackList.RemoveList(badtiles); // and release them for others
					cError.RaiseError();
					return -2;
					}
			else
					{
					DInfo("Pathfinder task "+mytask.UID+" pass checks.",1);
					INSTANCE.buildDelay=0;
					if (cStationRail.IsPrimaryLineBuilt(stationID) && !cStationRail.IsAlternateLineBuilt(stationID))
						{
						// if we are building mainline, then IsPrmaryLineBuild is false ; so if it's true, we are building altline and we were called to build it
						// so let's recall it to let it know where we are.
						local staobj = cStation.Load(stationID);
						if (!staobj)	{ cError.RaiseError(); return -2; }
						local uid_obj = cRoute.Load(staobj.s_Train[TrainType.OWNER]);
						if (!uid_obj)	{ return -2; }
						cBuilder.RailStationPathfindAltTrack(uid_obj);
						}
					return 0;
					}
		}
	local smallerror = 0;
	if (status == -1)	smallerror = -2; // failure, we have nothing to do if status is already set to failure
	local path = cPathfinder.GetSolve(head1, head2);
	if (path == null)	{ smallerror = -2; } // if we couldn't get a valid solve here, there's something wrong then
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
								cTileTools.TerraformLevelTiles(prevprev, targetTile);
								}*/
							if (!AIRail.BuildRail(prevprev, prev, targetTile))
									{
									smallerror=cBuilder.EasyError(AIError.GetLastError());
									if (smallerror==-1)
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
			DError("Pathfinder has detect a failure.",1);
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

function cBuilder::FindStationEntryToExitPoint(src, dst)
// find the closest path from station src to station dst
// We return result in array: 0=src tile, 1=1(entry)0(exit), 1=dst tile, value=1(entry)0(exit)
// return array empty on error
//
	{
	// check entry/exit avaiablility on stations
	local srcEntry=cStationRail.IsRailStationEntryOpen(src);
	local srcExit=cStationRail.IsRailStationExitOpen(src);
	local dstEntry=cStationRail.IsRailStationEntryOpen(dst);
	local dstExit=cStationRail.IsRailStationExitOpen(dst);
	local frontTile = cStationRail.GetRelativeTileForward(src, true);
	local srcEntryLoc = (5*frontTile) + cStationRail.GetRailStationFrontTile(true, cStation.GetLocation(src), src);
	frontTile = cStationRail.GetRelativeTileForward(dst, true);
	local dstEntryLoc = (5*frontTile) + cStationRail.GetRailStationFrontTile(true, cStation.GetLocation(dst), dst);
	frontTile = cStationRail.GetRelativeTileForward(src, false);
	local srcExitLoc = (5*frontTile) + cStationRail.GetRailStationFrontTile(false, cStation.GetLocation(src), src);
	frontTile = cStationRail.GetRelativeTileForward(dst, false);
	local dstExitLoc = (5*frontTile) + cStationRail.GetRailStationFrontTile(false, cStation.GetLocation(dst), dst);
	local srcStation=cStation.Load(src);
	local dstStation=cStation.Load(dst);
	if ( !srcStation || !dstStation || (!srcEntry && !srcExit) || (!dstEntry && !dstExit) )
			{
			DInfo("That station have its entry and exit closed. No more connections could be made with it",1);
			return [];
			}
	local srcEntryBuild=(srcStation.s_EntrySide[TrainSide.IN] != -1); // because if we have build it and it is still open, we must use that point, even if it's not the shortest path
	local srcExitBuild=(srcStation.s_ExitSide[TrainSide.IN] != -1);  // else we may prefer another point that would be shorter, leaving that entry/exit built for nothing
	local dstEntryBuild=(dstStation.s_EntrySide[TrainSide.OUT] != -1);
	local dstExitBuild=(dstStation.s_ExitSide[TrainSide.OUT] != -1);
	local best=100000000000;
	local bestsrc=-1;
	local bestdst=-1;
	local check=-1;
	local srcFlag=0;
	local dstFlag=0; // use to check if we're connect to entry(1) or exit(0)
	if (srcEntry && !srcExitBuild)
			{
			if (dstExit)
					{
					check = AIMap.DistanceManhattan(srcEntryLoc,dstExitLoc);
					if (check < best && !dstEntryBuild)	{ best=check; bestsrc=srcEntryLoc; bestdst=dstExitLoc; }
					}
			DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2);
			if (dstEntry)
					{
					check = AIMap.DistanceManhattan(srcEntryLoc,dstEntryLoc);
					if (check < best && !dstExitBuild)	{ best=check; bestsrc=srcEntryLoc; bestdst=dstEntryLoc; }
					}
			DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2);
			}
	if (srcExit && !srcEntryBuild)
			{
			if (dstEntry)
					{
					check = AIMap.DistanceManhattan(srcExitLoc,dstEntryLoc);
					if (check < best && !dstExitBuild)	{ best=check; bestsrc=srcExitLoc; bestdst=dstEntryLoc; }
					}
			DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2);
			if (dstExit)
					{
					check = AIMap.DistanceManhattan(srcExitLoc,dstExitLoc);
					if (check < best && !dstEntryBuild)	{ best=check; bestsrc=srcExitLoc; bestdst=dstExitLoc; }
					}
			DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2);
			}
	// Now we know where to build our roads
	local bestWay=[];
	if (check == -1) { return []; }
	if (bestsrc == srcEntryLoc)	{ srcFlag=1; }
	if (bestdst == dstEntryLoc)	{ dstFlag=1; }
	bestWay.push(bestsrc);
	bestWay.push(srcFlag);
	bestWay.push(bestdst);
	bestWay.push(dstFlag);
	DInfo("Best connecting source="+bestsrc+" destination="+bestdst+" srcFlag="+srcFlag+" dstFlag="+dstFlag,2);
	cDebug.PutSign(bestsrc,"CS");
	cDebug.PutSign(bestdst,"CT");
	return bestWay;
	}

function cBuilder::CreateStationsConnection(fromObj, toObj)
// Connect station fromObj to station toObj by picking entry/exit close to each other and create connections in front of them
// fromObj, toObj: 2 valid rail stations
// this also set the INSTANCE.main.route.* properties
	{
	local srcStation=cStation.Load(fromObj);
	local dstStation=cStation.Load(toObj);
	if (!srcStation || !dstStation)	{ return -1; }
	DInfo("Connecting rail station "+srcStation.s_Name+" to "+dstStation.s_Name,1);
	if (cStationRail.IsPrimaryLineBuilt(fromObj) && cStationRail.IsPrimaryLineBuilt(toObj))
		{
		if (!cStationRail.IsAlternateLineBuilt(fromObj) || !cStationRail.IsAlternateLineBuilt(toObj))	return false;
		return true;
		}
	local retry=true;
	local bestWay=AIList();
	local srcresult=false;
	local dstresult=false;
	local srcpos=null;
	local dstpos=null;
	local srclink=0;
	local dstlink=0;
	local srcUseEntry=null;
	local dstUseEntry=null;
	do
			{
			bestWay=INSTANCE.main.builder.FindStationEntryToExitPoint(fromObj, toObj);
			if (bestWay.len()==0)	{ cError.RaiseError(); return false; }
			else	{ retry=true; }
			if (retry) // we found a possible connection
					{
					srcpos=bestWay[0];
					dstpos=bestWay[2];
					srcUseEntry=(bestWay[1]==1);
					dstUseEntry=(bestWay[3]==1);
					DInfo("srcUseEntry="+srcUseEntry+" dstUseEntry="+dstUseEntry,2);
					if (!srcresult)	{ srcresult=INSTANCE.main.builder.RailStationGrow(fromObj, srcUseEntry, true); }
					if (!srcresult)
							{
							DWarn("RailStationGrow report failure",1);
							if (cError.IsError())	{ return false; }
							}
					if (!dstresult)	{ dstresult=INSTANCE.main.builder.RailStationGrow(toObj, dstUseEntry, false); }
					if (!dstresult)
							{
							DWarn("RailStationGrow report failure",1);
							if (cError.IsError())	{ return false; }
							}
					if (dstresult && srcresult)
							{
							// need to grab the real locations first, as they might have change while building entrances of station
							local mainowner=srcStation.s_Train[TrainType.OWNER];
							if (srcUseEntry)	{ srclink=srcStation.s_EntrySide[TrainSide.IN_LINK]; }
							else	{ srclink=srcStation.s_ExitSide[TrainSide.IN_LINK]; }
							if (dstUseEntry)	{ dstlink=dstStation.s_EntrySide[TrainSide.OUT_LINK]; }
							else	{ dstlink=dstStation.s_ExitSide[TrainSide.OUT_LINK]; }
							srcpos=srclink+cStationRail.GetRelativeTileBackward(srcStation.s_ID, srcUseEntry);
							dstpos=dstlink+cStationRail.GetRelativeTileBackward(dstStation.s_ID, dstUseEntry);
							DInfo("Calling rail pathfinder: srcpos="+srcpos+" dstpos="+dstpos+" srclink="+srclink+" dstlink="+dstlink,2);
							local result=cPathfinder.GetStatus([srclink,srcpos],[dstlink,dstpos], srcStation.s_ID, srcUseEntry);
							switch (result)
									{
									case	-1:
										cPathfinder.CloseTask([srclink,srcpos],[dstlink,dstpos]);
										cError.RaiseError();
										return false;
										break;
									case	2:
										retry = false;
										break;
									default:
										return false;
									}
							dstStation.s_Train[TrainType.OWNER]= INSTANCE.main.route.UID;
							srcStation.s_Train[TrainType.OWNER]= INSTANCE.main.route.UID;
							}
					}
			}
	while (retry);
	// pfff here, all connections were made, and rails built
	INSTANCE.main.route.Source_RailEntry=srcUseEntry;
	INSTANCE.main.route.Target_RailEntry=dstUseEntry;
	INSTANCE.main.route.SourceStation.SetPrimaryLineBuilt();
	INSTANCE.main.route.TargetStation.SetPrimaryLineBuilt();
	INSTANCE.main.route.Primary_RailLink=true;
	INSTANCE.main.route.Route_GroupNameSave();
	cPathfinder.CloseTask([srclink,srcpos],[dstlink,dstpos]);
	return true;
	}

function cBuilder::CreateAndBuildTrainStation(tilepos, direction, platnum, link = AIStation.STATION_NEW)
// Create a new station, we still don't know if station will be usable
// that's a task handle by CreateStationConnection
// link: true to link to a previous station
	{
	local c = AITile.GetTownAuthority(tilepos);
	if (AITown.IsValidTown(c) && AITown.GetRating(c, AICompany.COMPANY_SELF) < AITown.TOWN_RATING_POOR)	{ cTileTools.SeduceTown(c); }
	local money = (INSTANCE.main.carrier.train_length*AIRail.GetBuildCost(AIRail.GetCurrentRailType(), AIRail.BT_STATION)*cBanker.GetInflationRate()).tointeger();
	if (!cBanker.CanBuyThat(money))	{ DInfo("We lack money to buy the station",1); }
	cBanker.RaiseFundsBy(money);
	if (link != AIStation.STATION_NEW && AIStation.IsValidStation(link))
        {
        local rt = AIRail.GetRailType(AIStation.GetLocation(link));
        cTrack.SetRailType(rt);
        }
	if (!AIRail.BuildRailStation(tilepos, direction, platnum, INSTANCE.main.carrier.train_length, link))
			{
			DInfo("Rail station couldn't be built, link="+link+" cost="+money,1);
			cDebug.PutSign(tilepos,"!");
			return false;
			}
    return true;
	}

function cBuilder::RailStationRemovePlatform(staloc)
// remove a rail station platform we found at staloc
// discard any errors, we just try to remove it
	{
	local tilelist=cTileTools.FindStationTiles(statile);
	if (tilelist.IsEmpty())	{ return true; }
	local Keeper=null;
	local railtrack=null;
	if (AIRail.GetRailStationDirection(staloc) == AIRail.RAILTRACK_NW_SE)
			{ tilelist.Valuate(AIMap.GetTileX); Keeper=AIMap.GetTileX(staloc); railtrack=AIRail.RAILTRACK_NW_SE; }
	else	{ tilelist.Valuate(AIMap.GetTileY); Keeper=AIMap.GetTileY(staloc); railtrack=AIRail.RAILTRACK_NE_SW; }
	tilelist.KeepValue(Keeper);
	cDebug.showLogic(tilelist);
	foreach (tile, dummy in tilelist)	AIRail.RemoveRailTrack(tile, railtrack);
	return true;
	}

function cBuilder::PlatformConnectors(platform, useEntry)
// connect a platform (build rail and the signal before crosspoint)
// platform: platform tile to work on
// useEntry: connect the platform entry or exit
// on error -1, if rails are already there, no error is report, only if we cannot manage to connect it
	{
	local frontTile=cStationRail.GetPlatformFrontTile(platform, useEntry);
	if (frontTile==-1)	{ DError("Invalid front tile",1); return false; }
	local stationID=AIStation.GetStationID(platform);
	local thatstation=cStation.Load(stationID);
	if (!thatstation)	{ return false; }
	cTrack.SetRailType(thatstation.s_SubType); // not to forget
	local crossing = 0;
	if (useEntry)	{ crossing=thatstation.s_EntrySide[TrainSide.CROSSING]; }
            else	{ crossing=thatstation.s_ExitSide[TrainSide.CROSSING]; }
	if (crossing < 0)	{ DError("Crossing isn't define yet",2); return false; }
	local forwardTileOf=cStationRail.GetRelativeTileForward(stationID, useEntry);
	local backwardTileOf=cStationRail.GetRelativeTileBackward(stationID, useEntry);
	local leftTileOf=cStationRail.GetRelativeTileLeft(stationID, useEntry);
	local rightTileOf=cStationRail.GetRelativeTileRight(stationID, useEntry);
	local direction=thatstation.GetRailStationDirection();
	local goal=0;
	local railFront, railCross, railLeft, railRight, railUpLeft, railUpRight = null;
	if (direction == AIRail.RAILTRACK_NW_SE)
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
			}
	local rail=railFront;
	local sweeper=AIList();
	local error=false;
	cDebug.PutSign(goal,"g");
	cTileTools.TerraformLevelTiles(frontTile+backwardTileOf, goal);
	local i=frontTile;
	local signaldone=false;
	while (i != goal)
			{
			cTileTools.DemolishTile(i); // rails are protect there
			cDebug.PutSign(i,"o");
			if (cTileTools.CanUseTile(i, thatstation.s_ID) && cTrack.DropRailHere(rail, i, stationID, useEntry))
					{
					sweeper.AddItem(i, 0);
					signaldone = (AIRail.GetSignalType(i, i+backwardTileOf) != AIRail.SIGNALTYPE_NONE);
					if (!signaldone)	{ signaldone= cError.ForceAction(AIRail.BuildSignal, i, i+backwardTileOf, AIRail.SIGNALTYPE_PBS); }
					}
			else
					{
					error = cTileTools.CanUseTile(i, thatstation.s_ID);
					if (error)	{ break; }
					}
			i+=forwardTileOf;
			}
	if (!error)
			{
			local sta_left = frontTile+backwardTileOf+leftTileOf;
            local sta_right = frontTile+backwardTileOf+rightTileOf;
            local got_left = (AIStation.GetStationID(sta_left) == stationID);
            local got_right = (AIStation.GetStationID(sta_right) == stationID);
            cTileTools.DemolishTile(goal);
            if (got_left)	{ cTrack.DropRailHere(railLeft, goal, stationID, useEntry); }
            if (got_right)	{ cTrack.DropRailHere(railRight, goal, stationID, useEntry); }
            if (got_left && got_right)	{ cTrack.DropRailHere(railCross, goal, stationID, useEntry); }
            cBuilder.RailConnectorSolver(goal+backwardTileOf, goal, true);
			}
	if (error)	{ cTrack.RailCleaner(sweeper, stationID); }
	return true;
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
	local direction=cBuilder.GetDirection(tilefrom, tileto);
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
			local jumpdir=cBuilder.GetDirection(tileto, endat);
			if (jumpdir == direction) // if the bridge/tunnel goes the same direction, then consider it a plain rail
					{
					tileto_mask=tileto_need;
					}
			}
	if (cBridge.IsBridgeTile(tilefrom) || AITunnel.IsTunnelTile(tilefrom))
			{
			local endat=null;
			endat=cBridge.IsBridgeTile(tilefrom) ? AIBridge.GetOtherBridgeEnd(tilefrom) : AITunnel.GetOtherTunnelEnd(tilefrom);
			local jumpdir=cBuilder.GetDirection(endat, tilefrom); // reverse direction to find the proper one
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
					testdir=cBuilder.GetDirection(tile, test);
					DInfo("Rail depot found",2);
					trackinfo= (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
					}
			if (AITunnel.IsTunnelTile(tile))
					{
					test=AITunnel.GetOtherTunnelEnd(tile);
					testdir=cBuilder.GetDirection(tile, test);
					DInfo("Tunnel found",2);
					trackinfo = (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
					}
			if (cBridge.IsBridgeTile(tile))
					{
					test=AIBridge.GetOtherBridgeEnd(tile);
					testdir=cBuilder.GetDirection(tile, test);
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
            seek_search = directionmap.GetValue(cBuilder.GetDirection(tile_target, tile_seek));
			// we ask direction target->seek to find what point tile_seek need set, so SW-SE = SW
            local dest_search = directionmap.GetValue(cBuilder.GetDirection(tile_target, dest));
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
	local max_signals_distance=3;
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
				sourcedir=cBuilder.GetDirection(source+voisin, source);
				DInfo("Found source signal at "+source+" facing "+sourcedir+" voisin="+(source+voisin),2);
				sourcecheck=source+voisin; // to feed pathfinder with a tile without the signal on it
				cDebug.PutSign(sourcecheck,"s");
				}
		}
	if (sourcedir == null)	{ DError("Cannot find source signal at "+source,2); return false; }
	foreach (voisin in directions)
		{
		if (AIRail.GetSignalType(target, target+voisin) == AIRail.SIGNALTYPE_PBS)
				{
				targetdir=cBuilder.GetDirection(target+voisin, target);
				DInfo("Found target signal at "+target+" facing "+targetdir+" voisin="+(target+voisin),2);
				targetcheck=target+voisin;
				cDebug.PutSign(targetcheck,"t");
				}
		}
	if (targetdir == null)	{ DError("Cannot find target signal at "+target,2); return false; }
	local pathwalker = RailFollower();
	pathwalker.InitializePath([[source, sourcecheck]], [[targetcheck, target]]);// start beforestart    end afterend
	local path = pathwalker.FindPath(20000);
	if (path == null)	{ DError("Pathwalking failure.",2); return false; }
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
					else
							{
							cDebug.PutSign(tile,"!");
							local smallerror=cBuilder.EasyError(AIError.GetLastError());
							DError("Error building signal ",1);
							//max_signals_distance++;
							if (smallerror == -1)	{ return false; }
							}
					}
			cc++;
			prev=tile;
			path = path.GetParent();
			}
	return allsuccess;
	}
