/* -*- Mode: C++; tab-width: 6 -*- */ 
/**
 *    This file is part of DictatorAI
 *
 *    It's free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 2 of the License, or
 *    (at your option) any later version.
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
local dir, tilelist, otherplace, isneartown = null;
local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
local istown=false;
local srcpoint=null;
local sourceplace=null;
local statile=null;
if (start)	{
		dir = INSTANCE.builder.GetDirection(INSTANCE.route.source_location, INSTANCE.route.target_location);
		if (INSTANCE.route.source_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.route.sourceID);
			tilelist.Valuate(AITile.GetCargoProduction, INSTANCE.route.cargoID, 1, 1, rad);
			tilelist.KeepAboveValue(0); 
			istown=true;
			}
		else	{
			tilelist = AITileList_IndustryProducing(INSTANCE.route.sourceID, rad);
			istown=false;
			}
		otherplace=INSTANCE.route.target_location; sourceplace=INSTANCE.route.source_location;
		}
	else	{
		dir = INSTANCE.builder.GetDirection(INSTANCE.route.target_location, INSTANCE.route.source_location);
		if (INSTANCE.route.target_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.route.targetID);
			tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.route.cargoID, 1, 1, rad);
			tilelist.KeepAboveValue(8); 
			istown=true;
			}
		else	{
			tilelist = AITileList_IndustryAccepting(INSTANCE.route.targetID, rad);
			isneartown=false; istown=false;
			}
		otherplace=INSTANCE.route.source_location; sourceplace=INSTANCE.route.target_location;
		}
tilelist.Valuate(cTileTools.IsBuildable);
tilelist.KeepValue(1);
tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
tilelist.Sort(AIList.SORT_BY_VALUE, true);
local success = false;
DInfo("Tilelist set to "+tilelist.Count(),1,"BuildTrainStation");
showLogic(tilelist); 
//DInfo("isneartown="+isneartown+" istown="+istown,2,"BuildTrainStation");
ClearSignsALL();
foreach (tile, dummy in tilelist)
	{
	if (start)	dir=INSTANCE.builder.GetDirection(tile, INSTANCE.route.source_location);
		else	dir=INSTANCE.builder.GetDirection(INSTANCE.route.target_location,tile);
	// find where that point is compare to its source for the station
	PutSign(tile,"d:"+dir+"");
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
	DInfo("New direction set to "+dir,1,"BuildTrainStation");
	if (dir == AIRail.RAILTRACK_NW_SE)	statile=cTileTools.CheckLandForConstruction(tile, 1, 5);
						else	statile=cTileTools.CheckLandForConstruction(tile, 5, 1);
	if (statile == -1)	continue; // we have no solve to build a station here
	if (istown)	
		{
		if (start)	cTileTools.SeduceTown(INSTANCE.route.sourceID, AITown.TOWN_RATING_MEDIOCRE);
			else	cTileTools.SeduceTown(INSTANCE.route.targetID, AITown.TOWN_RATING_MEDIOCRE);
		}
	success=INSTANCE.builder.CreateAndBuildTrainStation(statile, dir);
	if (!success)
		{
		// switch again station direction, a solve exist there
		if (dir == AIRail.RAILTRACK_NE_SW)	dir=AIRail.RAILTRACK_NW_SE;
							else	dir=AIRail.RAILTRACK_NE_SW;
		success=INSTANCE.builder.CreateAndBuildTrainStation(statile, dir);
		}
	if (success)	{
				//statile=tile;
				break;
				}
			else	{ // see why we fail
				INSTANCE.builder.IsCriticalError();
				if (INSTANCE.builder.CriticalError)	{ break; }
				if (AIError.GetLastError()==AIError.ERR_LOCAL_AUTHORITY_REFUSES)	{ break; }
				}
	}
ClearSignsALL();

if (!success) 
	{
	DInfo("Can't find a good place to build the train station ! "+tilelist.Count(),1,"BuildTrainStation");
	return false;
	}
// here, so we success to build one
local staID=AIStation.GetStationID(statile);
if (start)	INSTANCE.route.source_stationID=staID;
	else	INSTANCE.route.target_stationID=staID;
INSTANCE.route.CreateNewStation(start);
return true;
}

function cBuilder::BuildRoadRAIL(head1, head2) {
local pathfinder = MyRailPF();
pathfinder._cost_level_crossing = 900;
pathfinder._cost_slope = 200;
pathfinder._cost_coast = 100;
pathfinder._cost_bridge_per_tile = 90;
pathfinder._cost_tunnel_per_tile = 75;
pathfinder._max_bridge_length = 20;
pathfinder._max_tunnel_length = 20;
pathfinder.InitializePath([head1], [head2]);
local savemoney=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
local pfInfo=null;
INSTANCE.bank.SaveMoney(); // thinking long time, don't waste money
pfInfo=AISign.BuildSign(head1[0],"Pathfinding...");
DInfo("Rail Pathfinding...",1);
local counter = 0;
local path = false;
while (path == false && counter < 150)
	{
	path = pathfinder.FindPath(150);
	counter++;
	AISign.SetName(pfInfo,"Pathfinding... "+counter);
	AIController.Sleep(1);
	}
if (path != null && path != false)
	{
	DInfo("Path found. (" + counter + ")");
	ClearSignsALL();
	}
else	{
	ClearSignsALL();
	DInfo("Pathfinding failed.",1);
	INSTANCE.builder.CriticalError=true;
	INSTANCE.bank.RaiseFundsTo(savemoney);
	return false;
	}
	INSTANCE.bank.RaiseFundsBigTime();
	local prev = null;
	local prevprev = null;
	local pp1, pp2, pp3 = null;
	while (path != null) {
		if (prevprev != null) {
			if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1) {
				if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile()) {
					if (!AITunnel.BuildTunnel(AIVehicle.VT_RAIL, prev)) {
						DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
							DInfo("That tunnel would be too expensive. Construction aborted.",2);
							return false;
						}
						if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false; else return true;
					}
				} else {
					local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
					bridgelist.Valuate(AIBridge.GetMaxSpeed);
					if (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridgelist.Begin(), prev, path.GetTile())) {
						DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
							DInfo("That bridge would be too expensive. Construction aborted.",2);
							return false;
						}
						if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false; else return true;
					}
				}
				pp3 = pp2;
				pp2 = pp1;
				pp1 = prevprev;
				prevprev = prev;
				prev = path.GetTile();
				path = path.GetParent();
			} else {
				if (!AIRail.BuildRail(prevprev, prev, path.GetTile())) {
					DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
					if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false; else return true;
				}
			}
		}
		if (path != null) {
			pp3 = pp2;
			pp2 = pp1;
			pp1 = prevprev;
			prevprev = prev;
			prev = path.GetTile();
			path = path.GetParent(); 
		}
	}
	return true;
}

function cBuilder::RetryRail(prevprev, pp1, pp2, pp3, head1)
{
	/*recursiondepth++;
	if (recursiondepth > 10) {
		AILog.Error("It looks like I got into an infinite loop.");
		return false;
	}*/
	if (pp1 == null) return false;
	local head2 = [null, null];
	local tiles = [pp3, pp2, pp1, prevprev];
	foreach (idx, tile in tiles) {
		if (tile != null) {
			head2[1] = tile;
			break;
		}
	}
	tiles = [prevprev, pp1, pp2, pp3]
	foreach (idx, tile in tiles) {
		if (tile == head2[1]) {
			break;
		} else {
			if (AIRail.IsLevelCrossingTile(tile)) {
				local track = AIRail.GetRailTracks(tile);
				if (!AIRail.RemoveRailTrack(tile, track)) {
					local counter = 0;
					AIController.Sleep(75);
					while (!AIRail.RemoveRailTrack(tile, track) && counter < 3) {
						counter++;
						AIController.Sleep(75);
					}
				}
			} else {
				cTileTools.DemolishTile(tile);
			}
			head2[0] = tile;
		}
	}
	if (cBuilder.BuildRoadRAIL(head2, head1)) return true; else return false;
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
// We return result in AIList, 0:item=src tile, value=1(entry)0(exit), 1:item=dst tile, value=1(entry)0(exit)
// return AIList() on failure
// 
{
// check entry/exit avaiablility on stations
local srcEntry=INSTANCE.builder.IsRailStationEntryOpen(src);
local srcExit=INSTANCE.builder.IsRailStationExitOpen(src);
local dstEntry=INSTANCE.builder.IsRailStationEntryOpen(dst);
local dstExit=INSTANCE.builder.IsRailStationEntryOpen(dst);
local srcEntryLoc=INSTANCE.builder.GetRailStationIN(true,src);
local srcExitLoc=INSTANCE.builder.GetRailStationIN(false,src);
local dstEntryLoc=INSTANCE.builder.GetRailStationIN(true,dst);
local dstExitLoc=INSTANCE.builder.GetRailStationIN(false,dst);

if ( (!srcEntry && !srcExit) || (!dstEntry && !dstExit) )
	{
	DInfo("That station have its entry and exit closed. No more connections could be made with it",1,"FindStationEntryToExitPoint");
	return AIList();
	}
local best=100000000000;
local bestsrc=0;
local bestdst=0;
local check=0;
local srcFlag=0;
local dstFlag=0; // use to check if we're connect to entry(1) or exit(0)

if (srcEntry)
	{
	if (dstExit)
		{
		check = AIMap.DistanceManhattan(srcEntryLoc,dstExitLoc);
		if (check < best)	{ best=check; bestsrc=srcEntryLoc; bestdst=dstExitLoc; }
		}
		DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2,"FindStationEntryToExit");
	if (dstEntry)
		{
		check = AIMap.DistanceManhattan(srcEntryLoc,dstEntryLoc);
		if (check < best)	{ best=check; bestsrc=srcEntryLoc; bestdst=dstEntryLoc; }
		}
		DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2,"FindStationEntryToExit");
	}
if (srcExit)
	{
	if (dstEntry)
		{
		check = AIMap.DistanceManhattan(srcExitLoc,dstEntryLoc);
		if (check < best)	{ best=check; bestsrc=srcExitLoc; bestdst=dstEntryLoc; }
		}
	DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2,"FindStationEntryToExit");
	if (dstExit)
		{
		check = AIMap.DistanceManhattan(srcExitLoc,dstExitLoc); 
		if (check < best)	{ best=check; bestsrc=srcExitLoc; bestdst=dstExitLoc; }
		}
	DInfo("distance="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2,"FindStationEntryToExit");
	}
// Now we know where to build our roads
local bestWay=AIList();
if (bestsrc == srcEntryLoc)	srcFlag=1;
if (bestdst == dstEntryLoc)	dstFlag=1;
bestWay.AddItem(bestsrc, srcFlag);
bestWay.AddItem(bestdst, dstFlag);
DInfo("Best connecting source="+bestsrc+" destination="+bestdst+" srcFlag="+srcFlag+" dstFlag="+dstFlag,2,"FindStationEntryToExit");
PutSign(bestsrc,"CS");
PutSign(bestdst,"CT");
return bestWay;
}

function cBuilder::CreateStationsConnection(fromObj, toObj)
// Connect station fromObj to station toObj
// Pickup entry/exit close to each other
// Create the connections in front of these stations
{
local srcStation=cStation.GetStationObject(fromObj);
local dstStation=cStation.GetStationObject(toObj);
DInfo("Connecting rail station "+AIStation.GetName(srcStation.stationID)+" to "+AIStation.GetName(dstStation.stationID),1,"CreateStationsConnection");
local retry=true;
local bestWay=AIList();
local srcresult=false;
local dstresult=false;
local srcpos=null;
local dstpos=null;
do	{
	bestWay=INSTANCE.builder.FindStationEntryToExitPoint(fromObj, toObj);
	if (bestWay.IsEmpty())	retry=false;
				else	retry=true;
	if (retry) // we found a possible connection
		{
		srcpos=bestWay.Begin();
		dstpos=bestWay.Next();
		local srcUseEntry=(bestWay.GetValue(srcpos)==1);
		local dstUseEntry=(bestWay.GetValue(dstpos)==1);
		DInfo("srcUseEntry="+srcUseEntry+" dstUseEntry="+dstUseEntry,2,"cBuilder::CreateStationsConnection");
		if (!srcresult)	srcresult=INSTANCE.builder.RailStationGrow(fromObj, srcUseEntry, true);
		if (!srcresult)
			{
			DWarn("RailStationGrow report failure",1,"cBuilder::CreateStationConnection");
			if (INSTANCE.builder.CriticalError)	return false;
			}
		if (!dstresult)	dstresult=INSTANCE.builder.RailStationGrow(toObj, dstUseEntry, false);
		if (!dstresult)
			{
			DWarn("RailStationGrow report failure",1,"cBuilder::CreateStationConnection");
			if (INSTANCE.builder.CriticalError)	return false;
			}
		if (dstresult && srcresult)
			{
			// need to grab the real locations first, as they might have change while building entrances of station
			if (srcUseEntry)	srcpos=srcStation.locations.GetValue(1);
					else	srcpos=srcStation.locations.GetValue(3);
			if (dstUseEntry)	dstpos=dstStation.locations.GetValue(1);
					else	dstpos=dstStation.locations.GetValue(3);
			DInfo("Calling rail pathfinder: srcpos="+srcpos+" dstpos="+dstpos,2,"CreateStationConnection");
			local srclink=0;
			local dstlink=0;
			if (AIRail.GetRailStationDirection(AIStation.GetLocation(srcStation.stationID))==AIRail.RAILTRACK_NW_SE)
					srclink=srcpos+AIMap.GetTileIndex(0,-1);
				else	srclink=srcpos+AIMap.GetTileIndex(-1,0); // NE_SW
			if (AIRail.GetRailStationDirection(AIStation.GetLocation(dstStation.stationID))==AIRail.RAILTRACK_NW_SE)
					dstlink=dstpos+AIMap.GetTileIndex(0,-1);
				else	dstlink=dstpos+AIMap.GetTileIndex(-1,0); // NE_SW
			PutSign(dstpos,"D");
			PutSign(dstlink,"d");
			PutSign(srcpos,"S");
			PutSign(srclink,"s");
			INSTANCE.NeedDelay(150);
			if (!INSTANCE.builder.BuildRoadRAIL([srcpos,srclink],[dstlink,dstpos]))
					return false;
				else	retry=false;
			}
		}
	} while (retry);
// pfff here, all connections were made, and rail built
if (srcUseEntry)	srcStation.locations.SetValue(11,dstpos);
		else	srcStation.locations.SetValue(13,dstpos);
if (dstUseEntry)	dstStation.locations.SetValue(11,srcpos);
		else	dstStation.locations.SetValue(13,srcpos);
return true;
}

function cBuilder::CreateAndBuildTrainStation(tilepos, direction, link=null)
// Create a new station, we still don't know if station will be usable
// that's a task handle by CreateStationConnection
// link: true to link to a previous station
{
/*
if (direction == AIRail.RAILTRACK_NE_SW)	cTileTools.CheckLandForConstruction(tilepos, 5, 1);
						else	cTileTools.CheckLandForConstruction(tilepos, 1, 5);
*/
if (link==null)	link=AIStation.STATION_NEW;
if (!AIRail.BuildRailStation(tilepos, direction, 1, 5, link))
	{
	DInfo("Rail station couldn't be built: "+AIError.GetLastErrorString(),1,"cBuilder::CreateAndBuildTrainStation");
	PutSign(tilepos,"!"); INSTANCE.NeedDelay(100);
	return false;
	}
return true;
}

function cBuilder::IsRailStationEntryOpen(stationID=null)
// return true if station entry bit is set
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.locations.GetValue(0);
if ((entry & 1) == 1)	return true;
return false;
}

function cBuilder::IsRailStationExitOpen(stationID=null)
// return true if station exit bit is set
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.locations.GetValue(0);
if ((exit & 2) == 2)	return true;
return false;
}

function cBuilder::RailStationCloseEntry(stationID=null)
// return true if station entry bit is set
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.locations.GetValue(0);
entry=entry & 1;
thatstation.locations.SetValue(0, entry);
DInfo("Closing the entry of station "+AIStation.GetName(thatstation.stationID),1,"RailStationCloseEntry");
}

function cBuilder::RailStationCloseExit(stationID=null)
// Unset exit bit of the station
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.locations.GetValue(0);
exit=exit & 1;
thatstation.locations.SetValue(0, exit);
DInfo("Closing the exit of station "+AIStation.GetName(thatstation.stationID),1,"RailStationCloseEntry");
}


function cBuilder::GetRailStationIN(getEntry, stationID=null)
// Return the tile where the station IN point is
// getEntry = true to return the entry IN, false to return exit IN
// If the IN point doesn't exist, return the virtual position where the station IN would be
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.locations.GetValue(1);
local exit=thatstation.locations.GetValue(3);
if (getEntry && entry != -1)	return entry;
if (!getEntry && exit != -1)	return exit;
local stapos=AIStation.GetLocation(thatstation.stationID);
local direction=AIRail.GetRailStationDirection(stapos);
local exitpos=stapos;
local entrypos=stapos;
if (direction == AIRail.RAILTRACK_NW_SE)
		{
		entrypos+=AIMap.GetTileIndex(0,-3);
		exitpos+=AIMap.GetTileIndex(0,7);
		}
	else	{
		entrypos+=AIMap.GetTileIndex(-3,0);
		exitpos+=AIMap.GetTileIndex(7,0);
		}
//PutSign(stapos,"Sta");
//PutSign(entrypos,"Entry");
//PutSign(exitpos,"Exit");
// if we're still here, we know we have entry or exit set to -1
if (getEntry)	return entrypos;
		else	return exitpos;
}

function cBuilder::GetRailStationOUT(getEntry, stationID=null)
// Return the tile where the station OUT point is
// getEntry = true to return the entry OUT, false to return exit OUT
// If the OUT point doesn't exist, return the virtual position where the station OUT would be
// If the station width==1 there's no OUT point and so we will return -1
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.locations.GetValue(2);
local exit=thatstation.locations.GetValue(4);
if (thatstation.size==1)
	{
	DError("Train station of 1 width doesn't need or have an OUT point !",1,"cBuilder::GetRailStationOUT");
	return -1;
	}
if (getEntry)	return entry;
		else	return exit;
}

function cBuilder::SetRailType(rtype=null)
// set current railtype
{
	if (rtype == null)
		{
		local railtypes = AIRailTypeList();
		if (railtypes.IsEmpty())	{ DError("There's no railtype avaiable !",1,"cBuilder::SetRailType"); return false; }
		rtype=railtypes.Begin();
		}
	if (!AIRail.IsRailTypeAvailable(rtype))	{ DError("Railtype "+rtype+" is not available !",1,"cBuilder::SetRailType"); return false; }
	AIRail.SetCurrentRailType(rtype);
}

function cBuilder::RailStationGuessEmptyPlatform(staloc)
// Guess what platform is empty (its entry and exit is not yet connect with rails)
// and return the tile where we found one
// staloc : tile location to check the station
// return -1 on error
{
if (!AIRail.IsRailStationTile(staloc))
	{
	DInfo("Not a rail station location "+staloc,1,"cBuilder::RailStationGuessEmptyTrack");
	return -1;
	}
local frontTile, backTile, leftTile, rightTile, direction= null;
direction=AIRail.GetRailStationDirection(staloc);
if (direction == AIRail.RAILTRACK_NW_SE)
	{
	frontTile=AIMap.GetTileIndex(0,1);
	backTile=AIMap.GetTileIndex(0,-1);
	leftTile=AIMap.GetTileIndex(1,0);
	rightTile=AIMap.GetTileIndex(-1,0);
	}
else	{ // NE_SW
	frontTile=AIMap.GetTileIndex(-1,0);
	backTile=AIMap.GetTileIndex(1,0);
	leftTile=AIMap.GetTileIndex(0,-1);
	rightTile=AIMap.GetTileIndex(0,1);
	}
local isEntryClear, isExitClear=null;
local lookup=staloc;
// search up
while (AIRail.IsRailStationTile(lookup))
		{
		local scanner=lookup+backTile;
		isEntryClear=!AIRail.IsRailTile(lookup+frontTile);
		while (AIRail.IsRailStationTile(scanner))	scanner+=backTile;
		isExitClear=!AIRail.IsRailTile(scanner);
		lookup+=leftTile;
		if (isEntryClear && isExitClear)	break;
		}
// search down
if (!isEntryClear && !isExitClear)
	{
	lookup=staloc;
	while (AIRail.IsRailStationTile(lookup))
			{
			local scanner=lookup+backTile;
			isEntryClear=!AIRail.IsRailTile(lookup+frontTile);
			while (AIRail.IsRailStationTile(scanner))	scanner+=backTile;
			isExitClear=!AIRail.IsRailTile(scanner);
			lookup+=rightTile;
			}
	}
if (isEntryClear && isExitClear)	return lookup;
					else	return -1;
}

function cBuilder::RailStationRemovePlatform(staloc)
// remove a rail station platform we found at staloc
// discard any errors, we just try to remove it
{
local tilelist=cTileTools.FindStationTiles(statile);
if (tilelist.IsEmpty())	return;
local Keeper=null;
local railtrack=null;
if (AIRail.GetRailStationDirection(staloc) == AIRail.RAILTRACK_NW_SE)
	{ tilelist.Valuate(AIMap.GetTileX); Keeper=AIMap.GetTileX(staloc); railtrack=AIRail.RAILTRACK_NW_SE; }
else	{ tilelist.Valuate(AIMap.GetTileY); Keeper=AIMap.GetTileY(staloc); railtrack=AIRail.RAILTRACK_NE_SW; }
tilelist.KeepValue(Keeper);
showLogic(tilelist);
foreach (tile, dummy in tilelist)	AIRail.RemoveRailTrack(tile, railtrack);
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
if (useEntry)
	{
	if (taker)	trainEntryTaker++;
		else	trainEntryDropper++;
	}
else	{
	if (taker)	trainExitTaker++;
		else	trainExitDropper++;
	}
// 7: number of train dropper using entry
// 8: number of train dropper using exit
// 9: number of train taker using entry
// 10: number of train taker using exit
local newStationSize=trainEntryTaker+trainExitTaker+(trainEntryDropper / 2)+(trainExitDropper / 2);
local position=AIStation.GetLocation(thatstation.stationID);
local direction=AIRail.GetRailStationDirection(position);
INSTANCE.builder.SetRailType(thatstation.specialType);
local leftTileOf=null;
local rightTileOf=null;
local forwardTileOf=null;
local backwardTileOf=null;
local workTile=null; // the station front tile, but depend on entry or exit
local railFront, railCross, railLeft, railRight, fire = null;
//local backTileOf=null;
if (direction == AIRail.RAILTRACK_NW_SE)
	{
	leftTileOf=AIMap.GetTileIndex(-1,0);
	rightTileOf=AIMap.GetTileIndex(1,0);
	railFront=AIRail.RAILTRACK_NW_SE;
	railCross=AIRail.RAILTRACK_NE_SW;
	railLeft=AIRail.RAILTRACK_SW_SE;
	railRight=AIRail.RAILTRACK_NE_SE;
	if (useEntry)	{
				forwardTileOf=AIMap.GetTileIndex(0,-1);
				backwardTileOf=AIMap.GetTileIndex(0,1);
				workTile=position+forwardTileOf;
				}
			else	{
				forwardTileOf=AIMap.GetTileIndex(0,1);
				backwardTileOf=AIMap.GetTileIndex(0,-1);
				workTile=position+AIMap.GetTileIndex(0,6);
				}
	}
else	{ // NE_SW
	leftTileOf=AIMap.GetTileIndex(0,-1);
	rightTileOf=AIMap.GetTileIndex(0,1);
	railFront=AIRail.RAILTRACK_NE_SW;
	railCross=AIRail.RAILTRACK_NW_SE;
	railLeft=AIRail.RAILTRACK_NW_SW;
	railRight=AIRail.RAILTRACK_SW_SE;
	if (useEntry)	{
				forwardTileOf=AIMap.GetTileIndex(-1,0);
				backwardTileOf=AIMap.GetTileIndex(1,0);
				workTile=position+forwardTileOf;
				}
			else	{
				forwardTileOf=AIMap.GetTileIndex(1,0);
				backwardTileOf=AIMap.GetTileIndex(-1,0);
				workTile=position+AIMap.GetTileIndex(6,0);
				}
	}
PutSign(workTile,"W");
local displace=AIMap.GetTileIndex(0,0); // don't move
if (newStationSize > thatstation.size)
	{
	DInfo("Upgrading "+AIStation.GetName(thatstation.stationID)+" to "+newStationSize,0,"RailStationGrow");
	if (thatstation.maxsize==thatstation.size)
		{
		DInfo("We'll need another platform to handle that train, but the station "+AIStation.GetName(thatstation.stationID)+" cannot grow anymore.",1,"RailStationGrow");
		INSTANCE.builder.CriticalError=true; // raise it ourselves
		return false;
		}
	local allfail=false;
	local fail=false;
	fail=CreateAndBuildTrainStation(position+leftTileOf, direction, thatstation.stationID);
	displace=position+leftTileOf;
	if (fail)
		{
		INSTANCE.builder.IsCriticalError();
		allfail=INSTANCE.builder.CriticalError;
		INSTANCE.builder.CriticalError=false;
		fail=CreateAndBuildTrainStation(position+rightTileOf, direction, thatstation.stationID);
		displace=position+RightTileOf;
		if (fail)	
			{
			INSTANCE.builder.IsCriticalError();
			if (INSTANCE.builder.CriticalError && allfail)
				{ // We will never be able to build one more station platform in that station so
				DInfo("Critical failure, station couldn't be upgrade anymore!",1,"RailStationGrow");
				thatstation.maxsize=thatstation.size;
				local guessplatform=INSTANCE.builder.RailStationGuessEmptyPlatform(position);
				INSTANCE.builder.RailStationRemovePlatform(guessplatform);
				INSTANCE.builder.CriticalError=true; // Make sure caller will be aware of that failure
				return false;
				}
			else	{
				DInfo("Temporary failure, station couldn't be upgrade for now",1,"RailStationGrow");
				return false;
				}
			}
		}
	// if we are here, we endup successfuly add a new track to the station
	thatstation.size++;
	}
local se_IN, se_OUT, se_crossing = null; // entry
local sx_IN, sx_OUT, sx_crossing = null; // exit
se_IN=thatstation.locations.GetValue(1);
se_OUT=thatstation.locations.GetValue(2);
sx_IN=thatstation.locations.GetValue(3);
sx_OUT=thatstation.locations.GetValue(4);
se_crossing=thatstation.locations.GetValue(5);
sx_crossing=thatstation.locations.GetValue(6);
// 1: entry_in
// 2: entry_out
// 3: exit_in
// 4: exit_out
// 5: entry_crossing
// 6: exit_crossing
local deadEntry=false;
local deadExit=false;
local rail=null;
local success=false;
local crossing=null;
// define & build crossing point
if ( (useEntry && se_crossing==-1) || (!useEntry && sx_crossing==-1) )
	{
	// try to level the area to work on
	/*if (direction == AIRail.RAILTRACK_NE_SW)	cTileTools.CheckLandForConstruction(workTile, 5, 1);
							else	cTileTools.CheckLandForConstruction(workTile, 1, 5);*/
	// We first try to build the crossing area from worktile+1 upto worktile+3 to find where one is doable
	// Because a rail can cross a road, we choose one that will fail to cross one to be sure it's a valid spot for crossing
	rail=railLeft;
	DInfo("Building crossing point ",2,"RailStationGrow");
	local j=1;
	do	{
		PutSign(workTile+(j*forwardTileOf),"x"); INSTANCE.NeedDelay();
		cTileTools.TerraformLevelTiles(position,workTile+(j*forwardTileOf));
		//AITile.LevelTiles(workTile+backwardTileOf, workTile+(j*forwardTileOf));
		success=INSTANCE.builder.DropRailHere(rail, workTile+(j*forwardTileOf));
		if (success)	{
					if (useEntry)	{ se_crossing=workTile+(j*forwardTileOf); crossing=se_crossing; }
							else	{ sx_crossing=workTile+(j*forwardTileOf); crossing=sx_crossing; }
					}
		j++;
		} while (j < 4 && !success);
	if (success)
		{
		for (local h=1; h < 4; h++)	INSTANCE.builder.DropRailHere(rail,workTile+(j*forwardTileOf),true);
		// remove previous tracks to clean area
		INSTANCE.builder.DropRailHere(railFront, crossing);
		INSTANCE.builder.DropRailHere(railCross, crossing);
		if (useEntry)
				{
				thatstation.locations.SetValue(5,se_crossing);
				DInfo("Entry crossing is now set to : "+se_crossing,2,"RailStationGrow");
				PutSign(se_crossing,"X");
				}
			else	{
				thatstation.locations.SetValue(6,sx_crossing);
				DInfo("Exit crossing is now set to : "+sx_crossing,2,"RailStationGrow");
				PutSign(sx_crossing,"X");
				}
		}
	else	{
		INSTANCE.builder.IsCriticalError();
		if (INSTANCE.builder.CriticalError)
				{
				if (useEntry)	INSTANCE.builder.RailStationCloseEntry(thatstation.stationID);
						else	INSTANCE.builder.RailStationCloseExit(thatstation.stationID);
				INSTANCE.builder.CriticalError=false;
				return false;
				}
			else	return false; // just give up this time
		}
	}

// build entry/exit IN, if anyone use entry or exit, we need it built
local eopen=INSTANCE.builder.IsRailStationEntryOpen(thatstation.stationID);
local xopen=INSTANCE.builder.IsRailStationExitOpen(thatstation.stationID);
if ((se_IN == -1 && useEntry && eopen) || (sx_IN == -1 && !useEntry && xopen))
	{
	DInfo("Building IN point",1,"RailStationGrow");
	rail=railFront;
	local j=1;
	local fromtile=0;
	if (useEntry)	fromtile=se_crossing;
			else	fromtile=sx_crossing;
	do	{
		PutSign(fromtile+(j*forwardTileOf),"."); INSTANCE.NeedDelay();
		//AITile.LevelTiles(position, fromtile+(j*forwardTileOf));
		cTileTools.TerraformLevelTiles(position,fromtile+(j*forwardTileOf));
		success=INSTANCE.builder.DropRailHere(rail, fromtile+(j*forwardTileOf));
		if (INSTANCE.builder.IsCriticalError())
			{
			if (INSTANCE.builder.CriticalError)	
				{
				if (useEntry)	INSTANCE.builder.RailStationCloseEntry(thatstation.stationID);
						else	INSTANCE.builder.RailStationCloseExit(thatstation.stationID);
				INSTANCE.builder.CriticalError=false;
				return false;
				}
			else	return false; // giveup and retry later
			}
		DInfo("Building signal",1,"Deb");
		success=AIRail.BuildSignal(fromtile+(j*forwardTileOf), fromtile+((j-1)*forwardTileOf), AIRail.SIGNALTYPE_NORMAL_TWOWAY);
		if (success)	{
					if (useEntry)	{ se_IN=fromtile+(j*forwardTileOf); }
							else	{ sx_IN=fromtile+(j*forwardTileOf); }
					}
		j++;
		INSTANCE.NeedDelay(100);
		} while (j < 4 && !success);
	if (success)
		{
		if (useEntry)	{
					thatstation.locations.SetValue(1,se_IN);
					DInfo("IN Entry point set to "+se_IN,1,"RailStationGrow");
					}
				else	{
					thatstation.locations.SetValue(3,sx_IN);
					DInfo("IN Exit point set to "+sx_IN,1,"RailStationGrow");
					}
		}
	}

// 7: number of train dropper using entry
// 8: number of train dropper using exit
// 9: number of train taker using entry
// 10: number of train taker using exit
// If we reach this line, it means everything upper was succesful (and i hope this will be !)
thatstation.locations.SetValue(9,trainEntryTaker);
thatstation.locations.SetValue(10,trainExitTaker);
thatstation.locations.SetValue(7,trainEntryDropper);
thatstation.locations.SetValue(8,trainExitDropper);
DInfo("Station "+AIStation.GetName(thatstation.stationID)+" have "+(trainEntryTaker+trainEntryDropper)+" trains using its entry and "+(trainExitTaker+trainExitDropper)+" using its exit",1,"RailStationGrow");

//success=INSTANCE.builder.BuildRoadRAIL([srclink,srcpos],[dstlink,dstpos]);
return true;
}

function cBuilder::DropRailHere(railneed, pos, remove=false)
// Put a rail at position pos, on failure clear the area and retry
// Can also drop a signal if railneed >= 500
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
			DInfo("Cannot build rail track at "+pos,1,"DropRailHere");
			return false;
		}
	}
else	return true;
return !AIRail.BuildRailTrack(pos,railneed);
}
