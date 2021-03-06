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

function cRoute::DutyOnRailsRoute(uid)
// this is where we handle rails route, that are too specials for common handling
{
	local firstveh = false;
	local road = cRoute.LoadRoute(uid);
	if (!road || road.Status != RouteStatus.WORKING)	return;
	local maxveh=0;
	local cargoid=road.CargoID;
	local railtype=road.SourceStation.s_SubType;
	local depot = cRoute.GetDepot(uid);
	local futur_engine= cCarrier.ChooseRailCouple(cargoid, railtype, -1);
	if (futur_engine[0] == -1)	return;
                        else	futur_engine = futur_engine[1]; // the wagon
	local futur_engine_capacity = cEngineLib.GetCapacity(futur_engine, road.CargoID);
    if (futur_engine_capacity <= 0) return;
	road.SourceStation.UpdateStationInfos();
	DInfo("After station update",2);
	local vehneed=0;
	if (road.VehicleCount == 0)	{ firstveh=true; }
	local cargowait=0;
	local capacity=0;
	local dual=road.SourceProcess.IsTown; // we need to check both side if source is town we're on a dual route (pass or mail)
	cargowait=road.SourceStation.s_CargoProduce.GetValue(cargoid);
	capacity=road.SourceStation.s_VehicleCapacity.GetValue(cargoid);
	if (capacity==0)
			{
			if (road.SourceProcess.IsTown)	cargowait=AITown.GetLastMonthProduction(road.SourceProcess.ID, cargoid);
                                    else	cargowait=AIIndustry.GetLastMonthProduction(road.SourceProcess.ID, cargoid);
			capacity=futur_engine_capacity;
			}
		if (dual)
			{
			road.TargetStation.UpdateStationInfos();
			local src_capacity=capacity;
			local dst_capacity= road.TargetStation.s_VehicleCapacity.GetValue(cargoid);
			local src_wait = cargowait;
			local dst_wait = road.TargetStation.s_CargoProduce.GetValue(cargoid);
			if (dst_capacity == 0)	{ dst_wait=AITown.GetLastMonthProduction(road.TargetProcess.ID,cargoid); dst_capacity=futur_engine_capacity; }
			if (src_wait < dst_wait)	cargowait=src_wait; // keep the lowest cargo amount
                                else	cargowait=dst_wait;
			if (src_capacity < dst_capacity)	capacity=dst_capacity; // but keep the highest capacity we have
										else	capacity=src_capacity;
			DInfo("Source capacity="+src_capacity+" wait="+src_wait+" --- Target capacity="+dst_capacity+" wait="+dst_wait,2);
			}
	if (capacity==0)	capacity++; // avoid /0
	local remain = cargowait - capacity;
	if (remain < 0)	vehneed=0;
			else	vehneed = (cargowait / capacity);
	if (vehneed == 0 && firstveh)	{ vehneed = 3; } // a never used wagon that need refit will report 255 capacity
	if (vehneed > 8)	vehneed=8; // limit to a max 8 wagons per trys
	DInfo("Route capacity="+capacity+" vehicleneed="+vehneed+" cargowait="+cargowait+" vehicule#="+road.VehicleCount+" firstveh="+firstveh,2);
	if (vehneed > 0) cCarrier.RouteNeedVehicle(road.GroupID, vehneed);
			else	{
					// evaluate if we can use less trains
					local max_prod = cStation.GetMaxProduction(road.SourceStation.s_ID, road.CargoID);
					// disable the checks for pass and mail : it will not works with towns
					if (road.CargoID == cCargo.GetPassengerCargo() || road.CargoID == cCargo.GetMailCargo())	max_prod = 0;
					if (max_prod != 0 && capacity > max_prod * 2)
						{
						local train_list = AIVehicleList_Group(road.GroupID);
						train_list.Valuate(AIVehicle.GetAgeLeft);
						train_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
						local kill_train = train_list.Begin();
						cCarrier.VehicleSendToDepot(kill_train, DepotAction.SELL);
						DInfo("Removing a train from "+road.UID+" to match production rate",2);
						}
					/*
					print("capacity = "+capacity+" max_prod="+max_prod);
					local max_to_full = 50;
					local num_wagons = 0;
					local potential_wagons = 0;
					local train_list = AIVehicleList_Group(road.GroupID);
					train_list.Valuate(AIVehicle.GetAgeLeft);
					train_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
					local stationLen = road.SourceStation.s_Depth * 16;
					local kill_train = train_list.Begin();
					local tot_capacity = 0;
					foreach (train, ageleft in train_list)
						{
						local nw = cEngineLib.VehicleGetNumberOfWagons(train);
						num_wagons += nw;
						print("train: "+cCarrier.GetVehicleName(train)+" wagons: "+nw+ "numwagons="+num_wagons);
                        if (cTrain.IsFull(train) && max_to_full > nw)
							{
							max_to_full = nw;
							potential_wagons = train_list.Count() * max_to_full;
							}
						if (max_to_full == 50)
							{
							local eng = [];
							eng.push(AIVehicle.GetEngineType(train));
							eng.push(AIVehicle.GetWagonEngineType(train, cEngineLib.VehicleGetRandomWagon(train)));
							max_to_full = cEngineLib.GetMaxWagons(eng, stationLen, road.CargoID);
							if (max_to_full == -1)	max_to_full = 4;
							potential_wagons = train_list.Count() * max_to_full;
							}
						}
					local free_space = potential_wagons - num_wagons - 2; // keep a 2 wagons margin
					print("num_wagons= "+num_wagons+" potential_wagons= "+potential_wagons+" free_space= "+free_space+" max_to_full= "+max_to_full);
					if (free_space > max_to_full)	cCarrier.VehicleSendToDepot(kill_train, DepotAction.SELL);*/
					}
}

