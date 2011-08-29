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

function cCarrier::ChooseRailWagon(cargo, rtype, compengine)
// pickup a wagon that could be use to carry "cargo", on railtype "rtype"
{
	local wagonlist = AIEngineList(AIVehicle.VT_RAIL);
	if (rtype!=null)	
		{
		wagonlist.Valuate(AIEngine.CanRunOnRail, rtype);
		wagonlist.KeepValue(1);
		}
	if (compengine!=null)
		{
		wagonlist.Valuate(cEngine.IsCompatible, compengine);
		wagonlist.KeepValue(1);
		}
	wagonlist.Valuate(AIEngine.IsWagon);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.CanRefitCargo, cargo);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.GetMaxSpeed);
	wagonlist.KeepValue(wagonlist.GetValue(wagonlist.Begin()));
	wagonlist.Valuate(cEngine.GetCapacity, cargo);
	wagonlist.Sort(AIList.SORT_BY_VALUE,false);
	wagonlist.KeepValue(wagonlist.GetValue(wagonlist.Begin()));
	wagonlist.Valuate(cEngine.GetPrice, cargo);
	wagonlist.Sort(AIList.SORT_BY_VALUE,true);
	if (wagonlist.IsEmpty()) 
		{ DError("No wagons can transport that cargo "+AICargo.GetCargoLabel(cargo),1,"ChooseWagon"); return null; }
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
local wagon=cCarrier.ChooseRailWagon(cargo, rtype, engine);
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

function cCarrier::ChooseRailEngine(rtype=null, cargoID=null)
// return fastest+powerfulest engine
{
local vehlist = AIEngineList(AIVehicle.VT_RAIL);
if (rtype != null)
	{
	vehlist.Valuate(AIEngine.HasPowerOnRail, rtype);
	vehlist.KeepValue(1);
	}
if (cargoID!=null)
	{
	vehlist.Valuate(cEngine.CanPullCargo, cargoID);
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
if (vehlist.IsEmpty())	DInfo("Cannot find a train engine for that rail type",1,"cCarrier::ChooseRailEngine");
			else	veh=vehlist.Begin();
return veh;
}

function cCarrier::TrainSetOrders(trainID)
// Set orders for a train
{
local uid=INSTANCE.carrier.VehicleFindRouteIndex(trainID);
if (uid==null)	{ DError("Cannot find uid for that train",1,"cCarrier::TrainSetOrders"); return false; }
local road=cRoute.GetRouteObject(uid);
if (road==null)	return false;
DInfo("Append orders to "+AIVehicle.GetName(trainID),2,"cCarrier::TrainSetOrder");
local firstorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
local secondorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
if (!road.source_istown)	firstorder+=AIOrder.AIOF_FULL_LOAD_ANY;
if (!AIOrder.AppendOrder(trainID, AIStation.GetLocation(road.source.stationID), firstorder))
	{ DError(AIVehicle.GetName(trainID)+" refuse first order",2,"cCarrier::TrainSetOrder"); return false; }
if (!AIOrder.AppendOrder(trainID, AIStation.GetLocation(road.target.stationID), secondorder))
	{ DError(AIVehicle.GetName(trainID)+" refuse second order",2,"cCarrier::TrainSetOrder"); return false; }
return true;
}

function cCarrier::GetWagonsInGroup(groupID)
// return number of wagons present in the group
{
local vehlist=AIVehicleList_Group(groupID);
vehlist.Valuate(AIEngine.IsWagon);
vehlist.KeepValue(1);
local total=0;
foreach (veh, dummy in vehlist)	total+=AIVehicle.GetNumWagons(veh);
return total;
}

function cCarrier::CreateTrainsEngine(engineID, depot, cargoID)
// Create vehicle engineID at depot
{
if (!AIEngine.IsValidEngine(engineID))	return -1;
local price=AIEngine.GetPrice(engineID);
INSTANCE.bank.RaiseFundsBy(price);
if (!INSTANCE.bank.CanBuyThat(price))	DInfo("We lack money to buy "+AIEngine.GetName(engineID)+" : "+price,1,"cCarrier::CreateTrainsEngine");
local vehID=AIVehicle.BuildVehicle(depot, engineID);
if (!AIVehicle.IsValidVehicle(vehID))	{ DInfo("Failure to buy "+AIEngine.GetName(engineID),1,"cCarrier::CreateTrainsEngine"); return -1; }
cEngine.Update(vehID);
// get & set refit cost
local testRefit=AIAccounting();
if (!AIVehicle.RefitVehicle(vehID, cargoID))
	{
	DError("We fail to refit the engine, maybe we run out of money ?",1,"cCarrier::CreateTrainEngine");
	}
else	{
	local refitprice=testRefit.GetCosts();
	cEngine.SetRefitCost(engineID, cargoID, refitprice);
	}
testRefit=null;
return vehID;
}

function cCarrier::AddNewTrain(uid, wagonNeed)
// Called when creating a route, as no train is there no need to worry that much
{
local road=cRoute.GetRouteObject(uid);
if (road==null)	return false;
local locotype=INSTANCE.carrier.ChooseRailEngine(road.source.specialType, road.cargoID);
if (locotype==null)	return false;
local wagontype=INSTANCE.carrier.ChooseRailWagon(road.cargoID, road.source.specialType, locotype);
if (wagontype==null)	return false;
local confirm=false;
local depot=road.source.GetRailDepot();
local wagonID=null;
if (depot==-1)	{ DInfo("Station "+road.source.name+" doesn't have a valid depot",1,"cCarrier::AddNewTrain"); return false; }
local pullerID=INSTANCE.carrier.CreateTrainsEngine(locotype, depot, road.cargoID);
if (pullerID==-1)	{ DError("Cannot create the train engine "+AIEngine.GetName(locotype),1,"cCarrier::AddNewTrain"); return false; }
local another=null; // use to get a new wagonID, but this one doesn't need to be buy
PutSign(depot,"Depot");
print("BREAKPOINT");
local wagonlist = AIEngineList(AIVehicle.VT_RAIL);
wagonlist.Valuate(AIEngine.IsWagon);
wagonlist.KeepValue(1);
wagonlist.Valuate(AIEngine.CanRunOnRail, road.source.specialType);
wagonlist.KeepValue(1);
wagonlist.Valuate(AIEngine.CanRefitCargo, road.cargoID);
wagonlist.KeepValue(1);
local wagonTestList=AIList();
local ourMoney=INSTANCE.bank.GetMaxMoneyAmount();
//wagonlist.Valuate(AIEngine.IsCompatible, compengine);
//wagonlist.KeepValue(1);
//wagonlist.Valuate(AIEngine.GetCapacity);
//wagonlist.Sort(AIList.SORT_BY_VALUE,false);
local lackMoney=false;
while (!confirm)
	{
	lackMoney=!cBanker.CanBuyThat(cEngine.GetPrice(wagontype, road.cargoID));
	wagonTestList.Clear();
	wagonTestList.AddList(wagonlist);
	//wagonTestList.RemoveItem(wagontype); // don't retake the same engine
	if (lackMoney)
		{
		DError("We don't have enought money to buy "+cEngine.GetName(wagontype),2,"cCarrier::AddNewTrain");
		wagonID==-1;
		}
	else	wagonID=INSTANCE.carrier.CreateTrainsEngine(wagontype, depot, road.cargoID);
	// now that the wagon is create, we know its capacity with any cargo
	if (wagonID==-1)
		{
		DError("Cannot create the wagon "+cEngine.GetName(wagontype),2,"cCarrier::AddNewTrain");
		}
	wagonTestList.Valuate(cEngine.IsCompatible, locotype); // kick out incompatible wagon
	wagonTestList.KeepValue(1);
	wagonTestList.Valuate(cEngine.GetCapacity, road.cargoID);
	wagonTestList.Sort(AIList.SORT_BY_VALUE,false);
	wagonTestList.KeepValue(cEngine.GetCapacity(wagonTestList.Begin(),road.cargoID)); // keep wagons == to that top capacity
//	wagonTestList.Valuate(cEngine.GetPrice, road.cargoID);
//	wagonTestList.KeepBelowValue(ourMoney);
	wagonTestList.Sort(AIList.SORT_BY_VALUE, true); // and put cheapest one first
	if (wagonTestList.IsEmpty())	another=null;
					else	another=wagonTestList.Begin();
	print("wagontype="+wagontype+" another="+another+" wprice="+cEngine.GetPrice(wagontype,road.cargoID)+" aprice="+cEngine.GetPrice(another,road.cargoID)+" size:"+wagonTestList.Count()+" "+wagonTestList.IsEmpty());
	if (another==wagontype && another!=null) // same == cannot find a better one or we have no more choice
		{
		// try attach it
		confirm=AIVehicle.MoveWagonChain(wagonID, 0, pullerID, AIVehicle.GetNumWagons(pullerID)-1);
		if (!confirm)
			{
			DInfo("Wagon "+AIEngine.GetName(wagontype)+" is not usable with "+AIEngine.GetName(locotype),1,"cCarrier::AddNewTrain");
			cEngine.Incompatible(wagontype, locotype);
			}
		}
	else	wagontype=another;
	INSTANCE.NeedDelay(100);
	if (wagonID!=-1)	AIVehicle.SellVehicle(wagonID); // and finally sell the test wagon
	if (another==null)
		{
		if (lackMoney)	DError("Find some wagons that might work with that train engine "+cEngine.GetName(locotype)+", but cannot try them as we lack money",2,"cCarrier::AddNewTrain");
				else	DError("Can't find any wagons usable with that train engine "+cEngine.GetName(locotype),2,"cCarrier::AddNewTrain");
		return false;
		}
	AIController.Sleep(1); // we should rush that, but it might be too hard without a pause
	}

//if (engines.IsEmpty())	return false;
print("BREAKPOINT OUT");
local deletetrain=false;
for (local i=0; i < wagonNeed; i++)
	{
	wagonID=INSTANCE.carrier.CreateTrainsEngine(wagontype, depot, road.cargoID);
	if (wagonID!=-1)
		if (!AIVehicle.MoveWagonChain(wagonID, 0, pullerID, AIVehicle.GetNumWagons(pullerID) - 1))
			{
			DError("Wagon "+AIEngine.GetName(wagontype)+" cannot be attach to "+AIEngine.GetName(locotype),2,"cCarrier::AddNewTrain");
			}
	}
if (AIVehicle.GetNumWagons(pullerID)<2)	{ DInfo("Train doesn't have any wagons attach to it",1,"cCarrier::AddNewTrain"); deletetrain=true; }
print("num wagons="+AIVehicle.GetNumWagons(pullerID)); // lookout why getnumwagons say 3
AIGroup.MoveVehicle(road.groupID, pullerID);
if (INSTANCE.carrier.TrainSetOrders(pullerID))	AIVehicle.StartStopVehicle(pullerID);
							else	deletetrain=true;
if (deletetrain)	{ AIVehicle.SellVehicle(pullerID); DInfo("Selling train engine as the train isn't working",1,"cCarrier::AddNewTrain"); }

INSTANCE.NeedDelay(200);
//local test=cEngine.GetPrice(engines.Begin()); print("test="+test);
return true;
}

function cCarrier::AddWagon(uid, wagonNeed)
// Add wagons to route uid, handle the train engine by buying it if need
{
// TODO: handle getting all trains to depot before doing buys
return true;
local road=cRoute.GetRouteObject(uid);
if (road==null)	return false;
local numWagons=cCarrier.GetWagonsInGroup(road.groupID);
local vehlist=AIVehicleList_Group(groupID);
local numTrains=vehlist.Count();
if (numTrains==0)	{ return; }
local balancing=0;
local trainNeed=(numWagons+wagonNeed) / INSTANCE.carrier.train_length;
if (numtrains >0)	balancing=(numWagons+wagonNeed)/numTrains;
DWarn("WE REACH A DEAD END, NEED TO FINISH CODE",1,"cCarrier::AddWagons");
}

