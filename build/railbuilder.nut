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

//tilelist.Valuate(cTileTools.IsBuildable);
//tilelist.KeepValue(1);
local success = false;
local saveList=AIList();
saveList.AddList(tilelist);
//DInfo("isneartown="+isneartown+" istown="+istown,2,"BuildTrainStation");
local buildmode=0;
local cost=5*AIRail.GetBuildCost(AIRail.GetCurrentRailType(),AIRail.BT_STATION);
DInfo("Rail station cost: "+cost+" byinflat"+(cost*cBanker.GetInflationRate()),2,"BuildTrainStation");
INSTANCE.bank.RaiseFundsBy(cost);
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
			tilelist.Valuate(cTileTools.IsBuildableRectangleFlat,1,11);
			tilelist.KeepValue(1);
			break;
		case	1:
			tilelist.Valuate(cTileTools.IsBuildableRectangleFlat,11,1);
			tilelist.KeepValue(1);
			break;
		case	2:
			tilelist.Valuate(AITile.IsBuildableRectangle,1,11); // allow terraform19
			tilelist.KeepValue(1);
			break;
		case	3:
			tilelist.Valuate(AITile.IsBuildableRectangle,11,1); // allow terraform91
			tilelist.KeepValue(1);
			break;
		case	4:
			tilelist.Valuate(cTileTools.IsBuildable); // even water will be terraform
			tilelist.KeepValue(1);
			break;
		}
	DInfo("Tilelist set to "+tilelist.Count()+" in mode "+buildmode,1,"BuildTrainStation");
	// restore previous valuated values...
	foreach (ltile, lvalue in saveList)	if (tilelist.HasItem(ltile))	tilelist.SetValue(ltile, lvalue);
	if (!istown)
		{
		tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
		tilelist.Sort(AIList.SORT_BY_VALUE, true);
		}
	else	{ tilelist.Sort(AIList.SORT_BY_VALUE, false); }
	showLogic(tilelist); 
	ClearSignsALL();
	foreach (tile, dummy in tilelist)
		{
		// find where that point is compare to its source for the station
			if (start)	dir=INSTANCE.builder.GetDirection(tile, INSTANCE.route.source_location);
				else	dir=INSTANCE.builder.GetDirection(INSTANCE.route.target_location,tile);
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
			DInfo("New station direction set to "+dir,1,"BuildTrainStation");
		if (buildmode==4)
			{
			if (dir == AIRail.RAILTRACK_NW_SE)	statile=cTileTools.CheckLandForConstruction(tile, 1, 5);
								else	statile=cTileTools.CheckLandForConstruction(tile, 5, 1);
			}
		else	statile=tile;
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
					statile=tile;
					break;
					}
				else	{ // see why we fail
					if (buildmode==4)	cTileTools.BlackListTileSpot(statile);
					INSTANCE.builder.IsCriticalError();
					if (INSTANCE.builder.CriticalError)	{ break; }
					if (AIError.GetLastError()==AIError.ERR_LOCAL_AUTHORITY_REFUSES)	{ break; }
					}
		}
	buildmode++;
	} while (!success && buildmode!=5);
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
/*pathfinder._cost_level_crossing = 900;
pathfinder.cost_slope = 200;
pathfinder.cost_coast = 100;
pathfinder.cost_bridge_per_tile = 90;
pathfinder.cost_tunnel_per_tile = 75;
pathfinder.max_bridge_length = 20;
pathfinder.max_tunnel_length = 20;*/
pathfinder.cost.turn = 200;
pathfinder.cost.max_bridge_length=30;
pathfinder.cost.max_tunnel_length=20;
pathfinder.cost.tile=80;
pathfinder.cost.slope=100;
//pathfinder.cost.diagonal_tile=100;

local src=head1;
local dst=head2;

pathfinder.InitializePath([src], [dst]);
local savemoney=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
local pfInfo=null;
INSTANCE.bank.SaveMoney(); // thinking long time, don't waste money
pfInfo=AISign.BuildSign(head1[0],"Pathfinding...");
DInfo("Rail Pathfinding...",1);
local counter = 0;
local path = false;
while (path == false && counter < 350)
	{
	path = pathfinder.FindPath(350);
	counter++;
	AISign.SetName(pfInfo,"Pathfinding... "+counter);
	//AIController.Sleep(1);
	}
if (path != null && path != false)
	{
	DInfo("Path found. (" + counter + ")",0,"BuildRoadRAIL");
	AISign.RemoveSign(pfInfo);
	ClearSignsALL();
	}
else	{
	ClearSignsALL();
	DInfo("Pathfinding failed.",1);
	INSTANCE.builder.CriticalError=true;
	INSTANCE.bank.RaiseFundsBy(savemoney);
	AISign.RemoveSign(pfInfo);
	return false;
	}
INSTANCE.bank.RaiseFundsBigTime();
local prev = null;
local prevprev = null;
local pp1, pp2, pp3 = null;
while (path != null)
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
					if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH)
						{
						DInfo("That tunnel would be too expensive. Construction aborted.",2);
						return false;
						}
					if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false; else return true;
					}
				}
			else	{
				local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
				bridgelist.Valuate(AIBridge.GetPrice,AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
				bridgelist.Sort(AIList.SORT_BY_VALUE,true);
				if (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridgelist.Begin(), prev, path.GetTile()))
					{
					DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
					if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH)
						{
						DInfo("That bridge would be too expensive. Construction aborted.",2);
						return false;
						}
					if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false; else return true;
					cBridge.IsBridgeTile(prev); // force bridge check
					}
				}
			pp3 = pp2;
			pp2 = pp1;
			pp1 = prevprev;
			prevprev = prev;
			prev = path.GetTile();
			path = path.GetParent();
			}
		 else {
			if (!AIRail.BuildRail(prevprev, prev, path.GetTile()))
				{
				DInfo("An error occured while I was building the rail: " + AIError.GetLastErrorString(),2);
				if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false; else return true;
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
// We return result in array: 0=src tile, 1=1(entry)0(exit), 1=dst tile, value=1(entry)0(exit)
// return array empty on error
// 
{
// check entry/exit avaiablility on stations
local srcEntry=cStation.IsRailStationEntryOpen(src);
local srcExit=cStation.IsRailStationExitOpen(src);
local dstEntry=cStation.IsRailStationEntryOpen(dst);
local dstExit=cStation.IsRailStationExitOpen(dst);
local srcEntryLoc=cStation.GetRailStationIN(true,src);
local srcExitLoc=cStation.GetRailStationIN(false,src);
local dstEntryLoc=cStation.GetRailStationIN(true,dst);
local dstExitLoc=cStation.GetRailStationIN(false,dst);
if (srcEntryLoc==-1)	srcEntryLoc=cStation.GetRailStationFrontTile(true, cStation.GetLocation(src), src);
if (dstEntryLoc==-1)	dstEntryLoc=cStation.GetRailStationFrontTile(true, cStation.GetLocation(dst), dst);
if (srcExitLoc==-1)	srcExitLoc=cStation.GetRailStationFrontTile(false, cStation.GetLocation(src), src);
if (dstExitLoc==-1)	dstExitLoc=cStation.GetRailStationFrontTile(false, cStation.GetLocation(dst), dst);

if ( (!srcEntry && !srcExit) || (!dstEntry && !dstExit) )
	{
	DInfo("That station have its entry and exit closed. No more connections could be made with it",1,"FindStationEntryToExitPoint");
	return [];
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
local bestWay=[];
if (bestsrc == srcEntryLoc)	srcFlag=1;
if (bestdst == dstEntryLoc)	dstFlag=1;
bestWay.push(bestsrc);
bestWay.push(srcFlag);
bestWay.push(bestdst);
bestWay.push(dstFlag);
DInfo("Best connecting source="+bestsrc+" destination="+bestdst+" srcFlag="+srcFlag+" dstFlag="+dstFlag,2,"FindStationEntryToExit");
PutSign(bestsrc,"CS");
PutSign(bestdst,"CT");
return bestWay;
}

function cBuilder::CreateStationsConnection(fromObj, toObj)
// Connect station fromObj to station toObj by picking entry/exit close to each other and create connections in front of them
// fromObj, toObj: 2 valid rail stations
// this also set the INSTANCE.route.* properties
{
local srcStation=cStation.GetStationObject(fromObj);
local dstStation=cStation.GetStationObject(toObj);
DInfo("Connecting rail station "+cStation.StationGetName(srcStation.stationID)+" to "+cStation.StationGetName(dstStation.stationID),1,"CreateStationsConnection");
local retry=true;
local bestWay=AIList();
local srcresult=false;
local dstresult=false;
local srcpos=null;
local dstpos=null;
local srcUseEntry=null;
local dstUseEntry=null;
do	{
	bestWay=INSTANCE.builder.FindStationEntryToExitPoint(fromObj, toObj);
	if (bestWay.len()==0)	{ INSTANCE.builder.CriticalError=true; return false; }
				else	retry=true;
	if (retry) // we found a possible connection
		{
		srcpos=bestWay[0];
		dstpos=bestWay[2];
		srcUseEntry=(bestWay[1]==1);
		dstUseEntry=(bestWay[3]==1);
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
			local srclink=0;
			local dstlink=0;
			local mainowner=srcStation.locations.GetValue(22);
			if (srcUseEntry)	srclink=srcStation.locations.GetValue(11);
					else	srclink=srcStation.locations.GetValue(13);
			if (dstUseEntry)	dstlink=dstStation.locations.GetValue(12);
					else	dstlink=dstStation.locations.GetValue(14);
			srcpos=srclink+cStation.GetRelativeTileBackward(srcStation.stationID, srcUseEntry);
			dstpos=dstlink+cStation.GetRelativeTileBackward(dstStation.stationID, dstUseEntry);
			if (mainowner==-1)
				{
				DInfo("Calling rail pathfinder: srcpos="+srcpos+" dstpos="+dstpos,2,"CreateStationConnection");
				PutSign(dstpos,"D");
				PutSign(dstlink,"d");
				PutSign(srcpos,"S");
				PutSign(srclink,"s");
				if (!INSTANCE.builder.BuildRoadRAIL([srclink,srcpos],[dstlink,dstpos]))
						return false;
					else	retry=false;
				dstStation.locations.SetValue(22,INSTANCE.route.UID);
				srcStation.locations.SetValue(22,INSTANCE.route.UID);
				}
			else	retry=false;
			}
		}
	} while (retry);
// pfff here, all connections were made, and rails built
if (srcUseEntry)	srcStation.locations.SetValue(11,dstpos);
		else	srcStation.locations.SetValue(13,dstpos);
if (dstUseEntry)	dstStation.locations.SetValue(11,srcpos);
		else	dstStation.locations.SetValue(13,srcpos);
INSTANCE.route.source_RailEntry=srcUseEntry;
INSTANCE.route.target_RailEntry=dstUseEntry;
INSTANCE.route.primary_RailLink=true;
return true;
}

function cBuilder::CreateAndBuildTrainStation(tilepos, direction, link=null)
// Create a new station, we still don't know if station will be usable
// that's a task handle by CreateStationConnection
// link: true to link to a previous station
{
if (link==null)	link=AIStation.STATION_NEW;
local money=AIRail.GetBuildCost(AIRail.GetCurrentRailType(), AIRail.BT_STATION);
if (!cBanker.CanBuyThat(money))	DInfo("We lack money to buy the station",1,"cBuilder::CreateAndBuildTrainStation");
INSTANCE.bank.RaiseFundsBy(money);
if (!AIRail.BuildRailStation(tilepos, direction, 1, 5, link))
	{
	DInfo("Rail station couldn't be built, link="+link+" err: "+AIError.GetLastErrorString(),1,"cBuilder::CreateAndBuildTrainStation");
	PutSign(tilepos,"!");
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
		if (railtypes.IsEmpty())	{ DError("There's no railtype avaiable !",1,"cBuilder::SetRailType"); return false; }
		rtype=railtypes.Begin();
		}
	if (!AIRail.IsRailTypeAvailable(rtype))	{ DError("Railtype "+rtype+" is not available !",1,"cBuilder::SetRailType"); return false; }
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
showLogic(tilelist);
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
//print("raw**: trainEntryTaker="+trainExitTaker+" trainEntryDropper="+trainEntryDropper+" trainexitTaker="+trainExitTaker+" trainexitDropper="+trainExitDropper);

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
local tED=trainEntryDropper / 2;
if (trainEntryDropper > 0 && tED==0)	tED++;
local tXD=trainExitDropper / 2;
if (trainExitDropper > 0 && tXD==0)	tXD++;
local newStationSize=trainEntryTaker+trainExitTaker+tED+tXD;

local maxE_total=thatstation.maxsize * 2;
if (!cStation.IsRailStationEntryOpen(staID))	maxE_total=thatstation.size *2;
local maxX_total=thatstation.maxsize * 2;
if (!cStation.IsRailStationExitOpen(staID))	maxX_total=thatstation.size *2;
DInfo(thatstation.name+" entry throughput : "+(trainEntryDropper+trainEntryTaker)+"/"+maxE_total+" trains",1,"cBuilder::StationGrow");
DInfo(thatstation.name+" exit throughput : "+(trainExitDropper+trainExitTaker)+"/"+maxX_total+" trains",1,"cBuilder::StationGrow");
if (!cStation.IsRailStationEntryOpen(staID) && useEntry)	{ DWarn(thatstation.name+" entry is CLOSE",1,"cBuilder::StationGrow"); return false }
if (!cStation.IsRailStationExitOpen(staID) && !useEntry)	{ DWarn(thatstation.name+" exit is CLOSE",1,"cBuilder::StationGrow"); return false }

local position=thatstation.GetLocation();
local direction=thatstation.GetRailStationDirection();
INSTANCE.builder.SetRailType(thatstation.specialType); // not to forget
local leftTileOf, rightTileOf, forwardTileOf, backwardTileOf =null;
local workTile=null; // the station front tile, but depend on entry or exit
local railFront, railCross, railLeft, railRight, railUpLeft, railUpRight, fire = null;
workTile=thatstation.GetRailStationFrontTile(useEntry,position);
// find route that use the station
local road=null;

if (thatstation.owner.IsEmpty())
	{
	DWarn("Nobody claim that station yet",1,"RailStationGrow");
	}
else	{
	local uidowner=thatstation.locations[22];
	road=cRoute.GetRouteObject(uidowner);
	if (road==null)
		{
		DWarn("The route owner ID "+uidowner+" is invalid",1,"RailStationGrow");
		}
	else	DWarn("Station main owner "+uidowner,1,"RailStationGrow");
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
if (useEntry)	DInfo("Working on station entry",1,"RailStationGrow");
		else	DInfo("Working on station exit",1,"RailStationGrow");
leftTileOf=cStation.GetRelativeTileLeft(staID, useEntry);
rightTileOf=cStation.GetRelativeTileRight(staID, useEntry);
forwardTileOf=cStation.GetRelativeTileForward(staID, useEntry);
backwardTileOf=cStation.GetRelativeTileBackward(staID, useEntry);
PutSign(workTile,"W");
local displace=0;
// need grow the station ?
// only define when a train activate it, so only run 1 time
//newStationSize=thatstation.size+1;
DInfo("Phase 1: grow",1,"RailStationGrow");
if (newStationSize > thatstation.size)
	{
	DInfo("Upgrading "+thatstation.StationGetName()+" to "+newStationSize+" platforms",0,"RailStationGrow");
	if (thatstation.maxsize==thatstation.size)
		{
		DInfo("We'll need another platform to handle that train, but the station "+cStation.StationGetName(thatstation.stationID)+" cannot grow anymore.",1,"RailStationGrow");
		INSTANCE.builder.CriticalError=true; // raise it ourselves
		return false;
		}
	local allfail=false;
	local topLeftPlatform=thatstation.locations.GetValue(20);
	local topRightPlatform=thatstation.locations.GetValue(21);
	local idxRightPlatform=cStation.GetPlatformIndex(topRightPlatform, useEntry);
	local idxLeftPlatform=cStation.GetPlatformIndex(topLeftPlatform, useEntry);
	local plat_main=idxLeftPlatform;
	local plat_alt=idxRightPlatform;
	local pside=leftTileOf;
	if (useEntry)
		{
		pside=rightTileOf; // try build to right side when using entry first, else try left side
		plat_main=idxRightPlatform;
		plat_alt=idxLeftPlatform;
		}
	displace=plat_main+pside;
	local areaclean=AITileList();
	areaclean.AddRectangle(displace,displace+(backwardTileOf*(station_depth-1)));
	areaclean.Valuate(AITile.IsBuildable);
	showLogic(areaclean); // deb
	local canDestroy=cTileTools.IsAreaBuildable(areaclean,staID);
	if (canDestroy)
		foreach (ctile, cdummy in areaclean)
			{ !cTileTools.DemolishTile(ctile);	}
	cTileTools.TerraformLevelTiles(plat_main, displace+(backwardTileOf*(station_depth-1)));
	success=INSTANCE.builder.CreateAndBuildTrainStation(cStation.GetPlatformIndex(plat_main,true)+pside, direction, thatstation.stationID);
	if (success)	foreach (tile, dummy in areaclean)	thatstation.StationClaimTile(tile, thatstation.stationID);
	if (!success)
		{
		INSTANCE.builder.IsCriticalError();
		allfail=INSTANCE.builder.CriticalError;
		INSTANCE.builder.CriticalError=false;
		pside=rightTileOf;
		if (useEntry)	pside=leftTileOf;
		displace=plat_alt+pside;
		local areaclean=AITileList();
		areaclean.AddRectangle(displace,displace+(backwardTileOf*(station_depth-1)));
		showLogic(areaclean);
		if (cTileTools.IsAreaBuildable(areaclean,staID))
			foreach (ctile, cdummy in areaclean)	cTileTools.DemolishTile(ctile);
		cTileTools.TerraformLevelTiles(plat_alt, displace+(backwardTileOf*(station_depth-1)));
		success=INSTANCE.builder.CreateAndBuildTrainStation(cStation.GetPlatformIndex(plat_alt,true)+pside, direction, thatstation.stationID);
		if (success)	foreach (tile, dummy in areaclean)	thatstation.StationClaimTile(tile, thatstation.stationID);
		if (!success)	
			{
			INSTANCE.builder.IsCriticalError();
			if (INSTANCE.builder.CriticalError && allfail)
				{ // We will never be able to build one more station platform in that station so
				DInfo("Critical failure, station couldn't be upgrade anymore!",1,"RailStationGrow");
				thatstation.maxsize=thatstation.size;
				INSTANCE.builder.CriticalError=true; // Make sure caller will be aware of that failure
				return false;
				}
			else	{
				DInfo("Temporary failure, station couldn't be upgrade for now",1,"RailStationGrow");
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
DInfo("Phase2: define entry/exit point",1,"RailStationGrow");
// find if we can use that entry/exit if none is define yet
// run only 1 time as it's only define when a train trigger it
if ( (useEntry && se_crossing==-1) || (!useEntry && sx_crossing==-1) )
	{ // look if we're going too much inside a town, making big damages to it, and mostly sure failure to use that direction to build rails
	local towncheck=AITileList();
	local testcheck=AITileList();
	towncheck.AddRectangle(workTile, workTile+rightTileOf+(5*forwardTileOf));
	testcheck.AddList(towncheck);
	testcheck.Valuate(cTileTools.IsBuildable);
	testcheck.KeepValue(0);
	success=true;
	if (testcheck.Count()>5)	{ DInfo("Giving up, we may put too much havock there",1,"RailStationGrow"); success=false; }
	else	{
		if (cTileTools.IsAreaBuildable(towncheck,staID))
			{
			testcheck.AddList(towncheck);
			cTileTools.YexoValuate(testcheck, cTileTools.IsRemovable); // rails are protect here
			showLogic(testcheck);
			INSTANCE.NeedDelay(100);
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
						DInfo("Giving up, we're probably going inside "+AITown.GetName(neartown),1,"RailStationGrow");
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
				else	{ DInfo("We gave up, too much troubles",1,"RailStationGrow"); closeIt=true; }
	}

// define & build crossing point if none exist yet
// only need define when need, when a train try use one of them, so only run 1 time
DInfo("Phase3: define crossing point",1,"RailStationGrow");
if ( ((useEntry && se_crossing==-1) || (!useEntry && sx_crossing==-1)) && !closeIt )
	{
	// We first try to build the crossing area from worktile+1 upto worktile+3 to find where one is doable
	// Because a rail can cross a road, we try build a track that will fail to cross a road to be sure it's a valid spot for crossing
	rail=railLeft;
	DInfo("Building crossing point ",2,"RailStationGrow");
	local j=1;
	do	{
		temptile=workTile+(j*forwardTileOf);
		cTileTools.TerraformLevelTiles(position,temptile);
		if (cTileTools.CanUseTile(temptile,staID))
			success=INSTANCE.builder.DropRailHere(rail, temptile);
		else	{ INSTANCE.builder.CriticalError=true; success=false; }
		if (success)	{
					if (useEntry)	{ se_crossing=temptile; crossing=se_crossing; }
							else	{ sx_crossing=temptile; crossing=sx_crossing; }
					INSTANCE.builder.DropRailHere(rail, temptile,true); // remove the test track
					}
		j++;
		} while (j < 4 && !success);
	if (success)
		{
		thatstation.RailStationClaimTile(crossing, useEntry);
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
		INSTANCE.builder.CriticalError=false;
		}
	else	{
		INSTANCE.builder.IsCriticalError();
		if (INSTANCE.builder.CriticalError)
				{
				closeIt=true;
				INSTANCE.builder.CriticalError=false;
				}
		}
	}

DInfo("Phase4: build entry&exit IN/OUT",1,"RailStationGrow");
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
//print("traindump: trainEntryTaker="+trainEntryTaker+" trainEntryDropper="+trainEntryDropper+" trainexitTaker="+trainExitTaker+" trainexitDropper="+trainExitDropper);
//print("needIN="+needIN+" needOUT="+needOUT);
if (needIN > 0 || needOUT > 0)
	{
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
	DInfo("Building "+in_str+" point",1,"RailStationGrow");
	local endconnector=fromtile;
	local building_maintrack=true;
	if (road==null)	building_maintrack=true;
			else	if (road.primary_RailLink)	building_maintrack=false;
	do	{
		temptile=fromtile+(j*forwardTileOf);
		cTileTools.TerraformLevelTiles(position,temptile);
		if (cTileTools.CanUseTile(temptile,staID))
			success=INSTANCE.builder.DropRailHere(rail, temptile);
		else	{ INSTANCE.builder.CriticalError=true; success=false; }
		if (success)	thatstation.RailStationClaimTile(temptile,useEntry);
		if (INSTANCE.builder.IsCriticalError())
			{
			if (INSTANCE.builder.CriticalError)	closeIt=true;
			INSTANCE.builder.CriticalError=false;
			break;
			}
		if (building_maintrack) // we're building IN/OUT point for the primary track
			{
			PutSign(temptile+(1*forwardTileOf),"R1");
			PutSign(temptile+(2*forwardTileOf),"R2");

			cTileTools.TerraformLevelTiles(position,temptile+(3*forwardTileOf));
			if (cTileTools.CanUseTile(temptile+(1*forwardTileOf), staID))
				success=INSTANCE.builder.DropRailHere(rail, temptile+(1*forwardTileOf));
			else	{ INSTANCE.builder.CriticalError=true; success=false; }
			if (success) thatstation.RailStationClaimTile(temptile+(1*forwardTileOf),useEntry);
			if (cTileTools.CanUseTile(temptile+(2*forwardTileOf), staID))
				success=INSTANCE.builder.DropRailHere(rail, temptile+(2*forwardTileOf));
			else	{ INSTANCE.builder.CriticalError=true; success=false; }
			if (success) thatstation.RailStationClaimTile(temptile+(2*forwardTileOf),useEntry);
			}
		if (tmptaker)	sigdir=fromtile+((j+1)*forwardTileOf);
				else	sigdir=fromtile+((j-1)*forwardTileOf);
		DInfo("Building "+in_str+" point signal",1,"RailStationGrow");
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
							if (INSTANCE.builder.DropRailHere(railUpLeft, fromtile))
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
					DInfo(in_str+" "+entry_str+" point set to "+pointview,1,"RailStationGrow");
					PutSign(pointview,in_str);
					}
		j++;
		INSTANCE.NeedDelay(100);
		} while (j < 4 && !success);
		if (!success)	closeIt=true;
	}

// build station entrance point to crossing point
// this need two runs, as we might need entry & exit built in one time
DInfo("Phase5: build & connect station entrance",1,"RailStationGrow");
local entry_build=(se_IN != -1 || se_OUT != -1);
local exit_build=(sx_IN != -1 || sx_OUT != -1);
DInfo("Entry build="+entry_build+" - exit build="+exit_build,2,"RailStationGrow");
DInfo("se_in="+se_IN+" se_out="+se_OUT+" sx_in="+sx_IN+" sx_out="+sx_OUT+" closeit="+closeIt+" useEntry="+useEntry,2,"RailStationGrow");
ClearSignsALL();
foreach (platform, status in thatstation.platforms)
	{
	if (entry_build)	cBuilder.PlatformConnectors(platform, true);
	if (exit_build)	cBuilder.PlatformConnectors(platform, false);
	AIController.Sleep(1);
	}
thatstation.DefinePlatform();  // scan the station platforms for their status
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
			PutSign(wpoint,dir); INSTANCE.NeedDelay(50);
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
				if (INSTANCE.builder.DropRailHere(rail, wpoint))	thatstation.RailStationClaimTile(wpoint, stationside);
			if (runthru && cTileTools.CanUseTile(wpoint,staID))
				if (INSTANCE.builder.DropRailHere(railCross, wpoint))	thatstation.RailStationClaimTile(wpoint, stationside);
			INSTANCE.NeedDelay(50);
			AIController.Sleep(1);
			}
	foreach (platf, openclose in thatstation.platforms)
		{
		local platfront=cStation.GetRelativeCrossingPoint(platf, stationside);
		cTileTools.DemolishTile(platfront); // rails protect
		cBuilder.RailConnectorSolver(platfront+backwardTileOf, platfront, true);
		thatstation.RailStationClaimTile(platfront,staID);
		INSTANCE.NeedDelay(100);
		}
	ClearSignsALL();									
	} // hh loop
thatstation.DefinePlatform();

DInfo("Phase6: building alternate track",1,"RailStationGrow");
// first look if we need some more work
//print("needIN="+needIN);
if (needIN>0) // only work when needIN is built as we only work on target station for that part
	{
	local dowork=true;
	if (road==null)
		{
		DWarn("Our owner route is not yet valid",1,"RailStationGrow");
		dowork=false;
		}
	else	{
		if (road.secondary_RailLink==false)	dowork=true; // only work if we haven't build the connection yet
		if (road.source_stationID == staID)	dowork=false;// but only if we are the target station
//print("source station ID = "+road.source_stationID+" staID="+staID);
		}
//print("dowork="+dowork);
	if (dowork)
		{
		local srcpos, srclink, dstpos, dstlink= null;
		if (road.source_RailEntry)
			srclink=road.source.locations.GetValue(12);
		else	srclink=road.source.locations.GetValue(14);
		if (road.target_RailEntry)
			dstlink=road.target.locations.GetValue(11);
		else	dstlink=road.target.locations.GetValue(13);
		srcpos=srclink+cStation.GetRelativeTileBackward(road.source.stationID, road.source_RailEntry);
		dstpos=dstlink+cStation.GetRelativeTileBackward(road.target.stationID, road.target_RailEntry);
		DInfo("Calling rail pathfinder: srcpos="+srcpos+" dstpos="+dstpos,2,"RailStationGrow");
		PutSign(dstpos,"D");
		PutSign(dstlink,"d");
		PutSign(srcpos,"S");
		PutSign(srclink,"s");
//print("break");
		if (!INSTANCE.builder.BuildRoadRAIL([srclink,srcpos],[dstlink,dstpos]))
			{
			DError("Fail to build alternate track",1,"RailStationGrow");
			return false;
			}
		else	{ road.secondary_RailLink=true; }
		}
	}

DInfo("Phase7: building signals",1,"RailStationGrow");
if (road!=null && road.secondary_RailLink) // route must be valid + alternate rail is built
	{
/*PutSign(road.source.locations.GetValue(1),"S1");
PutSign(road.source.locations.GetValue(2),"S2");
PutSign(road.source.locations.GetValue(3),"S3");
PutSign(road.source.locations.GetValue(4),"S4");
PutSign(road.target.locations.GetValue(1),"T1");
PutSign(road.target.locations.GetValue(2),"T2");
PutSign(road.target.locations.GetValue(3),"T3");
PutSign(road.target.locations.GetValue(4),"T4");
print("SIGNAL STOP");*/
	local srcpos, dstpos = null;
/*	if (road.source_RailEntry)
			srclink=road.source.locations.GetValue(11);
		else	srclink=road.source.locations.GetValue(13);
		if (road.target_RailEntry)
			dstlink=road.target.locations.GetValue(12);
		else	dstlink=road.target.locations.GetValue(14);
		srcpos=srclink+cStation.GetRelativeTileBackward(road.source.stationID, road.source_RailEntry);
		dstpos=dstlink+cStation.GetRelativeTileBackward(road.target.stationID, road.target_RailEntry);
*/
//	PutSign(road.source.locations.GetValue(1),"D");
//	PutSign(dstlink,"d");
//	PutSign(srcpos,"S");
//	PutSign(srclink,"s");
	if (road.source_RailEntry)
			srcpos=road.source.locations.GetValue(1);
		else	srcpos=road.source.locations.GetValue(3);
	if (road.target_RailEntry)
			dstpos=road.target.locations.GetValue(2);
		else	dstpos=road.target.locations.GetValue(4);

	if (!cStation.IsRailStationPrimarySignalBuilt(road.source.stationID))
		{
		DInfo("Building signals on primary track",2,"RailStationGrow");
		if (cBuilder.SignalBuilder(dstpos, srcpos))
			{
			DInfo("...done",2,"RailStationGrow");
			cStation.RailStationSetPrimarySignalBuilt(road.source.stationID);
			}
		else	{ DInfo("... not all signals were built",2,"RailStationGrow"); }
		}
	print("SIGNAL stop");
	ClearSignsALL();
	if (road.source_RailEntry)
			srcpos=road.source.locations.GetValue(2);
		else	srcpos=road.source.locations.GetValue(4);
	if (road.target_RailEntry)
			dstpos=road.target.locations.GetValue(1);
		else	dstpos=road.target.locations.GetValue(3);
/*
	if (road.source_RailEntry)
			srclink=road.source.locations.GetValue(12);
		else	srclink=road.source.locations.GetValue(14);
	if (road.target_RailEntry)
			dstlink=road.target.locations.GetValue(11);
		else	dstlink=road.target.locations.GetValue(13);
	srcpos=srclink+cStation.GetRelativeTileBackward(road.source.stationID, road.source_RailEntry);
	dstpos=dstlink+cStation.GetRelativeTileBackward(road.target.stationID, road.target_RailEntry);*/
	if (!cStation.IsRailStationSecondarySignalBuilt(road.target.stationID))
		{
		DInfo("Building signals on secondary track",2,"RailStationGrow");
		if (cBuilder.SignalBuilder(srcpos, dstpos))
			{
			DInfo("...done",2,"RailStationGrow");
			cStation.RailStationSetSecondarySignalBuilt(road.target.stationID);
			}
		else	{ DInfo("... not all signals were built",2,"RailStationGrow"); }
		}
	print("SIGNAL stop");
	ClearSignsALL();
	}

DInfo("Phase8: build depot",1,"RailStationGrow");
// build depot for it,
// in order to build cleaner rail we build the depot where the OUT line should goes, reserving space for it
// if this cannot be done, we build it next to the IN line, and we just swap lines (OUT<>IN)
// we may need to build entry & exit depot at the same time, so 2 runs

local tile_OUT=null;
local depot_checker=null;
local removedepot=false;
success=false;
for (local hh=0; hh < 2; hh++)
	{
	local stationside=(hh==0); // first run we work on entry, second one on exit
	if (stationside && !entry_build)	continue;
	if (!stationside && !exit_build)	continue;
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
	local topLeftPlatform=thatstation.locations.GetValue(20);
	local topRightPlatform=thatstation.locations.GetValue(21);
	local topRL=cStation.GetRelativeCrossingPoint(topLeftPlatform, stationside);
	local topRR=cStation.GetRelativeCrossingPoint(topRightPlatform, stationside);
	local depotlocations=[topRL+rightTileOf, topRL+leftTileOf, topRR+rightTileOf, topRR+leftTileOf, topRL+forwardTileOf, topRR+forwardTileOf];
	local depotfront=[topRL, topRL, topRR, topRR, topRL, topRR];
	DInfo("Building station depot",1,"RailStationGrow");
	for (local h=0; h < depotlocations.len(); h++)
		{
		cTileTools.TerraformLevelTiles(crossing,depotlocations[h]);
		PutSign(depotlocations[h],"D");
		if (cTileTools.CanUseTile(depotlocations[h],staID))
			{
			cTileTools.DemolishTile(depotlocations[h]);
			removedepot=AIRail.BuildRailDepot(depotlocations[h], depotfront[h]);
			}
		local depotFront=AIRail.GetRailDepotFrontTile(depotlocations[h]);
		if (AIMap.IsValidTile(depotFront))	success=cBuilder.RailConnectorSolver(depotlocations[h],depotFront,true);
		if (success)	{
					DInfo("We built depot at "+depotlocations[h],1,"RailStationGrow");
					thatstation.RailStationClaimTile(depotlocations[h],stationside);
					if (stationside)	thatstation.depot=depotlocations[h];
							else	thatstation.locations[15]=depotlocations[h];
					success=true;
					break;
					}
		}
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
	INSTANCE.builder.CriticalError=false; // let's get another chance to build exit/entry when fail
	return false;
	}
DInfo("Station "+cStation.StationGetName(thatstation.stationID)+" have "+(trainEntryTaker+trainEntryDropper)+" trains using its entry and "+(trainExitTaker+trainExitDropper)+" using its exit",1,"RailStationGrow");
return true;
}

function cBuilder::PlatformConnectors(platform, useEntry)
// connect a platform (build rail and the signal before crosspoint)
// platform: platform tile to work on
// useEntry: connect the platform entry or exit
// on error -1, if rails are already there, no error is report, only if we cannot manage to connect it
{
local frontTile=cStation.GetPlatformFrontTile(platform, useEntry);
if (frontTile==-1)	{ DError("Invalid front tile",1,"cBuilder::PlatformConnectors"); return -1; }
local stationID=AIStation.GetStationID(platform);
local thatstation=cStation.GetStationObject(stationID);
local forwardTileOf=cStation.GetRelativeTileForward(stationID, useEntry);
local backwardTileOf=cStation.GetRelativeTileBackward(stationID, useEntry);
local crossing=0;
local direction=thatstation.GetRailStationDirection();
if (useEntry)	crossing=thatstation.locations.GetValue(5);
		else	crossing=thatstation.locations.GetValue(6);
if (crossing < 0)	{ DError("Crossing isn't define yet",1,"cBuilder::PlatformConnectors"); return false; }
local goal=0;
local rail=AIRail.RAILTRACK_NE_SW;
local sweeper=AIList();
local error=false;
if (direction==AIRail.RAILTRACK_NE_SW)
		goal=AIMap.GetTileIndex(AIMap.GetTileX(crossing),AIMap.GetTileY(frontTile));
	else	{ goal=AIMap.GetTileIndex(AIMap.GetTileX(frontTile),AIMap.GetTileY(crossing)); rail=AIRail.RAILTRACK_NW_SE; }
INSTANCE.NeedDelay(50);
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
			DInfo("Cannot build rail track at "+pos,1,"DropRailHere");
			return false;
		}
	}
else	return true;
return AIRail.BuildRailTrack(pos,railneed);
}

function cBuilder::RailCleaner(targetTile)
// clean the tile by removing rails/depot/station... we found there
// targetTile : the tile to remove or an AIList of tiles to remove
{
local many=AIList();
if (targetTile instanceof ::AIList)	many.AddList(targetTile);
					else	many.AddItem(targetTile,0);
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
	PutSign(tile,"Z"); AIController.Sleep(40);
	if (AITile.GetOwner(tile) != AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))	continue;
	if (AIRail.IsRailStationTile(tile))	continue; // protect station
	if (AIRail.IsRailDepotTile(tile))
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

function cBuilder::AreRailTilesConnected(tilefrom, tileto)
// Look at tilefront and build rails to connect that tile to its neightbourg tiles that are us with rails
// tilefrom, tileto : tiles to check
// return true if you can walk from tilefrom to tileto
{
local atemp=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
if (AITile.GetOwner(tilefrom) != atemp)	return false; // not own by us
if (AITile.GetOwner(tileto) != atemp)		return false; // not own by us
atemp=AIRail.GetRailType(tilefrom);
if (AIRail.GetRailType(tileto) != atemp)	return false; // not same railtype
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
PutSign(tilefront,"X");
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
	{ DError("We must use two tiles close to each other !",1,"RailConnectorSolver"); return false; }
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
			DInfo("Rail depot found",2,"RailConnectorSolver");
			if (test==tilefront)
				trackinfo= (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
			}
		if (AITunnel.IsTunnelTile(tile))
			{
			test=AITunnel.GetOtherTunnelEnd(tile);
			testdir=cBuilder.GetDirection(tile, test);
			DInfo("Tunnel found",2,"RailConnectorSolver");
			trackinfo = (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
			}
		if (cBridge.IsBridgeTile(tile))
			{
			test=AIBridge.GetOtherBridgeEnd(tile);
			testdir=cBuilder.GetDirection(tile, test);
			DInfo("Bridge found",2,"RailConnectorSolver");
			trackinfo = (testdir == 0 || testdir == 1) ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW;
			}
		}
	if (trackinfo==255)	{ DInfo("No rails found",2,"RailConnectorSolver"); continue; } // no rails here
	test=AITile.GetOwner(tile);
	if (test != AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))	{ DInfo("Not a rail of our company",2,"RailConnectorSolver"); PutSign(tile,"N"); continue; } // we don't own that
	test = AIRail.GetRailType(tile);
	if (test != tileposRT)	{ DInfo("Rails are not of the same type",2,"RailConnectorSolver"); continue; } // not the same rail type
	
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
			if (connection && i==direction)	{ DInfo("Starting rails have entry we can work on",2,"RailConnectorSolver"); startposValid=true; break; }
			if (!startposValid)	continue;
			if (connection)	{ connections.push(tile); } // save status to later connect everyone if need, avoid 90 turn check
			if (!turn_enable && turnbit!=0)	if ((trackmapping & turnbit) == turnbit)	connection=false;
			}
		if (connection && startposValid)
			{
			if (!AIRail.BuildRail(tilepos, tilefront, tile))
				{
				INSTANCE.builder.IsCriticalError();
				if (INSTANCE.builder.CriticalError)	return false;
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
				INSTANCE.builder.IsCriticalError();
				if (INSTANCE.builder.CriticalError)	return false;
				}
			}
	}
return true;
}


function cBuilder::SignalBuilder(source, target)
// Follow all directions to walk through the path starting at source, ending at target
// return true if we build all signals
{
local max_signals_distance=8;
local spacecounter=0;
local signdir=0;
local railpath=AIList();
local directions=[AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(1, 0)];
//local dir=cBuilder.GetDirection(source, buildstart);
local dir=null;
local sourcedir=null;
local targetdir=null;
PutSign(source,"S");
PutSign(target,"T");
local sourcecheck=null;
local targetcheck=null;
foreach (voisin in directions)
	{
	if (AIRail.GetSignalType(source, source+voisin) == AIRail.SIGNALTYPE_PBS)
		{
		sourcedir=cBuilder.GetDirection(source+voisin, source);
		DInfo("Found source signal at "+source+" facing "+sourcedir+" voisin="+(source+voisin),2,"SignalBuilder");
		sourcecheck=source+voisin; // to feed pathfinder with a tile without the signal on it
		PutSign(sourcecheck,"s");
		}
	}
if (sourcedir == null)	{ DError("Cannot find source signal at "+source,2,"SignalBuilder"); return false; }
foreach (voisin in directions)
	{
	if (AIRail.GetSignalType(target, target+voisin) == AIRail.SIGNALTYPE_PBS)
		{
		targetdir=cBuilder.GetDirection(target+voisin, target);
		DInfo("Found target signal at "+target+" facing "+targetdir+" voisin="+(target+voisin),2,"SignalBuilder");
		targetcheck=target+voisin;
		PutSign(targetcheck,"t");
		}
	}
print("SIGNAL STOP");
if (targetdir == null)	{ DError("Cannot find target signal at "+target,2,"SignalBuilder"); return false; }
local pathwalker = RailFollower();
pathwalker.InitializePath([[source, sourcecheck]], [[targetcheck, target]]);// start beforestart    end afterend
local path = pathwalker.FindPath(20000);
if (path == null)	{ DError("Pathwalking failure.",2,"SignalBuilder"); return false; }
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
			tilesource=tile;
			tilefront=prev;
			break;
		case	2: // SW-NE
			tilesource=prev;
			tilefront=tile;
			break;
		case	3: // NE-SW
			tilesource=prev;
			tilefront=tile;
			break;
		}

//	if (!AITile.HasTransportType(tile, AITile.TRANSPORT_RAIL)) print("bad tile");
	if (cc >= max_signals_distance)
		{
		if (AIRail.GetSignalType(tilesource,tilefront) != AIRail.SIGNALTYPE_NONE)	{ cc=0; prev=tile; continue; }
		if (AIRail.BuildSignal(tilesource,tilefront, AIRail.SIGNALTYPE_NORMAL))	{ print("build signal: tilesource="+tilesource+" tilefront="+tilefront); PutSign(tile,"Y"); cc=0; max_signals_distance=8; }
					else { print("error building"+AIError.GetLastErrorString()); max_signals_distance++; allsuccess=false; }
		}
	//PutSign(tile,cc);
AIController.Sleep(4);
	//PutSign(tile,"*");
	cc++;
	prev=tile;
	path = path.GetParent();
	}
return allsuccess;
}

