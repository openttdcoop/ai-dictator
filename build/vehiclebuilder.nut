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


enum AircraftType {
	EFFICIENT,
	BEST,
	CHOPPER
}

class cCarrier
{
static	AirportTypeLimit=[6, 15, 0, 30, 60, 0, 0, 140, 0]; // limit per airport type
static	IDX_HELPER = 512;		// use to create an uniq ID (also use to set handicap value)
static	AIR_NET_CONNECTOR=3000;		// town is add to air network when it reach that value population
static	TopEngineList=AIList();		// the list of engine ID we know if it can be upgrade or not
static	ToDepotList=AIList();		// list all vehicle going to depot
static	vehicle_database={};		// database for vehicles
static	VirtualAirRoute=[];		// the air network destinations list
static	function GetVehicleObject(vehicleID)
		{
		return vehicleID in cCarrier.vehicle_database ? cCarrier.vehicle_database[vehicleID] : null;
		}

	rail_max=null;		// maximum trains vehicle a station can handle
	road_max=null;		// maximum a road station can upgarde (max: 6)
	air_max=null;		// maximum aircraft a station can handle
	airnet_max=null;	// maximum aircraft on a network
	airnet_count=null;	// current number of aircrafts running the network
	water_max=null;		// maximum ships a station can handle
	road_max_onroute=null;  // maximum road vehicle on a route

//	under_upgrade=null;	// true when we are doing upgrade on something

	vehnextprice=null;	// we just use that to upgrade vehicle
	do_profit=null;		// Record each vehicle profits

	constructor()
		{
		vehnextprice=0;
		do_profit=AIList();
		
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

function cCarrier::CanAddNewVehicle(roadidx, start) // TODO: the new RoadStationUpgrade can now support easy upto 6 stations
// check if we can add another vehicle at the start/end station of that route
{
local chem=cRoute.GetRouteObject(roadidx);
local thatstation=null;
local thatentry=null;
if (start)	{ thatstation=chem.source; }
	else	{ thatstation=chem.target; }
local divisor=0;
switch (chem.route_type)
	{
	case AIVehicle.VT_ROAD:
		if (thatstation.CanUpgradeStation())
			{ // can still upgrade
			if (thatstation.vehicle_count+1 > thatstation.vehicle_max)
				{ // we must upgrade
				if (INSTANCE.secureStart ==0)
					{ // we can upgrade
					INSTANCE.builder.RoadStationNeedUpgrade(roadidx, start);
					local fake=thatstation.CanUpgradeStation(); // to see if upgrade success
					}
				else	return true; // cannot upgrade but assuming we will success and tell we're ok
				}
			if (thatstation.vehicle_count+1 > thatstation.vehicle_max)	return false;
			// limit by the max the station could handle
			if (chem.vehicle_count+1 > INSTANCE.carrier.road_max_onroute)	return false;
			// limit by number of vehicle per route
			if (!use_road)	return false;
			// limit by vehicle disable (this can happen if we reach max vehicle game settings too
			}
		else	{ // max size already
			if (thatstation.vehicle_count+1 > thatstation.vehicle_max)	return false;
			// limit by the max the station could handle
			if (chem.vehicle_count+1 > INSTANCE.carrier.road_max_onroute)	return false;
			// limit by number of vehicle per route
			if (!INSTANCE.use_road)	return false;
			// limit by vehicle disable (this can happen if we reach max vehicle game settings too
			}
	break;
	case AIVehicle.VT_RAIL:
		if (thatstation.CanUpgradeStation())
			{
			if (!INSTANCE.use_train)	return false;
			if (thatstation.vehicle_count+1 > thatstation.vehiclemax)	return false;
			// don't try upgrade if we cannot add a new train
			return INSTANCE.builder.TrainStationNeedUpgrade(roadidx, start); // if we fail to upgrade...
			}
		else	{
			if (!INSTANCE.use_train) return false;
			if (thatstation.vehicle_count+1 > thatstation.vehicle_max)	return false;
			}
	break;
	case AIVehicle.VT_WATER:
		if (!INSTANCE.use_boat)	return false;
		if (thatstation.vehicle_count+1 > thatstation.vehicle_max)	return false;
	break;
// TODO: upgrade airport before adding new aircraft if upgrade is avaiable
	case AIVehicle.VT_AIR: // Airport upgrade is not related to number of aircrafts using them
		if (INSTANCE.use_air)	return false;
		local checklimit=thatstation.CanUpgradeStation(); // force recheck limits
		local aircraftMax=INSTANCE.chemin.air_max; // max aircraft for non network airport
		local aircraftCurrent=thatstation.STATION.e_count+1; // number of aircraft for non network airport
		local currAirport=INSTANCE.builder.GetAirportType();
		local maxperairport=INSTANCE.carrier.AirportTypeLimit[currAirport];
		DInfo("currAirportType="+currAirport+" limit/airport="+maxperairport,2);
		if (road.ROUTE.kind==1000)
			{ // in the network
			aircraftCurrent=INSTANCE.chemin.airnet_count+1;
			aircraftMax=INSTANCE.chemin.airnet_max * (INSTANCE.chemin.virtual_air.len()-1);
			}
		if (aircraftMax > maxperairport)	aircraftMax=maxperairport; // per airport type limitation
		DInfo("Limit for aircraft "+aircraftCurrent+"/"+aircraftMax,2);
		if (aircraftCurrent > aircraftMax) return false;
	break;
	}
return true;
}

function cCarrier::BuildAndStartVehicle(routeid)
// Create a new vehicle on route
{
local road=cRoute.GetRouteObject(routeid);
if (road == null)	{ DWarn("Building a vehicle cannot be done on unknown route !",1); }
local res=false;
switch (road.route_type)
	{
	case AIVehicle.VT_ROAD:
//	if (duplicate)	res=INSTANCE.carrier.CloneRoadVehicle(idx);
		res=INSTANCE.carrier.CreateRoadVehicle(routeid);
	break;
	case AIVehicle.VT_RAIL:
//	if (duplicate)	{ } //INSTANCE.carrier.CloneRoadVehicle(idx);
		res=INSTANCE.carrier.CreateRailVehicle(routeid);
	break;
	case AIVehicle.VT_WATER:
	break;
	case AIVehicle.VT_AIR:
//	if (duplicate)	{ res=INSTANCE.carrier.CloneAirVehicle(idx); }
		res=INSTANCE.carrier.CreateAirVehicle(routeid);
	break;
	default:
//	if (duplicate)	{ res=INSTANCE.carrier.CloneAirVehicle(idx); }
		res=INSTANCE.carrier.CreateAirVehicle(routeid);
	break;
	}
if (res)	road.RouteAddVehicle();
return res;
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
if (veh == null)
	{ DError("Fail to pickup a vehicle",1); return false; }
INSTANCE.bank.RaiseFundsBy(price);
local firstveh = AIVehicle.BuildVehicle(homedepot, veh);
if (!AIVehicle.IsValidVehicle(firstveh))
	{ DWarn("Cannot buy the vehicle :",1); return false; }
else	{ DInfo("Just brought a new vehicle: "+AIVehicle.GetName(firstveh),1); }
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
if (!AIVehicle.StartStopVehicle(firstveh)) { DError("Cannot start the vehicle:",1); }
return true;
}

function cCarrier::CreateAirVehicle(routeidx)
// Build first vehicule of an air route
{
local road=cRoute.GetRouteObject(routeidx);
local srcplace = road.source.locations.Begin();
local dstplace = road.target.locations.Begin();
local homedepot = road.GetRouteDepot();
local cargoid = road.cargoID;
// TODO: platform check to build a new aircraft
DInfo("srcplace="+srcplace+" dstplace="+dstplace,2);
PutSign(srcplace,"Route "+routeidx+" Source Airport ");
PutSign(dstplace,"Route "+routeidx+" Destination Airport");
local modele=AircraftType.EFFICIENT;
if (road.route_type == RouteType.AIRNET)	modele=AircraftType.BEST; // top speed/capacity for network
if (road.route_type == RouteType.CHOPPER)	modele=AircraftType.CHOPPER; // need a chopper
local veh = INSTANCE.carrier.ChooseAircraft(road.cargoID,modele);
local price = AIEngine.GetPrice(veh);
if (veh == null)
	{ DError("Cannot pickup an aircraft",1); return false; }
INSTANCE.bank.RaiseFundsBy(price);
local firstveh = AIVehicle.BuildVehicle(homedepot, veh);
if (!AIVehicle.IsValidVehicle(firstveh))
	{ DWarn("Cannot buy the vehicle :",1); return false; }
else	{ DInfo("Just brought a new vehicle: "+AIVehicle.GetName(firstveh)+" "+AIEngine.GetName(AIVehicle.GetEngineType(firstveh)),1); }
// no refit on aircrafts, we endup with only passengers aircraft, and ones that should do mail will stay different
// with the fastest engine
local firstorderflag = null;
local secondorderflag = null;
secondorderflag = AIOrder.AIOF_FULL_LOAD_ANY;
AIOrder.AppendOrder(firstveh, srcplace, secondorderflag);
AIOrder.AppendOrder(firstveh, dstplace, secondorderflag);
AIGroup.MoveVehicle(road.groupID, firstveh);
if (road.route_type == RouteType.CHOPPER)	VehicleOrderSkipCurrent(firstveh);
if (!AIVehicle.StartStopVehicle(firstveh)) { DError("Cannot start the vehicle:",1); }
return true;
}

function cCarrier::GetRailVehicle(idx)
// get a rail vehicle
{
local road= INSTANCE.chemin.RListGetItem(idx);
local veh = INSTANCE.carrier.ChooseRailVeh(idx);
if (veh == null)	{
			DError("No suitable train to buy !",1);
			road=INSTANCE.chemin.RouteMalusHigher(road);
			INSTANCE.chemin.RListUpdateItem(INSTANCE.chemin.nowJob,road);
			return -1;
			}
DInfo("Choosen train: "+AIEngine.GetName(veh),2);
return veh;
}

function cCarrier::GetRoadVehicle()
// get a road vehicle
{
local veh = INSTANCE.carrier.ChooseRoadVeh(cCargo.GetPassengerCargo());
if (veh == null)	{
			DError("No suitable road vehicle to buy !",1);
			}
DInfo("Choosen road vehicle: "+AIEngine.GetName(veh),2);
return veh;
}

function cCarrier::GetAirVehicle()
// get an aircraft
{
local modele=AircraftType.EFFICIENT;
if (INSTANCE.route.route_type == RouteType.AIRNET)	modele=AircraftType.BEST;
if (INSTANCE.route.route_type == RouteType.CHOPPER)	modele=AircraftType.CHOPPER;
local veh = ChooseAircraft(INSTANCE.route.cargoID,modele);
if (veh == null)	{
			if (INSTANCE.route.route_type == RouteType.CHOPPER)	DWarn("No suitable chopper to buy !",1);
									else	DWarn("No suitable aircraft to buy !");
			}
DInfo("Choosen aircraft: "+AIEngine.GetName(veh),2);
return veh;
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
{
local vehlist = AIEngineList(AIVehicle.VT_AIR);
//AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL
vehlist.Valuate(AIEngine.CanRefitCargo, cargo);
vehlist.KeepValue(1);
if (airtype < AircraftType.CHOPPER)
	{
	if (AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL)
		// for mail i use fastest engine + best efficiency ratio cargonum/price&running_cost
		{ vehlist.Valuate(AIEngine.GetMaxSpeed); }
	else	{ vehlist.Valuate(AIEngine.GetCapacity); } // bigest for passengers
		vehlist.Sort(AIList.SORT_BY_VALUE,false);
		local first=vehlist.GetValue(vehlist.Begin()); // get top value (speed or capacity)
		vehlist.KeepValue(first);
		if (airtype == AircraftType.EFFICIENT)
			{
			vehlist.Valuate(cCarrier.GetEngineEfficiency);
			vehlist.Sort(AIList.SORT_BY_VALUE,true);
			}
	} 
else	{
	vehlist.Valuate(AIEngine.GetPlaneType);
	vehlist.KeepValue(AIAirport.PT_HELICOPTER);
	vehlist.Valuate(AIEngine.GetMaxSpeed);	
	vehlist.Sort(AIList.SORT_BY_VALUE,false);
	}
return vehlist.Begin();
}

function cCarrier::GetEngineEfficiency(engine)
// engine = enginetype to check
// return an index, the smallest = the better of ratio cargo/runningcost+cost of engine
// simple formula it's (price+(age*runningcost)) / cargoamount
{
local price=AIEngine.GetPrice(engine);
local capacity=AIEngine.GetCapacity(engine);
local lifetime=AIEngine.GetMaxAge(engine);
local runningcost=AIEngine.GetRunningCost(engine);
return (price+(lifetime*runningcost))/capacity;
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
local top=null;
vehlist.Valuate(AIEngine.GetCapacity);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
top=vehlist.GetValue(vehlist.Begin());
vehlist.KeepValue(top);
vehlist.Valuate(AIEngine.GetMaxSpeed);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
top=vehlist.GetValue(vehlist.Begin());
vehlist.KeepValue(top);
vehlist.Valuate(AIEngine.GetReliability);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
top=vehlist.GetValue(vehlist.Begin());
vehlist.KeepValue(top);
foreach (vehicle, capacity in vehlist)
	{
	DInfo("Vehicle "+vehicle+" - "+AIEngine.GetName(vehicle)+" Speed: "+AIEngine.GetMaxSpeed(vehicle)+" Capacity: "+AIEngine.GetCapacity(vehicle)+" Price: "+AIEngine.GetPrice(vehicle),2);
	}
DInfo("Road vehicule selected: "+AIEngine.GetName(vehlist.Begin()),2);
local veh = -1;
if (vehlist.Count() > 0) { veh=vehlist.Begin();	}
return veh;
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

function cCarrier::ChooseRailVeh(idx) // TODO: recheck that, for case where a train could be better base on power
{
local vehlist = AIEngineList(AIVehicle.VT_RAIL);
vehlist.Valuate(AIEngine.HasPowerOnRail, AIRail.GetCurrentRailType());
vehlist.KeepValue(1);
vehlist.Valuate(AIEngine.IsWagon);
vehlist.KeepValue(0);
vehlist.Valuate(AIEngine.GetMaxSpeed);
DInfo("Train found: "+vehlist.Count(),2);
local veh = null;
if (vehlist.Count() > 0)	veh=vehlist.Begin();
return veh;
}

function cCarrier::GetVehicle()
// Get current choosen vehicle, reroute depending on road type
{
local success=-1;
switch (INSTANCE.route.route_type)
	{
	case RouteType.ROAD:
	success=INSTANCE.carrier.GetRoadVehicle();
	break;
	case RouteType.RAIL:
	//success=INSTANCE.carrier.GetRailVehicle(idx);
	successs=false;
	break;
	case RouteType.WATER:
	success=false;
	break;
	case RouteType.AIR:
	case RouteType.AIRNET:
	success=INSTANCE.carrier.GetAirVehicle();
	break;
	}
return success;
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
