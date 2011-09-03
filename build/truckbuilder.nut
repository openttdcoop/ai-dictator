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

function cCarrier::CreateRoadEngine(engineID, depot, cargoID)
// Create road vehicle engineID at depot
{
if (!AIEngine.IsValidEngine(engineID))	return -1;
local price=cEngine.GetPrice(engineID);
INSTANCE.bank.RaiseFundsBy(price);
if (!INSTANCE.bank.CanBuyThat(price))	DWarn("We lack money to buy "+AIEngine.GetName(engineID)+" : "+price,1,"cCarrier::CreateRoadEngine");
local vehID=AIVehicle.BuildVehicle(depot, engineID);
if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Failure to buy "+AIEngine.GetName(engineID),1,"cCarrier::CreateRoadEngine"); return -1; }
cEngine.Update(vehID);
// get & set refit cost
local testRefit=AIAccounting();
if (!AIVehicle.RefitVehicle(vehID, cargoID))
	{
	DError("We fail to refit the engine, maybe we run out of money ?",1,"cCarrier::CreateRoadEngine");
	}
else	{
	local refitprice=testRefit.GetCosts();
	cEngine.SetRefitCost(engineID, cargoID, refitprice, AIVehicle.GetLength(vehID));
	}
testRefit=null;
return vehID;
}

function cCarrier::CreateRoadVehicle(roadidx)
// Build a road vehicle for route roadidx
{
local road=cRoute.GetRouteObject(roadidx);
local srcplace = road.source.locations.Begin();
local dstplace = road.target.locations.Begin();
local cargoid= road.cargoID;
local engineID = INSTANCE.carrier.ChooseRoadVeh(cargoid);
local homedepot = cRoute.GetDepot(roadidx);
local altplace=(road.vehicle_count > 0 && road.vehicle_count % 2 != 0 && road.cargoID == cCargo.GetPassengerCargo());
if (altplace && road.target.depot != null)	homedepot = road.target.depot;
if (!cStation.IsDepot(homedepot))
	{
	INSTANCE.builder.RouteIsDamage(roadidx);
	DError("Route "+road.name+" depot is not valid, adding route to repair task.",1,"cCarrier::CreateRoadVehicle");
	return false;
	}

local vehID=null;
local lackMoney=false;
local confirm=false;
local another=false;
print("BREAKPOINT");
while (!confirm)
	{
	local price=cEngine.GetPrice(engineID, road.cargoID);
	INSTANCE.bank.RaiseFundsBy(price);
	lackMoney=!cBanker.CanBuyThat(price);
	if (lackMoney)
		{
		DError("We don't have enought money to buy "+cEngine.GetName(engineID),2,"cCarrier::CreateRoadVehicle");
		vehID==-1;
		}
	else	vehID=INSTANCE.carrier.CreateRoadEngine(engineID, homedepot, cargoid);
	if (vehID==-1)
		DError("Cannot create the road vehicle "+cEngine.GetName(engineID),2,"cCarrier::CreateRoadVehicle");
	else	DInfo("Just brought a new road vehicle: "+AIVehicle.GetName(vehID),0,"cCarrier::CreateRoadVehicle");
	another=INSTANCE.carrier.ChooseRoadVeh(cargoid);
	if (another==engineID && another!=null)
		confirm=true;
	else	engineID=another;
	if (another==null && lackMoney)	{ DError("Find some road vehicle, but we lack money to buy it "+cEngine.GetName(engineID),2,"cCarrier::CreateRoadVehicle"); return -2; }
	INSTANCE.NeedDelay(60);
	if (!confirm && vehID!=-1)	cCarrier.VehicleSell(vehID);
	AIController.Sleep(1);
	}

local firstorderflag = null;
local secondorderflag = null;
if (AICargo.GetTownEffect(cargoid) == AICargo.TE_PASSENGERS || AICargo.GetTownEffect(cargoid) == AICargo.TE_MAIL)
	{
	firstorderflag = AIOrder.AIOF_NON_STOP_INTERMEDIATE;
	secondorderflag = AIOrder.AIOF_NON_STOP_INTERMEDIATE;
	}
else	{
	firstorderflag = AIOrder.AIOF_FULL_LOAD_ANY + AIOrder.AIOF_NON_STOP_INTERMEDIATE;
	secondorderflag = AIOrder.AIOF_NON_STOP_INTERMEDIATE;
	}
AIGroup.MoveVehicle(road.groupID, vehID);
AIOrder.AppendOrder(vehID, srcplace, firstorderflag);
AIOrder.AppendOrder(vehID, dstplace, secondorderflag);
if (altplace)	INSTANCE.carrier.VehicleOrderSkipCurrent(vehID);
if (!AIVehicle.StartStopVehicle(vehID)) { DError("Cannot start the vehicle:",2,"cCarrier::CreateRoadVehicle"); }
local topspeed=AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(vehID));
if (INSTANCE.carrier.speed_MaxRoad < topspeed)
	{
	DInfo("Setting maximum speed for road vehicle to "+topspeed,0,"cCarrier::CreateRoadVehicle");
	INSTANCE.carrier.speed_MaxRoad=topspeed;
	}
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
vehlist.Valuate(AIEngine.IsBuildable);
vehlist.KeepValue(1);
vehlist.Valuate(AIEngine.GetPrice);
vehlist.RemoveValue(0); // remove towncars toys
vehlist.Valuate(AIEngine.IsArticulated);
vehlist.KeepValue(0);
/*if (INSTANCE.safeStart>0)
	{
	vehlist.Valuate(AIEngine.GetCargoType);
	vehlist.KeepValue(cargoid);
	}
else	{*/
	vehlist.Valuate(AIEngine.CanRefitCargo, cargoid);
	vehlist.KeepValue(1);
	//}
vehlist.Valuate(cEngine.GetCapacity, cargoid);
vehlist.RemoveBelowValue(8); // clean out too small dumb vehicle size
vehlist.Valuate(cCarrier.GetEngineEfficiency, cargoid);
vehlist.Sort(AIList.SORT_BY_VALUE,true);
DInfo("Selected bus/truck : "+AIEngine.GetName(vehlist.Begin())+" eff: "+vehlist.GetValue(vehlist.Begin()),1,"cCarrier::ChooseRoadVeh");
return (vehlist.IsEmpty()) ? null : vehlist.Begin();
}


