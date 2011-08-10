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

function cCarrier::ChooseRailWagon(cargo, rtype=null)
// pickup a wagon that could be use to carry "cargo", on railtype "rtype"

{
	local wagonlist = AIEngineList(AIVehicle.VT_RAIL);
	if (rtype!=null)	
		{
		wagonlist.Valuate(AIEngine.CanRunOnRail, rtype);
		wagonlist.KeepValue(1);
		}
	wagonlist.Valuate(AIEngine.IsWagon);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.GetCargoType);
	wagonlist.KeepValue(cargo);
	wagonlist.Valuate(AIEngine.GetCapacity);
	wagonlist.Sort(AIList.SORT_BY_VALUE,false);
	if (wagonlist.IsEmpty()) 
		{ DError("No wagons can transport that cargo.",1,"ChooseWagon"); return null; }
	return wagonlist.Begin();
}

function cCarrier::ChooseRailCouple(cargo, rtype=null)
// This function will choose a wagon to carry that cargo, and a train engine to carry it
// It will return AIList with item=engineID, value=wagonID
// AIList() on error
{
local couple=AIList();
local engine=ChooseRailEngine(rtype);
if (rtype==null)	rtype=cCarrier.GetRailTypeNeedForEngine(engine);
if (engine==null || rtype==-1)	return couple;
local wagon=cCarrier.ChooseRailWagon(cargo, rtype);
if (wagon != null)	couple.AddItem(engine,wagon);
return couple;
}

function cCarrier::GetRailTypeNeedForEngine(engineID)
// return the railtype the engine need to work on
{
local rtypelist=AIRailTypeList();
foreach (rtype, dum in rtypelist)
	{
	if (AIEngine.HasPowerOnRail(engineID, rtype))	return rtype;
	}
return -1;
}

function cCarrier::ChooseRailEngine(rtype=null)
// return fastest+powerfulest engine
{
local vehlist = AIEngineList(AIVehicle.VT_RAIL);
if (rtype != null)
	{
	vehlist.Valuate(AIEngine.HasPowerOnRail, rtype);
	vehlist.KeepValue(1);
	}
vehlist.Valuate(AIEngine.IsWagon);
vehlist.KeepValue(0);
vehlist.Valuate(AIEngine.GetMaxSpeed);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
vehlist.KeepValue(vehlist.GetValue(vehlist.Begin()));
vehlist.Valuate(AIEngine.GetPower);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
local veh = null;
if (!vehlist.IsEmpty())	veh=vehlist.Begin();
DInfo("Selected train engine : "+AIEngine.GetName(veh),2,"ChooseRailEngine");
return veh;
}

function cCarrier::CreateRailVehicle(roadidx)
{
local road=INSTANCE.chemin.RListGetItem(roadidx);
local real_src_id=INSTANCE.chemin.GListGetItem(road.ROUTE.src_station);
local srcplace = real_src_id.STATION.station_id; // train real station is there
DInfo("src station is valid :"+AIStation.IsValidStation(srcplace),1);
local real_dst_id=INSTANCE.chemin.GListGetItem(road.ROUTE.dst_station);
local dstplace = real_dst_id.STATION.station_id;
DInfo("dst station is valid :"+AIStation.IsValidStation(dstplace),1);
local cargoid= road.ROUTE.cargo_id;
local veh = INSTANCE.carrier.ChooseRailVeh(roadidx);
local wagon = INSTANCE.carrier.ChooseWagon(road.ROUTE.cargo_id);
local homedepot = real_src_id.STATION.e_depot;
local price = AIEngine.GetPrice(veh);
price+=AIEngine.GetPrice(wagon)*5;
local length = 5;
DInfo("Stationid: "+srcplace+" "+AIStation.GetName(srcplace),2);
DInfo("Depotid: "+homedepot,2);
if (veh == null) return false;
if (!INSTANCE.bank.RaiseFundsBy(price))
	{
	DWarn("I don't have enough money to buy that train and its wagons "+AIEngine.GetName(veh),1);
	return false;
	}
else	{ DInfo("Train "+AIEngine.GetName(veh)+" and wagons will cost "+price,1); }
local trainengine = AIVehicle.BuildVehicle(homedepot, veh);
DInfo("Train created",2);
AIVehicle.RefitVehicle(veh, road.ROUTE.cargo_id);
local first=null;
first=AIVehicle.BuildVehicle(homedepot, wagon); // 4 to start operating
AIVehicle.BuildVehicle(homedepot, wagon);
AIVehicle.BuildVehicle(homedepot, wagon);
AIVehicle.BuildVehicle(homedepot, wagon);
AIVehicle.MoveWagonChain(first, 0, trainengine, AIVehicle.GetNumWagons(trainengine) - 1);
DInfo("wagons moved.",2);
local firstorderflag = null;
if (AICargo.GetTownEffect(road.ROUTE.cargo_id) == AICargo.TE_PASSENGERS || AICargo.GetTownEffect(road.ROUTE.cargo_id) == AICargo.TE_MAIL)
	{
	firstorderflag = AIOrder.AIOF_NON_STOP_INTERMEDIATE;
	}
 else	{
	firstorderflag = AIOrder.AIOF_FULL_LOAD_ANY + AIOrder.AIOF_NON_STOP_INTERMEDIATE;
	}
DInfo("Append order to "+AIEngine.GetName(trainengine)+" to "+AIStation.GetName(srcplace),2);
if (!AIOrder.AppendOrder(trainengine, AIStation.GetLocation(srcplace), firstorderflag))
	{ DError("Fail to set order !!!"+AIError.GetLastErrorString(),1); }
if (!AIOrder.AppendOrder(trainengine, AIStation.GetLocation(dstplace), AIOrder.AIOF_NON_STOP_INTERMEDIATE))
	{ DError("Fail to set order !!!"+AIError.GetLastErrorString(),1); }
DInfo("orders set",1);
if (!AIVehicle.StartStopVehicle(trainengine))
	{ DInfo(AIVehicle.GetName(trainengine)+" refuse to start !!!"+AIError.GetLastErrorString(),1); }
AIGroup.MoveVehicle(road.ROUTE.group_id, trainengine);
return true;
}
