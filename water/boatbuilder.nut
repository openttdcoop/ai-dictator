/* -*- Mode: C++; tab-width: 4 -*- */
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


function cCarrier::GetWaterVehicle(routeidx, cargo = -1)
// return the vehicle we will pickup if we build a vehicle on that route
{
	local object = cEngineLib.Infos();
	object.cargo_id = cargo;
	object.engine_type = AIVehicle.VT_WATER;
	if (cargo == -1)
		{
		local road = cRoute.LoadRoute(routeidx);
		if (!road)	return -1;
		object.cargo_id = road.CargoID;
		object.depot = cRoute.GetDepot(routeidx);
		}
	local veh = cEngineLib.GetBestEngine(object, cCarrier.VehicleFilterWater);
	return veh[0];
}

function cCarrier::CreateWaterVehicle(routeidx)
// Build an aircraft
{
	if (!INSTANCE.use_boat)	return false;
	local road = cRoute.LoadRoute(routeidx);
	if (!road)	return false;
	local engineID = cCarrier.GetWaterVehicle(routeidx);
	if (engineID == -1)	{ DWarn("Cannot find any boats to transport that cargo "+cCargo.GetCargoLabel(road.CargoID),1); return false; }
	local srcplace = road.SourceStation.s_Location;
	local dstplace = road.TargetStation.s_Location;
	local homedepot = cStation.GetStationDepot(road.SourceStation.s_ID);
	local altplace=(road.Twoway && road.VehicleCount > 0 && road.VehicleCount % 2 != 0);
	if (altplace)	homedepot = cStation.GetStationDepot(road.TargetStation.s_ID);
	if (!cEngineLib.IsDepotTile(homedepot))
            {
            homedepot = cRoute.GetDepot(routeidx);
            if (!cEngineLib.IsDepotTile(homedepot))   return false;
            }
	local price = AIEngine.GetPrice(engineID);
	local vehID = cEngineLib.VehicleCreate(homedepot, engineID, road.CargoID);
	if (vehID != -1)
			{
			DInfo("Just brought a new boat: "+cCarrier.GetVehicleName(vehID),0);
            INSTANCE.main.carrier.vehicle_cash -= price;
			}
    else	{
			DError("Cannot create the boat "+cEngine.GetEngineName(engineID),2);
			return false;
			}
	AIGroup.MoveVehicle(road.GroupID, vehID);
	cCarrier.VehicleSetOrders(vehID);
	if (altplace)	cEngineLib.VehicleOrderSkipCurrent(vehID);
	if (!cCarrier.StartVehicle(vehID))  {
                                        DError("Cannot start the vehicle: "+cCarrier.GetVehicleName(vehID),2);
                                        cCarrier.VehicleSell(vehID, false);
                                        return false;
                                        }
	road.VehicleCount++;
	return true;
}
