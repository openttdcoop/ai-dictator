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

// generic vehicle building functions

class cCarrier
{
static	AirportTypeLimit=[6, 10, 2, 16, 30, 5, 6, 60, 8]; // limit per airport type
static	IDX_HELPER = 512;			// use to create an uniq ID (also use to set handicap value)
static	AIR_NET_CONNECTOR=2500;		// town is add to air network when it reach that value population
//static	TopEngineList=AIList();		// the list of engine ID we know if it can be upgrade or not
static	ToDepotList=AIList();		// list vehicle going to depot, value=DepotAction for trains we also add wagons need
static	vehicle_database={};		// database for vehicles
static	VirtualAirRoute=[];		// the air network destinations list
static 	OldVehicle=1095;			// age left we consider a vehicle is old
static	MaintenancePool=[];		// list of vehicles that need maintenance
static	function GetVehicleObject(vehicleID)
		{
		return vehicleID in cCarrier.vehicle_database ? cCarrier.vehicle_database[vehicleID] : null;
		}

	rail_max		=null;	// maximum trains vehicle a station can handle
	road_max		=null;	// maximum a road station can upgarde (max: 6)
	road_upgrade	=null;	// maximum vehicle a road station can support before upgarde itself
	air_max		=null;	// maximum aircraft a station can handle
	airnet_max		=null;	// maximum aircraft on a network
	airnet_count	=null;	// current number of aircrafts running the network
	water_max		=null;	// maximum ships a station can handle
	road_max_onroute	=null;	// maximum road vehicle on a route
	train_length	=null;	// maximum length for train/rail station
	vehnextprice	=null;	// we just use that to upgrade vehicle
	do_profit		=null;	// Record each vehicle profits
	warTreasure		=null;	// total current value of nearly all our road vehicle
	highcostAircraft	=null;	// the highest cost for an aircraft we need
	speed_MaxTrain	=null;	// maximum speed a train could do
	speed_MaxRoad	=null;	// maximum speed a road vehicle could do

	constructor()
		{
		rail_max		=0;
		road_max		=0;
		road_upgrade	=0;
		air_max		=0;
		airnet_max		=0;
		airnet_count	=0;
		water_max		=0;
		road_max_onroute	=0;
		train_length	=0;
		vehnextprice	=0;
		do_profit		=AIList();
		warTreasure		=0;
		highcostAircraft	=0;
		speed_MaxTrain	=0;
		speed_MaxRoad	=0;
		}
}


function cCarrier::VehicleGetCargoType(veh)
// return cargo type the vehicle is handling
{
local cargotype=AICargoList();
foreach (cargo, dummy in cargotype)
	{
	if (AIVehicle.GetCapacity(veh, cargo) > 0)	return cargo;
	}
}

function cCarrier::VehicleGetProfit(veh)
// add a vehicle to do_profit list, calc its profit and also return it
{
local profit=AIVehicle.GetProfitThisYear(veh);
local oldprofit=0;
if (INSTANCE.carrier.do_profit.HasItem(veh))	oldprofit=INSTANCE.carrier.do_profit.GetValue(veh);
							else	INSTANCE.carrier.do_profit.AddItem(veh,0);
if (profit > oldprofit)	oldprofit=profit - oldprofit;
			else	oldprofit=oldprofit+profit;
INSTANCE.carrier.do_profit.SetValue(veh, oldprofit);
return oldprofit;
}

function cCarrier::CanAddNewVehicle(roadidx, start, max_allow)
// check if we can add another vehicle at the start/end station of that route
{
local chem=cRoute.GetRouteObject(roadidx);
if (chem == null) return 0;
chem.RouteUpdateVehicle();
local thatstation=null;
local thatentry=null;
local otherstation=null;
if (start)	{ thatstation=chem.source; otherstation=chem.target; }
	else	{ thatstation=chem.target; otherstation=chem.source; }
local divisor=0;
local sellvalid=( (AIDate.GetCurrentDate() - chem.date_VehicleDelete) > 60);
// prevent buy a new vehicle if we sell one less than 60 days before (this isn't affect by replacing/upgrading vehicle)
if (!sellvalid)	{ max_allow=0; DInfo("Route sold a vehicle not a long time ago",1); }
local virtualized=cStation.IsStationVirtual(thatstation.stationID);
local othervirtual=cStation.IsStationVirtual(otherstation.stationID);
local airportmode="(classic)";
local shared=false;
if (thatstation.owner.Count() > 1)	{ shared=true; airportmode="(shared)"; }
if (virtualized)	airportmode="(network)";
local airname=AIStation.GetName(thatstation.stationID)+"-> ";
switch (chem.route_type)
	{
	case AIVehicle.VT_ROAD:
		DInfo("Road station "+AIStation.GetName(thatstation.stationID)+" limit "+thatstation.vehicle_count+"/"+thatstation.vehicle_max,1);
		if (thatstation.CanUpgradeStation())
			{ // can still upgrade
			if (chem.vehicle_count+max_allow > INSTANCE.carrier.road_max_onroute)	max_allow=(INSTANCE.carrier.road_max_onroute-chem.vehicle_count);
			// limit by number of vehicle per route
			if (!INSTANCE.use_road)	max_allow=0;
			// limit by vehicle disable (this can happen if we reach max vehicle game settings too
//			if (thatstation.vehicle_count+1 > thatstation.size)
			if ( (thatstation.vehicle_count+max_allow) > thatstation.vehicle_max)
				{ // we must upgrade
				INSTANCE.builder.RoadStationNeedUpgrade(roadidx, start);
				local fake=thatstation.CanUpgradeStation(); // to see if upgrade success
				}
			if (thatstation.vehicle_count+max_allow > thatstation.vehicle_max)	max_allow=thatstation.vehicle_max-thatstation.vehicle_count;
			// limit by the max the station could handle
			}
		else	{ // max size already
			if (thatstation.vehicle_count+max_allow > thatstation.vehicle_max)	max_allow=INSTANCE.carrier.road_max_onroute-thatstation.vehicle_count;
			// limit by the max the station could handle
			if (chem.vehicle_count+max_allow > INSTANCE.carrier.road_max_onroute)	max_allow=INSTANCE.carrier.road_max_onroute-chem.vehicle_count;
			// limit by number of vehicle per route
			if (!INSTANCE.use_road)	return max_allow=0;
			// limit by vehicle disable (this can happen if we reach max vehicle game settings too
			}
	break;
	case AIVehicle.VT_RAIL:
		if (thatstation.CanUpgradeStation())
			{
			if (!INSTANCE.use_train)	max_allow=0;
			if (thatstation.vehicle_count+max_allow > thatstation.vehicle_max)	max_allow=thatstation.vehicle_max-thatstation.vehicle_count;
			// don't try upgrade if we cannot add a new train
			if (!INSTANCE.builder.TrainStationNeedUpgrade(roadidx, start))	max_allow=0; // if we fail to upgrade...
			}
		else	{
			if (!INSTANCE.use_train) max_allow=0;
			if (thatstation.vehicle_count+max_allow > thatstation.vehicle_max)	max_allow=thatstation.vehicle_max-thatstation.vehicle_count;
			}
	break;
	case AIVehicle.VT_WATER:
		if (!INSTANCE.use_boat)	max_allow=0;
		if (thatstation.vehicle_count+max_allow > thatstation.vehicle_max)	max_allow=thatstation.vehicle_max-thatstation.vehicle_count;
	break;
	case RouteType.AIRNET:
		thatstation.CheckAirportLimits(); // force recheck limits
		if (thatstation.CanUpgradeStation())
			{
			if (INSTANCE.builder.AirportNeedUpgrade(thatstation.stationID))	max_allow=0;
			// get out after an upgrade, station could have change place...
			}
		DInfo(airname+"Limit for that route (network): "+chem.vehicle_count+"/"+INSTANCE.carrier.airnet_max*cCarrier.VirtualAirRoute.len(),1);
		DInfo(airname+"Limit for that airport (network): "+chem.vehicle_count+"/"+thatstation.vehicle_max,1);
		if (chem.vehicle_count+max_allow > INSTANCE.carrier.airnet_max*cCarrier.VirtualAirRoute.len()) max_allow=(INSTANCE.carrier.airnet_max*cCarrier.VirtualAirRoute.len()) - chem.vehicle_count;
		if (chem.vehicle_count+max_allow > thatstation.vehicle_max)	max_allow=thatstation.vehicle_max-chem.vehicle_count;
	break;
	case RouteType.CHOPPER:
		DInfo(airname+"Limit for that route (choppers): "+chem.vehicle_count+"/4",1);
		DInfo(airname+"Limit for that airport "+airportmode+": "+thatstation.vehicle_max,1);
		if (chem.vehicle_count+max_allow > 4)	max_allow=4-chem.vehicle_count;
	break;
	case AIVehicle.VT_AIR: // Airport upgrade is not related to number of aircrafts using them
		thatstation.CheckAirportLimits(); // force recheck limits
		if (thatstation.CanUpgradeStation())
			{
			if (INSTANCE.builder.AirportNeedUpgrade(thatstation.stationID)) max_allow=0;
			}
		local limitmax=INSTANCE.carrier.air_max;
		if (shared)
			{
			if (thatstation.owner.Count()>0)	limitmax=limitmax / thatstation.owner.Count();
			if (limitmax < 1)	limitmax=1;
			}
		if (virtualized)	limitmax=2; // only 2 aircrafts when the airport is also in network
		local dualnetwork=false;
		local routemod="(classic)";
		if (virtualized && othervirtual)	
			{
			limitmax=0;	// no aircrafts at all on that route if both airport are in the network
			dualnetwork=true;
			routemod="(dual network)";
			}
		DInfo(airname+"Limit for that route "+routemod+": "+chem.vehicle_count+"/"+limitmax,1);
		DInfo(airname+"Limit for that airport "+airportmode+": "+thatstation.vehicle_count+"/"+thatstation.vehicle_max,1);
		if (!INSTANCE.use_air)	max_allow=0;
		if (chem.vehicle_count+max_allow > limitmax)	max_allow=limitmax - chem.vehicle_count;
		// limit by route limit
		if (thatstation.vehicle_count+max_allow > thatstation.vehicle_max)	max_allow=thatstation.vehicle_max-thatstation.vehicle_count;
		// limit by airport capacity
	break;
	}
if (max_allow < 0)	max_allow=0;
return max_allow;
}

function cCarrier::BuildAndStartVehicle(routeid)
// Create a new vehicle on route
{
local road=cRoute.GetRouteObject(routeid);
if (road == null)	return false;
local res=false;
switch (road.route_type)
	{
	case AIVehicle.VT_ROAD:
		res=INSTANCE.carrier.CreateRoadVehicle(routeid);
	break;
	case AIVehicle.VT_RAIL:
		res=INSTANCE.carrier.CreateRailVehicle(routeid);
	break;
	case AIVehicle.VT_WATER:
	break;
	case RouteType.AIRNET:
	case RouteType.CHOPPER:
	case AIVehicle.VT_AIR:
		res=INSTANCE.carrier.CreateAirVehicle(routeid);
	break;
	}
if (res)	road.RouteUpdateVehicle();
return res;
}

function cCarrier::GetVehicle(routeidx)
// return the vehicle we will pickup if we build a vehicle for that route
{
local road=cRoute.GetRouteObject(routeidx);
if (road == null)	return null;
switch (road.route_type)
	{
	case	RouteType.RAIL:
		return null;
	break;
	case	RouteType.WATER:
		return null;
	break;
	case	RouteType.ROAD:
		return INSTANCE.carrier.GetRoadVehicle(routeidx);
	break;
	default:
		return INSTANCE.carrier.GetAirVehicle(routeidx);
	break;
	}
}

function cCarrier::GetEngineEfficiency(engine, cargoID)
// engine = enginetype to check
// return an index, the smallest = the better of ratio cargo/runningcost+cost of engine
// simple formula it's (price+(age*runningcost)) / (capacity*0.9+speed)
{
local price=cEngine.GetPrice(engine, cargoID);
local capacity=cEngine.GetCapacity(engine, cargoID);
local lifetime=AIEngine.GetMaxAge(engine);
local runningcost=AIEngine.GetRunningCost(engine);
local speed=AIEngine.GetMaxSpeed(engine);
if (capacity==0)	return 999999999;
if (price<=0)	return 999999999;
local eff=(100000+ (price+(lifetime*runningcost))) / ((capacity*0.9)+speed).tointeger();
return eff;
}

function cCarrier::GetEngineRawEfficiency(engine, cargoID)
// only consider the raw capacity/speed ratio
// engine = enginetype to check
// return an index, the smallest = the better of ratio cargo/runningcost+cost of engine
// simple formula is speed/capacity
{
local capacity=cEngine.GetCapacity(engine, cargoID);
local speed=AIEngine.GetMaxSpeed(engine);
if (capacity<=0)	return 999999999;
if (price<=0)	return 999999999;
local eff=100000 / ((capacity*0.9)+speed).tointeger();
return eff;
}

function cCarrier::CheckOneVehicleOrGroup(vehID, doGroup)
// Add a vehicle to the maintenance pool
// vehID: the vehicleID to check
// doGroup: if true, we will add all the vehicles that belong to the vehicleID group
{
if (!AIVehicle.IsValidVehicle(vehID))	return false;
local vehList=AIList();
local vehGroup=AIVehicle.GetGroupID(vehID);
if (doGroup)	vehList.AddList(AIVehicleList_Group(vehGroup));
		else	vehList.AddItem(vehID,0);
foreach (vehicle, dummy in vehList)
	if (!vehicle in cCarrier.MaintenancePool)	cCarrier.MaintenancePool.push(vehicle);
}

function cCarrier::CheckOneVehicleOfGroup(doGroup)
// Add one vehicle of each vehicle groups we own to maintenance check
// doGroup: true to also do the whole group add, this mean all vehicles we own
{
local allgroup=AIGroupList();
foreach (groupID, dummy in allgroup)
	{
	local vehlist=AIVehicleList_Group(groupID);
	if (!vehlist.IsEmpty())	cCarrier.CheckOneVehicleOrGroup(vehlist.Begin(),doGroup);
	AIController.Sleep(1);
	}
}

