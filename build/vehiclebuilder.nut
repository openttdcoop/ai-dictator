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


class cCarrier
{
static	AirportTypeLimit=[6, 10, 2, 16, 30, 5, 6, 60, 8]; // limit per airport type
static	IDX_HELPER = 512;			// use to create an uniq ID (also use to set handicap value)
static	AIR_NET_CONNECTOR=2500;		// town is add to air network when it reach that value population
static	TopEngineList=AIList();		// the list of engine ID we know if it can be upgrade or not
static	ToDepotList=AIList();		// list all vehicle going to depot, date as value
static	vehicle_database={};		// database for vehicles
static	VirtualAirRoute=[];		// the air network destinations list
static 	OldVehicle=1095;			// age left we consider a vehicle is old
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
	vehnextprice	=null;	// we just use that to upgrade vehicle
	do_profit		=null;	// Record each vehicle profits
	warTreasure		=null;	// total current value of nearly all our road vehicle
	highcostAircraft	=null;	// the highest cost for an aircraft we need

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
		vehnextprice	=0;
		do_profit		=AIList();
		warTreasure		=0;
		highcostAircraft	=0;
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
if (start)	{ thatstation=chem.source; }
	else	{ thatstation=chem.target; }
local divisor=0;
local sellvalid=( (AIDate.GetCurrentDate() - chem.date_VehicleDelete) > 60);
// prevent buy a new vehicle if we sell one less than 60 days before (this isn't affect by replacing/upgrading vehicle)
if (!sellvalid)	{ max_allow=0; DInfo("Route sold a vehicle not a long time ago",1); }
local virtualized=cStation.IsStationVirtual(thatstation.stationID);
local airportmode="(classic)";
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
		if (virtualized)	limitmax=2; // only 2 aircrafts when the airport is also in network
		DInfo(airname+"Limit for that route (classic): "+chem.vehicle_count+"/"+limitmax,1);
		DInfo(airname+"Limit for that airport "+airportmode+": "+thatstation.vehicle_count+"/"+thatstation.vehicle_max,1);
		if (!INSTANCE.use_air)	max_allow=0;
		if (chem.vehicle_count+max_allow > limitmax)	max_allow=limitmax - chem.vehicle_count;
		// limit by route limit
		if (thatstation.vehicle_count+max_allow > thatstation.vehicle_max)	max_allow=thatstation.vehicle_max-thatstation.vehicle_count;
		// limit by airport capacity
	break;
	}
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

function cCarrier::GetRoadVehicle(routeidx)
// return the vehicle we will pickup if we to build a vehicle on that route
{
local road=cRoute.GetRouteObject(routeidx);
if (road == null)	return null;
local veh = INSTANCE.carrier.ChooseRoadVeh(road.cargoID);
return veh;
}

function cCarrier::CreateRoadVehicle(roadidx)
// Build a road vehicle for route roadidx
{
local road=cRoute.GetRouteObject(roadidx);
local srcplace = road.source.locations.Begin();
local dstplace = road.target.locations.Begin();
local cargoid= road.cargoID;
local veh = INSTANCE.carrier.ChooseRoadVeh(cargoid);
local homedepot = road.GetRouteDepot();
local price = AIEngine.GetPrice(veh);
local altplace=(road.vehicle_count > 0 && road.vehicle_count % 2 != 0 && road.cargoID == cCargo.GetPassengerCargo());
if (altplace)	homedepot = road.target.depot;
if (veh == null)
	{ DError("Fail to pickup a vehicle",1); return false; }
INSTANCE.bank.RaiseFundsBy(price);
local firstveh = AIVehicle.BuildVehicle(homedepot, veh);
if (!AIVehicle.IsValidVehicle(firstveh))
	{ DWarn("Cannot buy the road vehicle : "+price,1); return false; }
else	{ DInfo("Just brought a new road vehicle: "+AIVehicle.GetName(firstveh),0); }
if (AIEngine.GetCargoType(veh) != cargoid) AIVehicle.RefitVehicle(firstveh, cargoid);
local firstorderflag = null;
local secondorderflag = null;
if (AICargo.GetTownEffect(cargoid) == AICargo.TE_PASSENGERS || AICargo.GetTownEffect(cargoid) == AICargo.TE_MAIL)
	{
	firstorderflag = AIOrder.AIOF_NON_STOP_INTERMEDIATE + AIOrder.AIOF_FULL_LOAD_ANY;
	secondorderflag = AIOrder.AIOF_NON_STOP_INTERMEDIATE + AIOrder.AIOF_FULL_LOAD_ANY;
	}
else	{
	firstorderflag = AIOrder.AIOF_FULL_LOAD_ANY + AIOrder.AIOF_NON_STOP_INTERMEDIATE;
	secondorderflag = AIOrder.AIOF_NON_STOP_INTERMEDIATE;
	}
AIGroup.MoveVehicle(road.groupID, firstveh);
AIOrder.AppendOrder(firstveh, srcplace, firstorderflag);
AIOrder.AppendOrder(firstveh, dstplace, secondorderflag);
if (altplace)	INSTANCE.carrier.VehicleOrderSkipCurrent(firstveh);
if (!AIVehicle.StartStopVehicle(firstveh)) { DError("Cannot start the vehicle:",1); }
if (!altplace)	INSTANCE.Sleep(74);
return true;
}

function cCarrier::GetAirVehicle(routeidx)
// return the vehicle we will pickup if we to build a vehicle on that route
{
local road=cRoute.GetRouteObject(routeidx);
if (road == null)	return null;
local modele=AircraftType.EFFICIENT;
if (road.route_type == RouteType.AIRNET)	modele=AircraftType.BEST; // top speed/capacity for network
if (road.source.specialType == AIAirport.AT_SMALL || road.target.specialType == AIAirport.AT_SMALL)	modele+=20;
if (road.route_type == RouteType.CHOPPER)	modele=AircraftType.CHOPPER; // need a chopper
local veh = INSTANCE.carrier.ChooseAircraft(road.cargoID,modele);
return veh;
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

function cCarrier::CreateAirVehicle(routeidx)
// Build first vehicule of an air route
{
local road=cRoute.GetRouteObject(routeidx);
local srcplace = road.source.locations.Begin();
local dstplace = road.target.locations.Begin();
local homedepot = road.source.depot;
local altplace=(road.vehicle_count > 0 && road.vehicle_count % 2 != 0);
if (road.route_type == RouteType.CHOPPER)	altplace=true; // chopper don't have a source airport, but a platform
if (altplace)	homedepot = road.target.depot;
local cargoid = road.cargoID;
DInfo("srcplace="+srcplace+" dstplace="+dstplace,2);
PutSign(srcplace,"Route "+routeidx+" Source Airport ");
PutSign(dstplace,"Route "+routeidx+" Destination Airport");
local veh = INSTANCE.carrier.GetAirVehicle(routeidx);
local price = AIEngine.GetPrice(veh);
if (veh == null)
	{ DError("Cannot pickup an aircraft",1); return false; }
INSTANCE.bank.RaiseFundsBy(price);
local firstveh = AIVehicle.BuildVehicle(homedepot, veh);
if (!AIVehicle.IsValidVehicle(firstveh))
	{ DWarn("Cannot buy the aircraft : "+price,1); return false; }
else	{ DInfo("Just brought a new aircraft: "+AIVehicle.GetName(firstveh)+" "+AIEngine.GetName(AIVehicle.GetEngineType(firstveh)),0); }
// no refit on aircrafts, we endup with only passengers aircraft, and ones that should do mail will stay different
// as thir engine is the fastest always
local firstorderflag = null;
local secondorderflag = null;
secondorderflag = AIOrder.AIOF_FULL_LOAD_ANY;
AIOrder.AppendOrder(firstveh, srcplace, secondorderflag);
AIOrder.AppendOrder(firstveh, dstplace, secondorderflag);
AIGroup.MoveVehicle(road.groupID, firstveh);
if (altplace)	INSTANCE.carrier.VehicleOrderSkipCurrent(firstveh);
if (!AIVehicle.StartStopVehicle(firstveh)) { DError("Cannot start the vehicle:",1); }
return true;
}

function cCarrier::AircraftIsChopper(vehicle)
// return true if we are a chopper
{
local vehlist = AIEngineList(AIVehicle.VT_AIR);
vehlist.Valuate(AIEngine.GetPlaneType);
vehlist.KeepValue(AIAirport.PT_HELICOPTER);
local vehengine=AIVehicle.GetEngineType(vehicle);
return vehlist.HasItem(vehengine);
}

function cCarrier::ChooseAircraft(cargo,airtype=0)
// build an aircraft base on cargo
// airtype = 0=efficiency, 1=best, 2=chopper
// We can endup with 5+ different type of aircrafts running
{
local vehlist = AIEngineList(AIVehicle.VT_AIR);
vehlist.Valuate(AIEngine.CanRefitCargo, cargo);
vehlist.KeepValue(1);
vehlist.Valuate(AIEngine.GetMaxSpeed);
vehlist.KeepAboveValue(45); // some newgrf use weird unplayable aircrafts (for our distance usage)
local limitsmall=false;
if (airtype >= 20)
	{
	airtype-=20; // this will get us back to original aircraft type
	limitsmall=true;
	}
switch (airtype)
	{
	case	AircraftType.EFFICIENT: // top efficient aircraft for passenger and top speed (not efficient) for mail
	// top efficient aircraft is generally the same as top capacity/efficient one
		if (limitsmall)
			{
			vehlist.Valuate(AIEngine.GetPlaneType);
			vehlist.KeepValue(AIAirport.PT_SMALL_PLANE);
			}
		vehlist.Valuate(cCarrier.GetEngineEfficiency);
		vehlist.Sort(AIList.SORT_BY_VALUE,true);
		if (AICargo.GetTownEffect(cargo) == cCargo.GetMailCargo())
			{
			vehlist.Valuate(AIEngine.GetMaxSpeed);
			vehlist.Sort(AIList.SORT_BY_VALUE,false);
			}
	break;
	case	AircraftType.BEST:
		if (limitsmall)
			{
			vehlist.Valuate(AIEngine.GetPlaneType);
			vehlist.KeepValue(AIAirport.PT_SMALL_PLANE);
			}
		if (AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL)
			// here: top efficient capacity for passenger and top efficient speed for mail
			{ vehlist.Valuate(AIEngine.GetMaxSpeed); }
		else	{ vehlist.Valuate(AIEngine.GetCapacity); }
			vehlist.Sort(AIList.SORT_BY_VALUE,false);
			local first=vehlist.GetValue(vehlist.Begin()); // get top value (speed or capacity)
			vehlist.KeepValue(first);
			if (airtype == AircraftType.EFFICIENT)
				{
				vehlist.Valuate(cCarrier.GetEngineEfficiency);
				vehlist.Sort(AIList.SORT_BY_VALUE,true);
				}
	break;
	case	AircraftType.CHOPPER: // top efficient chopper
		vehlist.Valuate(AIEngine.GetPlaneType);
		vehlist.KeepValue(AIAirport.PT_HELICOPTER);
		vehlist.Valuate(cCarrier.GetEngineEfficiency);
		vehlist.Sort(AIList.SORT_BY_VALUE,true);
	break;
	}
return (vehlist.IsEmpty()) ? null : vehlist.Begin();
}

function cCarrier::GetEngineEfficiency(engine)
// engine = enginetype to check
// return an index, the smallest = the better of ratio cargo/runningcost+cost of engine
// simple formula it's (price+(age*runningcost)) / (cargoamount*speed)
{
local price=AIEngine.GetPrice(engine);
local capacity=AIEngine.GetCapacity(engine);
local lifetime=AIEngine.GetMaxAge(engine);
local runningcost=AIEngine.GetRunningCost(engine);
local speed=AIEngine.GetMaxSpeed(engine);
return (price+(lifetime*runningcost))/((capacity*0.9)*speed).tointeger();
}

function cCarrier::ChooseRoadVeh(cargoid)
/**
* Pickup a road vehicle base on -> max capacity > max speed > max reliability
* @return the vehicle engine id
*/
{
local vehlist = AIEngineList(AIVehicle.VT_ROAD);
vehlist.Valuate(AIEngine.GetRoadType);
vehlist.KeepValue(AIRoad.ROADTYPE_ROAD);
vehlist.Valuate(AIEngine.IsArticulated);
vehlist.KeepValue(0);
vehlist.Valuate(AIEngine.CanRefitCargo, cargoid);
vehlist.KeepValue(1);
vehlist.Valuate(cCarrier.GetEngineEfficiency);
vehlist.Sort(AIList.SORT_BY_VALUE,true);
return (vehlist.IsEmpty()) ? null : vehlist.Begin();
}

function cCarrier::ChooseWagon(cargo)
{
	local wagonlist = AIEngineList(AIVehicle.VT_RAIL);
	wagonlist.Valuate(AIEngine.CanRunOnRail, AIRail.GetCurrentRailType());
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.IsWagon);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.GetCargoType);
	wagonlist.KeepValue(cargo);
	wagonlist.Valuate(AIEngine.GetCapacity);
	if (wagonlist.Count() == 0) 
		{ DError("No wagons can transport that cargo.",1); return null; }
	return wagonlist.Begin();
}

function cCarrier::ChooseRailVeh() // TODO: fix&recheck that, for case where a train could be better base on power
{
local vehlist = AIEngineList(AIVehicle.VT_RAIL);
vehlist.Valuate(AIEngine.HasPowerOnRail, AIRail.GetCurrentRailType());
vehlist.KeepValue(1);
vehlist.Valuate(AIEngine.IsWagon);
vehlist.KeepValue(0);
vehlist.Valuate(AIEngine.GetMaxSpeed);
local veh = null;
if (vehlist.Count() > 0)	veh=vehlist.Begin();
return veh;
}

function cCarrier::CreateRailVehicle(roadidx)
{
local road=INSTANCE.chemin.RListGetItem(roadidx);
local real_src_id=INSTANCE.chemin.GListGetItem(road.ROUTE.src_station);
local srcplace = real_src_id.STATION.station_id; // train real station is there
DInfo("src station is valid :"+AIStation.IsValidStation(srcplace),1);
local real_dst_id=INSTANCE.chemin.GListGetItem(road.ROUTE.dst_station);
local dstplace = real_dst_id.STATION.station_id;
DInfo("dst station is valid :"+AIStation.IsValidStation(dstplace),1);
local cargoid= road.ROUTE.cargo_id;
local veh = INSTANCE.carrier.ChooseRailVeh(roadidx);
local wagon = INSTANCE.carrier.ChooseWagon(road.ROUTE.cargo_id);
local homedepot = real_src_id.STATION.e_depot;
local price = AIEngine.GetPrice(veh);
price+=AIEngine.GetPrice(wagon)*5;
local length = 5;
DInfo("Stationid: "+srcplace+" "+AIStation.GetName(srcplace),2);
DInfo("Depotid: "+homedepot,2);
if (veh == null) return false;
if (!INSTANCE.bank.RaiseFundsBy(price))
	{
	DWarn("I don't have enough money to buy that train and its wagons "+AIEngine.GetName(veh),1);
	return false;
	}
else	{ DInfo("Train "+AIEngine.GetName(veh)+" and wagons will cost "+price,1); }
local trainengine = AIVehicle.BuildVehicle(homedepot, veh);
DInfo("Train created",2);
AIVehicle.RefitVehicle(veh, road.ROUTE.cargo_id);
local first=null;
first=AIVehicle.BuildVehicle(homedepot, wagon); // 4 to start operating
AIVehicle.BuildVehicle(homedepot, wagon);
AIVehicle.BuildVehicle(homedepot, wagon);
AIVehicle.BuildVehicle(homedepot, wagon);
AIVehicle.MoveWagonChain(first, 0, trainengine, AIVehicle.GetNumWagons(trainengine) - 1);
DInfo("wagons moved.",2);
local firstorderflag = null;
if (AICargo.GetTownEffect(road.ROUTE.cargo_id) == AICargo.TE_PASSENGERS || AICargo.GetTownEffect(road.ROUTE.cargo_id) == AICargo.TE_MAIL)
	{
	firstorderflag = AIOrder.AIOF_NON_STOP_INTERMEDIATE;
	}
 else	{
	firstorderflag = AIOrder.AIOF_FULL_LOAD_ANY + AIOrder.AIOF_NON_STOP_INTERMEDIATE;
	}
DInfo("Append order to "+AIEngine.GetName(trainengine)+" to "+AIStation.GetName(srcplace),2);
if (!AIOrder.AppendOrder(trainengine, AIStation.GetLocation(srcplace), firstorderflag))
	{ DError("Fail to set order !!!"+AIError.GetLastErrorString(),1); }
if (!AIOrder.AppendOrder(trainengine, AIStation.GetLocation(dstplace), AIOrder.AIOF_NON_STOP_INTERMEDIATE))
	{ DError("Fail to set order !!!"+AIError.GetLastErrorString(),1); }
DInfo("orders set",1);
if (!AIVehicle.StartStopVehicle(trainengine))
	{ DInfo(AIVehicle.GetName(trainengine)+" refuse to start !!!"+AIError.GetLastErrorString(),1); }
AIGroup.MoveVehicle(road.ROUTE.group_id, trainengine);
return true;
}
