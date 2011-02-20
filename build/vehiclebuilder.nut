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
	root = null;
static	DEPOT_SELL = 0;		// goto depot for selling
static	DEPOT_REPLACE = 1;	// to replace it
static	DEPOT_STOP = 2;		// to stop & wait in depot
static	DEPOT_SAVE = 3;		// to start
static	DEPOT_UPGRADE = 4;	// to upgrade engine
static	DEPOT_WAGON = 5;	// to add wagons
	DEPOT_RESTART = 6;	// force vehicle restart
	vehsavelist=null;	// our list of vehicles saved
	vehsaveactive=null;	// when true, we have some vehicles saved that need a restore
	vehnextprice=null;	// we just use that to upgrade vehicle
	AirportTypeLimit=null;  // can't make it a const, squirrel is so weird
	top_vehicle=null;	// the list of vehicle engine id we know cannot be upgrade

	constructor(that)
		{
		root=that;
		vehsavelist=[];
		vehsaveactive=false;
		vehnextprice=0;
		top_vehicle=AIList();
		AirportTypeLimit=[6, 15, 0, 30, 60, 0, 0, 140, 0]; // limit per airport type
		}
	}

function cCarrier::SaveVehicleAndDelete(veh)
// save a vehicle then delete it
{
if (!AIVehicle.IsValidVehicle(veh))	return false;
if (!AIVehicle.IsStoppedInDepot(veh))	return false;
local idx=root.carrier.VehicleFindRouteIndex(veh);
if (idx == -1) return false;
if (!root.carrier.vehsaveactive)	root.carrier.vehsaveactive=true;
root.carrier.vehsavelist.push(idx); // save it
DInfo("Saving vehicle from route "+idx,1);
root.carrier.VehicleSell(veh);
}

function cCarrier::RestoreSavedVehicle(veh)
// restore previously saved vehicle
{
local idx=null;
do	{
	idx=vehsavelist.pop;
	DInfo("Restoring vehicle from route "+idx,1);
	local road=root.chemin.GListGetItem(idx);
	local duplicate=true;
	if (road.ROUTE.vehicule == 0) duplicate=false;
	local success=root.carrier.BuildAndStartVehicle(idx,duplicate);
	if (success)	{ DInfo("Adding a vehicle to route #"+idx+" "+road.ROUTE.cargo_name+" from "+road.ROUTE.src_name+" to "+road.ROUTE.dst_name,1); }
	} while (vehsavelist.len()>0);
vehsaveactive=false;
}

function cCarrier::VehicleExists(veh)
// just return true if we own the vehicle
{
local vehlist=AIVehicleList();
if (vehlist.IsEmpty()) return false;
if (!vehlist.HasItem(veh)) return false;
return true;
}

function cCarrier::VehicleListFlag()
// flag list the vehicle
{
local vehlist=AIVehicleList();
if (vehlist.IsEmpty())	return;
foreach (i, dummy in vehlist)
	{
	DInfo("vehicle="+i+" dummy="+dummy+" name="+AIVehicle.GetName(i)+" type="+AIEngine.GetName(AIVehicle.GetEngineType(i)),2);
	}
}

function cCarrier::VehicleRemoveFlag(veh)
// Remove a flag from a vehicle
{
if (!cCarrier.VehicleExists(veh)) return false;
if (!cCarrier.VehicleIsFlag(veh)) return false;
local name=AIVehicle.GetName(veh);
name=name.slice(3);
local i=0;
while (!AIVehicle.SetName(veh,name))
	{
	name=i+name;
	i++;
	}
return true;
}

function cCarrier::VehicleIsFlag(veh)
// return true if we have a flag set on that vehicle
{
if (!cCarrier.VehicleExists(veh)) return false;
local name=AIVehicle.GetName(veh);
if (name.len() < 4) return false;
local ourID=""+AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)+"";
local sec="non";
local fir="non";
local thi="non";
fir=name.slice(0,1);
sec=name.slice(1,2);
thi=name.slice(2,3);
if (fir == ourID && thi == ourID) return true;
return false;
}

function cCarrier::VehicleGetFlag(veh)
// get the flag on a vehicle, and return it
{
if (!cCarrier.VehicleExists(veh)) return -1;
if (!cCarrier.VehicleIsFlag(veh)) return -1;
local name=AIVehicle.GetName(veh);
local val=name.slice(1,2);
//val.tointeger();
return val.tointeger();
}

function cCarrier::VehicleSetFlag(veh,flag)
// flag the vehicle
{
if (!cCarrier.VehicleExists(veh)) return false;
local ourID=""+AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)+"";
cCarrier.VehicleRemoveFlag(veh);
local name=AIVehicle.GetName(veh);
flag.tostring();
flag=ourID+flag+ourID+name;
return AIVehicle.SetName(veh,flag);
}

function cCarrier::CanAddNewVehicle(roadidx, start)
// check if we can add another vehicle at the start/end station of that route
{
local road=root.chemin.RListGetItem(roadidx);
local thatstation=null;
local thatentry=null;
if (start)	{ thatstation=root.chemin.GListGetItem(road.ROUTE.src_station);	}
else		{ thatstation=root.chemin.GListGetItem(road.ROUTE.dst_station);	}
local divisor=0;
switch (road.ROUTE.kind)
	{
	case AIVehicle.VT_ROAD:
		divisor=root.chemin.road_max / (3-thatstation.STATION.size);
		if (thatstation.STATION.type==0)
			{ // max size already
			if (thatstation.STATION.e_count+1 > divisor) return false; 
			// this limit us to road vehicle depending on the station size
			}
		else	{ // not yet upgrade
			// we have reach maximum vehicule count on a 1 station value, we must upgrade the station
			if (thatstation.STATION.e_count+1 > 8 && root.secureStart == 0)
			 // upgrade now if 8+ and if we're not still at game start, save properties costs
				{ if (!root.builder.RoadStationNeedUpgrade(roadidx,start)) return false; }
			if (thatstation.STATION.e_count+1 > root.chemin.road_max) return false;
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
			return root.builder.TrainStationNeedUpgrade(roadidx,start);
			}
	break;
	case AIVehicle.VT_WATER:
	if (thatstation.STATION.e_count+1 > root.chemin.water_max) return false;
	break;
	case AIVehicle.VT_AIR: // Airport upgrade is not related to number of aircrafts using them
		local aircraftMax=root.chemin.air_max; // max aircraft for non network airport
		local aircraftCurrent=thatstation.STATION.e_count+1; // number of aircraft for non network airport
		local currAirport=root.builder.GetAirportType();
		local maxperairport=root.carrier.AirportTypeLimit[currAirport];
		DInfo("currAirportType="+currAirport+" limit/airport="+maxperairport,2);
		if (road.ROUTE.kind==1000)
			{ // in the network
			aircraftCurrent=root.chemin.airnet_count+1;
			aircraftMax=root.chemin.airnet_max * (root.chemin.virtual_air.len()-1);
			}
		if (aircraftMax > maxperairport)	aircraftMax=maxperairport; // per airport type limitation
		DInfo("Limit for aircraft "+aircraftCurrent+"/"+aircraftMax,2);
		if (aircraftCurrent > aircraftMax) return false;
	break;
	}
return true;
}

function cCarrier::CloneRoadVehicle(roadidx)
// add another vehicule on that route, sharing orders
{
local road=root.chemin.RListGetItem(roadidx);
local vehlist=AIVehicleList_Group(road.ROUTE.groupe_id);
vehlist.Valuate(AIOrder.IsGotoDepotOrder,AIOrder.ORDER_CURRENT);
vehlist.KeepValue(0);
if (vehlist.IsEmpty())
	{
	DInfo("Can't find any vehicle to duplicated on that route",1);
	return false;
	}
// first check we can add one more vehicle to start or ending station
if (!root.carrier.CanAddNewVehicle(roadidx,true) || !root.carrier.CanAddNewVehicle(roadidx,false))
	{
	DInfo("One station on that route is full, cannot add more vehicle",1);
	return false;
	}
local veh=vehlist.Begin();
local price = AIEngine.GetPrice(AIVehicle.GetEngineType(veh));
root.bank.RaiseFundsBy(price);
local startdepot=true;
local switcher=false;
if (AICargo.GetTownEffect(road.ROUTE.cargo_id)==AICargo.TE_PASSENGERS || AICargo.GetTownEffect(road.ROUTE.cargo_id)==AICargo.TE_MAIL)
	{ switcher = true; }

if (road.ROUTE.vehicule%2 != 0 && switcher) // impair vehicule selection, because impair+1 = pair :)
	{ startdepot=false; }
/*if (road.ROUTE.kind == AIVehicle.VT_ROAD && AICargo.GetTownEffect(road.ROUTE.cargo_id) == AICargo.TE_PASSENGERS)
	{ startdepot=false; }*/ // we are creating a new bus, we don't really care where it will start
// but it's a good idea to build it at destination, and route it directly to destination station

local newveh=AIVehicle.CloneVehicle(root.builder.GetDepotID(roadidx,startdepot),veh,true);
if (!AIVehicle.IsValidVehicle(newveh))
	{ DError("Cannot buy the vehicle :"+price,2); return false; }
else	{ DInfo("Just brought a new vehicle: "+AIVehicle.GetName(newveh),1); }
root.carrier.RouteAndStationVehicleCounterUpdate(roadidx);
if (!AIVehicle.StartStopVehicle(newveh))
	{ DError("Cannot start the vehicle :",1); return false; }
if (!startdepot)	AIOrder.SkipToOrder(newveh, 1);
// we skip first order to force the vehicle goes to destination station first
return true;
}

function cCarrier::BuildAndStartVehicle(idx,duplicate)
// Create a new vehicle on route or duplicate one
{
local road=root.chemin.RListGetItem(idx);
local res=true;
switch (road.ROUTE.kind)
	{
	case AIVehicle.VT_ROAD:
	if (duplicate)	res=root.carrier.CloneRoadVehicle(idx);
		else	res=root.carrier.CreateRoadVehicle(idx);
	break;
	case AIVehicle.VT_RAIL:
	if (duplicate)	{ } //root.carrier.CloneRoadVehicle(idx);
		else	res=root.carrier.CreateRailVehicle(idx);
	break;
	case AIVehicle.VT_WATER:
	break;
	case AIVehicle.VT_AIR:
	if (duplicate)	{ res=root.carrier.CloneAirVehicle(idx); }
		else	{ res=root.carrier.CreateAirVehicle(idx); }
	break;
	case 1000:
	if (duplicate)	{ res=root.carrier.CloneAirVehicle(idx); }
		else	{ res=root.carrier.CreateAirVehicle(idx); }
	break;
	}
return res;
}

function cCarrier::RouteAndStationVehicleCounterUpdate(roadidx)
// Update the route and stations vehicle counters
{
local road=root.chemin.RListGetItem(roadidx);
local entry=true;
local station_id=0;
local station=null;
local vehgroup=null;
if (road.ROUTE.groupe_id > -1)
	{
	vehgroup=AIVehicleList_Group(road.ROUTE.groupe_id);
	road.ROUTE.vehicule=vehgroup.Count();
	}
else	road.ROUTE.vehicule=0;

station=root.chemin.GListGetItem(road.ROUTE.src_station);
vehgroup=AIVehicleList_Station(station.STATION.station_id);
entry=road.ROUTE.src_entry;
if (entry)	{ station.STATION.e_count=vehgroup.Count(); }
	else	{ station.STATION.s_count=vehgroup.Count(); }
root.chemin.GListUpdateItem(road.ROUTE.src_station,station);
station=root.chemin.GListGetItem(road.ROUTE.dst_station);
vehgroup=AIVehicleList_Station(station.STATION.station_id);
entry=road.ROUTE.dst_entry;
if (entry)	{ station.STATION.e_count=vehgroup.Count(); }
	else	{ station.STATION.s_count=vehgroup.Count(); }
root.chemin.GListUpdateItem(road.ROUTE.dst_station,station);
root.chemin.RListUpdateItem(roadidx,road);
}

function cCarrier::CreateRoadVehicle(roadidx)
// Build first vehicule of a road
{
local road=root.chemin.RListGetItem(roadidx);
local srcplace = AIStation.GetLocation(root.builder.GetStationID(roadidx,true));
local dstplace = AIStation.GetLocation(root.builder.GetStationID(roadidx,false));
local cargoid= road.ROUTE.cargo_id;
local veh = root.carrier.ChooseRoadVeh(cargoid);
local homedepot = root.builder.GetDepotID(roadidx,true);
local price = AIEngine.GetPrice(veh);
if (veh == null)
	{ DError("Fail to pickup a vehicle",1); return false; }
root.bank.RaiseFundsBy(price*2);
local firstveh = AIVehicle.BuildVehicle(homedepot, veh);
if (!AIVehicle.IsValidVehicle(firstveh))
	{ DError("Cannot buy the vehicle :",1); return false; }
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
AIGroup.MoveVehicle(road.ROUTE.groupe_id, firstveh);
AIOrder.AppendOrder(firstveh, srcplace, firstorderflag);
AIOrder.AppendOrder(firstveh, dstplace, secondorderflag);
if (!AIVehicle.StartStopVehicle(firstveh)) { DError("Cannot start the vehicle:",1); }
root.carrier.RouteAndStationVehicleCounterUpdate(roadidx);
return true;
}

function cCarrier::CloneAirVehicle(roadidx)
// add another vehicule on that route, sharing orders
{
local road=root.chemin.RListGetItem(roadidx);
local vehlist=AIVehicleList_Group(road.ROUTE.groupe_id);
if (vehlist.IsEmpty())
	{
	DInfo("Can't find any vehicle to duplicated on that route",1);
	return false;
	}
// first check we can add one more vehicle to start or ending station
if (!root.carrier.CanAddNewVehicle(roadidx,true) || !root.carrier.CanAddNewVehicle(roadidx,false))
	{
	DInfo("One airport is full, cannot add more aircrafts",1);
	return false;
	}
local veh=vehlist.Begin();
local price = AIEngine.GetPrice(AIVehicle.GetEngineType(veh));
root.bank.RaiseFundsBy(price);
local startdepot=true;
local switcher=true;
if (road.ROUTE.vehicule%2 != 0 && switcher) // impair vehicule selection, because impair+1 = pair :)
	{ startdepot=false; }
// but it's a good idea to build it at destination, and route it directly to destination station
if (!road.ROUTE.src_entry)	startdepot=false;
local newveh=AIVehicle.CloneVehicle(root.builder.GetDepotID(roadidx,startdepot),veh,true);
if (!AIVehicle.IsValidVehicle(newveh))
	{ DError("Cannot buy the vehicle :"+price,2); return false; }
else	{ DInfo("Just brought a new vehicle: "+AIVehicle.GetName(newveh)+" "+AIEngine.GetName(AIVehicle.GetEngineType(newveh)),1); }
root.carrier.RouteAndStationVehicleCounterUpdate(roadidx);
if (!startdepot)	AIOrder.SkipToOrder(newveh, 1);
if (!AIVehicle.StartStopVehicle(newveh))
	{ DError("Cannot start the vehicle :",1); return false; }
// we skip first order to force the vehicle goes to destination station first

return true;
}

function cCarrier::CreateAirVehicle(roadidx)
// Build first vehicule of an air route
{
local road=root.chemin.RListGetItem(roadidx);
local srcplace = AIStation.GetLocation(root.builder.GetStationID(roadidx,true));
local dstplace = AIStation.GetLocation(root.builder.GetStationID(roadidx,false));
local homedepot = root.builder.GetDepotID(roadidx,true);
local cargoid = road.ROUTE.cargo_id;
if (!road.ROUTE.src_entry) // platform use no entry
	{
	srcplace = AIIndustry.GetHeliportLocation(road.ROUTE.src_place);
	homedepot = root.builder.GetDepotID(roadidx,false);
	}
DInfo("srcplace="+srcplace+" dstplace="+dstplace,2);
PutSign(srcplace,"Route "+roadidx+" Source Airport ");
PutSign(dstplace,"Route "+roadidx+" Destination Airport");
local modele=AircraftType.EFFICIENT;
if (road.ROUTE.kind == 1000)	modele=AircraftType.BEST; // top speed/capacity for network
if (!road.ROUTE.src_entry)	modele=AircraftType.CHOPPER; // need a chopper
local veh = root.carrier.ChooseAircraft(road.ROUTE.cargo_id,modele);
local price = AIEngine.GetPrice(veh);
if (veh == null)
	{ DError("Fail to pickup a vehicle",1); return false; }
root.bank.RaiseFundsBy(price);
local firstveh = AIVehicle.BuildVehicle(homedepot, veh);
if (!AIVehicle.IsValidVehicle(firstveh))
	{ DError("Cannot buy the vehicle :",1); return false; }
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
AIGroup.MoveVehicle(road.ROUTE.groupe_id, firstveh);
root.carrier.RouteAndStationVehicleCounterUpdate(roadidx);
return true;
}

function cCarrier::GetRailVehicle(idx)
// get a rail vehicle
{
local road= root.chemin.RListGetItem(idx);
local veh = root.carrier.ChooseRailVeh(idx);
if (veh == null)	{
			DInfo("No suitable train to buy !",1);
			road=root.chemin.RouteMalusHigher(road);
			root.chemin.RListUpdateItem(root.chemin.nowJob,road);
			return false;
			}
DInfo("Choosen train: "+AIEngine.GetName(veh),2);
return true;
}

function cCarrier::GetRoadVehicle(idx)
// get a road vehicle
{
local road= root.chemin.RListGetItem(idx);
local veh = root.carrier.ChooseRoadVeh(road.ROUTE.cargo_id);
if (veh == null)	{
			DInfo("No suitable road vehicle to buy !",1);
			road=root.chemin.RouteMalusHigher(road);
			root.chemin.RListUpdateItem(idx,road);
			return false;
			}
DInfo("Choosen vehicule: "+AIEngine.GetName(veh),2);
return true;
}

function cCarrier::GetAirVehicle(idx)
// get an aircraft
{
local road= root.chemin.RListGetItem(idx);
local modele=AircraftType.EFFICIENT;
if (road.ROUTE.kind == 1000)	modele=AircraftType.BEST;
if (!road.ROUTE.src_entry)	modele=AircraftType.CHOPPER;
local veh = root.carrier.ChooseAircraft(road.ROUTE.cargo_id,modele);
if (veh == null)	{
			if (road.ROUTE.src_entry)	DInfo("No suitable aircraft to buy !",1);
				else	DInfo("No suitable choppers to buy !");
			road=root.chemin.RouteMalusHigher(road);
			root.chemin.RListUpdateItem(idx,road);
			return false;
			}
DInfo("Choosen aircraft: "+AIEngine.GetName(veh),2);
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

function cCarrier::ChooseRoadVeh(cargo)
/**
* Pickup a road vehicle base on -> max capacity > max speed > max reliability
* @param cargo the cargo we should carry
* @return the vehicle engine id
*/
{
local vehlist = AIEngineList(AIVehicle.VT_ROAD);
vehlist.Valuate(AIEngine.GetRoadType);
vehlist.KeepValue(AIRoad.ROADTYPE_ROAD);
vehlist.Valuate(AIEngine.IsArticulated);
vehlist.KeepValue(0);
vehlist.Valuate(AIEngine.CanRefitCargo, cargo);
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
		{ DInfo("No wagons can transport that cargo.",1); return null; }
	return wagonlist.Begin();
}

function cCarrier::ChooseRailVeh(idx)
{
local vehlist = AIEngineList(AIVehicle.VT_RAIL);
vehlist.Valuate(AIEngine.HasPowerOnRail, AIRail.GetCurrentRailType());
vehlist.KeepValue(1);
vehlist.Valuate(AIEngine.IsWagon);
vehlist.KeepValue(0);
vehlist.Valuate(AIEngine.GetMaxSpeed);
DInfo("vehicule found: "+vehlist.Count(),2);
local veh = null;
local fast=null;
local slow=null;
if (vehlist.Count() > 0)
	{
	fast=vehlist.Begin();
	while (vehlist.HasNext())	{ slow=vehlist.Next(); }
	DInfo("Cheap engine: "+AIEngine.GetName(slow)+" Best engine: "+AIEngine.GetName(fast),2);
	}
if (root.chemin.buildmode)	{ veh=fast; }
		else	{ veh=slow; }
return veh;
}

function cCarrier::GetVehicle(idx)
// Get current choosen vehicle, reroute depending on road type
{
local what=root.chemin.RListGetItem(idx);
local success=false;
switch (what.ROUTE.kind)
	{
	case AIVehicle.VT_ROAD:
	success=root.carrier.GetRoadVehicle(idx);
	break;
	case AIVehicle.VT_RAIL:
	success=root.carrier.GetRailVehicle(idx);
	break;
	/*case AIVehicle.VT_WATER:*/
	break;
	case AIVehicle.VT_AIR:
	success=root.carrier.GetAirVehicle(idx);
	break;
	}
return success;
}

function cCarrier::CreateRailVehicle(roadidx)
{
local road=root.chemin.RListGetItem(roadidx);
local real_src_id=root.chemin.GListGetItem(road.ROUTE.src_station);
local srcplace = real_src_id.STATION.station_id; // train real station is there
DInfo("src station is valid :"+AIStation.IsValidStation(srcplace),1);
local real_dst_id=root.chemin.GListGetItem(road.ROUTE.dst_station);
local dstplace = real_dst_id.STATION.station_id;
DInfo("dst station is valid :"+AIStation.IsValidStation(dstplace),1);
local cargoid= road.ROUTE.cargo_id;
local veh = root.carrier.ChooseRailVeh(roadidx);
local wagon = root.carrier.ChooseWagon(road.ROUTE.cargo_id);
local homedepot = real_src_id.STATION.e_depot;
local price = AIEngine.GetPrice(veh);
price+=AIEngine.GetPrice(wagon)*5;
local length = 5;
DInfo("Stationid: "+srcplace+" "+AIStation.GetName(srcplace),2);
DInfo("Depotid: "+homedepot,2);
if (veh == null) return false;
if (!root.bank.RaiseFundsBy(price))
	{
	DInfo("I don't have enough money to buy that train and its wagons "+AIEngine.GetName(veh),1);
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
	{ DInfo("Fail to set order !!!"+AIError.GetLastErrorString(),1); }
if (!AIOrder.AppendOrder(trainengine, AIStation.GetLocation(dstplace), AIOrder.AIOF_NON_STOP_INTERMEDIATE))
	{ DInfo("Fail to set order !!!"+AIError.GetLastErrorString(),1); }
DInfo("orders set",1);
if (!AIVehicle.StartStopVehicle(trainengine))
	{ DInfo(AIVehicle.GetName(trainengine)+" refuse to start !!!"+AIError.GetLastErrorString(),1); }
AIGroup.MoveVehicle(road.ROUTE.groupe_id, trainengine);
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

