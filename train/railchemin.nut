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
	local road = cRoute.Load(uid);
	if (!road || road.Status != RouteStatus.WORKING)	return;
	local maxveh=0;
	INSTANCE.main.carrier.highcostTrain=0;
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
	local vehonroute=INSTANCE.main.carrier.GetWagonsInGroup(road.GroupID);
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
			else	vehneed = (cargowait / capacity)+1;
	if (vehneed == 0 && firstveh)	{ vehneed = 3; } // a never used wagon that need refit will report 255 capacity
	if (vehneed > 8)	vehneed=8; // limit to a max 8 wagons per trys
	DInfo("Route capacity="+capacity+" vehicleneed="+vehneed+" cargowait="+cargowait+" vehicule#="+road.VehicleCount+" firstveh="+firstveh,2);
	if (vehneed > 0 && !cCarrier.IsTrainRouteBusy(uid)) INSTANCE.main.carrier.AddWagon(uid,vehneed);
}

