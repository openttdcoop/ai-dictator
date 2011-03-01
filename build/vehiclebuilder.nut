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

	rail_max=null;		// maximum trains vehicle a station can handle
	road_max=null;		// maximum road vehicle a station can handle
	air_max=null;		// maximum aircraft a station can handle
	airnet_max=null;	// maximum aircraft on a network
	airnet_count=null;	// current number of aircrafts running the network
	water_max=null;		// maximum ships a station can handle
	road_max_onroute=null;  // maximum road vehicle on a route

//	under_upgrade=null;	// true when we are doing upgrade on something

	vehnextprice=null;	// we just use that to upgrade vehicle
	top_vehicle=null;	// the list of vehicle engine id we know cannot be upgrade
	to_depot=null;		// list the vehicle going to depot
	do_profit=null;		// Record each vehicle profits

	constructor()
		{
		//root=that;
		vehnextprice=0;
		top_vehicle=AIList();
		to_depot=AIList();
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
local road=INSTANCE.chemin.RListGetItem(roadidx);
local thatstation=null;
local thatentry=null;
if (start)	{ thatstation=INSTANCE.chemin.GListGetItem(road.ROUTE.src_station);	}
else		{ thatstation=INSTANCE.chemin.GListGetItem(road.ROUTE.dst_station);	}
local divisor=0;
switch (road.ROUTE.kind)
	{
	case AIVehicle.VT_ROAD:
		if (thatstation.STATION.type==0)
			{ // max size already
			if (thatstation.STATION.e_count+1 > INSTANCE.chemin.road_max) return false; 
			}
		else	{ // not yet upgrade
			if (thatstation.STATION.e_count > INSTANCE.chemin.road_max_onroute && INSTANCE.secureStart == 0)
				INSTANCE.builder.RoadStationNeedUpgrade(roadidx,start);
			if (thatstation.STATION.e_count+1 > INSTANCE.chemin.road_max) return false;
			}
	break;
	case AIVehicle.VT_RAIL:
		local trains=thatstation.STATION.e_count+thatstation.STATION.s_count;
		if (thatstation.STATION.type==0)
			{ // max size already
			if (trains+1 > thatstation.STATION.size) return false; 
			// can't build more than the station size
			}
		else	{ // we could upgrade it, assuming it can be upgrade, we still don't go higher than our limit
			return INSTANCE.builder.TrainStationNeedUpgrade(roadidx,start);
			}
	break;
	case AIVehicle.VT_WATER:
	if (thatstation.STATION.e_count+1 > INSTANCE.chemin.water_max) return false;
	break;
	case AIVehicle.VT_AIR: // Airport upgrade is not related to number of aircrafts using them
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

function cCarrier::CloneRoadVehicle(roadidx)
// add another Vehicle on that route, sharing orders
{
local road=INSTANCE.chemin.RListGetItem(roadidx);
local vehlist=AIVehicleList_Group(road.ROUTE.group_id);
vehlist.Valuate(AIOrder.IsGotoDepotOrder,AIOrder.ORDER_CURRENT);
vehlist.KeepValue(0);
if (vehlist.IsEmpty())
	{
	DError("Can't find any vehicle to duplicated on that route",1);
	return false;
	}
// first check we can add one more vehicle to start or ending station
if (!INSTANCE.carrier.CanAddNewVehicle(roadidx,true) || !INSTANCE.carrier.CanAddNewVehicle(roadidx,false))
	{
	DWarn("One station on that route is full, cannot add more vehicle",1);
	return false;
	}
local veh=vehlist.Begin();
local price = AIEngine.GetPrice(AIVehicle.GetEngineType(veh));
INSTANCE.bank.RaiseFundsBy(price);
local startdepot=true;
local switcher=false;
if (AICargo.GetTownEffect(road.ROUTE.cargo_id)==AICargo.TE_PASSENGERS || AICargo.GetTownEffect(road.ROUTE.cargo_id)==AICargo.TE_MAIL)
	{ switcher = true; }

if (road.ROUTE.vehicule%2 != 0 && switcher) // impair Vehicle selection, because impair+1 = pair :)
	{ startdepot=false; }
/*if (road.ROUTE.kind == AIVehicle.VT_ROAD && AICargo.GetTownEffect(road.ROUTE.cargo_id) == AICargo.TE_PASSENGERS)
	{ startdepot=false; }*/ // we are creating a new bus, we don't really care where it will start
// but it's a good idea to build it at destination, and route it directly to destination station

local newveh=AIVehicle.CloneVehicle(INSTANCE.builder.GetDepotID(roadidx,startdepot),veh,true);
if (!AIVehicle.IsValidVehicle(newveh))
	{ DWarn("Cannot buy the vehicle : "+price,2); return false; }
else	{ DInfo("Just brought a new vehicle: "+AIVehicle.GetName(newveh),1); }
INSTANCE.carrier.RouteAndStationVehicleCounterUpdate(roadidx);
if (!AIVehicle.StartStopVehicle(newveh))
	{ DError("Cannot start the vehicle :",1); return false; }
if (!startdepot)	AIOrder.SkipToOrder(newveh, 1);
// we skip first order to force the vehicle goes to destination station first
return true;
}

function cCarrier::BuildAndStartVehicle(idx,duplicate)
// Create a new vehicle on route or duplicate one
{
local road=INSTANCE.chemin.RListGetItem(idx);
local res=true;
switch (road.ROUTE.kind)
	{
	case AIVehicle.VT_ROAD:
	if (duplicate)	res=INSTANCE.carrier.CloneRoadVehicle(idx);
		else	res=INSTANCE.carrier.CreateRoadVehicle(idx);
	break;
	case AIVehicle.VT_RAIL:
	if (duplicate)	{ } //INSTANCE.carrier.CloneRoadVehicle(idx);
		else	res=INSTANCE.carrier.CreateRailVehicle(idx);
	break;
	case AIVehicle.VT_WATER:
	break;
	case AIVehicle.VT_AIR:
	if (duplicate)	{ res=INSTANCE.carrier.CloneAirVehicle(idx); }
		else	{ res=INSTANCE.carrier.CreateAirVehicle(idx); }
	break;
	case 1000:
	if (duplicate)	{ res=INSTANCE.carrier.CloneAirVehicle(idx); }
		else	{ res=INSTANCE.carrier.CreateAirVehicle(idx); }
	break;
	}
return res;
}

function cCarrier::RouteAndStationVehicleCounterUpdate(roadidx)
// Update the route and stations vehicle counters
{
local road=INSTANCE.chemin.RListGetItem(roadidx);
local entry=true;
local station_id=0;
local station=null;
local vehgroup=null;
if (road.ROUTE.group_id > -1)
	{
	vehgroup=AIVehicleList_Group(road.ROUTE.group_id);
	road.ROUTE.vehicule=vehgroup.Count();
	}
else	road.ROUTE.vehicule=0;

station=INSTANCE.chemin.GListGetItem(road.ROUTE.src_station);
vehgroup=AIVehicleList_Station(station.STATION.station_id);
entry=road.ROUTE.src_entry;
if (entry)	{ station.STATION.e_count=vehgroup.Count(); }
	else	{ station.STATION.s_count=vehgroup.Count(); }
INSTANCE.chemin.GListUpdateItem(road.ROUTE.src_station,station);
station=INSTANCE.chemin.GListGetItem(road.ROUTE.dst_station);
vehgroup=AIVehicleList_Station(station.STATION.station_id);
entry=road.ROUTE.dst_entry;
if (entry)	{ station.STATION.e_count=vehgroup.Count(); }
	else	{ station.STATION.s_count=vehgroup.Count(); }
INSTANCE.chemin.GListUpdateItem(road.ROUTE.dst_station,station);
INSTANCE.chemin.RListUpdateItem(roadidx,road);
}

function cCarrier::CreateRoadVehicle(roadidx)
// Build first Vehicle of a road
{
local road=INSTANCE.chemin.RListGetItem(roadidx);
local srcplace = AIStation.GetLocation(INSTANCE.builder.GetStationID(roadidx,true));
local dstplace = AIStation.GetLocation(INSTANCE.builder.GetStationID(roadidx,false));
local cargoid= road.ROUTE.cargo_id;
local veh = INSTANCE.carrier.ChooseRoadVeh(cargoid);
local homedepot = INSTANCE.builder.GetDepotID(roadidx,true);
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
AIGroup.MoveVehicle(road.ROUTE.group_id, firstveh);
AIOrder.AppendOrder(firstveh, srcplace, firstorderflag);
AIOrder.AppendOrder(firstveh, dstplace, secondorderflag);
if (!AIVehicle.StartStopVehicle(firstveh)) { DError("Cannot start the vehicle:",1); }
INSTANCE.carrier.RouteAndStationVehicleCounterUpdate(roadidx);
return true;
}

function cCarrier::CloneAirVehicle(roadidx)
// add another Vehicle on that route, sharing orders
{
local road=INSTANCE.chemin.RListGetItem(roadidx);
local vehlist=AIVehicleList_Group(road.ROUTE.group_id);
if (vehlist.IsEmpty())
	{
	DError("Can't find any vehicle to duplicated on that route",1);
	return false;
	}
// first check we can add one more vehicle to start or ending station
if (!INSTANCE.carrier.CanAddNewVehicle(roadidx,true) || !INSTANCE.carrier.CanAddNewVehicle(roadidx,false))
	{
	DWarn("One airport is full, cannot add more aircrafts",1);
	return false;
	}
local veh=vehlist.Begin();
local price = AIEngine.GetPrice(AIVehicle.GetEngineType(veh));
INSTANCE.bank.RaiseFundsBy(price);
local startdepot=true;
local switcher=true;
if (road.ROUTE.vehicule%2 != 0 && switcher) // impair vehicule selection, because impair+1 = pair :)
	{ startdepot=false; }
// but it's a good idea to build it at destination, and route it directly to destination station
if (!road.ROUTE.src_entry)	startdepot=false;
local newveh=AIVehicle.CloneVehicle(INSTANCE.builder.GetDepotID(roadidx,startdepot),veh,true);
if (!AIVehicle.IsValidVehicle(newveh))
	{ DWarn("Cannot buy the vehicle :"+price,2); return false; }
else	{ DInfo("Just brought a new vehicle: "+AIVehicle.GetName(newveh)+" "+AIEngine.GetName(AIVehicle.GetEngineType(newveh)),1); }
INSTANCE.carrier.RouteAndStationVehicleCounterUpdate(roadidx);
if (!startdepot)	AIOrder.SkipToOrder(newveh, 1);
if (!AIVehicle.StartStopVehicle(newveh))
	{ DError("Cannot start the vehicle :",1); return false; }
// we skip first order to force the vehicle goes to destination station first

return true;
}

function cCarrier::CreateAirVehicle(roadidx)
// Build first vehicule of an air route
{
local road=INSTANCE.chemin.RListGetItem(roadidx);
local srcplace = AIStation.GetLocation(INSTANCE.builder.GetStationID(roadidx,true));
local dstplace = AIStation.GetLocation(INSTANCE.builder.GetStationID(roadidx,false));
local homedepot = INSTANCE.builder.GetDepotID(roadidx,true);
local cargoid = road.ROUTE.cargo_id;
if (!road.ROUTE.src_entry) // platform use no entry
	{
	srcplace = AIIndustry.GetHeliportLocation(road.ROUTE.src_place);
	homedepot = INSTANCE.builder.GetDepotID(roadidx,false);
	}
DInfo("srcplace="+srcplace+" dstplace="+dstplace,2);
PutSign(srcplace,"Route "+roadidx+" Source Airport ");
PutSign(dstplace,"Route "+roadidx+" Destination Airport");
local modele=AircraftType.EFFICIENT;
if (road.ROUTE.kind == 1000)	modele=AircraftType.BEST; // top speed/capacity for network
if (!road.ROUTE.src_entry)	modele=AircraftType.CHOPPER; // need a chopper
local veh = INSTANCE.carrier.ChooseAircraft(road.ROUTE.cargo_id,modele);
local price = AIEngine.GetPrice(veh);
if (veh == null)
	{ DError("Fail to pickup a vehicle",1); return false; }
INSTANCE.bank.RaiseFundsBy(price);
local firstveh = AIVehicle.BuildVehicle(homedepot, veh);
if (!AIVehicle.IsValidVehicle(firstveh))
	{ DWarn("Cannot buy the vehicle :",1); return false; }
else	{ DInfo("Just brought a new vehicle: "+AIVehicle.GetName(firstveh)+" "+AIEngine.GetName(AIVehicle.GetEngineType(firstveh)),1); }
//if (AIEngine.GetCargoType(veh) != cargoid) AIVehicle.RefitVehicle(firstveh, cargoid);
// no refit on aircrafts, we endup with only passengers aircraft, and ones that should do mail will stay different
// with the fastest engine
local firstorderflag = null;
local secondorderflag = null;
secondorderflag = AIOrder.AIOF_FULL_LOAD_ANY;
AIOrder.AppendOrder(firstveh, srcplace, secondorderflag);
AIOrder.AppendOrder(firstveh, dstplace, secondorderflag);
if (!road.ROUTE.src_entry)	AIOrder.SkipToOrder(firstveh, 1);
if (!AIVehicle.StartStopVehicle(firstveh)) { DError("Cannot start the vehicle:",1); }
AIGroup.MoveVehicle(road.ROUTE.group_id, firstveh);
INSTANCE.carrier.RouteAndStationVehicleCounterUpdate(roadidx);
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
local veh = INSTANCE.carrier.ChooseRoadVeh();
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
if (INSTANCE.route.route_type == RouteType.AIRSLAVE)	modele=AircraftType.BEST;
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

function cCarrier::ChooseRoadVeh()
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
vehlist.Valuate(AIEngine.CanRefitCargo, INSTANCE.route.cargoID);
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
	case RouteType.AIRSLAVE:
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

function cCarrier::GetMailCargo()
{
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist) {
		if (AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL) return cargo;
	}
	return null;
}

function cCarrier::GetPassengerCargo()
{
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist) {
		if (AICargo.GetTownEffect(cargo) == AICargo.TE_PASSENGERS) return cargo;
	}
	return null;
}

