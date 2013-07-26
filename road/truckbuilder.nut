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

function cCarrier::GetRoadVehicle(routeidx)
// return the vehicle we will pickup if we to build a vehicle on that route
{
	local road=cRoute.Load(routeidx);
	if (!road)	return null;
	local veh = INSTANCE.main.carrier.ChooseRoadVeh(road.CargoID);
	return veh;
}

function cCarrier::CreateRoadEngine(engineID, depot, cargoID)
// Create road vehicle engineID at depot
// return -1 on errors, the vehicleID created on success
{
	if (engineID == null)	return -1;
	if (!AIEngine.IsValidEngine(engineID))	return -1;
	local price=cEngine.GetPrice(engineID);
	INSTANCE.main.bank.RaiseFundsBy(price);
	if (!INSTANCE.main.bank.CanBuyThat(price))	DWarn("We lack money to buy "+AIEngine.GetName(engineID)+" : "+price,1);
	local vehID=AIVehicle.BuildVehicle(depot, engineID);
	if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Failure to buy "+AIEngine.GetName(engineID),1); return -1; }
	INSTANCE.main.carrier.vehnextprice-=price;
	if (INSTANCE.main.carrier.vehnextprice < 0)	INSTANCE.main.carrier.vehnextprice=0;
	cEngine.Update(vehID);
	// get & set refit cost
	local testRefit=AIAccounting();
	if (!AIVehicle.RefitVehicle(vehID, cargoID))
		{
		DError("We fail to refit the engine, maybe we run out of money ?",1);
		AIVehicle.SellVehicle(vehID);
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
	if (!INSTANCE.use_road)	return false;
	local road=cRoute.Load(roadidx);
	if (!road)	return false;
	local srcplace = road.SourceStation.s_Location;
	local dstplace = road.TargetStation.s_Location;
	local cargoid= road.CargoID;
	local engineID = INSTANCE.main.carrier.ChooseRoadVeh(cargoid);
	if (engineID==null)	{ DWarn("Cannot find any vehicle to transport that cargo",1); return -2; }
	local homedepot = cRoute.GetDepot(roadidx);
	local altplace=(road.VehicleCount > 0 && road.VehicleCount % 2 != 0 && road.CargoID == cCargo.GetPassengerCargo());
	if (altplace && road.TargetStation.s_Depot != null)	homedepot = road.TargetStation.s_Depot;
	if (!cStation.IsDepot(homedepot))
		{
		INSTANCE.main.builder.RouteIsDamage(roadidx);
		DError("Route "+road.Name+" depot is not valid, adding route to repair task.",1);
		return false;
		}
	local vehID=null;
	local lackMoney=false;
	local confirm=false;
	local another=false;
	while (!confirm)
		{
		vehID=INSTANCE.main.carrier.CreateRoadEngine(engineID, homedepot, cargoid);
		if (AIVehicle.IsValidVehicle(vehID))
			{
			DInfo("Just brought a new road vehicle: "+cCarrier.GetVehicleName(vehID),0);
			}
		else	{
			DError("Cannot create the road vehicle "+cEngine.GetName(engineID),2);
			lackMoney=(vehID==-2);
			}
		another=INSTANCE.main.carrier.ChooseRoadVeh(cargoid);
		if (another==engineID)	confirm=true;
					else	engineID=another;
		if (lackMoney)
			{
			DWarn("Find some road vehicle, but we lack money to buy it "+cEngine.GetName(engineID),1);
			return -2;
			}
		if (!confirm && AIVehicle.IsValidVehicle(vehID))	cCarrier.VehicleSell(vehID,false);
		local pause = cLooper();
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
	if (!cCarrier.StartVehicle(vehID)) { DError("Cannot start the vehicle:",2); }
	local topspeed=AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(vehID));
	if (INSTANCE.main.carrier.speed_MaxRoad < topspeed)
		{
		DInfo("Setting maximum speed for road vehicle to "+topspeed,0);
		INSTANCE.main.carrier.speed_MaxRoad=topspeed;
		}
	return true;
}

function cCarrier::ChooseRoadVeh(cargoid)
// Pickup a road vehicle base on -> max capacity > max speed > max reliability
// @return the vehicle engine id

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
vehlist.Valuate(cEngine.IsEngineBlacklist);
vehlist.KeepValue(0);
vehlist.Valuate(AIEngine.CanRefitCargo, cargoid);
vehlist.KeepValue(1);
vehlist.Valuate(cEngine.GetCapacity, cargoid);
vehlist.RemoveBelowValue(8); // clean out too small dumb vehicle size
if (INSTANCE.main.bank.unleash_road)	vehlist.Valuate(cCarrier.GetEngineRawEfficiency, cargoid, true);
						else	vehlist.Valuate(cCarrier.GetEngineEfficiency, cargoid);
vehlist.Sort(AIList.SORT_BY_VALUE,true);
//DInfo("Selected bus/truck : "+AIEngine.GetName(vehlist.Begin())+" eff: "+vehlist.GetValue(vehlist.Begin()),1,"cCarrier::ChooseRoadVeh");
if (!vehlist.IsEmpty())	cEngine.EngineIsTop(vehlist.Begin(), cargoid, true); // set top engine for trucks
return (vehlist.IsEmpty()) ? null : vehlist.Begin();
}
