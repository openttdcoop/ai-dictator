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
	success=root.builder.AutoRailBuilder(oneway[i], oneway[i+1], src, entry, direction, false);
	i++;
	if (!success)	break;
	}
if (!success)
	{ // failure, removing rail by demolish, not removing the station
	for (local j=0; j <= i; j++)
		{
		root.builder.AutoRailBuilder(oneway[j], oneway[j+1], src, entry, direction, true);
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
	if (!AITile.IsBuildable(ti) && AITile.GetOwner(ti)!=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF))	{ AITile.DemolishTile(ti); }
//	PutSign(ti,"!-"+AITile.GetMinHeight(ti)+"/"+AITile.GetMaxHeight(ti));
	if (direction==AIRail.RAILTRACK_NE_SW)
			{ tracktype=AIRail.RAILTRACK_NE_SW; }
		else	{ tracktype=AIRail.RAILTRACK_NW_SE; }
	if (remove)	{ AITile.DemolishTile(ti); }
		else	{ success=AIRail.BuildRailTrack(ti, tracktype); }
	DInfo("Putting a rail",1);
	}
if (objtype==2) // rail
	{
	if (!AITile.IsBuildable(ti))	{ AITile.DemolishTile(ti); }
//	PutSign(ti,"!-"+AITile.GetMinHeight(ti)+"/"+AITile.GetMaxHeight(ti));
	if (direction==AIRail.RAILTRACK_NE_SW)
			{ tracktype=AIRail.RAILTRACK_NW_NE; } // ok
		else	{ tracktype=AIRail.RAILTRACK_NW_NE; } //NE_SE
	if (remove)	{ AITile.DemolishTile(ti); }
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
	if (!AITile.IsBuildable(depottile))	{ AITile.DemolishTile(depottile); }
	if (remove)	{ AITile.DemolishTile(depottile); }
		else	{
			cTileTools.FlattenTile(stationOrigin,depottile);
			success=AIRail.BuildRailTrack(t,f);
			success=success && AIRail.BuildRailTrack(t,s);
			success=success && AIRail.BuildRailDepot(depottile, t);
			root.builder.savedepot=depottile;
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
local road = root.chemin.RListGetItem(root.chemin.nowRoute);
local istown=false;
local srcpoint=null;
local sourceplace=null;
if (start) 	{
		dir = root.builder.GetDirection(road.ROUTE.src_place, road.ROUTE.dst_place);
		if (road.ROUTE.src_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(road.ROUTE.src_id);
			isneartown=true; istown=true;
			}
		else	{
			tilelist = AITileList_IndustryProducing(road.ROUTE.src_id, rad);
			isneartown=true; istown=false;
			}
		otherplace=road.ROUTE.dst_place; sourceplace=road.ROUTE.src_place;
		}
	else	{
		dir = root.builder.GetDirection(road.ROUTE.dst_place, road.ROUTE.src_place);
		if (road.ROUTE.dst_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(road.ROUTE.dst_id);
			isneartown=true; istown=true;
			}
		else	{
			tilelist = AITileList_IndustryAccepting(road.ROUTE.dst_id, rad);
			isneartown=false; istown=false;
			}
		otherplace=road.ROUTE.src_place; sourceplace=road.ROUTE.dst_place;
		}
tilelist.Valuate(AITile.IsBuildable);
tilelist.KeepValue(1);
//showLogic(tilelist); // !
if (isneartown)	{
		tilelist.Valuate(AITile.GetCargoAcceptance, road.ROUTE.cargo_id, 1, 1, rad);
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
local savetown=tilelist;
/*
if (isneartown)
	{
	tilelist.Valuate(AITile.GetCargoAcceptance, road.ROUTE.cargo_id, 1, 1, rad);
	tilelist.KeepAboveValue(2); 
	tilelist.Sort(AIList.SORT_BY_VALUE, false);
	showLogic(tilelist) // !
	}
*/
DInfo("Tilelist set to "+tilelist.Count(),2);
//if (tilelist.IsEmpty())	{ tilelist=savetown; DInfo("Location list is empty !",2); } // restore previous list, we need a place

showLogic(tilelist) // !
ClearSignsALL();
DInfo("isneartown="+isneartown+" istown="+istown,2);
foreach (tile, dummy in tilelist)
	{
	if (start)	dir=root.builder.GetDirection(tile, road.ROUTE.src_place);
		else	dir=root.builder.GetDirection(road.ROUTE.dst_place,tile);
	// find where that point is compare to its source for the station
	// TODO: switch station direction
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
		DInfo("New direction set to "+dir,2);
		}
		
	if (cBuilder.CanBuildRailStation(tile, dir, 5))
		{
		success = true;
		//PutSign(tile,"!"+dir);
		break;
		}
	else	continue;
	}
ClearSignsALL();

if (!success) 
	{
	DInfo("Can't find a good place to build the train station ! "+tilelist.Count(),1);
	return false;
	}
// if we are here all should be fine, we could build now
success=root.builder.CreateAndBuildTrainStation(statop,stationdir);
if (!success)
	{
//	DInfo("Railtype? "+AIRail.IsRailTypeAvailable(AIRail.GetCurrentRailType()),2); 
	DInfo("Station construction was stopped.",1)
	return false;
	}

if (start)
	{
	road.ROUTE.src_station = root.chemin.GListGetSize()-1;
	}
 else	{
	road.ROUTE.dst_station = root.chemin.GListGetSize()-1;
	}
root.chemin.RListUpdateItem(root.chemin.nowRoute,road);
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
root.bank.SaveMoney(); // thinking long time, don't waste money
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
	root.builder.CriticalError=true;
	root.bank.RaiseFundsTo(savemoney);
	return false;
	}
	root.bank.RaiseFundsBigTime();
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
				AITile.DemolishTile(tile);
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




