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
local firstveh=false;
local road=cRoute.GetRouteObject(uid);
// no checks, as this is call after DutyOnRoute checks
if (road == null || !road.isWorking)	return;
local maxveh=0;
INSTANCE.carrier.highcostTrain=0;
local cargoid=road.cargoID;
local railtype=road.source.specialType;
local futur_engine=INSTANCE.carrier.ChooseRailWagon(cargoid, railtype, null);
local futur_engine_capacity=1;
if (futur_engine != null)	futur_engine_capacity=cEngine.GetCapacity(futur_engine);
				else	return;
road.source.UpdateStationInfos();
DInfo("After station update",2,"DutyOnRailsRoute");
local vehneed=0;
if (road.vehicle_count == 0)	{ firstveh=true; }
local vehonroute=INSTANCE.carrier.GetWagonsInGroup(road.groupID);
local cargowait=0;
local capacity=0;
local dual=road.source_istown; // we need to check both side if source is town we're on a dual route (pass or mail)
cargowait=road.source.cargo_produce.GetValue(cargoid);
capacity=road.source.vehicle_capacity.GetValue(cargoid);
if (capacity==0)
		{
		if (road.source_istown)	cargowait=AITown.GetLastMonthProduction(road.sourceID, cargoid);
					else	cargowait=AIIndustry.GetLastMonthProduction(road.sourceID, cargoid);
		capacity=futur_engine_capacity;
		}
	if (dual)
		{
		road.target.UpdateStationInfos();
		local src_capacity=capacity;
		local dst_capacity= road.target.vehicle_capacity.GetValue(cargoid);
		local src_wait = cargowait;
		local dst_wait = road.target.cargo_produce.GetValue(cargoid);
		if (cStation.IsStationVirtual(road.target.stationID))	dst_capacity-=cRoute.VirtualAirGroup[2];
		if (dst_capacity == 0)	{ dst_wait=AITown.GetLastMonthProduction(road.targetID,cargoid); dst_capacity=futur_engine_capacity; }
		if (src_wait < dst_wait)	cargowait=src_wait; // keep the lowest cargo amount
						else	cargowait=dst_wait;
		if (src_capacity < dst_capacity)	capacity=dst_capacity; // but keep the highest capacity we have
							else	capacity=src_capacity;
		DInfo("Source capacity="+src_capacity+" wait="+src_wait+" --- Target capacity="+dst_capacity+" wait="+dst_wait,2,"DutyOnRailsRoute");
		}
if (capacity==0)	capacity++; // avoid /0
local remain = cargowait - capacity;
if (remain < 0)	vehneed=0;
		else	vehneed = (cargowait / capacity)+1;
if (vehneed > 8)	vehneed=8; // limit to a max 8 wagons per trys
DInfo("Route capacity="+capacity+" vehicleneed="+vehneed+" cargowait="+cargowait+" vehicule#="+road.vehicle_count+" firstveh="+firstveh,2,"DutyOnRailsRoute");
//if (firstveh)	vehneed=1;
if (vehneed > 0)
	if (!INSTANCE.carrier.AddWagon(uid,vehneed))	INSTANCE.bank.busyRoute=true;
}

