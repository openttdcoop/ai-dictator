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

function cBuilder::RoadFindCompatibleDepot(tile)
/**
* Try to find an existing road depot near tile and reuse it
*
* @param tile the tile to search the depot
* @return -1 on failure, depot location on success
*/
{
local reusedepot=cTileTools.GetTilesAroundPlace(tile);
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
local road=cRoute.GetRouteObject(roadidx);
if (road == null)	return false;
local work=null;
if (start)	work=road.source;
	else	work=road.target;
DInfo("Upgrading road station "+AIStation.GetName(work.stationID),0);
local depot_id=work.depot;
DInfo("Road depot is at "+depot_id,2);
// first lookout where is the station, where is its entry, where is the depot, where is the depot entry
local sta_pos=AIStation.GetLocation(work.stationID);
local sta_front=AIRoad.GetRoadStationFrontTile(sta_pos);
local dep_pos=depot_id;
local dep_front=AIRoad.GetRoadDepotFrontTile(depot_id);
local depotdead=false;
local statype= AIRoad.ROADVEHTYPE_BUS;
if (work.stationType == AIStation.STATION_TRUCK_STOP)	statype=AIRoad.ROADVEHTYPE_TRUCK;
local deptype=AIRoad.ROADVEHTYPE_BUS+100000; // we add 100000
local new_sta_pos=-1;
local new_dep_pos=-1;
local success=false;
local sta_pos_list=AIList();
local sta_front_list=AIList();
local facing=INSTANCE.builder.GetDirection(sta_pos, sta_front);
local p_left=0;
local p_right=0;
local p_back=0;
switch (facing)
	{
	case DIR_NW:
		p_left = AIMap.GetTileIndex(1,0);
		p_right =AIMap.GetTileIndex(-1,0);
		p_back = AIMap.GetTileIndex(0,-1);
//		p_back = AIMap.GetTileIndex(0,1);
	break;
	case DIR_NE:
		p_left = AIMap.GetTileIndex(0,-1);
		p_right =AIMap.GetTileIndex(0,1);
		p_back = AIMap.GetTileIndex(-1,0);
//		p_back = AIMap.GetTileIndex(1,0); 
	break;
	case DIR_SW:
		p_left = AIMap.GetTileIndex(0,1);
		p_right =AIMap.GetTileIndex(0,-1); 
		p_back = AIMap.GetTileIndex(1,0);
//		p_back = AIMap.GetTileIndex(-1,0);
	break;
	case DIR_SE:
		p_left = AIMap.GetTileIndex(1,0);
		p_right =AIMap.GetTileIndex(-1,0);
		p_back = AIMap.GetTileIndex(0,1);
//		p_back = AIMap.GetTileIndex(0,-1);
	break;
	}
PutSign(sta_pos+p_left,"L");
PutSign(sta_pos+p_right,"R");
PutSign(sta_pos+p_back,"B");
if (work.size == 1)
	{
	if (!AIRoad.IsRoadTile(sta_front+p_left))
		{ cTileTools.DemolishTile(sta_front+p_left); AIRoad.BuildRoad(sta_front, sta_front+p_left); }
	if (!AIRoad.IsRoadTile(sta_front+p_right))
		{ cTileTools.DemolishTile(sta_front+p_right); AIRoad.BuildRoad(sta_front, sta_front+p_right); }
	}
// possible entry + location of station
// these ones = left, right, front (other side of road), frontleft, frontright
/*
sta_front_list.AddItem(sta_front,		sta_front+p_back); // revert middle
sta_front_list.AddItem(sta_front+p_left,		sta_pos+p_left);	// same left
sta_front_list.AddItem(sta_front+p_right,		sta_pos+p_right); // same right
sta_front_list.AddItem(sta_pos+p_left+p_left,		sta_pos+p_left); // same left
sta_front_list.AddItem(sta_pos+p_right+p_right,		sta_pos+p_right); // same right
sta_front_list.AddItem(sta_front+p_left,	sta_front+p_back+p_left);
sta_front_list.AddItem(sta_front+p_back+p_left+p_left,	sta_front+p_back+p_left);
sta_front_list.AddItem(sta_front+p_right,	sta_front+p_back+p_right);
sta_front_list.AddItem(sta_front+p_back+p_right+p_right,	sta_front+p_back+p_right);
*/
sta_front_list.AddItem(sta_pos+p_left,1);
sta_front_list.AddItem(sta_pos+p_right,2);
sta_front_list.AddItem(sta_front+p_back,4);
sta_front_list.AddItem(sta_front+p_back+p_left,5);
sta_front_list.AddItem(sta_front+p_back+p_right,6);
sta_front_list.Sort(AIList.SORT_BY_VALUE,true);

local allfail=true;
/*
foreach (direction, tile in sta_front_list)
	{
	if (AIRoad.IsRoadStationTile(tile))	continue; // don't build on a station
	new_sta_pos=INSTANCE.builder.BuildRoadStationOrDepotAtTile(tile, direction, statype, work.stationID);
	if (!INSTANCE.builder.CriticalError)	allfail=false; // if we have only critical errors we're doom
	INSTANCE.builder.CriticalError=false; // discard it
	if (new_sta_pos != -1)	break;
	AIController.Sleep(1);
	}
*/
foreach (tile, direction in sta_front_list)
	{
	if (AIRoad.IsRoadStationTile(tile)) continue; // don't build on a station
	PutSign(tile,"T");
	new_sta_pos=INSTANCE.builder.BuildAndStickToRoad(tile, statype, work.stationID);
	if (!INSTANCE.builder.CriticalError)	allfail=false; // if we have only critical errors we're doom
	INSTANCE.builder.CriticalError=false; // discard it
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
	new_dep_pos=INSTANCE.builder.BuildRoadDepotAtTile(new_sta_pos);
	work.depot=new_dep_pos;
	INSTANCE.builder.CriticalError=false;
	// Should be more than enough
	}
if (new_sta_pos > -1)
	{
	DInfo("Station "+AIStation.GetName(work.stationID)+" has been upgrade",0);
	local loc=AIStation.GetLocation(work.stationID);
	work.locations=cTileTools.FindStationTiles(loc);
	foreach(loc, dummy in work.locations)	work.locations.SetValue(loc, AIRoad.GetRoadStationFrontTile(loc));
	work.size=work.locations.Count();
	DInfo("New station size: "+work.size+"/"+work.maxsize,2);
	}
else	{ // fail to upgrade station
	DInfo("Failure to upgrade "+AIStation.GetName(work.stationID),1);
	if (allfail)
		{
		work.maxsize=work.size;
		DInfo("Cannot upgrade "+AIStation.GetName(work.stationID)+" anymore !",1);
		}
	success=false;
	}
foreach (uid, dummy in work.owner)	{ INSTANCE.builder.RouteIsDamage(uid); }
// ask ourselves a check for every routes that own that station, because station or depot might have change
return success;
}

function cBuilder::BuildRoadStationOrDepotAtTile(tile, direction, stationtype, stationnew)
/**
* Build a road depot or station, add tile to blacklist on critical failure
* Also build the entry tile with road if need. Try also to find a compatible depot near the wanted position and re-use it
*
* @param tile the tile where to put the structure
* @param direction the tile where the structure will be connected
* @param stationtype if AIRoad.ROADVEHTYPE_BUS+100000 build a depot, else build a station of stationtype type
* @param stationnew invalid station id to build a new station, else joint the station with stationid
* @return tile position on success. -1 on error, set CriticalError
*/
{
// before spending money on a "will fail" structure, check the structure could be connected to a road
if (AITile.IsStationTile(tile))	return -1; // don't destroy a station, might even not be our
INSTANCE.bank.RaiseFundsBigTime(); 
if (!AIRoad.IsRoadTile(direction))
	{
	if (!cTileTools.DemolishTile(direction))
		{
		DWarn("Can't remove the tile front structure to build a road at "+direction,2); PutSign(direction,"X");
		INSTANCE.builder.IsCriticalError();
		return -1;
		}
	}

if (!AIRoad.AreRoadTilesConnected(direction,tile))
	{
	if (!AIRoad.BuildRoad(direction,tile))
		{
		DWarn("Can't build road entrance for the structure",2);
		INSTANCE.builder.IsCriticalError();
		return -1;
		}
	}
INSTANCE.builder.CriticalError=false;
if (!cTileTools.DemolishTile(tile))
	{
	DWarn("Can't remove the structure tile position at "+tile,2); PutSign(tile,"X");
	INSTANCE.builder.IsCriticalError();
	return -1;
	}
local success=false;
local newstation=0;
if (AIStation.IsValidStation(stationnew))	newstation=stationnew;
						else	newstation=AIStation.STATION_NEW;
if (stationtype == (AIRoad.ROADVEHTYPE_BUS+100000))
	{
	INSTANCE.bank.RaiseFundsBigTime();
	// first let's hack another depot if we can
	local hackdepot=INSTANCE.builder.RoadFindCompatibleDepot(tile);
	if (hackdepot == -1)	success=AIRoad.BuildRoadDepot(tile,direction);
			else	{
				tile=hackdepot;
				direction=AIRoad.GetRoadDepotFrontTile(tile);
				success=true;
				}
	PutSign(tile,"D");
	if (!success)
		{
		DWarn("Can't built a road depot at "+tile,2);
		INSTANCE.builder.IsCriticalError();
		}
	else	{
		if (hackdepot == -1)	DInfo("Built a road depot at "+tile,0);
				else	DInfo("Found a road depot near "+tile+", reusing that one",0);
		}
	}
else	{
	INSTANCE.bank.RaiseFundsBigTime(); ClearSignsALL();
	DInfo("Road info: "+tile+" direction"+direction+" type="+stationtype+" mod="+newstation);
	PutSign(tile,"s"); PutSign(direction,"c");
	success=AIRoad.BuildRoadStation(tile, direction, stationtype, newstation);
	if (!success)
		{
		DWarn("Can't built the road station at "+tile,2);
		INSTANCE.builder.IsCriticalError();
		}
	else	DInfo("Built a road station at "+tile,0);
	}
if (!success)
	{
	return -1;
	}
else	{
	if (!AIRoad.AreRoadTilesConnected(tile, direction))
		if (!AIRoad.BuildRoad(tile, direction))
		{
		DWarn("Fail to connect the road structure with the road in front of it",2);
		INSTANCE.builder.IsCriticalError();
		if (!cTileTools.DemolishTile(tile))
			{
			DWarn("Can't remove bad road structure !",2);
			}
		return -1;
		}
	return tile;
	}
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
local obj=INSTANCE.chemin.RListGetItem(idx);
local objStation=obj.ROUTE.dst_station;
local realID=-1;
if (start)	{ objStation=obj.ROUTE.src_station; }
if (objStation == -1) return -1;
local Station=INSTANCE.chemin.GListGetItem(objStation);
realID=Station.STATION.station_id;
if (AIStation.IsValidStation(realID))	return realID;
return -1;
}

function cBuilder::GetDepotID(idx, start)
// this function return the depot id
// no longer reroute to another depot_id if fail to find one, but mark route as damage
{
local road=cRoute.GetRouteObject(idx);
if (road == null) return -1;
local station_obj=null;
local realID=-1;
local depotchecklist=0;
switch (road.route_type)
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
local depotid=road.GetRouteDepot();
if (depotList.HasItem(depotid)) return depotid;
INSTANCE.builder.RouteIsDamage(idx); // if we are here, we fail to find a depotid
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
	//if (valid && INSTANCE.debug)	PutSign(direction,"*");
	//if (INSTANCE.debug) DInfo("Valid="+valid+" curdist="+currdistance+" origindist="+origin+" source="+source+" dir="+direction+" target="+target,2);
	if (!found && valid)	found=INSTANCE.builder.RoadRunner(direction, target, road_type, walkedtiles, origin);
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
// Upgrade the stations if need, pickup entry/exit close to each other
// Create the connections in front of that stations
{
local success=false;
local srcStation=INSTANCE.chemin.GListGetItem(fromObj);
local dstStation=INSTANCE.chemin.GListGetItem(toObj);
DInfo("Connecting rail station "+AIStation.GetName(srcStation.STATION.station_id)+" to "+AIStation.GetName(dstStation.STATION.station_id),1);
local retry=true;
local fst= true;
local sst=true;
local sse=srcStation.STATION.e_count;
local sss=srcStation.STATION.s_count;
local dse=dstStation.STATION.e_count;
local dss=dstStation.STATION.s_count;
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
obj.STATION.direction=direction;
obj.STATION.station_id=AIStation.GetStationID(tilepos);
obj.STATION.railtype=AIRail.GetRailType(tilepos);
obj.STATION.type=1;
INSTANCE.builder.RailStationFindEntrancePoints(obj);
INSTANCE.chemin.GListAddItem(obj);
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
local station_index=INSTANCE.chemin.GListGetStationIndex(stationid);
if (station_index == false)	return false;
local station_obj=INSTANCE.chemin.GListGetItem(station_index);
veh_using_station.Valuate(AITile.GetDistanceManhattanToTile, AIStation.GetLocation(stationid));

}


