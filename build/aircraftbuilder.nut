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

function cCarrier::CreateAircraftEngine(engineID, depot)
// Really create the engine and return it's ID if success
// return -1 on error
{
local price=cEngine.GetPrice(engineID);
INSTANCE.bank.RaiseFundsBy(price);
local vehID=AIVehicle.BuildVehicle(depot, engineID);
if (AIVehicle.IsValidVehicle(vehID))	return vehID;
						else	{
							DError("Cannot create the air vehicle ",2,"cCarrier::CreateAircraftEngine");
							return -1;
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
//DInfo("srcplace="+srcplace+" dstplace="+dstplace,2);
//PutSign(srcplace,"Route "+routeidx+" Source Airport ");
//PutSign(dstplace,"Route "+routeidx+" Destination Airport");
local veh = INSTANCE.carrier.GetAirVehicle(routeidx);
if (veh == null)
	{ DError("Cannot pickup an aircraft",1,"cCarrier::CreateAirVehicle"); return false; }
local price = AIEngine.GetPrice(veh);
INSTANCE.bank.RaiseFundsBy(price);
local firstveh = cCarrier.CreateAircraftEngine(veh, homedepot);
if (firstveh == -1)	{ DError("Cannot create the vehicle "+veh,2,"cCarrier::CreateAirVehicle"); return false; }
			else	{ DInfo("Just brought a new aircraft: "+AIVehicle.GetName(firstveh)+" "+AIEngine.GetName(AIVehicle.GetEngineType(firstveh)),0,"cCarrier::CreateAirVehicle"); }
// no refit on aircrafts, we endup with only passengers aircraft, and ones that should do mail will stay different
// as thir engine is the fastest always
local firstorderflag = null;
local secondorderflag = null;
secondorderflag = AIOrder.AIOF_NONE;
AIOrder.AppendOrder(firstveh, srcplace, secondorderflag);
AIOrder.AppendOrder(firstveh, dstplace, secondorderflag);
AIGroup.MoveVehicle(road.groupID, firstveh);
if (altplace)	INSTANCE.carrier.VehicleOrderSkipCurrent(firstveh);
if (!AIVehicle.StartStopVehicle(firstveh)) { DError("Cannot start the vehicle:",2,"cCarrier::CreateAirVehicle"); }
cEngine.VehicleIsTop(firstveh, road.route_type);
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
vehlist.Valuate(AIEngine.IsBuildable);
vehlist.KeepValue(1);
local passCargo=cCargo.GetPassengerCargo();
vehlist.Valuate(AIEngine.CanRefitCargo, passCargo);
vehlist.KeepValue(1);
vehlist.Valuate(AIEngine.GetMaxSpeed);
vehlist.KeepAboveValue(45); // some newgrf use weird unplayable aircrafts (for our distance usage)
local special=0;
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
		vehlist.Valuate(cCarrier.GetEngineEfficiency, passCargo);
		vehlist.Sort(AIList.SORT_BY_VALUE,true);
		if (AICargo.GetTownEffect(cargo) == cCargo.GetMailCargo())
			{
			vehlist.Valuate(AIEngine.GetMaxSpeed);
			vehlist.Sort(AIList.SORT_BY_VALUE,false);
			}
		special=RouteType.AIR;
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
				vehlist.Valuate(cCarrier.GetEngineEfficiency, passCargo);
				vehlist.Sort(AIList.SORT_BY_VALUE,true);
				}
		special=RouteType.AIRNET;
	break;
	case	AircraftType.CHOPPER: // top efficient chopper
		vehlist.Valuate(AIEngine.GetPlaneType);
		vehlist.KeepValue(AIAirport.PT_HELICOPTER);
		vehlist.Valuate(cCarrier.GetEngineEfficiency, passCargo);
		vehlist.Sort(AIList.SORT_BY_VALUE,true);
		special=RouteType.CHOPPER;
	break;
	}
if (!vehlist.IsEmpty())	cEngine.EngineIsTop(vehlist.Begin(), special, true); // set top engine for aircraft
return (vehlist.IsEmpty()) ? null : vehlist.Begin();
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


