/* -*- Mode: C++; tab-width: 6 -*- */ 
/**
 *    This file is part of DictatorAI
 *    (c) krinn@chez.com
 *
 *    It's free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 2 of the License, or
 *    any later version.
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
INSTANCE.main.bank.RaiseFundsBy(price);
local vehID=AIVehicle.BuildVehicle(depot, engineID);
if (!AIVehicle.IsValidVehicle(vehID))	{
							DError("Cannot create the air vehicle ",2);
							return -1;
							}
INSTANCE.main.carrier.vehnextprice-=price;
if (INSTANCE.main.carrier.vehnextprice < 0)	INSTANCE.main.carrier.vehnextprice=0;
return vehID;
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
local veh = INSTANCE.main.carrier.GetAirVehicle(routeidx);
if (veh == null)
	{ DError("Cannot pickup an aircraft",1); return false; }
local price = AIEngine.GetPrice(veh);
INSTANCE.main.bank.RaiseFundsBy(price);
local firstveh = cCarrier.CreateAircraftEngine(veh, homedepot);
if (firstveh == -1)	{ DError("Cannot create the vehicle "+veh,2); return false; }
			else	{ DInfo("Just brought a new aircraft: "+cCarrier.VehicleGetName(firstveh)+" "+AIEngine.GetName(AIVehicle.GetEngineType(firstveh)),0); }
// no refit on aircrafts, we endup with only passengers aircraft, and ones that should do mail will stay different
// as thir engine is the fastest always
local firstorderflag = null;
local secondorderflag = null;
secondorderflag = AIOrder.OF_NONE;
AIOrder.AppendOrder(firstveh, srcplace, secondorderflag);
AIOrder.AppendOrder(firstveh, dstplace, secondorderflag);
AIGroup.MoveVehicle(road.groupID, firstveh);
if (altplace)	INSTANCE.main.carrier.VehicleOrderSkipCurrent(firstveh);
if (!cCarrier.StartVehicle(firstveh)) { DError("Cannot start the vehicle:",2); }
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

function cCarrier::ChooseAircraft(cargo, distance, airtype=0)
// build an aircraft base on cargo
// distance is now need because of newGRF distance limit for aircraft
// airtype = 0=efficiency, 1=best, 2=chopper
// We can endup with 7+ different type of aircrafts running, now even more because of distance limit in newGRF :/
{
local vehlist = AIEngineList(AIVehicle.VT_AIR);
vehlist.Valuate(AIEngine.IsBuildable);
vehlist.KeepValue(1);
//vehlist.Valuate(AIEngine.GetMaximumOrderDistance);
//vehlist.KeepValue(distance); // Add for newGRF distance limit
vehlist.Valuate(cEngine.IsEngineBlacklist);
vehlist.KeepValue(0);
local passCargo=cCargo.GetPassengerCargo();
vehlist.Valuate(AIEngine.CanRefitCargo, passCargo);
vehlist.KeepValue(1);
vehlist.Valuate(AIEngine.GetMaxSpeed);
vehlist.KeepAboveValue(45); // some newgrf use weird unplayable aircrafts (for our distance usage)
local special=0;
local limitsmall=false;
local fastengine=false;
if (airtype >= 20)
	{
	airtype-=20; // this will get us back to original aircraft type
	if (airtype > 1)	airtype=0; // force EFFICIENT for small aircraft only
	limitsmall=true;
	}
switch (airtype)
	{
	case	AircraftType.EFFICIENT: // top efficient aircraft for passenger and top speed (not efficient) for mail
	// top efficient aircraft is generally the same as top capacity/efficient one
		vehlist.Valuate(AIEngine.GetMaxSpeed);
		vehlist.RemoveBelowValue(65); // remove too dumb aircraft 65=~250km/h
		vehlist.Valuate(cEngine.GetCapacity, passCargo)
		vehlist.RemoveBelowValue(30);
		if (limitsmall) // small ones
			{
			vehlist.Valuate(AIEngine.GetPlaneType);
			vehlist.KeepValue(AIAirport.PT_SMALL_PLANE);
			special=RouteType.SMALLAIR;
			}
		else	special=RouteType.AIR;
		if (AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL)
			{ // mail/fast ones
			vehlist.Valuate(AIEngine.GetMaxSpeed);
			special++; // AIRMAIL OR SMALLAIR
			vehlist.Sort(AIList.SORT_BY_VALUE,false);
			vehlist.KeepTop(5); // best fastest engine out of the 5 top fast one
			}
		else	{
			vehlist.Valuate(AIEngine.GetCapacity);
			vehlist.Sort(AIList.SORT_BY_VALUE,false);
			vehlist.KeepTop(5);
			}
		vehlist.Valuate(cCarrier.GetEngineEfficiency, passCargo); // passenger/big ones
		vehlist.Sort(AIList.SORT_BY_VALUE,true);
	break;
	case	AircraftType.BEST:
		special=RouteType.AIRNET;
		if (AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL) // fast aircraft
			{
			special++; //AIRNETMAIL
			fastengine=true;
			}
			vehlist.Valuate(cCarrier.GetEngineRawEfficiency, passCargo, fastengine);	// keep top raw efficiency out of remain ones
			vehlist.Sort(AIList.SORT_BY_VALUE,true);					// for fast aircrafts only 5 choices, but big aircrafts have plenty choices
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
if (!vehlist.IsEmpty())	print("aircraft="+cEngine.GetName(vehlist.Begin())+" r_dist="+distance+" r_distSQ="+(distance*distance)+" e_dist="+AIEngine.GetMaximumOrderDistance(vehlist.Begin()));
return (vehlist.IsEmpty()) ? null : vehlist.Begin();
}

function cCarrier::GetAirVehicle(routeidx)
// return the vehicle we will pickup if we to build a vehicle on that route
{
local road=cRoute.GetRouteObject(routeidx);
if (road == null)	return null;
local modele=AircraftType.EFFICIENT;
if (road.route_type == RouteType.AIRNET || road.route_type == RouteType.AIRNETMAIL)	modele=AircraftType.BEST; // top speed/capacity for network
if (road.source.specialType == AIAirport.AT_SMALL || road.target.specialType == AIAirport.AT_SMALL)	modele+=20;
if (road.route_type == RouteType.CHOPPER)	modele=AircraftType.CHOPPER; // need a chopper
local veh = INSTANCE.main.carrier.ChooseAircraft(road.cargoID, road.distance, modele);
return veh;
}


