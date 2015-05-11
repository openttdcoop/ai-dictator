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

function cCarrier::GetAirVehicle(routeidx, cargo = -1, modele = AircraftType.EFFICIENT)
// return the vehicle we will pickup if we build a vehicle on that route
// if eff = -1, get info from the routeidx, else we're in guess mode
{
	local object = cEngineLib.Infos();
	object.cargo_id = cargo;
	object.engine_type = AIVehicle.VT_AIR;
	if (cargo == -1)
		{
		local road = cRoute.LoadRoute(routeidx);
		if (!road)	return -1;
		if (road.VehicleType == RouteType.AIRNET || road.VehicleType == RouteType.AIRNETMAIL)	modele=AircraftType.BEST; // top speed/capacity for network
		if (road.SourceStation.s_SubType == AIAirport.AT_SMALL || road.TargetStation.s_SubType == AIAirport.AT_SMALL)	modele=20; // small
		if (road.VehicleType == RouteType.CHOPPER)	modele=AircraftType.CHOPPER; // need a chopper
		object.cargo_id = road.CargoID;
		object.depot = cRoute.GetDepot(routeidx);
		}
	object.bypass = modele; //passing wanted modele thru bypass
	local veh = cEngineLib.GetBestEngine(object, cCarrier.VehicleFilterAir);
	return veh[0];
}

function cCarrier::CreateAirVehicle(routeidx)
// Build an aircraft
{
	if (!INSTANCE.use_air)	return false;
	local road = cRoute.LoadRoute(routeidx);
	if (!road)	return false;
	local engineID = cCarrier.GetAirVehicle(routeidx);
	if (engineID == -1)	{ DWarn("Cannot find any aircraft to transport that cargo "+cCargo.GetCargoLabel(road.CargoID),1); return false; }
	local srcplace = road.SourceStation.s_Location;
	local dstplace = road.TargetStation.s_Location;
	local homedepot = road.SourceStation.s_Depot;
	local altplace=(road.Twoway && road.VehicleCount > 0 && road.VehicleCount % 2 != 0);
	if (road.VehicleType == RouteType.CHOPPER)	altplace=true; // chopper don't have a source airport, but a platform
	if (altplace)	homedepot = road.TargetStation.s_Depot;
	if (!cStation.IsDepot(homedepot))
            {
            homedepot = cRoute.GetDepot(routeidx);
            if (!cStation.IsDepot(homedepot))    return false;
            }
	local price = AIEngine.GetPrice(engineID);
	local vehID = cEngineLib.VehicleCreate(homedepot, engineID, -1); // force no refit
	if (vehID != -1)
			{
			DInfo("Just brought a new aircraft vehicle: "+cCarrier.GetVehicleName(vehID),0);
            INSTANCE.main.carrier.vehicle_cash -= price;
            INSTANCE.main.carrier.highcostAircraft = 0;
			}
		else	{
			DError("Cannot create the aircraft vehicle "+cEngine.GetEngineName(engineID),2);
			return false;
			}
	// no refit on aircrafts, we endup with only passengers aircraft, and ones that should do mail will stay different
	// as their engine is the fastest always
	AIGroup.MoveVehicle(road.GroupID, vehID);
	cCarrier.VehicleSetOrders(vehID);
	if (altplace)	cEngineLib.VehicleOrderSkipCurrent(vehID);
	if (!cCarrier.StartVehicle(vehID)) { DError("Cannot start the vehicle: "+cCarrier.GetVehicleName(vehID),2); cCarrier.VehicleSell(vehID, false); return false;}
	road.VehicleCount++;
	return true;
}

function cCarrier::AircraftIsChopper(vehicle)
// return true if we are a chopper
{
	local vehlist = cEngineLib.GetEngineList(AIVehicle.VT_AIR);
	vehlist.Valuate(AIEngine.GetPlaneType);
	vehlist.KeepValue(AIAirport.PT_HELICOPTER);
	local vehengine=AIVehicle.GetEngineType(vehicle);
	return vehlist.HasItem(vehengine);
}

