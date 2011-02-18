// this file handle stations (mostly handling rail stations) as they are specials


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

for (local i=0; i < root.chemin.GListGetSize(); i++) // loop gare
	{
	temp=root.chemin.GListGetItem(i);
	if (temp.STATION.station_id == thatstat)	{ stationfakeID=i; break;}
	else DInfo("Fail with "+temp.STATION.station_id+" at "+i,2);
	}
DInfo("StationID ="+stationfakeID,2);
local tempr=null;
local idx=-1;
for (local j=0; j < root.chemin.RListGetSize(); j++) // loop routes
	{
	tempr=root.chemin.RListGetItem(j);
	if (tempr.ROUTE.src_station == stationfakeID)	{ idx=j; break; start=true;}
	if (tempr.ROUTE.dst_station == stationfakeID)	{ idx=j; break; start=false;}
	}
DInfo("Route that use that station is "+idx,2);
if (idx != -1)
	{
	root.builder.TrainStationNeedUpgrade(idx,start);
	}
}

function cBuilder::TrainStationNeedUpgrade(roadidx,start)
// Upgrade an existing train station. The real hard part
// many many failures could occurs, in the best world, we can go upto a 2 in/ou usable 12 ways railway
// we return true on success
{
local road=root.chemin.RListGetItem(roadidx);
if (root.builder.TryUpgradeTrainStation(roadidx,start))
	{
	DInfo("Train station "+AIStation.GetName(stationobj.STATION.station_id)+" has been upgrade",0);
	}
else	{
	local station=null;
	if (start)	station=road.ROUTE.src_station;
		else	station=road.ROUTE.dst_station;
	local stationobj=root.chemin.GListGetItem(station);
	if (root.builder.CriticalError)
		{
		root.builder.CriticalError=false;
		DInfo("Critical failure to upgrade station "+AIStation.GetName(stationobj.STATION.station_id),1);
		stationobj.STATION.type=0; // no more upgrade possible
		root.chemin.GListUpdateItem(station,stationobj);
		}
	else	{ DInfo("Cannot upgrade train station "+AIStation.GetName(stationobj.STATION.station_id)+" for now, will retry later",1); }
	}
ClearSignsALL();
return false;
}

function cBuilder::TryUpgradeTrainStation(roadidx,start)
// called by TrainStationNeedUpgrade, do the upgrade, just return false on error
{
local road=root.chemin.RListGetItem(roadidx);
local stationID = root.builder.GetStationID(roadidx,start);
local stationInfo = null;
if (start) 	stationInfo=root.chemin.GListGetItem(road.ROUTE.src_station);
	else	stationInfo=root.chemin.GListGetItem(road.ROUTE.dst_station);
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
local testSide=root.builder.ValidateLocation(location, direction, width, 4); // ok
if (!testSide) // left side cannot be upgrade
	{
	testSide==root.builder.ValidateLocation(location+right, direction, width, 4); // ok
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
if (root.builder.IsCriticalError()) return false;*/
root.builder.BaseStationRailBuilder(stationInfo,location+basetile);
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
root.bank.RaiseFundsBigTime();

success=root.builder.CreateRailStationByPlan(basepoint, entry, direction, fakestation);
success=root.builder.CreateRailStationByPlan(otherbase, entry, otherdir, fakestation);
success=root.builder.CreateRailStationByPlan(basepoint, entry, direction, connectionbase);
success=root.builder.CreateRailStationByPlan(otherbase, entry, otherdir, connectionbase);
}

function cBuilder::RoadBuildDepot(roadidx, start)
// (re)-Build a depot for route index
// If it found a road depot near, it will use that one, else create a new one
{
local road=root.chemin.RListGetItem(roadidx);
local where=null;
local source=null;
local stationobj=null;
if (start)	source=road.ROUTE.src_station;
	else	source=road.ROUTE.dst_station;
stationobj=root.chemin.GListGetItem(source);
local stationloc=AIStation.GetLocation(stationobj.STATION.station_id);

local newdepottile=cTileTools.GetTilesAroundPlace(stationloc);
//newdepottile=root.builder.RemoveBlacklistTiles(newdepottile);
newdepottile.Valuate(AIRoad.GetNeighbourRoadCount); // now only keep places stick to a road
newdepottile.KeepAboveValue(0);
newdepottile.Valuate(AIRoad.IsRoadTile);
newdepottile.KeepValue(0);
newdepottile.Valuate(AITile.GetDistanceManhattanToTile,stationloc);
newdepottile.Sort(AIList.SORT_BY_VALUE, true);
newdepottile.RemoveAboveValue(20);
local reusedepot=AIList();
reusedepot.AddList(newdepottile);
reusedepot.Valuate(AIRoad.IsRoadDepotTile);
reusedepot.KeepValue(1);
reusedepot.Valuate(AITile.GetOwner);
local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
reusedepot.KeepValue(weare);
reusedepot.Valuate(AITile.GetDistanceManhattanToTile,stationloc);
reusedepot.Sort(AIList.SORT_BY_VALUE, true);
local newdeploc=-1;
showLogic(reusedepot);
root.NeedDelay(60);
if (!reusedepot.IsEmpty())
	{
	newdeploc=reusedepot.Begin();
	DInfo("Found a depot at "+newdeploc+" reusing that one",1);
	}
if (newdeploc == -1)
	foreach (tile, dummy in newdepottile)
		{
		newdeploc=cBuilder.BuildAndStickToRoad(tile, AIRoad.ROADVEHTYPE_BUS+100000);
		if (newdeploc > -1)	break;
		}
if (newdeploc > -1)
	{
	local atinfo=" at destination.";
	if (start)	atinfo=" at source.";
	DInfo("Building a depot for route #"+roadidx+" - Station "+AIStation.GetName(stationobj.STATION.station_id)+atinfo,0);
	stationobj.STATION.e_depot=newdeploc;
	root.chemin.GListUpdateItem(source,stationobj);
	return true;
	}
else	{ DInfo("We need a depot but we fail to find/create one !",1); root.builder.RouteIsDamage(idx); }
return false;
}

function cBuilder::RoadStationNeedUpgrade(roadidx,start)
// Upgrade an existing road station.
{
local road=root.chemin.RListGetItem(roadidx);
local station_obj=null;
local station_index=null;
if (start)	{ station_index=road.ROUTE.src_station; }
	else	{ station_index=road.ROUTE.dst_station; }
DInfo("station index "+station_index,2);
station_obj=root.chemin.GListGetItem(station_index);
local station_id=root.builder.GetStationID(roadidx,start);
local destination_loc=AIStation.GetLocation(root.builder.GetStationID(roadidx,!start));
DInfo("Upgrading road station "+AIStation.GetName(station_id),0);
local depot_id=root.builder.GetDepotID(roadidx,start);
// as depot id seems to be = tile index, depot location = depot id so
local facing=station_obj.STATION.direction;
local left = null;
local right = null;
local front= null;
DInfo("Station is facing : "+facing+" Depot is at "+depot_id,2);
switch (facing)
	{
// stationtile = statile
// statile = tile; deptile = tile + offdep;
// stafront = tile + offsta; depfront = tile + offsta + offdep;
	case DIR_NE:
// a gauche
		left = AIMap.GetTileIndex(0,-1);
		right= AIMap.GetTileIndex(0,1);
		front= AIMap.GetTileIndex(-1,0);
	break;
	case DIR_NW:
// haut
		left = AIMap.GetTileIndex(-1,0);
		right= AIMap.GetTileIndex(1,0);
		front= AIMap.GetTileIndex(0,-1);
	break;
	case DIR_SE:
// bas
		left = AIMap.GetTileIndex(1,0);
		right= AIMap.GetTileIndex(-1,0);
		front= AIMap.GetTileIndex(0,1);
	break;
	case DIR_SW:
// droite
		left = AIMap.GetTileIndex(0,1);
		right= AIMap.GetTileIndex(0,-1);
		front= AIMap.GetTileIndex(1,0);
	break;
	}
local sloc=AIStation.GetLocation(station_id);
local slloc=sloc+left; // left
local srloc=sloc+right; // right
local omloc=sloc+front+front; // otherside
local olloc=sloc+front+front+left; // otherside left
local orloc=sloc+front+front+right; // otherside right

PutSign(sloc,"S");
PutSign(slloc,"L");
PutSign(srloc,"R");
PutSign(sloc+front,"|");
PutSign(omloc,"O");
local depotdead=-1;
local statype=AIRoad.ROADVEHTYPE_BUS;
if (station_obj.STATION.railtype == 11)	{ statype=AIRoad.ROADVEHTYPE_TRUCK; }
local deptype=AIRoad.ROADVEHTYPE_BUS+100000; // we add 100000
local newstaloc=-1;
local newdeploc=-1;
local success=false;
success=root.builder.RoadStationExtend(slloc,slloc+front,statype); // try left
if (success)	{ newstaloc = slloc; }
	else	{
		success=root.builder.RoadStationExtend(srloc,srloc+front,statype); // right
		if (success)	{ newstaloc = srloc; }
		}
local test=false;
if (!AIRoad.IsRoadDepotTile(depot_id))	depotdead=newstaloc; // check if we have kill our depot while upgrading
if (depotdead > -1)
	{ // depot was destroy, look out possible places to rebuild one, this is safe if stations are there
	DInfo("Depot has been destroy while upgrading.",1);
	//root.builder.RoadBuildDepot(roadidx,start);
	}
if (success)
	{
	station_obj=root.chemin.GListGetItem(station_index); // because depot creation might alter it
	station_obj.STATION.type=0; // hmmm, not sure it's a good idea, but let it try to upgrade it until success
	DInfo("Station "+AIStation.GetName(station_obj.STATION.station_id)+" has been upgrade",0);
	station_obj.STATION.size++;
	station_obj.STATION.e_depot=depot_id;
	local df=AIRoad.GetRoadDepotFrontTile(newdeploc);
	local sf=AIRoad.GetRoadStationFrontTile(newstaloc);
	PutSign(df,"DepotFront"); PutSign(sf,"New station front");
	root.builder.BuildRoadROAD(AIRoad.GetRoadDepotFrontTile(newdeploc), AIRoad.GetRoadStationFrontTile(newstaloc));
	root.builder.BuildRoadROAD(AIRoad.GetRoadDepotFrontTile(newdeploc), AIRoad.GetRoadStationFrontTile(destination_loc));
	}

root.chemin.GListUpdateItem(station_index,station_obj); // save it
root.builder.RouteIsDamage(roadidx); // ask ourselves a check
return success;
}

function cBuilder::RoadStationExtend(tile, direction, stationtype)
{
if (AITile.IsStationTile(tile)) return false; // protect station
if (!cTileTools.DemolishTile(tile)) return false;
if (!AIRoad.IsRoadTile(direction))
		{ cTileTools.DemolishTile(direction); AIRoad.BuildRoad(direction,tile); }
if (!AIRoad.IsRoadTile(direction))	return false; // no need to build that station, it won't have a road in its front
if (!AIRoad.BuildRoadStation(tile, direction, stationtype, AIStation.STATION_JOIN_ADJACENT))
		{
		DError("Cannot create the station !",1);
		// TODO: need to rethink many (all) building/demolish trys functions, having a depot with a road vehicle in it (but not stop at depot) prevent demolishing the tile, this is not crical, but this fool us
		return false;
		}
	else	{ AIRoad.BuildRoad(direction,tile); return true; }
return false;
}

function cBuilder::GetStationType(stationid)
// Check if the stationid have a type and return it
// return the stationtype we found
{
if (!AIStation.IsValidStation(stationid))	return -1;
local stationtype=-1;
stationtype=AIStation.STATION_AIRPORT;
if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
stationtype=AIStation.STATION_TRAIN;
if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
stationtype=AIStation.STATION_DOCK;
if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
stationtype=AIStation.STATION_TRUCK_STOP;
if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
stationtype=AIStation.STATION_BUS_STOP;
if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
return -1;
}

function cBuilder::GetStationID(idx, start)
// this function return the real station id
{
local obj=root.chemin.RListGetItem(idx);
local objStation=obj.ROUTE.dst_station;
local realID=-1;
if (start)	{ objStation=obj.ROUTE.src_station; }
if (objStation == -1) return -1;
local Station=root.chemin.GListGetItem(objStation);
realID=Station.STATION.station_id;
if (AIStation.IsValidStation(realID))	return realID;
return -1;
}

function cBuilder::GetDepotID(idx, start)
// this function return the depot id
// no longer reroute to another depot_id if fail to find one
{
local road=root.chemin.RListGetItem(idx);
local station_obj=null;
if (start)	station_obj=root.chemin.GListGetItem(road.ROUTE.src_station);
	else	station_obj=root.chemin.GListGetItem(road.ROUTE.dst_station);
if (station_obj==-1)	return -1; // no station = no depot to find
local realID=-1;
local depotchecklist=0;
switch (road.ROUTE.kind)
	{
	case	1000: // air network is also air type, in case, because i don't think i will use that function for that case
	case	AIVehicle.VT_AIR:
		depotchecklist=AITile.TRANSPORT_AIR;
	break;
	case	AIVehicle.VT_RAIL:
		depotchecklist=AITile.TRANSPORT_RAIL;
	break;
	case	AIVehicle.VT_ROAD:
		depotchecklist=AITile.TRANSPORT_ROAD;
	break;
	case	AIVehicle.VT_WATER:
		depotchecklist=AITile.TRANSPORT_WATER;
	break;
	}
local depotList=AIDepotList(depotchecklist);
local depotid=null;
local entry_check=null;
if (start)	entry_check=road.ROUTE.src_entry;
	else	entry_check=road.ROUTE.dst_entry;
if (entry_check)	depotid=station_obj.STATION.e_depot;
		else	depotid=station_obj.STATION.s_depot;
if (depotList.HasItem(depotid)) return depotid;
return -1;
}

function cBuilder::FindStationEntryToExitPoint(src, dst)
// find the closest path from station src to station dst
// we return result values src.BestWay & dst.BestWay 
// 
{
// check entry/exit avaiablility on stations
if ((!src.STATION.haveEntry) && (!src.STATION.haveExit)) return false;
if ((!dst.STATION.haveEntry) && (!dst.STATION.haveExit)) return false;
local best=100000000000;
local bestsrc=0;
local bestdst=0;
local check=0;
DInfo(" esrc:"+src.STATION.e_loc+" edst:"+dst.STATION.e_loc,2);
DInfo(" ssrc:"+src.STATION.s_loc+" sdst:"+dst.STATION.s_loc,2);

if (src.STATION.haveEntry)  	// source entree: 85800, sortie: 80680
		{		// target entree: 11066, sortie: 5946
				// manual = sortie source + entree target -> 80680+11066
		if (dst.STATION.haveEntry)
			{
			check = AIMap.DistanceManhattan(src.STATION.e_loc,dst.STATION.e_loc); 
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

function cBuilder::RoadRunner(source, target, road_type, walkedtiles=null, origin=null)
// Follow all directions to walk through the path starting at source, ending at target
// check if the path is valid by using road_type (railtype, road)
// return true if we reach target
{
local max_wrong_direction=15;
if (origin == null)	origin=AITile.GetDistanceManhattanToTile(source, target);
if (walkedtiles == null)	{ walkedtiles=AIList(); }
local valid=false;
local direction=null;
local found=(source == target);
local directions=[AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)];
foreach (voisin in directions)
	{
	direction=source+voisin;
	if (road_type == AIVehicle.VT_ROAD)
		{
		if (AIBridge.IsBridgeTile(source) || AITunnel.IsTunnelTile(source))
			{
			local endat=null;
			endat=AIBridge.IsBridgeTile(source) ? AIBridge.GetOtherBridgeEnd(source) : AITunnel.GetOtherTunnelEnd(source);

			// i will jump at bridge/tunnel exit, check tiles around it to see if we are connect to someone (guessTile)
			// if we are connect to someone, i reset "source" to be "someone" and continue
			local guessTile=null;	
			foreach (where in directions)
				{
				if (AIRoad.AreRoadTilesConnected(endat, endat+where))
					{ guessTile=endat+where; }
				}
			if (guessTile != null)
				{
				source=guessTile;
				direction=source+voisin;
				}
			}
		valid=AIRoad.AreRoadTilesConnected(source, direction);
		}
	else	{ valid=AIRail.AreTilesConnected(source, direction, direction); }
	local currdistance=AITile.GetDistanceManhattanToTile(direction, target);
	if (currdistance > origin+max_wrong_direction)	{ valid=false; }
	if (walkedtiles.HasItem(direction))	{ valid=false; } 
	if (valid)	walkedtiles.AddItem(direction,0);
	if (valid && root.debug)	PutSign(direction,"*");
	//if (root.debug) DInfo("Valid="+valid+" curdist="+currdistance+" origindist="+origin+" source="+source+" dir="+direction+" target="+target,2);
	if (!found && valid)	found=root.builder.RoadRunner(direction, target, road_type, walkedtiles, origin);
	if (found) return found;
	}
return found;
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
			root.builder.savedepot=depottile;
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
	success=root.builder.StationAPutRail(src, oneway[i], oneway[i+1], false);
	i++;
	if (!success)	break;
	}
if (!success)
	{ // failure, removing rail by demolish, not removing the station
	for (local j=0; j <= i; j++)
		{
		root.builder.StationAPutRail(src, oneway[j], oneway[j+1], true);
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
	root.bank.RaiseFundsBigTime();
	success=root.builder.CreateRailStationSchematic(src, oneway);
	break;
	}
if (success)
	{
	local a="Station "+AIStation.GetName(src.STATION.station_id)+" connection created at its ";
	if (entry)	
		{
		src.STATION.query=src.STATION.e_loc;
		src.STATION.e_depot=root.builder.savedepot;
		a+="entry";
		} // success, really add the train
	else	{
		src.STATION.query=src.STATION.s_loc;
		src.STATION.s_depot=root.builder.savedepot;
		//src.STATION.s_count++;
		a+="exit";
		} 
	DInfo(a,1);
	}
return success;
}

function cBuilder::CreateStationsConnection(fromObj, toObj)
// Connect station fromObj to station toObj
// Upgrade the stations if need, pickup entry/exit close to each other
// Create the connections in front of that stations
{
local success=false;
local srcStation=root.chemin.GListGetItem(fromObj);
local dstStation=root.chemin.GListGetItem(toObj);
DInfo("Connecting rail station "+AIStation.GetName(srcStation.STATION.station_id)+" to "+AIStation.GetName(dstStation.STATION.station_id),1);
local retry=true;
local fst= true;
local sst=true;
local sse=srcStation.STATION.e_count;
local sss=srcStation.STATION.s_count;
local dse=dstStation.STATION.e_count;
local dss=dstStation.STATION.s_count;
do	{
	retry=root.builder.FindStationEntryToExitPoint(srcStation, dstStation);

	fst=root.builder.CreateRailForBestWay(srcStation);
	if (!fst)	{ // we weren't able to build the connection, but from other entry it might work
			if (srcStation.bestWay==srcStation.STATION.e_loc)
					{ srcStation.STATION.haveEntry=false; }
				else	{ srcStation.STATION.haveExit=false; } 
			}
		else	{ retry=false; }
	DInfo("Retry="+retry+" fst="+fst+" srcentry="+srcStation.STATION.haveEntry+" srcexit="+srcStation.STATION.haveExit,2);
	} while (retry);
do	{ 
	retry=root.builder.FindStationEntryToExitPoint(srcStation, dstStation);
	sst=root.builder.CreateRailForBestWay(dstStation);
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
	root.chemin.GListUpdateItem(fromObj,srcStation);
	root.chemin.GListUpdateItem(toObj,dstStation);
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
obj.STATION.direction=direction;
obj.STATION.station_id=AIStation.GetStationID(tilepos);
obj.STATION.railtype=AIRail.GetRailType(tilepos);
obj.STATION.type=1;
root.builder.RailStationFindEntrancePoints(obj);
root.chemin.GListAddItem(obj);
return true;
}

function cBuilder::IsRoadStationBusy(stationid)
// Check if a road station is busy and return the vehicle list that busy it
// Station must be AIStation.StationType==STATION_TRUCK_STOP
// We will valuate it with cargo type each vehicle use before return it
// Return false if not
{
if (!AIStation.HasStationType(stationid,AIStation.STATION_TRUCK_STOP))	return false;
local veh_using_station=AIVehicleList_Station(stationid);
if (veh_using_station.IsEmpty())	return false;
local station_tiles=cTileTools.FindRoadStationTiles(AIStation.GetLocation(stationid));
local station_index=root.chemin.GListGetStationIndex(stationid);
if (station_index == false)	return false;
local station_obj=root.chemin.GListGetItem(station_index);
veh_using_station.Valuate(AITile.GetDistanceManhattanToTile, AIStation.GetLocation(stationid));

}


