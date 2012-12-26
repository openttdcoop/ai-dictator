/* -*- Mode: C++; tab-width: 6 -*- */ 
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

class MyRailPF extends RailPathFinder
	{
	_cost_level_crossing = null;
	}

function MyRailPF::_Cost(path, new_tile, new_direction, self)
{
	local cost = ::RailPathFinder._Cost(path, new_tile, new_direction, self);
	return cost;
}
/*
function MyRailPF::_Estimate(cur_tile, cur_direction, goal_tiles, self)
{
	return 1.4*::RailPathFinder._Estimate(cur_tile, cur_direction, goal_tiles, self);
}*/

function MyRailPF::_Estimate(cur_tile, cur_direction, goal_tiles, self)
{
	local min_cost = self._max_cost;
	/* As estimate we multiply the lowest possible cost for a single tile with
	 *  with the minimum number of tiles we need to traverse. */
	foreach (tile in goal_tiles) {
		local dx = abs(AIMap.GetTileX(cur_tile) - AIMap.GetTileX(tile[0]));
		local dy = abs(AIMap.GetTileY(cur_tile) - AIMap.GetTileY(tile[0]));
		//min_cost = min(min_cost, min(dx, dy) * self._cost_diagonal_tile * 2 + (max(dx, dy) - min(dx, dy)) * self._cost_tile);
		local thatmul=0;
		if (AITile.GetSlope(cur_tile) == AITile.SLOPE_FLAT)	thatmul=self._cost_tile;
										else	thatmul=self._cost_slope;
		min_cost= max(dx, dy)*thatmul*1.4; // the Chebyshev_distance
		min_cost= max(dx, dy)*self._cost_tile*2;
	}
	return min_cost;
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
local dir, tilelist, otherplace, isneartown = null;
local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
local istown=false;
local srcpoint=null;
local sourceplace=null;
local statile=null;
if (start)	{
		dir = INSTANCE.main.builder.GetDirection(INSTANCE.main.route.source_location, INSTANCE.main.route.target_location);
		if (INSTANCE.main.route.source_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.main.route.sourceID);
			tilelist.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.cargoID, 1, 1, rad);
			tilelist.KeepAboveValue(0); 
			istown=true;
			}
		else	{
			tilelist = AITileList_IndustryProducing(INSTANCE.main.route.sourceID, rad);
			istown=false;
			}
		otherplace=INSTANCE.main.route.target_location; sourceplace=INSTANCE.main.route.source_location;
		}
	else	{
		dir = INSTANCE.main.builder.GetDirection(INSTANCE.main.route.target_location, INSTANCE.main.route.source_location);
		if (INSTANCE.main.route.target_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.main.route.targetID);
			tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.cargoID, 1, 1, rad);
			tilelist.KeepAboveValue(8); 
			istown=true;
			}
		else	{
			tilelist = AITileList_IndustryAccepting(INSTANCE.main.route.targetID, rad);
			isneartown=false; istown=false;
			}
		otherplace=INSTANCE.main.route.source_location; sourceplace=INSTANCE.main.route.target_location;
		}

//tilelist.Valuate(cTileTools.IsBuildable);
//tilelist.KeepValue(1);
local success = false;
local saveList=AIList();
saveList.AddList(tilelist);
//DInfo("isneartown="+isneartown+" istown="+istown,2,"BuildTrainStation");
local buildmode=0;
local cost=5*AIRail.GetBuildCost(AIRail.GetCurrentRailType(),AIRail.BT_STATION);
DInfo("Rail station cost: "+cost+" byinflat"+(cost*cBanker.GetInflationRate()),2);
INSTANCE.main.bank.RaiseFundsBy(cost);
local ssize=6+INSTANCE.main.carrier.train_length;
do
	{
/* 5 build mode:
- try find a place with stationsize+4 tiles flatten and buildable
- same other direction
- try find a place with stationsize+4 tiles maybe not flat and buildable
- same other direction
- try find a place with stationsize+4 tiles maybe not flat and buildable even on water
*/
	tilelist.Clear();
	tilelist.AddList(saveList);
	tilelist=cTileTools.PurgeBlackListTiles(tilelist, true);
	// remove known bad spot for creating a station
	switch (buildmode)
		{
		case	0:
			tilelist.Valuate(cTileTools.IsBuildableRectangleFlat,2,ssize);
			tilelist.KeepValue(1);
			break;
		case	1:
			tilelist.Valuate(cTileTools.IsBuildableRectangleFlat,ssize,1);
			tilelist.KeepValue(1);
			break;
		case	2:
			tilelist.Valuate(AITile.IsBuildableRectangle,1,ssize); // allow terraform19
			tilelist.KeepValue(1);
			break;
		case	3:
			tilelist.Valuate(AITile.IsBuildableRectangle,ssize,1); // allow terraform91
			tilelist.KeepValue(1);
			break;
		case	4:
			tilelist.Valuate(cTileTools.IsBuildable); // even water will be terraform
			tilelist.KeepValue(1);
			break;
		}
	DInfo("Tilelist set to "+tilelist.Count()+" in mode "+buildmode,1);
	// restore previous valuated values...
	foreach (ltile, lvalue in saveList)	if (tilelist.HasItem(ltile))	tilelist.SetValue(ltile, lvalue);
	if (!istown)
		{
		tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
		tilelist.Sort(AIList.SORT_BY_VALUE, true);
		}
	else	{ tilelist.Sort(AIList.SORT_BY_VALUE, false); }
	cDebug.showLogic(tilelist); 
	ClearSigns();
	foreach (tile, dummy in tilelist)
		{
		// find where that point is compare to its source for the station
			if (start)	dir=INSTANCE.main.builder.GetDirection(tile, INSTANCE.main.route.source_location);
				else	dir=INSTANCE.main.builder.GetDirection(INSTANCE.main.route.target_location,tile);
			switch (dir)
				{
				case DIR_NW: //0 south
					if (istown)	dir=AIRail.RAILTRACK_NW_SE;
						else	dir=AIRail.RAILTRACK_NE_SW;
					break;
				case DIR_SE: //1 north
					if (istown)	dir=AIRail.RAILTRACK_NW_SE;
						else	dir=AIRail.RAILTRACK_NE_SW;
					break;
				case DIR_SW: //3 est/droite
					if (istown)	dir=AIRail.RAILTRACK_NE_SW;
						else	dir=AIRail.RAILTRACK_NW_SE;
					break;
				case DIR_NE: //2 west/gauche
					if (istown)	dir=AIRail.RAILTRACK_NE_SW;
						else	dir=AIRail.RAILTRACK_NW_SE;
					break;
				}
			DInfo("New station direction set to "+dir,1);
		if (buildmode==4)
			{
			if (dir == AIRail.RAILTRACK_NW_SE)	statile=cTileTools.CheckLandForConstruction(tile, 1, INSTANCE.main.carrier.train_length);
								else	statile=cTileTools.CheckLandForConstruction(tile, INSTANCE.main.carrier.train_length, 1);
			}
		else	statile=tile;
		if (statile == -1)	continue; // we have no solve to build a station here
		success=INSTANCE.main.builder.CreateAndBuildTrainStation(statile, dir);
		if (!success)
			{
			// switch again station direction, a solve exist there
			if (dir == AIRail.RAILTRACK_NE_SW)	dir=AIRail.RAILTRACK_NW_SE;
								else	dir=AIRail.RAILTRACK_NE_SW;
			success=INSTANCE.main.builder.CreateAndBuildTrainStation(statile, dir);
			if (!success && AIError.GetLastError()==AIError.ERR_LOCAL_AUTHORITY_REFUSES)	{ break; }
			}
		if (success)	{
					statile=tile;
					break;
					}
				else	{ // see why we fail
					if (buildmode==4)	cTileTools.BlackListTileSpot(statile);
					cError.IsCriticalError();
					if (cError.IsError())	{ break; }
					}
		}
	buildmode++;
	} while (!success && buildmode!=5);
ClearSigns();

if (!success) 
	{
	DInfo("Can't find a good place to build the train station ! "+tilelist.Count(),1);
	if (tilelist.IsEmpty())	cError.RaiseError();
	return false;
	}
// here, so we success to build one
local staID=AIStation.GetStationID(statile);
if (start)	INSTANCE.main.route.source_stationID=staID;
	else	INSTANCE.main.route.target_stationID=staID;
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

function cBuilder::BuildRoadRAIL(head1, head2, useEntry, stationID)
{
local status=cPathfinder.GetStatus(head1, head2, stationID, useEntry);
local path=cPathfinder.GetSolve(head1, head2);
local smallerror=0;
if (path == null)	smallerror=-2;
switch (status)
	{
	case	0:	// still pathfinding
	return 0;
	case	-1:	// failure
	return -1;
	case	2:	// succeed
	return 1;
	case	3:	// waiting child to end
	return 0;
	}
// 1 is non covered as it's end of pathfinding, and should call us to build
INSTANCE.main.bank.RaiseFundsBigTime();
local prev = null;
local prevprev = null;
local pp1, pp2, pp3 = null;
local walked=[];
while (path != null && smallerror==0)
	{
	if (prevprev != null)
		{
		if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1)
			{
			if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile())
				{
				if (!AITunnel.BuildTunnel(AIVehicle.VT_RAIL, prev))
					{
					DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
					smallerror=cBuilder.EasyError(AIError.GetLastError());
					if (smallerror==-1)
						{
						DInfo("That tunnel would be too expensive. Construction aborted.",2);
						return false;
						}
					if (smallerror==-2)	break;
					}
				else	{
					cTileTools.BlackListTile(prev, -stationID); // i mark them as blacklist and assign to -stationID, so i could recover them later
					cTileTools.BlackListTile(path.GetTile(), -stationID);
					}
				}
			else	{
				local bridgeID = cBridge.GetCheapBridgeID(AIVehicle.VT_RAIL, AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
				if (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridgeID, prev, path.GetTile()))
					{
					DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
					smallerror=cBuilder.EasyError(AIError.GetLastError());
					if (smallerror==-1)
						{
						DInfo("That bridge would be too expensive. Construction aborted.",2);
						return false;
						}
					if (smallerror==-2)	break;
					}
				else	{
					cTileTools.BlackListTile(prev, -stationID);
					cTileTools.BlackListTile(path.GetTile(), -stationID);
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
		 else {
			// check for small up/down hills correction
			local targetTile=path.GetTile();
			print("prevprev="+AITile.GetSlope(prevprev)+"("+AITile.GetMinHeight(prevprev)+","+AITile.GetMaxHeight(prevprev)+")"+" prev="+AITile.GetSlope(prev)+"("+AITile.GetMinHeight(prev)+","+AITile.GetMaxHeight(prev)+")"+" targetTile="+AITile.GetSlope(targetTile)+"("+AITile.GetMinHeight(targetTile)+","+AITile.GetMaxHeight(targetTile)+")");
		//	local equal= (AITile.GetMinHeight(prev) == AITile.GetMinHeight(targetTile));
			//if (!equal)	equal = (AITile.GetMaxHeight(prev) == AITile.GetMaxHeight(targetTile));
			local smooth=false;
			if (AITile.GetSlope(prevprev) == AITile.SLOPE_FLAT && AITile.GetMaxHeight(targetTile) < AITile.GetMaxHeight(prev) && AITile.GetMaxHeight(prev) > AITile.GetMaxHeight(prevprev))	{ smooth=true; print("should smooth going up"); }
			if (AITile.GetSlope(prevprev) == AITile.SLOPE_FLAT && AITile.GetMinHeight(targetTile) >  AITile.GetMinHeight(prev) && AITile.GetMinHeight(prev) < AITile.GetMinHeight(prevprev))	{ smooth=true; print("should smooth going down"); }

//			if (false && equal && AITile.GetSlope(prev) != AITile.SLOPE_FLAT && AITile.GetSlope(targetTile) != AITile.SLOPE_FLAT && AITile.GetSlope(prevprev) == AITile.SLOPE_FLAT)
			if (false)
				{
				DInfo("Smoothing land to build rails",1);
				cTileTools.TerraformLevelTiles(prevprev, targetTile);
				}
			if (!AIRail.BuildRail(prevprev, prev, targetTile))
				{
				smallerror=cBuilder.EasyError(AIError.GetLastError());
				if (smallerror==-1)
					{
					DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
					return false;
					}
				if (smallerror==-2)	break;
				}
			else	{
				cTileTools.BlackListTile(prev, -stationID);
				cTileTools.BlackListTile(path.GetTile(), -stationID);
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
local mytask=cPathfinder.GetPathfinderObject(cPathfinder.GetUID(head1, head2));
local source=cPathfinder.GetUID(mytask.r_source, mytask.r_target);
if (smallerror == -2)
	{
	DError("Pathfinder has detect a failure.",1);
	if (walked.len() < 4)
		{
		DInfo("Pathfinder cannot do more",1);
		// unroll all tasks and fail
		source=cPathfinder.GetUID(mytask.source, mytask.target);
		while (source != null)
			{ // remove all sub-tasks
			DInfo("Pathfinder helper task "+source+" failure !",1);
			source=cPathfinder.GetUID(mytask.r_source, mytask.r_target);
			if (source != null)
				{
				cPathfinder.CloseTask(mytask.source, mytask.target);
				mytask=cPathfinder.GetPathfinderObject(source);
				}
			}
		DInfo("Pathfinder task "+mytask.UID+" failure !",1);
		mytask.status=-1;
		local badtiles=AIList();
		badtiles.AddList(cTileTools.TilesBlackList); // keep blacklisted tiles for -stationID
		badtiles.KeepValue(-mytask.stationID);
		cBuilder.RailCleaner(badtiles); // remove all rail we've built
		foreach (tiles, dummy in badtiles)	cTileTools.UnBlackListTile(tiles); // and release them for others
		cError.RaiseError();
		return false;
		}
	else	{
		local maxstepback=10;
		walked.pop(); // dismiss last one, it's the failure
		if (walked.len() < maxstepback)	maxstepback=walked.len()-1;
		local alist=AIList();
		for (local ii=1; ii < maxstepback; ii++)
			{
			prev=walked.pop();
			alist.AddItem(prev, 0);
			}
		prevprev=walked.pop();
		cBuilder.RailCleaner(alist);
		local newtarget=[prev, prevprev];
		DInfo("Pathfinder is calling an helper task",1);
		// Create the helper task
		local dummy= cPathfinder.GetStatus(head1, newtarget, stationID, useEntry);
		dummy=cPathfinder.GetPathfinderObject(cPathfinder.GetUID(head1, newtarget));
		dummy.r_source=head1;
		dummy.r_target=head2;
		mytask.status=3; // wait for subtask end
		return false;
		}
	}
else	{ // we cannot get smallerror==-1 because on -1 it always return, so limit to 0 or -2
	// let's see if we success or an helper task has succeed for us
	if (source != null)
		{
		source=cPathfinder.GetUID(mytask.source, mytask.target);
		while (source != null)
			{ // remove all sub-tasks
			DInfo("Pathfinder helper task "+source+" succeed !",1);
			source=cPathfinder.GetUID(mytask.r_source, mytask.r_target);
			if (source != null)
				{
				//DInfo("Pathfinder helper task "+source+" succeed !",1,"cBuilder::BuildRoadRail");
				cPathfinder.CloseTask(mytask.source, mytask.target);
				mytask=cPathfinder.GetPathfinderObject(source);
				}
			}
		}
	DInfo("Pathfinder task "+mytask.UID+" succeed !",1);
	mytask.status=2;
	local bltiles=AIList();
	bltiles.AddList(cTileTools.TilesBlackList);
	bltiles.KeepValue(-stationID);
	foreach (tile, dummy in bltiles)	cStation.RailStationClaimTile(tile, useEntry, stationID); // assign tiles to that station
	return true;
	}
}

function cBuilder::ReportHole(start, end, waserror)
{
	if (!waserror) {
		holestart = start;
	}
	holeend = end;
}

function cBuilder::FindStationEntryToExitPoint(src, dst)
// find the closest path from station src to station dst
// We return result in array: 0=src tile, 1=1(entry)0(exit), 1=dst tile, value=1(entry)0(exit)
// return array empty on error
// 
{
// check entry/exit avaiablility on stations
local srcEntry=cStation.IsRailStationEntryOpen(src);
local srcExit=cStation.IsRailStationExitOpen(src);
local dstEntry=cStation.IsRailStationEntryOpen(dst);
local dstExit=cStation.IsRailStationExitOpen(dst);
local srcEntryLoc=cStation.GetRailStationFrontTile(true, cStation.GetLocation(src), src);
local dstEntryLoc=cStation.GetRailStationFrontTile(true, cStation.GetLocation(dst), dst);
local srcExitLoc=cStation.GetRailStationFrontTile(false, cStation.GetLocation(src), src);
local dstExitLoc=cStation.GetRailStationFrontTile(false, cStation.GetLocation(dst), dst);

local srcStation=cStation.GetStationObject(src);
local dstStation=cStation.GetStationObject(dst);
if ( srcStation==null || dstStation==null || (!srcEntry && !srcExit) || (!dstEntry && !dstExit) )
	{
	DInfo("That station have its entry and exit closed. No more connections could be made with it",1);
	return [];
	}
local srcEntryBuild=(srcStation.locations.GetValue(11) != -1); // because if we have build it and it is still open, we must use that point, even if it's not the shortest path
local srcExitBuild=(srcStation.locations.GetValue(13) != -1);  // else we may prefer another point that would be shorter, leaving that entry/exit built for nothing
local dstEntryBuild=(dstStation.locations.GetValue(12) != -1);
local dstExitBuild=(dstStation.locations.GetValue(14) != -1);
print("srcEntryBuild="+srcEntryBuild+" srcExitBuild="+srcExitBuild+" dstEntryBuild="+dstEntryBuild+" dstExitBuild="+dstExitBuild);
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
if (check == -1) return [];
if (bestsrc == srcEntryLoc)	srcFlag=1;
if (bestdst == dstEntryLoc)	dstFlag=1;
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
local srcStation=cStation.GetStationObject(fromObj);
local dstStation=cStation.GetStationObject(toObj);
DInfo("Connecting rail station "+cStation.StationGetName(srcStation.stationID)+" to "+cStation.StationGetName(dstStation.stationID),1);
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
do	{
	bestWay=INSTANCE.main.builder.FindStationEntryToExitPoint(fromObj, toObj);
	if (bestWay.len()==0)	{ cError.RaiseError(); return false; }
				else	retry=true;
	if (retry) // we found a possible connection
		{
		srcpos=bestWay[0];
		dstpos=bestWay[2];
		srcUseEntry=(bestWay[1]==1);
		dstUseEntry=(bestWay[3]==1);
		DInfo("srcUseEntry="+srcUseEntry+" dstUseEntry="+dstUseEntry,2);
		if (!srcresult)	srcresult=INSTANCE.main.builder.RailStationGrow(fromObj, srcUseEntry, true);
		if (!srcresult)
			{
			DWarn("RailStationGrow report failure",1);
			if (cError.IsError())	return false;
			}
		if (!dstresult)	dstresult=INSTANCE.main.builder.RailStationGrow(toObj, dstUseEntry, false);
		if (!dstresult)
			{
			DWarn("RailStationGrow report failure",1);
			if (cError.IsError())	return false;
			}
		if (dstresult && srcresult)
			{
			// need to grab the real locations first, as they might have change while building entrances of station
			local mainowner=srcStation.locations.GetValue(22);
			if (srcUseEntry)	srclink=srcStation.locations.GetValue(11);
					else	srclink=srcStation.locations.GetValue(13);
			if (dstUseEntry)	dstlink=dstStation.locations.GetValue(12);
					else	dstlink=dstStation.locations.GetValue(14);
			srcpos=srclink+cStation.GetRelativeTileBackward(srcStation.stationID, srcUseEntry);
			dstpos=dstlink+cStation.GetRelativeTileBackward(dstStation.stationID, dstUseEntry);
			if (mainowner==-1)
				{

				DInfo("Calling rail pathfinder: srcpos="+srcpos+" dstpos="+dstpos+" srclink="+srclink+" dstlink="+dstlink,2);
				/*cDebug.PutSign(dstpos,"D");
				cDebug.PutSign(dstlink,"d");
				cDebug.PutSign(srcpos,"S");
				cDebug.PutSign(srclink,"s");*/
				local result=INSTANCE.main.builder.BuildRoadRAIL([srclink,srcpos],[dstlink,dstpos], srcUseEntry, srcStation.stationID);
				if (result != 1)
					{
					if (result == -1)	cPathfinder.CloseTask([srclink,srcpos],[dstlink,dstpos]);
					return false;
					}
				else	retry=false;
				dstStation.locations.SetValue(22,INSTANCE.main.route.UID);
				srcStation.locations.SetValue(22,INSTANCE.main.route.UID);
				}
			else	retry=false;
			}
		}
	} while (retry);
// pfff here, all connections were made, and rails built
if (srcUseEntry)	srcStation.locations.SetValue(11,dstpos);
		else	srcStation.locations.SetValue(13,dstpos);
if (dstUseEntry)	dstStation.locations.SetValue(12,srcpos);
		else	dstStation.locations.SetValue(14,srcpos);
INSTANCE.main.route.source_RailEntry=srcUseEntry;
INSTANCE.main.route.target_RailEntry=dstUseEntry;
INSTANCE.main.route.primary_RailLink=true;
cPathfinder.CloseTask([srclink,srcpos],[dstlink,dstpos]);
return true;
}

function cBuilder::CreateAndBuildTrainStation(tilepos, direction, link=null)
// Create a new station, we still don't know if station will be usable
// that's a task handle by CreateStationConnection
// link: true to link to a previous station
{
if (link==null)	link=AIStation.STATION_NEW;
local money=INSTANCE.main.carrier.train_length*AIRail.GetBuildCost(AIRail.GetCurrentRailType(), AIRail.BT_STATION)*cBanker.GetInflationRate();
if (!cBanker.CanBuyThat(money))	DInfo("We lack money to buy the station",1);
INSTANCE.main.bank.RaiseFundsBy(money);
if (!AIRail.BuildRailStation(tilepos, direction, 1, INSTANCE.main.carrier.train_length, link))
	{
	DInfo("Rail station couldn't be built, link="+link+" cost="+money+" err: "+AIError.GetLastErrorString(),1);
	cDebug.PutSign(tilepos,"!");
	return false;
	}
return true;
}

function cBuilder::SetRailType(rtype=null)
// set current railtype
{
	if (rtype == null)
		{
		local railtypes = AIRailTypeList();
		if (railtypes.IsEmpty())	{ DError("There's no railtype avaiable !",1); return false; }
		rtype=railtypes.Begin();
		}
	if (!AIRail.IsRailTypeAvailable(rtype))	{ DError("Railtype "+rtype+" is not available !",1); return false; }
	AIRail.SetCurrentRailType(rtype);
}

function cBuilder::RailStationRemovePlatform(staloc)
// remove a rail station platform we found at staloc
// discard any errors, we just try to remove it
{
local tilelist=cTileTools.FindStationTiles(statile);
if (tilelist.IsEmpty())	return true;
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

function cBuilder::RailStationGrow(staID, useEntry, taker)
// make the station grow and build entry/exit
// staID: stationID
// useEntry: true to add a train to its entry, false to add it at exit
// taker: true to add a taker train, false to add a dropper train
{
// when a station entry cannot be change anymore, we lock it and refuse any train on it
// "" for exit
// when both entry and exit are locked, still the station might be a valid & working one
// so a dead one is : entry+exit locked, no train using it, size=1
local thatstation=cStation.GetStationObject(staID);
if (thatstation.stationID == null)	return false;
local trainEntryTaker=thatstation.locations.GetValue(9);
local trainExitTaker=thatstation.locations.GetValue(10);
local trainEntryDropper=thatstation.locations.GetValue(7);
local trainExitDropper=thatstation.locations.GetValue(8);
local station_depth=thatstation.locations.GetValue(19);

local success=false;
local closeIt=false;
if (useEntry)
	{
	if (taker)	trainEntryTaker++;
		else	trainEntryDropper++;
	}
else	{
	if (taker)	trainExitTaker++;
		else	trainExitDropper++;
	}
local tED=(trainEntryDropper / 2);
local tXD=(trainExitDropper / 2);
if (trainEntryDropper != 0)
	{
	if (trainEntryDropper == 1)	tED=1;
					else	tED=(trainEntryDropper / 2)+1;
	}
if (trainExitDropper != 0)
	{
	if (trainExitDropper == 1)	tXD=1;
					else	tXD=(trainExitDropper / 2)+1;
	}
local newStationSize=trainEntryTaker+trainExitTaker+tED+tXD;
local maxE_total=thatstation.maxsize * 2;
if (!cStation.IsRailStationEntryOpen(staID))	maxE_total=thatstation.size *2;
local maxX_total=thatstation.maxsize * 2;
if (!cStation.IsRailStationExitOpen(staID))	maxX_total=thatstation.size *2;
if (!cStation.IsRailStationEntryOpen(staID) && useEntry)	{ DWarn(thatstation.name+" entry is CLOSE",1); return false }
if (!cStation.IsRailStationExitOpen(staID) && !useEntry)	{ DWarn(thatstation.name+" exit is CLOSE",1); return false }

DInfo(thatstation.name+" entry throughput : "+(trainEntryDropper+trainEntryTaker)+"/"+maxE_total+" trains",1);
DInfo(thatstation.name+" exit throughput : "+(trainExitDropper+trainExitTaker)+"/"+maxX_total+" trains",1);

local position=thatstation.GetLocation();
local direction=thatstation.GetRailStationDirection();
INSTANCE.main.builder.SetRailType(thatstation.specialType); // not to forget
local leftTileOf, rightTileOf, forwardTileOf, backwardTileOf =null;
local workTile=null; // the station front tile, but depend on entry or exit
local railFront, railCross, railLeft, railRight, railUpLeft, railUpRight, fire = null;
workTile=thatstation.GetRailStationFrontTile(useEntry,position);
// find route that use the station
local road=null;

if (thatstation.owner.IsEmpty())
	{
	DWarn("Nobody claim that station yet",1);
	}
else	{
	local uidowner=thatstation.locations[22];
	road=cRoute.GetRouteObject(uidowner);
	if (road==null)
		{
		DWarn("The route owner ID "+uidowner+" is invalid",1);
		}
	else	DWarn("Station main owner "+uidowner,1);
	}
//DWarn("Real main owner : "+thatstation.locations[22],1,"RailStationGrow");


local temptile=0;
if (direction == AIRail.RAILTRACK_NW_SE)
	{
	railFront=AIRail.RAILTRACK_NW_SE;
	railCross=AIRail.RAILTRACK_NE_SW;
	if (useEntry)	{ // going NW->SE
				railLeft=AIRail.RAILTRACK_SW_SE;
				railRight=AIRail.RAILTRACK_NE_SE;
				railUpLeft=AIRail.RAILTRACK_NW_SW;
				railUpRight=AIRail.RAILTRACK_NW_NE;
				}
			else	{ // going SE->NW
				railLeft=AIRail.RAILTRACK_NW_NE;
				railRight=AIRail.RAILTRACK_NW_SW;
				railUpLeft=AIRail.RAILTRACK_NE_SE;
				railUpRight=AIRail.RAILTRACK_SW_SE;
				}
	}
else	{ // NE_SW
	railFront=AIRail.RAILTRACK_NE_SW;
	railCross=AIRail.RAILTRACK_NW_SE;
	if (useEntry)	{ // going NE->SW
				railLeft=AIRail.RAILTRACK_NW_SW;
				railRight=AIRail.RAILTRACK_SW_SE;
				railUpLeft=AIRail.RAILTRACK_NW_NE;
				railUpRight=AIRail.RAILTRACK_NE_SE;
				}
			else	{ // going SW->NE
				railLeft=AIRail.RAILTRACK_NE_SE;
				railRight=AIRail.RAILTRACK_NW_NE;
				railUpLeft=AIRail.RAILTRACK_SW_SE;
				railUpRight=AIRail.RAILTRACK_NW_SW;
				}
	}
if (useEntry)	DInfo("Working on station entry",1);
		else	DInfo("Working on station exit",1);
leftTileOf=cStation.GetRelativeTileLeft(staID, useEntry);
rightTileOf=cStation.GetRelativeTileRight(staID, useEntry);
forwardTileOf=cStation.GetRelativeTileForward(staID, useEntry);
backwardTileOf=cStation.GetRelativeTileBackward(staID, useEntry);
//cDebug.PutSign(workTile,"W");
local displace=0;
// need grow the station ?
// only define when a train activate it, so only run 1 time
//newStationSize=thatstation.size+1;
local cangrow=true;
if (road == null || (!road.secondary_RailLink && road.target_stationID == staID))	cangrow=false; // don't let it grow if we have no usage for it (target station need a second raillink to grow)
thatstation.DefinePlatform();
if (newStationSize > thatstation.max_trains && cangrow)
	{
	DInfo("--- Phase 1: grow",1);
	DInfo("Upgrading "+thatstation.StationGetName()+" to "+newStationSize+" platforms",1);
	if (thatstation.maxsize==thatstation.size)
		{
		DInfo("We'll need another platform to handle that train, but the station "+cStation.StationGetName(thatstation.stationID)+" cannot grow anymore.",1);
		cError.RaiseError(); // raise it ourselves
		return false;
		}
	local allfail=false;
	local topLeftPlatform=thatstation.locations.GetValue(20);
	local topRightPlatform=thatstation.locations.GetValue(21);
	local idxRightPlatform=cStation.GetPlatformIndex(topRightPlatform, useEntry);
	local idxLeftPlatform=cStation.GetPlatformIndex(topLeftPlatform, useEntry);
cDebug.PutSign(topLeftPlatform,"L");
cDebug.PutSign(topRightPlatform,"R");
cDebug.PutSign(idxLeftPlatform,"IL");
cDebug.PutSign(idxRightPlatform,"IR");
local station_left=AIMap.GetTileIndex(0,-1);
local station_right=AIMap.GetTileIndex(0,1);
if (AIRail.GetRailStationDirection(staID) == AIRail.RAILTRACK_NE_SW)
	{
	station_left=AIMap.GetTileIndex(-1,0);
	station_right=AIMap.GetTileIndex(1,0);
	}
// main station + exit in use best place = left
	local plat_main=idxLeftPlatform;
	local plat_alt=idxRightPlatform;
	local pside=station_left;
	local platopenclose=((thatstation.platforms.GetValue(topLeftPlatform) & 2) == 2);
	if (useEntry)
		{
		pside=station_right; // try build to right side when using entry first, else try left side
		plat_main=idxRightPlatform;
		plat_alt=idxLeftPlatform;
		platopenclose=((thatstation.platforms.GetValue(topRightPlatform) & 1) == 1);
		}
	success=false;
	displace=plat_main+pside;
	local areaclean = AITileList();
	if (platopenclose)
		{
		areaclean.AddRectangle(displace,displace+(backwardTileOf*(station_depth-1)));
		areaclean.Valuate(AITile.IsBuildable);
		cDebug.showLogic(areaclean); // deb
print("BREAK 1");
		local canDestroy=cTileTools.IsAreaBuildable(areaclean,staID);
		if (canDestroy)
			foreach (ctile, cdummy in areaclean)	{ cTileTools.DemolishTile(ctile);	}
		cTileTools.TerraformLevelTiles(plat_main, displace+(backwardTileOf*(station_depth-1)));
		success=INSTANCE.main.builder.CreateAndBuildTrainStation(cStation.GetPlatformIndex(plat_main,true)+pside, direction, thatstation.stationID);
print("success="+success+" platindex="+(cStation.GetPlatformIndex(plat_main,true)+pside)+" direction="+direction);
cDebug.PutSign(cStation.GetPlatformIndex(plat_main,true)+pside,"+");
print("BREAK 2");
		if (success)	foreach (tile, dummy in areaclean)	thatstation.StationClaimTile(tile, thatstation.stationID);
		}
	if (!success)
		{
print("BREAK 3 on failure");
		cError.IsCriticalError();
		allfail=cError.IsError();
		cError.ClearError();
		pside=station_right;
		if (useEntry)	pside=station_left;
		displace=plat_alt+pside;
		local areaclean=AITileList();
		areaclean.AddRectangle(displace,displace+(backwardTileOf*(station_depth-1)));
		cDebug.showLogic(areaclean);
		if (cTileTools.IsAreaBuildable(areaclean,staID))
			foreach (ctile, cdummy in areaclean)	cTileTools.DemolishTile(ctile);
		cTileTools.TerraformLevelTiles(plat_alt, displace+(backwardTileOf*(station_depth-1)));
		success=INSTANCE.main.builder.CreateAndBuildTrainStation(cStation.GetPlatformIndex(plat_alt,true)+pside, direction, thatstation.stationID);
print("success="+success+" platindex="+(cStation.GetPlatformIndex(plat_alt,true)+pside)+" direction="+direction);
cDebug.PutSign(cStation.GetPlatformIndex(plat_alt,true)+pside,"+");
print("BREAK 4");
		if (success)	foreach (tile, dummy in areaclean)	thatstation.StationClaimTile(tile, thatstation.stationID);
		if (!success)	
			{
			cError.IsCriticalError();
			if (cError.IsError() && allfail)
				{ // We will never be able to build one more station platform in that station so
				DInfo("Critical failure, station couldn't be upgrade anymore!",1);
				thatstation.maxsize=thatstation.size;
				cError.RaiseError(); // Make sure caller will be aware of that failure
				return false;
				}
			else	{
				DInfo("Temporary failure, station couldn't be upgrade for now",1);
				return false;
				}
			}
		}
	// if we are here, we endup successfuly add a new platform to the station
	thatstation.DefinePlatform();
	}
local se_IN, se_OUT, se_crossing = null; // entry
local sx_IN, sx_OUT, sx_crossing = null; // exit
se_IN=thatstation.GetRailStationIN(true);
se_OUT=thatstation.GetRailStationOUT(true);
sx_IN=thatstation.GetRailStationIN(false);
sx_OUT=thatstation.GetRailStationOUT(false);
se_crossing=thatstation.locations.GetValue(5);
sx_crossing=thatstation.locations.GetValue(6);
local rail=null;
local success=false;
local crossing=null;
// find if we can use that entry/exit if none is define yet
// run only 1 time as it's only define when a train trigger it
if ( (useEntry && se_crossing==-1) || (!useEntry && sx_crossing==-1) )
	{ // look if we're going too much inside a town, making big damages to it, and mostly sure failure to use that direction to build rails
	DInfo("--- Phase2: define entry/exit point",1);
	local towncheck=AITileList();
	local testcheck=AITileList();
	towncheck.AddRectangle(workTile, workTile+rightTileOf+(5*forwardTileOf));
	testcheck.AddList(towncheck);
	testcheck.Valuate(cTileTools.IsBuildable);
	testcheck.KeepValue(0);
	success=true;
	if (testcheck.Count()>5)	{ DInfo("Giving up, we may put too much havock there",1); success=false; }
	else	{
		if (cTileTools.IsAreaBuildable(towncheck,staID))
			{
			testcheck.AddList(towncheck);
			cTileTools.YexoValuate(testcheck, cTileTools.IsRemovable); // rails are protect here
			cDebug.showLogic(testcheck);
			//INSTANCE.NeedDelay(100);
			testcheck.KeepValue(0);
			if (testcheck.IsEmpty()) // everything is removable
				{
				testcheck.AddList(towncheck);
				testcheck.Valuate(AITile.IsStationTile); // protect station here
				testcheck.KeepValue(1);
				if (testcheck.IsEmpty()) 
					{ // now look if we're not going too much in a town
					local neartown=AITile.GetClosestTown(workTile);
					local s_dst=AITown.GetDistanceManhattanToTile(neartown,workTile);
					local s_end=AITown.GetDistanceManhattanToTile(neartown,workTile+(4*forwardTileOf));
					if (s_dst < 10 && s_end < 10 && s_dst > s_end) // we must be going farer inside the town
						{
						DInfo("Giving up, we're probably going inside "+AITown.GetName(neartown),1);
						success=false;
						}
					else	success=true;
					}
				else	success=false; // station there
				}
			}
		else	{ // not everything is removable, still we might success to cross a road
			testcheck.Valuate(AIRoad.IsRoadTile);
			testcheck.KeepValue(0);
			success=(testcheck.IsEmpty());
			}
		}
	if (success)	foreach (tile, dummy in towncheck)	cTileTools.DemolishTile(tile);
				else	{ DInfo("We gave up, too much troubles",1); closeIt=true; }
	}

// define & build crossing point if none exist yet
// only need define when need, when a train try use one of them, so only run 1 time
if ( ((useEntry && se_crossing==-1) || (!useEntry && sx_crossing==-1)) && !closeIt )
	{
	// We first try to build the crossing area from worktile+1 upto worktile+3 to find where one is doable
	// Because a rail can cross a road, we try build a track that will fail to cross a road to be sure it's a valid spot for crossing
	DInfo("--- Phase3: define crossing point",1);
	rail=railLeft;
	DInfo("Building crossing point ",2);
	local j=1;
	cTileTools.DemolishTile(workTile);
	if (!AITile.IsBuildable(workTile))	{ closeIt=true; } // because we must have a tile in front of the station buildable for the signal
	do	{
		temptile=workTile+(j*forwardTileOf);
		cTileTools.TerraformLevelTiles(position,temptile);
		if (cTileTools.CanUseTile(temptile,staID))
			success=INSTANCE.main.builder.DropRailHere(rail, temptile);
		else	{ cError.RaiseError(); success=false; }
		if (success)	{
					if (useEntry)	{ se_crossing=temptile; crossing=se_crossing; }
							else	{ sx_crossing=temptile; crossing=sx_crossing; }
					INSTANCE.main.builder.DropRailHere(rail, temptile,true); // remove the test track
					}
		j++;
		} while (j < 5 && !success);
	if (success)
		{
		thatstation.RailStationClaimTile(crossing, useEntry);
		if (useEntry)
				{
				thatstation.locations.SetValue(5,se_crossing);
				DInfo("Entry crossing is now set to : "+se_crossing,2);
				cDebug.PutSign(se_crossing,"X");
				}
			else	{
				thatstation.locations.SetValue(6,sx_crossing);
				DInfo("Exit crossing is now set to : "+sx_crossing,2);
				cDebug.PutSign(sx_crossing,"X");
				}
		cError.ClearError();
		}
	else	{
		cError.IsCriticalError();
		if (cError.IsError())
				{
				closeIt=true;
				cError.ClearError();
				}
		}
	}

// build entry/exit IN and OUT, if anyone use entry or exit, we need it built
// this doesn't need to be run more than 1 time, as each train may trigger the building
local needIN=0;
local needOUT=0;
if (!closeIt)
	{
	if (se_IN==-1 && trainEntryTaker > 0) needIN++; // a train use the entry in
	if (sx_IN==-1 && trainExitTaker > 0) needIN++;  // a train use the exit in
	if (se_OUT==-1 && trainEntryDropper > 0) needOUT++; // a train use the entry out
	if (sx_OUT==-1 && trainExitDropper > 0) needOUT++; // a train use the exit out
	if ( (se_IN==-1 || se_OUT==-1) && (trainEntryTaker+trainEntryDropper > 1) ) { needIN++; needOUT++; }
	// more than 1 trains use the entry
	if ( (sx_IN==-1 || sx_OUT==-1) && (trainExitTaker+trainExitDropper > 1) ) { needIN++; needOUT++; }
	// more than 1 trains use the exit
	}
if (needIN > 0 || needOUT > 0)
	{
	DInfo("--- Phase4: build entry&exit IN/OUT",1);
	local tmptaker=taker;
	local in_str="";
	rail=railFront;
	local j=1;
	local fromtile=0;
	local sigtype=AIRail.SIGNALTYPE_PBS;
	local sigdir=0;
	if (useEntry)
		{
		fromtile=se_crossing;
		if (tmptaker)	{ if (se_IN!=-1)	tmptaker=false; }
				else	{ if (se_OUT!=-1)	tmptaker=true; }
		if (tmptaker)	in_str="entry IN";
				else	{ in_str="entry OUT"; fromtile+=rightTileOf; }
		}
	else	{
		fromtile=sx_crossing;
		if (tmptaker)	{ if (sx_IN!=-1)	tmptaker=false; }
				else	{ if (sx_OUT!=-1)	tmptaker=true; }
		if (tmptaker)	in_str="exit IN";
				else	{ in_str="exit OUT"; fromtile+=rightTileOf; }
		}
	DInfo("Building "+in_str+" point",1);
	cBuilder.StationKillDepot(thatstation.depot);
	cBuilder.StationKillDepot(thatstation.locations[15]);
	local endconnector=fromtile;
	local building_maintrack=true;
	if (road==null)	building_maintrack=true;
			else	if (road.primary_RailLink)	building_maintrack=false;
	do	{
		temptile=fromtile+(j*forwardTileOf);
		cTileTools.TerraformLevelTiles(position,temptile);
		if (cTileTools.CanUseTile(temptile,staID))
			success=INSTANCE.main.builder.DropRailHere(rail, temptile);
		else	{ cError.RaiseError(); success=false; }
		if (success)	thatstation.RailStationClaimTile(temptile,useEntry);
		if (cError.IsCriticalError())
			{
			if (cError.IsError())	closeIt=true;
			cError.ClearError();
			break;
			}
		if (building_maintrack) // we're building IN/OUT point for the primary track
			{
			cDebug.PutSign(temptile+(1*forwardTileOf),"R1");
			cDebug.PutSign(temptile+(2*forwardTileOf),"R2");

			cTileTools.TerraformLevelTiles(position,temptile+(3*forwardTileOf));
			if (cTileTools.CanUseTile(temptile+(1*forwardTileOf), staID))
				success=INSTANCE.main.builder.DropRailHere(rail, temptile+(1*forwardTileOf));
			else	{ cError.RaiseError(); success=false; }
			if (success) thatstation.RailStationClaimTile(temptile+(1*forwardTileOf),useEntry);
			if (cTileTools.CanUseTile(temptile+(2*forwardTileOf), staID))
				success=INSTANCE.main.builder.DropRailHere(rail, temptile+(2*forwardTileOf));
			else	{ cError.RaiseError(); success=false; }
			if (success) thatstation.RailStationClaimTile(temptile+(2*forwardTileOf),useEntry);
			}
		if (tmptaker)	sigdir=fromtile+((j+1)*forwardTileOf);
				else	sigdir=fromtile+((j-1)*forwardTileOf);
		DInfo("Building "+in_str+" point signal",1);
		success=AIRail.BuildSignal(temptile, sigdir, sigtype);
		if (success)	{
					local entry_str="Entry";
					local pointview=0;
					if (AIRail.IsRailDepotTile(fromtile))	AITile.DemolishTile(fromtile); // remove depot
					if (tmptaker)
						{
						if (useEntry)
							{
							se_IN=temptile;
							thatstation.locations.SetValue(1,se_IN);
							if (building_maintrack)	thatstation.locations.SetValue(11, se_IN+(3*forwardTileOf)); // link
										else	thatstation.locations.SetValue(11, se_IN+forwardTileOf);
							if (!cTileTools.DemolishTile(thatstation.locations.GetValue(11)))	closeIt=true;
							pointview=se_IN;
							}
						else	{
							sx_IN=fromtile+(j*forwardTileOf);
							thatstation.locations.SetValue(3,sx_IN);
							if (building_maintrack)	thatstation.locations.SetValue(13, sx_IN+(3*forwardTileOf)); // link
										else	thatstation.locations.SetValue(13, sx_IN+forwardTileOf);
							if (!cTileTools.DemolishTile(thatstation.locations.GetValue(13)))	closeIt=true;
							pointview=sx_IN; entry_str="Exit";
							}
						}
					else	{
						if (cTileTools.CanUseTile(fromtile,staID)) // it's crossing+rightTileOf
							if (INSTANCE.main.builder.DropRailHere(railUpLeft, fromtile))
								thatstation.RailStationClaimTile(fromtile, useEntry);
						if (useEntry)
							{
							se_OUT=temptile;
							thatstation.locations.SetValue(2,se_OUT);
							if (building_maintrack)	thatstation.locations.SetValue(12, se_OUT+(3*forwardTileOf)); // link
										else	thatstation.locations.SetValue(12, se_OUT+(1*forwardTileOf));
							if (!cTileTools.DemolishTile(thatstation.locations.GetValue(12)))	closeIt=true;
							pointview=se_OUT;
							if (!cBuilder.RailConnectorSolver(fromtile+forwardTileOf, fromtile, true))
								closeIt=true; // this build rails at crossing point connecting to 1st rail of se_OUT
							else	thatstation.RailStationClaimTile(fromtile+forwardTileOf, useEntry);
							}
						else	{
							sx_OUT=temptile;
							thatstation.locations.SetValue(4,sx_OUT);
							if (building_maintrack)	thatstation.locations.SetValue(14, sx_OUT+(3*forwardTileOf)); // link
										else	thatstation.locations.SetValue(14, sx_OUT+(1*forwardTileOf));
							if (!cTileTools.DemolishTile(thatstation.locations.GetValue(14)))	closeIt=true;
							pointview=sx_OUT; entry_str="Exit";
							if (!cBuilder.RailConnectorSolver(fromtile, fromtile+forwardTileOf ,true))
								closeIt=true;
							else	thatstation.RailStationClaimTile(fromtile+forwardTileOf, useEntry);
							}
						}
					DInfo(in_str+" "+entry_str+" point set to "+pointview,1);
					cDebug.PutSign(pointview,in_str);
					}
		j++;
		//INSTANCE.NeedDelay(100);
		} while (j < 4 && !success);
		if (!success)	closeIt=true;
	}

// build station entrance point to crossing point
// this need two runs, as we might need entry & exit built in one time
local entry_build=(se_IN != -1 || se_OUT != -1);
local exit_build=(sx_IN != -1 || sx_OUT != -1);
DInfo("Entry build="+entry_build+" - exit build="+exit_build,2);
DInfo("se_in="+se_IN+" se_out="+se_OUT+" sx_in="+sx_IN+" sx_out="+sx_OUT+" closeit="+closeIt+" useEntry="+useEntry,2);
ClearSigns();

foreach (platform, status in thatstation.platforms)
	{
	if (entry_build)	cBuilder.PlatformConnectors(platform, true);
	if (exit_build)	cBuilder.PlatformConnectors(platform, false);
	AIController.Sleep(1);
	}
thatstation.DefinePlatform();  // scan the station platforms for their status
DInfo("--- Phase5: build & connect station entrance",1);
for (local hh=0; hh < 2; hh++)
	{
	local endConnector=AIList();
	local topLeftPlatform=thatstation.locations.GetValue(20);
	local topRightPlatform=thatstation.locations.GetValue(21);
	local stationside=(hh==0); // first run we work on entry, second one on exit
	if (stationside && !entry_build)	continue;
	if (!stationside && !exit_build)	continue;

	local RL, RR, RC = null; // local Rails define here, as it's only useful inside that loop
	if (direction == AIRail.RAILTRACK_NW_SE) // must redefine rails as use of entry or exit change according to stationside
		{
		RC=AIRail.RAILTRACK_NE_SW;
		if (stationside)	{ // going NW->SE
					RL=AIRail.RAILTRACK_SW_SE;
					RR=AIRail.RAILTRACK_NE_SE;
					}
				else	{ // going SE->NW
					RL=AIRail.RAILTRACK_NW_SW; //nwne
					RR=AIRail.RAILTRACK_NW_NE;
					}
		}
	else	{ // NE_SW
		RC=AIRail.RAILTRACK_NW_SE;
		if (stationside)	{ // going NE->SW
					RL=AIRail.RAILTRACK_NW_SW;
					RR=AIRail.RAILTRACK_SW_SE;
					}
				else	{ // going SW->NE
					RL=AIRail.RAILTRACK_NW_NE; //nese
					RR=AIRail.RAILTRACK_NE_SE;
					}
		}
		foreach (platf, openclose in thatstation.platforms)
			{
			local platid=cStation.GetPlatformIndex(platf, true); // get a fixed point
			local wpoint=cStation.GetRelativeCrossingPoint(platf, stationside); // now get it relative to entry/exit
			local refpoint=cStation.GetRelativeCrossingPoint(topLeftPlatform, stationside);
			local dir=cBuilder.GetDirection(wpoint, refpoint);
			local runthru=true;
			if (platid==topLeftPlatform)
				{
				dir=cBuilder.GetDirection(wpoint, cStation.GetRelativeCrossingPoint(topRightPlatform, stationside));
				runthru=false;
				}
			if (platid == topRightPlatform)	runthru=false;
			//cDebug.PutSign(wpoint,dir); INSTANCE.NeedDelay(50);
			switch (dir)
				{
				case	0: // SE-NW
					rail=RL;
					break;
				case	1: // NW-SE
					rail=RR;
					break;
				case	2: // SW-NE
					rail=RR;
					break;
				case	3: // NE-SW
					rail=RL;
					break;
				}
			if (cStation.IsPlatformOpen(platf, stationside) && cTileTools.CanUseTile(wpoint,staID) && topLeftPlatform!=topRightPlatform)
				if (INSTANCE.main.builder.DropRailHere(rail, wpoint))	thatstation.RailStationClaimTile(wpoint, stationside);
			if (runthru && cTileTools.CanUseTile(wpoint,staID))
				if (INSTANCE.main.builder.DropRailHere(railCross, wpoint))	thatstation.RailStationClaimTile(wpoint, stationside);
			//INSTANCE.NeedDelay(50);
			AIController.Sleep(1);
			}
	foreach (platf, openclose in thatstation.platforms)
		{
		local platfront=cStation.GetRelativeCrossingPoint(platf, stationside);
		cTileTools.DemolishTile(platfront); // rails protect
		cBuilder.RailConnectorSolver(platfront+backwardTileOf, platfront, true);
		thatstation.RailStationClaimTile(platfront,staID);
		//INSTANCE.NeedDelay(100);
		}
	ClearSigns();									
	} // hh loop
thatstation.DefinePlatform();

// first look if we need some more work
if ( road != null && !road.secondary_RailLink && (trainEntryDropper+trainEntryTaker > 1 || trainExitDropper+trainExitTaker > 1))
// only work when needIN is built as we only work on target station for that part
	{
	local dowork=true;
	if (road==null)
		{
		DWarn("Our owner route is not yet valid",1);
		dowork=false;
		}
	else	{
		if (road.secondary_RailLink==false)	dowork=true; // only work if we haven't build the connection yet
		if (road.source_stationID == staID)	dowork=false;// but only if we are the target station
		}
	if (dowork)
		{
		DInfo("--- Phase6: building alternate track",1);
		cBuilder.StationKillDepot(thatstation.depot);
		cBuilder.StationKillDepot(thatstation.locations[15]);
		local srcpos, srclink, dstpos, dstlink= null;
		if (road.source_RailEntry)
			srclink=road.source.locations.GetValue(12);
		else	srclink=road.source.locations.GetValue(14);
		if (road.target_RailEntry)
			dstlink=road.target.locations.GetValue(11);
		else	dstlink=road.target.locations.GetValue(13);
		srcpos=srclink+cStation.GetRelativeTileBackward(road.source.stationID, road.source_RailEntry);
		dstpos=dstlink+cStation.GetRelativeTileBackward(road.target.stationID, road.target_RailEntry);
		DInfo("Calling rail pathfinder: srcpos="+srcpos+" srclink="+" dstpos="+dstpos+" dstlink="+dstlink,2);
		/*cDebug.PutSign(dstpos,"D");
		cDebug.PutSign(dstlink,"d");
		cDebug.PutSign(srcpos,"S");
		cDebug.PutSign(srclink,"s");*/
		local result=INSTANCE.main.builder.BuildRoadRAIL([srclink,srcpos],[dstlink,dstpos], road.target_RailEntry, road.target.stationID);
		if (result != 1)
			{
			if (result == -1)
				{
				DError("We cannot build the alternate track for that station ",1);
				closeIt=true;
				if (useEntry)	cStation.RailStationCloseExit(road.source_stationID);
						else	cStation.RailStationCloseExit(road.target_stationID);
				cPathfinder.CloseTask([srclink,srcpos],[dstlink,dstpos]);
				closeIt=true;
				}
			else	return false;
			// lack money, still pathfinding... just wait to retry later nothing to do
			}
		else	{ road.secondary_RailLink=true; cPathfinder.CloseTask([srclink,srcpos],[dstlink,dstpos]); }
		}
	}

if (road!=null && road.secondary_RailLink && (trainEntryDropper+trainEntryTaker >2 || trainExitDropper+trainExitTaker > 2) && (!cStation.IsRailStationPrimarySignalBuilt(road.source_stationID) || !cStation.IsRailStationSecondarySignalBuilt(road.target_stationID))) // route must be valid + alternate rail is built
	{
	DInfo("--- Phase7: building signals",1);
	local vehlist=AIList();
	local vehlistRestart=AIList();
	if (road != null && road.groupID != null)
		{
		vehlist.AddList(AIVehicleList_Group(road.groupID));
		vehlist.Valuate(AIVehicle.GetState);
		vehlistRestart.AddList(vehlist);
		vehlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
		vehlistRestart.KeepValue(AIVehicle.VS_IN_DEPOT);
		if (!vehlist.IsEmpty())
			{ // erf, easy solve, not really nice, but this won't prevent our work on signal (that could stuck a train else)
			foreach (vehicle, dummy in vehlist)	INSTANCE.main.carrier.VehicleSendToDepot(vehicle,DepotAction.SIGNALUPGRADE)
			return false;
			}
		}
	local srcpos, dstpos = null;
	if (road.source_RailEntry)
			srcpos=road.source.locations.GetValue(1);
		else	srcpos=road.source.locations.GetValue(3);
	if (road.target_RailEntry)
			dstpos=road.target.locations.GetValue(2);
		else	dstpos=road.target.locations.GetValue(4);

	if (!cStation.IsRailStationPrimarySignalBuilt(road.source_stationID))
		{
		DInfo("Building signals on primary track",2);
		if (cBuilder.SignalBuilder(dstpos, srcpos))
			{
			DInfo("...done",2);
			cStation.RailStationSetPrimarySignalBuilt(road.source_stationID);
			}
		else	{ DInfo("... not all signals were built",2); }
		}
	ClearSigns();
	if (road.source_RailEntry)
			srcpos=road.source.locations.GetValue(2);
		else	srcpos=road.source.locations.GetValue(4);
	if (road.target_RailEntry)
			dstpos=road.target.locations.GetValue(1);
		else	dstpos=road.target.locations.GetValue(3);
	if (!cStation.IsRailStationSecondarySignalBuilt(road.target_stationID))
		{
		DInfo("Building signals on secondary track",2);
		if (cBuilder.SignalBuilder(srcpos, dstpos))
			{
			DInfo("...done",2);
			cStation.RailStationSetSecondarySignalBuilt(road.target_stationID);
			}
		else	{ DInfo("... not all signals were built",2); }
		}
	foreach (vehicle, dummy in vehlistRestart)
		{
		cCarrier.TrainExitDepot(vehicle);
		}
	}

DInfo("--- Phase8: build depot",1);
// build depot for it,
// in order to build cleaner rail we build the depot where the OUT line should goes, reserving space for it
// we may need to build entry & exit depot at the same time, so 2 runs

local tile_OUT=null;
local depot_checker=null;
local removedepot=false;
success=false;
local runTarget=cStation.RailStationGetRunnerTarget(staID);
for (local hh=0; hh < 2; hh++)
	{
	local stationside=(hh==0); // first run we work on entry, second one on exit
	if (stationside && !entry_build)	continue;
	if (!stationside && !exit_build)	continue;
//	if (runTarget==-1)	continue;
	if (stationside)
		{
		crossing=se_crossing;
		tile_OUT=se_IN;
		depot_checker=thatstation.depot;
		}
	else	{
		crossing=sx_crossing;
		tile_OUT=sx_IN;
		depot_checker=thatstation.locations[15];
		}
	if (!AIRail.IsRailDepotTile(depot_checker))	depot_checker=-1;
								else	continue;
	if (depot_checker==-1)
		{
		local topLeftPlatform=thatstation.locations.GetValue(20);
		local topRightPlatform=thatstation.locations.GetValue(21);
		local topRL=cStation.GetRelativeCrossingPoint(topLeftPlatform, stationside);
		local topRR=cStation.GetRelativeCrossingPoint(topRightPlatform, stationside);
		local depotlocations=[topRL+forwardTileOf, topRR+forwardTileOf, topRL+rightTileOf, topRL+leftTileOf, topRR+rightTileOf, topRR+leftTileOf, topRL+leftTileOf+leftTileOf, topRR+rightTileOf+rightTileOf];
		local depotfront=[topRL, topRL, topRR, topRR, topRL, topRR, topRL+leftTileOf, topRR+rightTileOf];
		DInfo("Building station depot",1);
		for (local h=0; h < depotlocations.len(); h++)
			{
			cTileTools.TerraformLevelTiles(crossing,depotlocations[h]);
			cDebug.PutSign(depotlocations[h],"DX");
			if (cTileTools.CanUseTile(depotlocations[h],staID))
				{
				cTileTools.DemolishTile(depotlocations[h]);
				removedepot=AIRail.BuildRailDepot(depotlocations[h], depotfront[h]);
				}
			local depot_Front=AIRail.GetRailDepotFrontTile(depotlocations[h]);
			
			if (AIMap.IsValidTile(depot_Front))	success=cBuilder.RailConnectorSolver(depotlocations[h],depot_Front,true);
			success=cStation.IsDepot(depotlocations[h]);
			if (success)
					{
					DInfo("We built depot at "+depotlocations[h],1);
					thatstation.RailStationClaimTile(depotlocations[h],stationside);
					if (stationside)	thatstation.depot=depotlocations[h];
							else	thatstation.locations[15]=depotlocations[h];
					success=true;
					break;
					}
				else	{ if (removedepot)	cTileTools.DemolishTile(depotlocations[h]); }
			}
		}
	} // for loop
if (!closeIt && thatstation.max_trains==0)
	{
	DInfo("Closing entrance as we have fail to build a valid one",1);	
	closeIt=true;
	}
if (closeIt)
	{ // something went wrong, the station entry or exit is now dead
	if (useEntry)
		{
		thatstation.RailStationCloseEntry();
		// entry is only valid if we have more than 1 train using it, because 1 (virtually add) train = 0 trains in real
		if ((trainEntryTaker+trainEntryDropper) == 1)	thatstation.RailStationDeleteEntrance(true);
		}
	else	{
		thatstation.RailStationCloseExit();
		if ((trainExitTaker+trainExitDropper) == 1)	thatstation.RailStationDeleteEntrance(false);
		}
	cError.ClearError(); // let's get another chance to build exit/entry when fail
	return false;
	}
DInfo("Station "+cStation.StationGetName(thatstation.stationID)+" have "+(trainEntryTaker+trainEntryDropper)+" trains using its entry and "+(trainExitTaker+trainExitDropper)+" using its exit, can handle "+thatstation.max_trains+" loading trains",1);
if (trainEntryTaker+trainExitTaker > thatstation.max_trains)	{ DInfo("Not enough platforms working to handle that number of trains",1); return false; }
return true;
}

function cBuilder::PlatformConnectors(platform, useEntry)
// connect a platform (build rail and the signal before crosspoint)
// platform: platform tile to work on
// useEntry: connect the platform entry or exit
// on error -1, if rails are already there, no error is report, only if we cannot manage to connect it
{
local frontTile=cStation.GetPlatformFrontTile(platform, useEntry);
if (frontTile==-1)	{ DError("Invalid front tile",1); return -1; }
local stationID=AIStation.GetStationID(platform);
local thatstation=cStation.GetStationObject(stationID);
local forwardTileOf=cStation.GetRelativeTileForward(stationID, useEntry);
local backwardTileOf=cStation.GetRelativeTileBackward(stationID, useEntry);
local crossing=0;
local direction=thatstation.GetRailStationDirection();
if (useEntry)	crossing=thatstation.locations.GetValue(5);
		else	crossing=thatstation.locations.GetValue(6);
if (crossing < 0)	{ DError("Crossing isn't define yet",1); return false; }
local goal=0;
local rail=AIRail.RAILTRACK_NE_SW;
local sweeper=AIList();
local error=false;
if (direction==AIRail.RAILTRACK_NE_SW)
		goal=AIMap.GetTileIndex(AIMap.GetTileX(crossing),AIMap.GetTileY(frontTile));
	else	{ goal=AIMap.GetTileIndex(AIMap.GetTileX(frontTile),AIMap.GetTileY(crossing)); rail=AIRail.RAILTRACK_NW_SE; }
cTileTools.TerraformLevelTiles(goal,frontTile);
local i=frontTile;
local signaldone=false;
while (i != goal)
	{
	cTileTools.DemolishTile(i); // rails are protect there
	if (cTileTools.CanUseTile(i, thatstation.stationID) && cBuilder.DropRailHere(rail, i))
		{
		thatstation.RailStationClaimTile(i, useEntry);
		sweeper.AddItem(i, 0);
		if (!signaldone)	signaldone=AIRail.BuildSignal(i, i+backwardTileOf, AIRail.SIGNALTYPE_PBS);
		}
	else	{ error=true; break; }
	i+=forwardTileOf;
	}
if (!error)	{ cTileTools.DemolishTile(goal); } // rails are protected
if (error)	{ cBuilder.RailCleaner(sweeper); }
return 0;
}

function cBuilder::DropRailHere(railneed, pos, remove=false)
// Put a rail at position pos, on failure clear the area and retry
// railneed : the railtrack we want build/remove
// pos : where to do the action
// remove: true to remove the track, false to add it
// return true on success
{
local lasterr=-1;
if (remove)
	{
	if (!AIRail.IsRailTile(pos))	return true;
					else	return AIRail.RemoveRailTrack(pos, railneed);
	}
if (!AIRail.BuildRailTrack(pos,railneed))
	{
	lasterr=AIError.GetLastError();
	switch (lasterr)
		{
		case	AIError.ERR_AREA_NOT_CLEAR:
			cTileTools.DemolishTile(pos);
			break;
		default:
			DInfo("Cannot build rail track at "+pos,1);
			return false;
		}
	}
else	return true;
return AIRail.BuildRailTrack(pos,railneed);
}

function cBuilder::RailCleaner(targetTile)
// clean the tile by removing rails/depot/station... we found there
// targetTile : an AIList of tiles to remove
{
local many=AIList();
many.AddList(targetTile);
if (many.IsEmpty())	return true;
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
	if (AITile.GetOwner(tile) != AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))	continue;
	if (AIRail.IsRailStationTile(tile))	continue; // protect station
	if (AIRail.IsRailDepotTile(tile))
		{
		AITile.DemolishTile(tile);
		continue;
		}
	if (AITile.HasTransportType(tile, AITile.TRANSPORT_RAIL) && (AIBridge.IsBridgeTile(tile) || AITunnel.IsTunnelTile(tile)) ) 
		{
		AITile.DemolishTile(tile);
		continue;
		}
	foreach (near in voisin)
		{
		while (AIRail.GetSignalType(tile,tile+near)!=AIRail.SIGNALTYPE_NONE)	AIRail.RemoveSignal(tile, tile+near);
		}
	seek=AIRail.GetRailTracks(tile);
	if (seek != 255)
		foreach (railtype, dummy in trackMap)	if ((seek & railtype) == railtype)	AIRail.RemoveRailTrack(tile,railtype);
	AIController.Sleep(1);
	}
}

function cBuilder::GetRailBitMask(rails)
// Return a nibble bitmask with each NE,SW,NW,SE direction set to 1
{
local NE = 1; // we will use them as bitmask
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
if (rails==255)	return 0; // invalid rail
local railmask=0;
foreach (tracks, value in trackMap)
	{
	if ((rails & tracks)==tracks)	{ railmask=railmask | value; }
	if (railmask==(NE+SW+NW+SE))	return railmask; // no need to test more tracks
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
if (AITile.GetOwner(tilefrom) != atemp)	return false; // not own by us
if (AITile.GetOwner(tileto) != atemp)		return false; // not own by us
atemp=AIRail.GetRailType(tilefrom);
if (AIRail.GetRailType(tileto) != atemp && stricttype)	return false; // not same railtype
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
if (AIRail.IsRailDepotTile(tileto) && AIRail.GetRailDepotFrontTile(tileto)==tilefrom)	tileto_mask=tileto_need;
if (AIRail.IsRailDepotTile(tilefrom) && AIRail.GetRailDepotFrontTile(tilefrom)==tileto)	tilefrom_mask=tilefrom_need;
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
if ( (tilefrom_mask & tilefrom_need)==tilefrom_need && (tileto_mask & tileto_need)==tileto_need)	return true;
return false;
}

function cBuilder::RailConnectorSolver(tilepos, tilefront, fullconnect=true)
// Look at tilefront and build rails to connect that tile to its neightbourg tiles that are us with rails
// tilepos : tile where we have a rail/depot...
// tilefront: tile where we want to connect tilepos to
// fullconnect: set to true to allow the tilefront to also connect neighbourg tiles to each other (this might not respect 90 turn settings!)
// so if tilepos=X, tilefront=Y, 2 tiles near Y as A & B
// without fullconnect -> it create AX, BX and with it, also do AB
// only return false if we fail to build all we tracks need at tilefront (and raise critical error)
{
local voisin=[AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0,-1), AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)]; // SE, NW, SW, NE
local NE = 1; // we will use them as bitmask
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
cDebug.PutSign(tilefront,"X");
// dirValid is [VV,II] VV=valid to go, II=invalid when no 90 turn is allow
// and for each direction we're going in order SE, NW, SW, NE
local dirValid=[
	NW,0, SE,0, NE,SE, SW,SE,  	// SE->NW (when we go from->to)- 0
	NW,0, SE,0, NE,NW, SW,NW,  	// NW->SE - 1
	NW,SW, SE,SW, NE,0, SW,0, 	// SW->NE - 2
	NW,NE, SE,NE, NE,0, SW,0 	// NE->SW - 3
	];
local workTile=[];
for (local i=0; i < 4; i++)	workTile.push(tilefront+voisin[i]);
if (AITile.GetDistanceManhattanToTile(tilepos,tilefront) > 1)
	{ DError("We must use two tiles close to each other ! tilepos="+tilepos+" tilefront="+tilefront,1); return false; }
local direction=cBuilder.GetDirection(tilepos, tilefront);
local checkArray=[];
local connections=[];
for (local i=0; i<8; i++)	checkArray.push(dirValid[i+(8*direction)]);
local tile=null;
local tileposRT=AIRail.GetRailType(tilepos);
local connection=false;
local checkOrder=[];
checkOrder.push(direction);
for (local i=0; i <4; i++)
	{
	if (i==direction)	continue;
	checkOrder.push(i);
	}
local startposValid=false;
for (local kk=0; kk<4; kk++)
	{
	local i = checkOrder[kk];
	tile=workTile[i];
	local trackinfo=AIRail.GetRailTracks(tile);
	local test=null;
	if (trackinfo==255)
		{ // maybe a tunnel, depot or bridge that "could" also be valid entries
		local testdir=null;
		if (AIRail.IsRailDepotTile(tile))
			{
			test=AIRail.GetRailDepotFrontTile(tile);
			testdir=cBuilder.GetDirection(tile, test);
			DInfo("Rail depot found",2);
			if (test==tilefront)
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
	if (trackinfo==255)	{ DInfo("No rails found",2); continue; } // no rails here
	test=AITile.GetOwner(tile);
	if (test != AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))	{ DInfo("Not a rail of our company",2); cDebug.PutSign(tile,"N"); continue; } // we don't own that
	test = AIRail.GetRailType(tile);
	if (test != tileposRT)	{ DInfo("Rails are not of the same type",2); continue; } // not the same rail type
	
	local validbit=checkArray[0+(i*2)];
	local turnbit=checkArray[1+(i*2)];
	local bitcheck=0;
	local connection=false;
	local turn_enable=(AIGameSettings.GetValue("forbid_90_deg") == 0);
	foreach (trackitem, trackmapping in trackMap)
		{
		if ((trackinfo & trackitem) == trackitem)	// we have that track
			{
			if ((trackmapping & validbit) == validbit)	connection=true;
			if (connection && i==direction)	{ DInfo("Starting rails have entry we can work on",2); startposValid=true; break; }
			if (!startposValid)	continue;
			if (connection)	{ connections.push(tile); } // save status to later connect everyone if need, avoid 90 turn check
			if (!turn_enable && turnbit!=0)	if ((trackmapping & turnbit) == turnbit)	connection=false;
			}
		if (connection && startposValid)
			{
			if (!AIRail.BuildRail(tilepos, tilefront, tile))
				{
				cError.IsCriticalError();
				if (cError.IsError())	return false;
				}
			else	{ break; }
			}
		}
	}
if (connections.len()>1 && fullconnect && startposValid)
	{
	foreach (con1 in connections)
		foreach (con2 in connections)
			{
			if (con1 != con2 && !AIRail.BuildRail(con1, tilefront, con2))
				{
				cError.IsCriticalError();
				if (cError.IsError())	return false;
				}
			}
	}
return true;
}

function cBuilder::StationKillDepot(tile)
// Just because we need to remove the depot at tile, and retry to make sure we can
{
if (!AIRail.IsRailDepotTile(tile))	return;
local vehlist=AIVehicleList();
vehlist.Valuate(AIVehicle.GetState);
vehlist.KeepValue(AIVehicle.VS_IN_DEPOT);
vehlist.Valuate(AIVehicle.GetLocation);
vehlist.KeepValue(tile);
if (!vehlist.IsEmpty())	DInfo("Restarting trains at depot "+tile+" so we can remove it",1);
foreach (veh, dummy in vehlist)
	{
	DInfo("Starting "+cCarrier.VehicleGetName(veh)+"...",0);
	cTrain.SetDepotVisit(veh);
	cCarrier.StartVehicle(veh);
	INSTANCE.Sleep(40);
	}
for (local i=0; i < 10; i++)
	{
	if (AITile.DemolishTile(tile))	return;
	INSTANCE.Sleep(20);
	}
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
//local dir=cBuilder.GetDirection(source, buildstart);
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
		if (AIRail.GetSignalType(tilesource,tilefront) != AIRail.SIGNALTYPE_NONE)	ignoreit=true;
		if (cBridge.IsBridgeTile(tilesource) || AITunnel.IsTunnelTile(tilesource))	ignoreit=true;
		if (ignoreit)	{ cc=0; prev=tile; continue; }
		if (AIRail.BuildSignal(tilesource,tilefront, AIRail.SIGNALTYPE_NORMAL))	{ cc=0; }
			else	{
				cDebug.PutSign(tile,"!");
				local smallerror=cBuilder.EasyError(AIError.GetLastError());
				DError("Error building signal ",1);
				//max_signals_distance++;
				if (smallerror == -1)	return false;
				}
		}
	AIController.Sleep(1);
	cc++;
	prev=tile;
	path = path.GetParent();
	}
return allsuccess;
}

