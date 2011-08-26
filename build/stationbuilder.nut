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


