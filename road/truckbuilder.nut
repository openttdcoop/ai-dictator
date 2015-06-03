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

function cCarrier::GetRoadVehicle(routeidx, cargoID = -1)
// return the vehicle we will pickup if we try to build a vehicle on that route
{
	local object = cEngineLib.Infos();
	object.cargo_id = cargoID;
	object.engine_type = AIVehicle.VT_ROAD;
	object.engine_roadtype = AIRoad.ROADTYPE_ROAD;
	if (cargoID == -1)
		{
		local road=cRoute.LoadRoute(routeidx);
		if (!road)	return -1;
		object.cargo_id = road.CargoID;
		object.depot = cRoute.GetDepot(routeidx);
		}
	local veh = cEngineLib.GetBestEngine(object, cCarrier.VehicleFilterRoad);
	return veh[0];
}

function cCarrier::CreateRoadVehicle(roadidx)
// Build a road vehicle for route roadidx
// return true/false
{
	if (!INSTANCE.use_road)	return false;
	local road=cRoute.LoadRoute(roadidx);
	if (!road)	return false;
	local engineID = cCarrier.GetRoadVehicle(roadidx);
	if (engineID == -1)	{ DWarn("Cannot find any road vehicle to transport that cargo "+cCargo.GetCargoLabel(road.CargoID),1); return false; }
	local homedepot = cStation.GetStationDepot(road.SourceStation.s_ID);
	local srcplace = road.SourceStation.s_Location;
	local dstplace = road.TargetStation.s_Location;
	local altplace=(road.Twoway && road.VehicleCount > 0 && road.VehicleCount % 2 != 0);
	if (altplace)   { homedepot = cStation.GetStationDepot(road.TargetStation.s_ID); }
	if (!cEngineLib.IsDepotTile(homedepot))
            {
            homedepot = cRoute.GetDepot(roadidx);
            if (!cEngineLib.IsDepotTile(homedepot))   { return false; }
            }
	local price=AIEngine.GetPrice(engineID);
	local vehID = cEngineLib.VehicleCreate(homedepot, engineID, road.CargoID);
	if (vehID != -1)
			{
			DInfo("Just brought a new road vehicle: "+cCarrier.GetVehicleName(vehID),0);
			INSTANCE.main.carrier.vehicle_cash -= price;
			}
		else	{
			DError("Cannot create the road vehicle "+cEngine.GetEngineName(engineID)+" Cargo="+cCargo.GetCargoLabel(road.CargoID)+" depot="+cMisc.Locate(homedepot),2);
			return false;
			}
	AIGroup.MoveVehicle(road.GroupID, vehID);
	cCarrier.VehicleSetOrders(vehID);
	if (altplace)	{ cEngineLib.VehicleOrderSkipCurrent(vehID); }
	road.VehicleCount++;
	if (!cCarrier.StartVehicle(vehID)) { DError("Cannot start the vehicle:",2); cCarrier.VehicleSell(vehID, false); return false; }
	cEngine.CheckMaxSpeed(engineID);
	return true;
}

