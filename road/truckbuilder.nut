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
		local road=cRoute.Load(routeidx);
		if (!road)	return -1;
		object.cargo_id = road.CargoID;
		object.depot = cRoute.GetDepot(routeidx);
		}
	local veh = cEngineLib.GetBestEngine(object, cCarrier.VehicleFilterRoad);
	print("Selected road engine = "+veh[0]+" * "+AIEngine.GetName(veh[0]));
	return veh[0];
}

function cCarrier::CreateRoadVehicle(roadidx)
// Build a road vehicle for route roadidx
// return true/false
{
	if (!INSTANCE.use_road)	return false;
	local road=cRoute.Load(roadidx);
	if (!road)	return false;
	local engineID = cCarrier.GetRoadVehicle(roadidx);
	if (engineID == -1)	{ DWarn("Cannot find any road vehicle to transport that cargo "+cCargo.GetCargoLabel(road.CargoID),1); return false; }
	local homedepot = cRoute.GetDepot(roadidx);
	local srcplace = road.SourceStation.s_Location;
	local dstplace = road.TargetStation.s_Location;
	local altplace=(road.VehicleCount > 0 && road.VehicleCount % 2 != 0 && road.CargoID == cCargo.GetPassengerCargo());
	if (altplace && road.TargetStation.s_Depot != null)	homedepot = road.TargetStation.s_Depot;
	if (!cStation.IsDepot(homedepot))	return false;
	local price=cEngine.GetPrice(engineID, road.CargoID);
	cBanker.RaiseFundsBy(price);
	local vehID = cEngineLib.CreateVehicle(homedepot, engineID, road.CargoID);
	if (vehID != -1)
			{
			DInfo("Just brought a new road vehicle: "+cCarrier.GetVehicleName(vehID),0);
			INSTANCE.main.carrier.vehnextprice -= price;
			if (INSTANCE.main.carrier.vehnextprice < 0)	INSTANCE.main.carrier.vehnextprice=0;

			}
		else	{
			DError("Cannot create the road vehicle "+cEngine.GetName(engineID),2);
			return false;
			}
	local firstorderflag = AIOrder.OF_NON_STOP_INTERMEDIATE;
	local secondorderflag = firstorderflag;
	if (!road.Twoway)	{ firstorderflag+=AIOrder.OF_FULL_LOAD_ANY; secondorderflag=AIOrder.OF_NO_LOAD; }
	AIGroup.MoveVehicle(road.GroupID, vehID);
	if (!AIOrder.AppendOrder(vehID, srcplace, firstorderflag))
		{ // detect IsArticulated bug
		DInfo("Vehicle "+cCarrier.GetVehicleName(vehID)+" refuse order !",1);
		local checkstation=AIStation.GetStationID(srcplace);
		local checkengine=AIVehicle.GetEngineType(vehID);
		local checktype=AIEngine.GetVehicleType(checkengine);
		if (AIStation.IsValidStation(checkstation) && (AIStation.HasStationType(checkstation, AIStation.STATION_BUS_STOP) || AIStation.HasStationType(checkstation, AIStation.STATION_TRUCK_STOP)))
			{
			cEngine.BlacklistEngine(checkengine);
			cCarrier.VehicleSell(vehID, false);
			}
		return false;
		}
	AIOrder.AppendOrder(vehID, dstplace, secondorderflag);
	if (altplace)	INSTANCE.main.carrier.VehicleOrderSkipCurrent(vehID);
	if (!cCarrier.StartVehicle(vehID)) { DError("Cannot start the vehicle:",2); cCarrier.VehicleSell(vehID, false); return false; }
	cEngine.CheckMaxSpeed(engineID);
	return true;
}
