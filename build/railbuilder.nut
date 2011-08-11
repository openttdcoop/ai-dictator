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

function cBuilder::TrainStationTesting()
{
local stat=AIStationList(AIStation.STATION_TRAIN);
//stat.Valuate(AIStation.HasStationType,AIStation.STATION_TRAIN);
//stat.KeepValue(1);
if (stat.IsEmpty())	{ DInfo("No train station to test",2); return false; }
foreach(i, dummy in stat)
	{
	DInfo("i="+i+" dummy="+dummy);
	}

local thatstat=stat.Begin();
local temp=null;
local stationfakeID=-1;
local start=true;
DInfo("looking for "+thatstat,2);

for (local i=0; i < INSTANCE.chemin.GListGetSize(); i++) // loop gare
	{
	temp=INSTANCE.chemin.GListGetItem(i);
	if (temp.STATION.station_id == thatstat)	{ stationfakeID=i; break;}
	else DInfo("Fail with "+temp.STATION.station_id+" at "+i,2);
	}
DInfo("StationID ="+stationfakeID,2);
local tempr=null;
local idx=-1;
for (local j=0; j < INSTANCE.chemin.RListGetSize(); j++) // loop routes
	{
	tempr=INSTANCE.chemin.RListGetItem(j);
	if (tempr.ROUTE.src_station == stationfakeID)	{ idx=j; break; start=true;}
	if (tempr.ROUTE.dst_station == stationfakeID)	{ idx=j; break; start=false;}
	}
DInfo("Route that use that station is "+idx,2);
if (idx != -1)
	{
	INSTANCE.builder.TrainStationNeedUpgrade(idx,start);
	}
}

function cBuilder::TrainStationNeedUpgrade(roadidx,start)
// Upgrade an existing train station. The real hard part
// many many failures could occurs, in the best world, we can go upto a 2 in/ou usable 12 ways railway
// we return true on success
{
local road=INSTANCE.chemin.RListGetItem(roadidx);
if (INSTANCE.builder.TryUpgradeTrainStation(roadidx,start))
	{
	DInfo("Train station "+AIStation.GetName(stationobj.STATION.station_id)+" has been upgrade",0);
	}
else	{
	local station=null;
	if (start)	station=road.ROUTE.src_station;
		else	station=road.ROUTE.dst_station;
	local stationobj=INSTANCE.chemin.GListGetItem(station);
	if (INSTANCE.builder.CriticalError)
		{
		INSTANCE.builder.CriticalError=false;
		DInfo("Critical failure to upgrade station "+AIStation.GetName(stationobj.STATION.station_id),1);
		stationobj.STATION.type=0; // no more upgrade possible
		INSTANCE.chemin.GListUpdateItem(station,stationobj);
		}
	else	{ DInfo("Cannot upgrade train station "+AIStation.GetName(stationobj.STATION.station_id)+" for now, will retry later",1); }
	}
ClearSignsALL();
return false;
}

function cBuilder::TryUpgradeTrainStation(roadidx,start)
// called by TrainStationNeedUpgrade, do the upgrade, just return false on error
{
local road=INSTANCE.chemin.RListGetItem(roadidx);
local stationID = INSTANCE.builder.GetStationID(roadidx,start);
local stationInfo = null;
if (start) 	stationInfo=INSTANCE.chemin.GListGetItem(road.ROUTE.src_station);
	else	stationInfo=INSTANCE.chemin.GListGetItem(road.ROUTE.dst_station);
local location=AIStation.GetLocation(stationInfo.STATION.station_id);
local direction=AIRail.GetRailStationDirection(location);
local railtype=AIRail.GetRailType(location);
AIRail.SetCurrentRailType(railtype);
local left=null;
local right=null;
local sleft=null;
local sright=null;
local width=stationInfo.STATION.size;
local sidepos=stationInfo.STATION.size-1;
local tileSet=AITileList();

DInfo("I'm upgrading station "+AIStation.GetName(stationID),0);
DInfo("Station is type :"+stationInfo.STATION.type+" Size:"+width+" Entry"+stationInfo.STATION.haveEntry+" Exit:"+stationInfo.STATION.haveExit,1);

switch (direction)
	{
	case AIRail.RAILTRACK_NE_SW:
// gauche/droite
		right = AIMap.GetTileIndex(0,sidepos+1);
		left= AIMap.GetTileIndex(0,0-(sidepos+1));
		sright = AIMap.GetTileIndex(0,1);
		sleft= AIMap.GetTileIndex(0,-1);
		PutSign(location,"NE_SW");
	break;
	case AIRail.RAILTRACK_NW_SE:
// haut/bas
		right = AIMap.GetTileIndex(0-(sidepos+1),0);
		left= AIMap.GetTileIndex(sidepos+1,0);
		sright = AIMap.GetTileIndex(-1,0);
		sleft= AIMap.GetTileIndex(1,0);
		PutSign(location,"NW_SE");
	break;
	}
local leftSide=false;
local testSide=INSTANCE.builder.ValidateLocation(location, direction, width, 4); // ok
if (!testSide) // left side cannot be upgrade
	{
	testSide==INSTANCE.builder.ValidateLocation(location+right, direction, width, 4); // ok
	if (testSide)	{ leftSide=false; } // right can be upgrade
		else	{ return false; } // tell caller we fail & let it handle that
	}
else	{ leftSide=true; }

// here we know if left side or right side is ok for a station
local basetile=null;
if (leftSide)	{ basetile=sleft; }
	else	{ basetile=rleft; }
//PutSign(location+basetile,"B");

//if (!AIRail.BuildRailStation(basetile
/*testSide=AIRail.BuildRailStation(basetile+location, direction, 1, 5, AIStation.STATION_JOIN_ADJACENT);
if (INSTANCE.builder.IsCriticalError()) return false;*/
INSTANCE.builder.BaseStationRailBuilder(stationInfo,location+basetile);
return true;
}

function cBuilder::BaseStationRailBuilder(basepoint)
{
// 0= flattenTile, 1,pos=track 2,pos=depot 3,pos=/rail 4,pos=\rail
//local oneway=[0,0,-2,1,-1,1,0,1,-1,2];
local direction=AIRail.RAILTRACK_NW_SE;
local otherdir=AIRail.RAILTRACK_NE_SW;
local otherbase=80844;
local entry=true;

local success=true;

PutSign(basepoint,"S");
local fakestation=[0,0, 0,1, -1,1, -2,1, -3,1, -4,1]; // 5 simple rail
// because we're going front to far from front of a station, positive numbers = farer, negative = running on the station

local connectionbase=[1,1 1,8, 2,2]; // that's the one rail in front + rail going right to join another rail at its right
local connectionvoisin=[0,0, -2,3]; // that's one rail connecting to the left neightbourg rail + the - rail to connect them
INSTANCE.bank.RaiseFundsBigTime();

success=INSTANCE.builder.CreateRailStationByPlan(basepoint, entry, direction, fakestation);
success=INSTANCE.builder.CreateRailStationByPlan(otherbase, entry, otherdir, fakestation);
success=INSTANCE.builder.CreateRailStationByPlan(basepoint, entry, direction, connectionbase);
success=INSTANCE.builder.CreateRailStationByPlan(otherbase, entry, otherdir, connectionbase);
}

function cBuilder::CanBuildRailStation(tile, direction, platform_length)
{
if (!AITile.IsBuildable(tile)) return false;
local vector, rvector = null;
switch (direction) 
	{
	case DIR_NW:
		vector = AIMap.GetTileIndex(0,-1);
		rvector = AIMap.GetTileIndex(-1,0);
		stationdir = AIRail.RAILTRACK_NW_SE;
	break;
	case DIR_NE:
		vector = AIMap.GetTileIndex(-1,0);
		rvector = AIMap.GetTileIndex(0,1);
		stationdir = AIRail.RAILTRACK_NE_SW;
	break;
	case DIR_SW:
		vector = AIMap.GetTileIndex(1,0);
		rvector = AIMap.GetTileIndex(0,-1);
		stationdir = AIRail.RAILTRACK_NE_SW;
	break;
	case DIR_SE:
		vector = AIMap.GetTileIndex(0,1);
		rvector = AIMap.GetTileIndex(1,0);
		stationdir = AIRail.RAILTRACK_NW_SE;
	break;
	}
if (direction == DIR_NW || direction == DIR_NE)
	{
	stabottom = tile;
	statop = tile + vector;
	if (platform_length == 3) statop = statop + vector;
	statile = statop;
	}
 else	{
	statop = tile;
	stabottom = tile + vector;
	if (platform_length == 3) stabottom = stabottom + vector;
	statile = stabottom;
	}
depfront = statile + vector;
deptile = depfront + rvector;
stafront = depfront + vector;
frontfront = stafront + vector;
local test = AITestMode(); // just a try to see
if (!AIRail.BuildRailStation(statop, stationdir, 1, platform_length, AIStation.STATION_NEW)) return false;
if (!AIRail.BuildRailDepot(deptile, depfront)) return false;
if (!AITile.IsBuildable(depfront)) return false;
if (!AIRail.BuildRail(statile, depfront, stafront)) return false;
if (!AIRail.BuildRail(statile, depfront, deptile)) return false;
if (!AIRail.BuildRail(deptile, depfront, stafront)) return false;
if (!AITile.IsBuildable(stafront)) return false;
if (!AIRail.BuildRail(depfront, stafront, frontfront)) return false;
if (!AITile.IsBuildable(frontfront)) return false;
if (AITile.IsCoastTile(frontfront)) return false;
if (AIRail.IsRailStationTile(statile - platform_length * vector))
	{
	if (AICompany.IsMine(AITile.GetOwner(statile - platform_length * vector)) && AIRail.GetRailStationDirection(statile - platform_length * vector) == stationdir)
			return false;
	}
test = null;
return true;
}

function cBuilder::CreateRailStationByPlan(src,entry,direction,oneway)
{
local success=true;
local i=0;
for (i=0; i < oneway.len(); i++)
	{
	success=INSTANCE.builder.AutoRailBuilder(oneway[i], oneway[i+1], src, entry, direction, false);
	i++;
	if (!success)	break;
	}
if (!success)
	{ // failure, removing rail by demolish, not removing the station
	for (local j=0; j <= i; j++)
		{
		INSTANCE.builder.AutoRailBuilder(oneway[j], oneway[j+1], src, entry, direction, true);
		j++;
		}
	}
return success;
}


function cBuilder::AutoRailBuilder(place, objtype, entrypos, doentry, direction, remove)
// Put an object relative to entry location
// place = relative position to entrypos
// objtype= the object
// entrypos = the basepoint where entry is
// doentry= true to build at entry, false to build at end
// direction = direction the station should be
// remove= true to remove object (for reversing purpose)
{
local pentry=entrypos;
local pexit=entrypos;
if (direction == AIRail.RAILTRACK_NE_SW)
		{
		pexit=entrypos+AIMap.GetTileIndex(-4,0);
		PutSign(pexit,"NE_SW");
		}
	else	{
		pexit=entrypos+AIMap.GetTileIndex(0,-4);
		PutSign(pexit,"NW_SE");
		}
PutSign(pentry,"E");
local entry=doentry;
local ti = null;
local tdir=null;
local tracktype=null;
local success=true;
local depottile=0;
local tprev=0;
local tnext=0;
local e_nexttile, e_prevtile, s_prevtile, s_nexttile=null;
//local stationOrigin=entrypos-3;
if (direction==AIRail.RAILTRACK_NE_SW) // Entry
	{
	pentry+=AIMap.GetTileIndex(place,0);
	e_prevtile=pentry+AIMap.GetTileIndex(-1,0);
	e_nexttile=pentry+AIMap.GetTileIndex(1,0);
	}
else	{
	pentry+=AIMap.GetTileIndex(0,place);
	e_prevtile=pentry+AIMap.GetTileIndex(0,-1);
	e_nexttile=pentry+AIMap.GetTileIndex(0,1);
	}
if (direction==AIRail.RAILTRACK_NE_SW) // Exit
	{
	pexit+=AIMap.GetTileIndex((0-place),0);
	s_prevtile=pexit+AIMap.GetTileIndex(-1,0);
	s_nexttile=pexit+AIMap.GetTileIndex(1,0);
	}
else	{
	pexit+=AIMap.GetTileIndex(0,(0-place));
	s_prevtile=pexit+AIMap.GetTileIndex(0,-1);
	s_nexttile=pexit+AIMap.GetTileIndex(0,1);
	}

if (entry)	{ ti=pentry; depottile=pentry; tprev = e_prevtile; tnext=e_nexttile;}
	else	{ ti=pexit; depottile=pexit; tprev= s_prevtile; tnext=s_nexttile;}

PutSign(ti,"!");
PutSign(tnext,"N");
PutSign(tprev,"P");
if (objtype==0 && !remove) // flatten
	{
	DInfo("Flatten land",1);
/*	cTileTools.FlattenTile(stationOrigin,ti);
	cTileTools.FlattenTile(stationOrigin,pentry);
	cTileTools.FlattenTile(stationOrigin,pexit);*/
	}
if (objtype==1) // rail
	{
	if (!AITile.IsBuildable(ti) && AITile.GetOwner(ti)!=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))	{ cTileTools.DemolishTile(ti); }
//	PutSign(ti,"!-"+AITile.GetMinHeight(ti)+"/"+AITile.GetMaxHeight(ti));
	if (direction==AIRail.RAILTRACK_NE_SW)
			{ tracktype=AIRail.RAILTRACK_NE_SW; }
		else	{ tracktype=AIRail.RAILTRACK_NW_SE; }
	if (remove)	{ cTileTools.DemolishTile(ti); }
		else	{ success=AIRail.BuildRailTrack(ti, tracktype); }
	DInfo("Putting a rail",1);
	}
if (objtype==2) // rail
	{
	if (!AITile.IsBuildable(ti))	{ cTileTools.DemolishTile(ti); }
//	PutSign(ti,"!-"+AITile.GetMinHeight(ti)+"/"+AITile.GetMaxHeight(ti));
	if (direction==AIRail.RAILTRACK_NE_SW)
			{ tracktype=AIRail.RAILTRACK_NW_NE; } // ok
		else	{ tracktype=AIRail.RAILTRACK_NW_NE; } //NE_SE
	if (remove)	{ cTileTools.DemolishTile(ti); }
		else	{ success=AIRail.BuildRailTrack(ti, tracktype); }
	DInfo("Putting a rail",1);
	}
if (objtype==8) // fire dual
	{
	if (AIRail.IsRailTile(ti))
		{
		if (remove)	{ AIRail.RemoveSignal(ti,tprev); }
			else	{ success=AIRail.BuildSignal(ti,tprev,AIRail.SIGNALTYPE_NORMAL_TWOWAY); }
		}
	DInfo("Putting a twoway signal");
	}

/*
if (objtype==10) // depot
	{
	local f=0;
	local s=0;
	local t=depottile;
	if (obj.STATION.direction==AIRail.RAILTRACK_NE_SW)
			{
			// left/right
			f=AIRail.RAILTRACK_NW_NE;//ok
			s=AIRail.RAILTRACK_NW_SW; //ok
			depottile+=AIMap.GetTileIndex(0,-1);
			} // 1 Y (upper)
		else	{
			f=AIRail.RAILTRACK_NE_SE;// ok
			s=AIRail.RAILTRACK_NW_NE;//ok 
			depottile+=AIMap.GetTileIndex(-1,0);
			} // 1 X (right)
	if (!AITile.IsBuildable(depottile))	{ cTileTools.DemolishTile(depottile); }
	if (remove)	{ cTileTools.DemolishTile(depottile); }
		else	{
			cTileTools.FlattenTile(stationOrigin,depottile);
			success=AIRail.BuildRailTrack(t,f);
			success=success && AIRail.BuildRailTrack(t,s);
			success=success && AIRail.BuildRailDepot(depottile, t);
			INSTANCE.builder.savedepot=depottile;
			}
	}
*/
if (!success)
	{
	DInfo("Can't build that rail: "+AIError.GetLastErrorString(),1);
	return false;
	}
ClearSignsALL();
return true;
}



function cBuilder::BuildTrainStation(start)
// It's where we find a spot for our train station
// Unlike classic stations that need best spot where to get cargo, train stations best spot
// is the one that can do its task while still provide most space to futher allow station upgrading
{
// for industry: to grab goods: best is near where it produce and closest to target
// to drop goods: best is closest target while still accept goods
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
if (start) 	{
		dir = INSTANCE.builder.GetDirection(INSTANCE.route.source_location, INSTANCE.route.target_location);
		if (INSTANCE.route.source_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.route.sourceID);
			isneartown=true; istown=true;
			}
		else	{
			tilelist = AITileList_IndustryProducing(INSTANCE.route.sourceID, rad);
			isneartown=true; istown=false;
			}
		otherplace=INSTANCE.route.target_location; sourceplace=INSTANCE.route.source_location;
		}
	else	{
		dir = INSTANCE.builder.GetDirection(INSTANCE.route.target_location, INSTANCE.route.source_location);
		if (INSTANCE.route.target_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.route.targetID);
			isneartown=true; istown=true;
			}
		else	{
			tilelist = AITileList_IndustryAccepting(INSTANCE.route.targetID, rad);
			isneartown=false; istown=false;
			}
		otherplace=INSTANCE.route.source_location; sourceplace=INSTANCE.route.target_location;
		}
//tilelist.Valuate(AITile.IsBuildable);
//tilelist.KeepValue(1);
//showLogic(tilelist);
isneartown=false; // dirty hack
if (isneartown)	{
		tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.route.cargoID, 1, 1, rad);
		tilelist.KeepAboveValue(8); 
		tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
		tilelist.Sort(AIList.SORT_BY_VALUE, true); // first values = biggest distance from the town
		// try to find a real good place to play with
		}
	else	{
		tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
		tilelist.Sort(AIList.SORT_BY_VALUE, true);
		}

local success = false;
//showLogic(tilelist); // !
DInfo("Tilelist set to "+tilelist.Count(),2,"BuildTrainStation");
showLogic(tilelist); 
ClearSignsALL();
DInfo("isneartown="+isneartown+" istown="+istown,2,"BuildTrainStation");
foreach (tile, dummy in tilelist)
	{
	if (start)	dir=INSTANCE.builder.GetDirection(tile, INSTANCE.route.source_location);
		else	dir=INSTANCE.builder.GetDirection(INSTANCE.route.target_location,tile);
	// find where that point is compare to its source for the station
	PutSign(tile,""+dir+"");
	if (isneartown) // now we hack direction to build a different station direction when we're in a town
		{ // we get a NE_SW station for 2/3 and a NW_SE for 0/1
		switch (dir)
			{
			case DIR_NW: //0 sud
				dir=0;
			break;
			case DIR_SE: //1 nord
				dir=1;
			break;
			case DIR_SW: //3 est/droite
				dir=3;
			break;
			case DIR_NE: //2 west/gauche
				dir=2;
			break;
			}
		DInfo("New direction set to "+dir,2,"BuildTrainStation");
		}
		
	if (INSTANCE.builder.CreateAndBuildTrainStation(tile, dir))
		{
		success=true;
		statile=tile;
		break;
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
		INSTANCE.route.target_stationID=staID;
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
INSTANCE.bank.SaveMoney(); // thinking long time, don't waste money
DInfo("Rail Pathfinding...",1);
local counter = 0;
local path = false;
while (path == false && counter < 150)
	{
	path = pathfinder.FindPath(150);
	counter++; PutSign(AICompany.GetCompanyHQ(AICompany.COMPANY_SELF),counter);
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
// We return result in AIList, item=src tile, value=dst tile
// 
{
// check entry/exit avaiablility on stations
local srcEntry=INSTANCE.builder.IsRailStationEntryOpen(src);
local srcExit=INSTANCE.builder.IsRailStationExitOpen(src);
local dstEntry=INSTANCE.builder.IsRailStationEntryOpen(dst);
local dstExit=INSTANCE.builder.IsRailStationEntryOpen(dst);
local srcEntryLoc=INSTANCE.builder.GetRailStationEntryIn(src);
local srcExitLoc=INSTANCE.builder.GetRailStationExitIn(src);
local dstEntryLoc=INSTANCE.builder.GetRailStationEntryIn(src);
local dstExitLoc=INSTANCE.builder.GetRailStationExitIn(src);


if (!srcEntry && !srcExit) return AIList();
if (!dstEntry && !dstExit) return AIList();
local best=100000000000;
local bestsrc=0;
local bestdst=0;
local check=0;

if (srcEntry)
	{
	if (dstExit)
		{
		check = AIMap.DistanceManhattan(srcEntry_loc,dst.STATION.e_loc); 
			if (check < best)	{ best=check; bestsrc=src.STATION.e_loc; bestdst=dst.STATION.e_loc; }
			}
		DInfo("check="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2);
		if (dst.STATION.haveExit)
			{
			check = AIMap.DistanceManhattan(src.STATION.e_loc,dst.STATION.s_loc); 
			if (check < best)	{ best=check; bestsrc=src.STATION.e_loc; bestdst=dst.STATION.s_loc; }
			}
		DInfo("check="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2);
		}
if (src.STATION.haveExit)
		{
		if (dst.STATION.haveEntry)
			{
			check = AIMap.DistanceManhattan(src.STATION.s_loc,dst.STATION.e_loc); 
			if (check < best)	{ best=check; bestsrc=src.STATION.s_loc; bestdst=dst.STATION.e_loc; }
			}
		DInfo("check="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2);
		if (dst.STATION.haveExit)
			{
			check = AIMap.DistanceManhattan(src.STATION.s_loc,dst.STATION.s_loc); 
			if (check < best)	{ best=check; bestsrc=src.STATION.s_loc; bestdst=dst.STATION.s_loc; }
			}
		DInfo("check="+check+" bestsrc="+bestsrc+" bestdst="+bestdst,2);
		}
// Now we know where to build our roads
src.bestWay=bestsrc;
dst.bestWay=bestdst;
DInfo("Bestway source="+src.bestWay+" destination="+dst.bestWay,2);
return true;
}

function cBuilder::RailStationFindEntrancePoints(obj)
// find where are the entry & exit of a station obj
// we need obj direction & station_id to work !!!
{
local entry=AIStation.GetLocation(obj.STATION.station_id);
local exit=entry;
local exithelper=entry;
local entryhelper=entry;
if (obj.STATION.direction==AIRail.RAILTRACK_NE_SW) // Entry
	{ entry+=AIMap.GetTileIndex(7,0); entryhelper=entry+AIMap.GetTileIndex(1,0); }
else	{ entry+=AIMap.GetTileIndex(0,7); entryhelper=entry+AIMap.GetTileIndex(0,1); }
if (obj.STATION.direction==AIRail.RAILTRACK_NE_SW) // Exit
	{ exit+=AIMap.GetTileIndex(-3,0); exithelper=exit+AIMap.GetTileIndex(-1,0); }
else	{ exit+=AIMap.GetTileIndex(0,-3); exithelper=exit+AIMap.GetTileIndex(0,-1); }
obj.STATION.e_loc=entry;
obj.STATION.s_loc=exit;
obj.STATION.e_link=entryhelper;
obj.STATION.s_link=exithelper;
DInfo("Fast calc entry="+entry+" objentry="+obj.STATION.e_loc+" exit="+exit+" objexit="+obj.STATION.s_loc,2);
}

function cBuilder::StationAPutRail(obj, place, objtype, remove)
// Put a rail relative to src station
// entry to put the rail at entry, false to put it at exit
// place : tile where to put the rail, relative to Entry/Exit point: 3 tile in front/bellow the station
// so place 0 = entry, -1 = 1 tile before entry = 2 tile in front of station
// destory: destroy the rail
{
local pentry=obj.STATION.e_loc;
local pexit=obj.STATION.s_loc;
local entry=(obj.STATION.e_loc==obj.bestWay);
local ti = null;
local tdir=null;
local tracktype=null;
local success=true;
local depottile=0;
local stationOrigin=AIStation.GetLocation(obj.STATION.station_id);
if (obj.STATION.direction==AIRail.RAILTRACK_NE_SW) // Entry
	{ pentry+=AIMap.GetTileIndex(place,0); }
else	{ pentry+=AIMap.GetTileIndex(0,place); }
if (obj.STATION.direction==AIRail.RAILTRACK_NE_SW) // Exit
	{ pexit+=AIMap.GetTileIndex((0-place),0); }
else	{ pexit+=AIMap.GetTileIndex(0,(0-place)); }

if (entry)	{ ti=pentry; depottile=pentry; }
	else	{ ti=pexit; depottile=pexit; }

if (objtype==0 && !remove) // flatten
	{
	DInfo("Flatten land",1);
	cTileTools.FlattenTile(stationOrigin,ti);
	cTileTools.FlattenTile(stationOrigin,pentry);
	cTileTools.FlattenTile(stationOrigin,pexit);
	}
if (objtype==1) // rail
	{
	if (!AITile.IsBuildable(ti))	{ cTileTools.DemolishTile(ti); }
//	PutSign(ti,"!-"+AITile.GetMinHeight(ti)+"/"+AITile.GetMaxHeight(ti));
	if (obj.STATION.direction==AIRail.RAILTRACK_NE_SW)
			{ tracktype=AIRail.RAILTRACK_NE_SW; }
		else	{ tracktype=AIRail.RAILTRACK_NW_SE; }
	if (remove)	{ cTileTools.DemolishTile(ti); }
		else	{ success=AIRail.BuildRailTrack(ti, tracktype); }
	DInfo("Putting a rail",1);
	}
if (objtype==2) // depot
	{
	local f=0;
	local s=0;
	local t=depottile;
	if (obj.STATION.direction==AIRail.RAILTRACK_NE_SW)
			{
			// left/right
			f=AIRail.RAILTRACK_NW_NE;//ok
			s=AIRail.RAILTRACK_NW_SW; //ok
			depottile+=AIMap.GetTileIndex(0,-1);
			} // 1 Y (upper)
		else	{
			f=AIRail.RAILTRACK_NE_SE;// ok
			s=AIRail.RAILTRACK_NW_NE;//ok 
			depottile+=AIMap.GetTileIndex(-1,0);
			} // 1 X (right)
	if (!AITile.IsBuildable(depottile))	{ cTileTools.DemolishTile(depottile); }
	if (remove)	{ cTileTools.DemolishTile(depottile); }
		else	{
			cTileTools.FlattenTile(stationOrigin,depottile);
			success=AIRail.BuildRailTrack(t,f);
			success=success && AIRail.BuildRailTrack(t,s);
			success=success && AIRail.BuildRailDepot(depottile, t);
			INSTANCE.builder.savedepot=depottile;
			}
	}
if (!success)
	{
	DInfo("Can't build that rail: "+AIError.GetLastErrorString(),1);
	return false;
	}
return true;
}

function cBuilder::CreateRailStationSchematic(src,oneway)
{
local success=true;
local i=0;
for (i=0; i < oneway.len(); i++)
	{
	success=INSTANCE.builder.StationAPutRail(src, oneway[i], oneway[i+1], false);
	i++;
	if (!success)	break;
	}
if (!success)
	{ // failure, removing rail by demolish, not removing the station
	for (local j=0; j <= i; j++)
		{
		INSTANCE.builder.StationAPutRail(src, oneway[j], oneway[j+1], true);
		j++;
		}
	}
return success;
}

function cBuilder::GetRailLastCreatedDepot()
// Return the depot ID of last created rail depot
{
local depList=AIDepotList(AITile.TRANSPORT_RAIL);
local depot=-1;
foreach (i, dummy in depList) { depot=i; }
DInfo("depot="+depot);
return depot;
}

function cBuilder::CreateRailForBestWay(src)
// Create the entry point on the src station
{
DInfo("Station "+AIStation.GetName(src.STATION.station_id)+" need a connection",1);
local startPoint=src.bestWay;
local entry = false;
local in_train=0;
local out_train=0;
local station_type=0;
local success=false;
// 0= flattenTile, 1,pos=track 2,pos=depot 3,pos=dualfire, 4,pos=entryfire
local oneway=[0,0,-2,1,-1,1,0,1,-1,2];
// this is where we should upgrade stations
if (src.bestWay == src.STATION.e_loc)	{ entry=true; }
if (entry)	{ in_train=src.STATION.e_count+1; }  // we should have 1 train more at entry
	else	{ out_train=src.STATION.s_count+1; } // or at exit
if (in_train+out_train==1)		{ station_type=1; } // single station
if (in_train==1 && out_train==1)	{ station_type=2; } // dual 1xentry 1xexit
if (in_train>=2 && out_train==0)	{ station_type=3; } // multi 1xentry
if (in_train==0 && out_train>=2)	{ station_type=4; } // multi 1xexit
if (in_train>=2 && out_train>=1)	{ station_type=5; } // multi 1xentry+1xexit
DInfo("STATIONTYPE: "+station_type,2);
switch (station_type)
	{
	case 1:
	INSTANCE.bank.RaiseFundsBigTime();
	success=INSTANCE.builder.CreateRailStationSchematic(src, oneway);
	break;
	}
if (success)
	{
	local a="Station "+AIStation.GetName(src.STATION.station_id)+" connection created at its ";
	if (entry)	
		{
		src.STATION.query=src.STATION.e_loc;
		src.STATION.e_depot=INSTANCE.builder.savedepot;
		a+="entry";
		} // success, really add the train
	else	{
		src.STATION.query=src.STATION.s_loc;
		src.STATION.s_depot=INSTANCE.builder.savedepot;
		//src.STATION.s_count++;
		a+="exit";
		} 
	DInfo(a,1);
	}
return success;
}

function cBuilder::CreateStationsConnection(fromObj, toObj)
// Connect station fromObj to station toObj
// Pickup entry/exit close to each other
// Create the connections in front of these stations
{
local success=false;
local srcStation=cStation.GetStationObject(fromObj);
local dstStation=cStation.GetStationObject(toObj);
DInfo("Connecting rail station "+AIStation.GetName(srcStation.stationID)+" to "+AIStation.GetName(dstStation.stationID),1,"CreateStationsConnection");
local retry=true;
local fst= true;
local sst=true;
/*local sse=srcStation.STATION.e_count;
local sss=srcStation.STATION.s_count;
local dse=dstStation.STATION.e_count;
local dss=dstStation.STATION.s_count;*/
do	{
	retry=INSTANCE.builder.FindStationEntryToExitPoint(srcStation, dstStation);

	fst=INSTANCE.builder.CreateRailForBestWay(srcStation);
	if (!fst)	{ // we weren't able to build the connection, but from other entry it might work
			if (srcStation.bestWay==srcStation.STATION.e_loc)
					{ srcStation.STATION.haveEntry=false; }
				else	{ srcStation.STATION.haveExit=false; } 
			}
		else	{ retry=false; }
	DInfo("Retry="+retry+" fst="+fst+" srcentry="+srcStation.STATION.haveEntry+" srcexit="+srcStation.STATION.haveExit,2);
	} while (retry);
do	{ 
	retry=INSTANCE.builder.FindStationEntryToExitPoint(srcStation, dstStation);
	sst=INSTANCE.builder.CreateRailForBestWay(dstStation);
	if (!sst)	{ // we weren't able to build the connection, but from other entry it might work
			if (dstStation.bestWay==dstStation.STATION.e_loc)
					{ dstStation.STATION.haveEntry=false; }
				else	{ dstStation.STATION.haveExit=false; } 
			}
		else	{ retry=false; }
	DInfo("Retry="+retry+" sst="+sst+" destentry="+dstStation.STATION.haveEntry+" dstexit="+dstStation.STATION.haveExit,2);
	} while (retry);

success=(fst && sst);
if (!fst)	{ srcStation.STATION.type=-1; } // set the station as invalid
if (!sst)	{ dstStation.STATION.type=-1; } // set the station as invalid
if (!success)
	{
	return false; // leave critical status for caller
	}
else	{ // ok save our new stations status
	INSTANCE.chemin.GListUpdateItem(fromObj,srcStation);
	INSTANCE.chemin.GListUpdateItem(toObj,dstStation);
	}
return success;
}

function cBuilder::CreateAndBuildTrainStation(tilepos, direction)
// Create a new station, we still don't know if station will be usable
// that's a task handle by CreateStationConnection
{
local obj=cStation();
if (!AIRail.BuildRailStation(tilepos, direction, 1, 5, AIStation.STATION_NEW))
	{
	DInfo("Rail station couldn't be built: "+AIError.GetLastErrorString(),1);
	return false;
	}
return true;
}

function cBuilder::IsRailStationEntryOpen(stationID=null)
// return true if station entry bit is set
{
if (stationID==null)	stationID=this;
		else		stationID=cStation.GetStationObj(stationID);
local entry=stationID.locations.GetValue(0);
if (entry & 1 == 1)	return true;
return false;
}

function cBuilder::IsRailStationExitOpen(stationID=null)
// return true if station exit bit is set
{
if (stationID==null)	stationID=this;
		else		stationID=cStation.GetStationObj(stationID);
local exit=stationID.locations.GetValue(0);
if (exit & 2 == 2)	return true;
return false;
}


