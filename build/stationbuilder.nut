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
/**
* Build a road depot for a route, re-use a depot if we can find one near, last re-use the other side depot
*
* @param roadidx the route index to build the depot
* @param start if true build for source, false for destination
* @return -1 on failure, depot location on success, set criticalerror
*/
{
local road=root.chemin.RListGetItem(roadidx);
local source=null;
local stationobj=null;
local other=null;
local otherobj=null;
if (start)	{ source=road.ROUTE.src_station; other=road.ROUTE.dst_station; }
	else	{ source=road.ROUTE.dst_station; other=road.ROUTE.src_station; }
stationobj=root.chemin.GListGetItem(source);
if (stationobj < 0)	return -1; // just return, that route is just too bad
otherobj=root.chemin.GListGetItem(other);
if (otherobj < 0)	return -1;
local stationloc=AIStation.GetLocation(stationobj.STATION.station_id);
local newdepottile=cTileTools.GetTilesAroundPlace(stationloc);
local reusedepot=AIList();
newdepottile=root.builder.FilterBlacklistTiles(newdepottile);
newdepottile.Valuate(AITile.GetDistanceManhattanToTile,stationloc);
newdepottile.Sort(AIList.SORT_BY_VALUE, true);
newdepottile.RemoveAboveValue(10);
reusedepot.AddList(newdepottile);
newdepottile.Valuate(AIRoad.GetNeighbourRoadCount); // now only keep places stick to a road
newdepottile.KeepAboveValue(0);
newdepottile.Valuate(AIRoad.IsRoadTile);
newdepottile.KeepValue(0);
reusedepot.Valuate(AIRoad.IsRoadDepotTile);
reusedepot.KeepValue(1);
reusedepot.Valuate(AITile.GetOwner);
local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
reusedepot.KeepValue(weare);
showLogic(reusedepot);
showLogic(newdepottile);
root.NeedDelay(60);
local newdeploc=-1;
local reuse=false;
if (!reusedepot.IsEmpty())
	{
	newdeploc=reusedepot.Begin();
	reuse=true;
	DInfo("Found a road depot near our station at "+newdeploc+" reusing that one",1);
	}
local allfail=false;
if (newdeploc == -1)
	{
	allfail=true;
	foreach (tile, dummy in newdepottile)
		{
		newdeploc=root.builder.BuildAndStickToRoad(tile, AIRoad.ROADVEHTYPE_BUS+100000);
		if (!root.builder.CriticalError)	allfail=false;
		root.builder.CriticalError=false; // discard error
		if (newdeploc > -1)	break;
		}
	}
if (allfail)
	{ // pfff ! We really can't build/find a depot, let's check other side depot
	local otherdep=otherobj.STATION.e_depot;
	if (!AIRoad.IsRoadDepotTile(otherdep))
		{ root.builder.CriticalError=true; }
	else	{
		allfail=false; reuse=true;
		newdeploc=otherdep;
		local forwho="source";
		if (start) forwho="destination";
		DInfo("All fail, reusing the depot from the "+frowho+" station",1);
		}
	}

local forwho="Destination";
if (start) forwho="Source";
if (newdeploc > -1)
	{
	PutSign(newdeploc,"D");
	local atinfo="Building ";
	if (reuse) atinfo="Reusing ";
	DInfo(atinfo+"road depot at "+newdeploc+" for route #"+roadidx+" - "+forwho+" station "+AIStation.GetName(stationobj.STATION.station_id),0);
	stationobj.STATION.e_depot=newdeploc;
	root.chemin.GListUpdateItem(source,stationobj);
	return newdeploc;
	}
else	{
	local tell="We need a depot but all our solves fail for route #"+roadidx+" - "+forwho+" station "+AIStation.GetName(stationobj.STATION.station_id);
	if (allfail)	{ DError(tell+". That's serious error !",1); root.builder.CriticalError=true; }
		else	DWarn(tell,1);
	return -1;
	}
return -1;
}

function cBuilder::RoadStationNeedUpgrade(roadidx,start)
/**
* Upgrade a road station.
* @param roadidx index of the route to upgrade
* @param start true to upgrade source station, false for destination station
* @return true or false
*/
{
local new_location=[AIMap.GetTileIndex(0,-1), AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(-1,0), AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,-1), AIMap.GetTileIndex(-1,1), AIMap.GetTileIndex(1,-1), AIMap.GetTileIndex(1,1)];
// left, right, behind middle, front middle, behind left, behind right, front left, front right
local new_facing=[AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0), AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0,-1)];
// 0 will be same as original station, north, south, east, west
local road=root.chemin.RListGetItem(roadidx);
if (road != -1)	return false;
local station_obj=null;
local station_index=null;
local other_index=null;
local other_obj=null;
if (start)	{ station_index=road.ROUTE.src_station; other_index=road.ROUTE.dst_station; }
	else	{ station_index=road.ROUTE.dst_station; other_index=road.ROUTE.src_station; }
station_obj=root.chemin.GListGetItem(station_index);
if (station_obj == -1)	{ DInfo("Route "+roadidx+" doesn't have a road station to upgrade.",2); return false; }
DInfo("Road station index "+station_index,2);
other_obj=root.chemin.GListGetItem(other_index);
local station_id=station_obj.STATION.station_id;
DInfo("Upgrading road station "+AIStation.GetName(station_id),0);
local depot_id=station_obj.STATION.e_depot;
// as depot id seems to be = tile index, depot location = depot id so
local facing=station_obj.STATION.direction;
DInfo("Road depot is at "+depot_id,2);
// first lookout where is the station, where is its entry, where is the depot, where is the depot entry
local sta_pos=AIStation.GetLocation(station_id);
local sta_front=AIRoad.GetRoadStationFrontTile(sta_pos);
local dep_pos=depot_id;
local dep_front=AIRoad.GetDepotFrontTile(dep_pos);
local depotdead=false;
local statype=AIRoad.ROADVEHTYPE_BUS;
if (station_obj.STATION.railtype == 11)	{ statype=AIRoad.ROADVEHTYPE_TRUCK; }
local deptype=AIRoad.ROADVEHTYPE_BUS+100000; // we add 100000
local new_sta_pos=-1;
local new_dep_pos=-1;
local success=false;
local sta_pos_list=AIList();
local sta_front_list=AIList();
foreach (voisin in new_location)
	{
	local newpos=1;
	if (sta_pos+voisin == sta_front)	{ newpos=-1; } // station will block other station entry, bad!
	sta_pos_list.AddItem(sta_pos+voisin, newpos);
	}
sta_pos_list=root.builder.FilterBlacklistTiles(sta_pos_list);
sta_pos.RemoveValue(-1);
foreach (tile, dummy in sta_pos_list)
	{ // building the list as (tilefront, tile), not (tile, tilefront) because tile won't be uniq
	foreach (directions in new_facing)
		{
		local newdirection=tile;
		if (tile+directions == sta_pos)	{ newdirection=-1; } // front of new station will be where our station is, bad!
		sta_front_list.AddItem(tile+directions,newdirection);
		}
	}
sta_front_list.RemoveValue(-1);
local allfail=true;
foreach (direction, tile in sta_front_list)
	{
	new_sta_pos=root.builder.BuildRoadStationOrDepotAtTile(tile, direction, statype, false);
	if (!root.builder.CriticalError)	allfail=false; // if we have only critical errors we're doom
	root.builder.CriticalError=false; // discard it
	if (new_sta_pos != -1)	break;
	AIController.Sleep(1);
	}
if (new_sta_pos == dep_pos)	{ depotdead = true; }
if (new_sta_pos == dep_front)
	{
	depotdead=true; // the depot entry is now block by the station
	cTileTools.DemolishTile(dep_pos);
	}
if (depotdead)	
	{
	DWarn("Road depot was destroy while upgrading",1);
	new_dep_pos=root.builder.RoadBuildDepot(roadidx,start);
	if (root.builder.CriticalError)	{ root.builder.CriticalError=false; }
				else	{ root.builder.RouteIsDamage(roadidx); }
	// can't do anything more than that :(
	}
else	{ new_dep_pos=depot_id; }
if (new_sta_pos > -1)
	{
	station_obj=root.chemin.GListGetItem(station_index); // because depot creation might change it
	station_obj.STATION.type=0; // no more upgrade for it
	DInfo("Station "+AIStation.GetName(station_obj.STATION.station_id)+" has been upgrade",0);
	station_obj.STATION.size++;
	station_obj.STATION.e_depot=new_dep_pos;
	}

root.chemin.GListUpdateItem(station_index,station_obj); // save it
root.builder.RouteIsDamage(roadidx); // ask ourselves a check
return success;
}

function cBuilder::BuildRoadStationOrDepotAtTile(tile, direction, stationtype, stationnew)
/**
* Build a road depot or station, add tile to blacklist on critical failure
* Also build the entry tile with road if need
*
* @param tile the tile where to put the structure
* @param direction the tile where the structure will be connected
* @param stationtype if AIRoad.ROADVEHTYPE_BUS+100000 build a depot, else build a station of stationtype type
* @param stationnew true to build a new station, false to joint the station
* @return tile position on success. -1 on error, set CriticalError
*/
{
// before spending money on a "will fail" structure, check the structure could be connected to a road
if (AITile.IsStationTile(tile))	return -1; // don't destroy a station, might even not be our
root.bank.RaiseFundsBy(3000); // should be enought to cover our building/demolishing
if (!AIRoad.IsRoadTile(direction))
	{
	if (!cTileTools.DemolishTile(direction))
		{
		DInfo("Can't remove that tile at "+tile,2); PutSign(tile,"X");
		root.builder.IsCriticalError();
		if (root.builder.CriticalError)	root.builder.BlacklistThatTile(tile);
		return -1;
		}
	if (!AIRoad.BuildRoad(direction,tile))
		{
		DInfo("Can't build road entrance for the station/depot structure",2);
		root.builder.IsCriticalError();
		if (root.builder.CriticalError)	root.builder.BlacklistThatTile(tile);
		return -1;
		}
	}
if (!cTileTools.DemolishTile(tile))
	{
	DInfo("Can't remove that tile at "+tile,2); PutSign(tile,"X");
	root.builder.IsCriticalError();
	if (root.builder.CriticalError)	root.builder.BlacklistThatTile(tile);
	root.builder.CriticalError=false;		
	return -1;
	}
local success=false;
local newstation=AIStation.STATION_JOIN_ADJACENT;
if (stationnew)	newstation=AIStation.STATION_NEW;
if (stationtype == (AIRoad.ROADVEHTYPE_BUS+100000))
	{
	success=AIRoad.BuildRoadDepot(tile,direction);
	PutSign(tile,"D");
	if (!success)
		{
		DInfo("Can't built a road depot at "+tile,2);
		root.builder.IsCriticalError();
		}
	else	{ DInfo("Built a road depot at "+tile,2); }
	}
else	{
	success=AIRoad.BuildRoadStation(tile, direction, stationtype, newstation);
	PutSign(tile,"S");
	if (!success)
		{
		DInfo("Can't built the road station at "+tile,2);
		root.builder.IsCriticalError();
		}
	else	{ DInfo("Built a road station at "+tile,2); }
	}
if (!success)
	{
	if (root.builder.CriticalError)	root.builder.BlacklistThatTile(tile);
	return -1;
	}
else	{
	return tile;
	}
}

function cBuilder::RoadStationExtend(tile, direction, stationtype, station)
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
// no longer reroute to another depot_id if fail to find one, but mark route as damage
{
local road=root.chemin.RListGetItem(idx);
if (road == -1) return -1;
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
root.builder.RouteIsDamage(idx); // if we are here, we fail to find a depotid
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


