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

function cCarrier::GetRoadVehicle(routeidx)
// return the vehicle we will pickup if we to build a vehicle on that route
{
local road=cRoute.GetRouteObject(routeidx);
if (road == null)	return null;
local veh = INSTANCE.carrier.ChooseRoadVeh(road.cargoID);
return veh;
}

function cCarrier::CreateRoadVehicle(roadidx)
// Build a road vehicle for route roadidx
{
local road=cRoute.GetRouteObject(roadidx);
local srcplace = road.source.locations.Begin();
local dstplace = road.target.locations.Begin();
local cargoid= road.cargoID;
local veh = INSTANCE.carrier.ChooseRoadVeh(cargoid);
local homedepot = road.GetRouteDepot();
local price = AIEngine.GetPrice(veh);
local altplace=(road.vehicle_count > 0 && road.vehicle_count % 2 != 0 && road.cargoID == cCargo.GetPassengerCargo());
if (altplace && road.target.depot != null)	homedepot = road.target.depot;
if (!cStation.IsDepot(homedepot))	
	{
	INSTANCE.builder.RouteIsDamage(roadidx);
	DInfo("Route "+road.name+" depot isn't valid, adding route to repair task.",1);
	return false;
	}
if (veh == null)
	{ DError("Fail to pickup a vehicle",1); return false; }
INSTANCE.bank.RaiseFundsBy(price);
local firstveh = AIVehicle.BuildVehicle(homedepot, veh);
if (!AIVehicle.IsValidVehicle(firstveh))
	{
	DWarn("Cannot buy the road vehicle : "+price+" - "+AIError.GetLastErrorString(),1);
	return false;
	}
else	{ DInfo("Just brought a new road vehicle: "+AIVehicle.GetName(firstveh),0); }
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
AIGroup.MoveVehicle(road.groupID, firstveh);
AIOrder.AppendOrder(firstveh, srcplace, firstorderflag);
AIOrder.AppendOrder(firstveh, dstplace, secondorderflag);
if (altplace)	INSTANCE.carrier.VehicleOrderSkipCurrent(firstveh);
if (!AIVehicle.StartStopVehicle(firstveh)) { DError("Cannot start the vehicle:",1); }
//if (!altplace)	INSTANCE.Sleep(74);
return true;
}

function cCarrier::ChooseRoadVeh(cargoid)
/**
* Pickup a road vehicle base on -> max capacity > max speed > max reliability
* @return the vehicle engine id
*/
{
local vehlist = AIEngineList(AIVehicle.VT_ROAD);
vehlist.Valuate(AIEngine.GetRoadType);
vehlist.KeepValue(AIRoad.ROADTYPE_ROAD);
vehlist.Valuate(AIEngine.IsArticulated);
vehlist.KeepValue(0);
vehlist.Valuate(AIEngine.CanRefitCargo, cargoid);
vehlist.KeepValue(1);
vehlist.Valuate(cCarrier.GetEngineEfficiency);
vehlist.Sort(AIList.SORT_BY_VALUE,true);
return (vehlist.IsEmpty()) ? null : vehlist.Begin();
}


