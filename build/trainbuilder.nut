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
	wagonlist.Valuate(AIEngine.IsBuildable);
	wagonlist.KeepValue(1);
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
	local puller=null;
	if (compengine!=null)	puller=cEngine.GetName(compengine);
	if (wagonlist.IsEmpty()) 
		{
		if (compengine==null)	DError("No wagons can transport that cargo "+AICargo.GetCargoLabel(cargo),1,"ChooseRailWagon");
					else	DError("The engine "+puller+" cannot handle any wagons that could transport "+AICargo.GetCargoLabel(cargo),1,"ChooseRailWagon");
		return null;
		}
	return wagonlist.Begin();
}

function cCarrier::ChooseRailCouple(cargo, rtype=null)
// This function will choose a wagon to carry that cargo, and a train engine to carry it
// It will return AIList with item=engineID, value=wagonID
// AIList() on error
{
local couple=AIList();
local engine=ChooseRailEngine(rtype, cargo);
AIController.Sleep(1);
if (engine==null)	return AIList();
if (rtype==null)	rtype=cCarrier.GetRailTypeNeedForEngine(engine);
if (rtype==-1)	return AIList();
local wagon=cCarrier.ChooseRailWagon(cargo, rtype, engine);
AIController.Sleep(1);
if (wagon != null)	couple.AddItem(engine,wagon);
return couple;
}

function cCarrier::GetRailTypeNeedForEngine(engineID)
// return the railtype the engine need to work on
{
local rtypelist=AIRailTypeList();
foreach (rtype, dum in rtypelist)
	{
	if (AIEngine.HasPowerOnRail(engineID, rtype) && AIRail.GetMaxSpeed(rtype)==0)	return rtype;
	}
return -1;
}

function cCarrier::ChooseRailEngine(rtype=null, cargoID=null, cheap=false)
// return fastest+powerfulest engine
{
local vehlist = AIEngineList(AIVehicle.VT_RAIL);
vehlist.Valuate(AIEngine.IsBuildable);
vehlist.KeepValue(1);
vehlist.Valuate(AIEngine.IsWagon);
vehlist.KeepValue(0);
if (cargoID!=null)
	{
	vehlist.Valuate(cEngine.CanPullCargo, cargoID);
	vehlist.KeepValue(1);
	}
vehlist.Valuate(cCarrier.GetEngineLocoEfficiency,cargoID, !INSTANCE.bank.unleash_road);
vehlist.Sort(AIList.SORT_BY_VALUE, true);
// before railtype filtering, add this engine as topengine using any railtype
if (!vehlist.IsEmpty())	cEngine.RailTypeIsTop(vehlist.Begin(), cargoID, true);
if (rtype != null)
	{
	vehlist.Valuate(AIEngine.HasPowerOnRail, rtype);
	vehlist.KeepValue(1);
	vehlist.Valuate(cCarrier.GetEngineLocoEfficiency,cargoID, !INSTANCE.bank.unleash_road);
	vehlist.Sort(AIList.SORT_BY_VALUE, true);
	}
else	rtype = AIRail.GetCurrentRailType();
//vehlist.Valuate(cCarrier.GetEngineLocoEfficiency,cargoID, !INSTANCE.bank.unleash_road);
//vehlist.Sort(AIList.SORT_BY_VALUE, true);
if (cheap)
	{
	vehlist.Valuate(AIEngine.GetPrice);
	vehlist.Sort(AIList.SORT_BY_VALUE,true);
	}
/*
if (!INSTANCE.bank.unleash_road)	// try to find the cheapest one out of the 5 most efficient ones
	{
	vehlist.KeepTop(5);
	vehlist.Valuate(AIEngine.GetPrice);
	vehlist.Sort(AIList.SORT_BY_VALUE, true);
	}*/
foreach (engid, eff in vehlist)	print("name="+cEngine.GetName(engid)+" eff="+eff+" price="+AIEngine.GetPrice(engid));
local veh = null;
if (vehlist.IsEmpty())	DWarn("Cannot find a train engine for that rail type",1,"cCarrier::ChooseRailEngine");
			else	veh=vehlist.Begin();
//if (veh != null)	print("pickup ="+cEngine.GetName(veh));
if (!vehlist.IsEmpty() && cargoID != null)	cEngine.EngineIsTop(vehlist.Begin(), cargoID, true); // set top engine for trains
if (veh != null)	print("Selected train engine "+AIEngine.GetName(veh)+" speed:"+AIEngine.GetMaxSpeed(veh));
return veh;
}

function cCarrier::GetNumberOfWagons(vehID)
// Count only part that are wagons, and not engine locomotive
{
if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Invalid vehicleID : "+vehID,2,"cCarrier::GetNumberOfWagons"); return 0; }
local numwagon=0;
local numpart=AIVehicle.GetNumWagons(vehID);
for (local i=0; i < numpart; i++)
	if (AIEngine.IsWagon(AIVehicle.GetWagonEngineType(vehID, i)))	numwagon++;
return numwagon;
}

function cCarrier::GetNumberOfLocos(vehID)
// Count how many locomotives are in vehicle
{
local numwagon=cCarrier.GetNumberOfWagons(vehID);
if (AIVehicle.GetVehicleType(vehID)!=AIVehicle.VT_RAIL)	return 0;
local numloco=AIVehicle.GetNumWagons(vehID);
if (numwagon > 0)
	{
	if (numwagon==numloco)	numloco=0; // made only with wagons
				else	numloco-=numwagon;
	}
return numloco;
}

function cCarrier::GetWagonFromVehicle(vehID)
// pickup a wagon from the vehicle and return its place in the vehicle
{
if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Invalid vehicleID : "+vehID,2,"cCarrier::GetAWagonFromVehicle"); return -1; }
local numengine=AIVehicle.GetNumWagons(vehID);
for (local z=0; z < numengine; z++)
	if (AIEngine.IsWagon(AIVehicle.GetWagonEngineType(vehID,z)))	return z;
}

function cCarrier::GetWagonsInGroup(groupID)
// return number of wagons present in the group
{
local vehlist=AIVehicleList_Group(groupID);
local total=0;
foreach (veh, dummy in vehlist)	total+=cCarrier.GetNumberOfWagons(veh);
return total;
}

function cCarrier::CreateTrainsEngine(engineID, depot, cargoID)
// Create vehicle engineID at depot
// return vehicleID
// return -1 when we lack money
// return -2 when we fail to refit the wagon
{
if (!AIEngine.IsValidEngine(engineID))	return -1;
local price=cEngine.GetPrice(engineID);
INSTANCE.bank.RaiseFundsBy(price);
if (!INSTANCE.bank.CanBuyThat(price))	DInfo("We lack money to buy "+AIEngine.GetName(engineID)+" : "+price,1,"cCarrier::CreateTrainsEngine");
local vehID=AIVehicle.BuildVehicle(depot, engineID);
if (vehID==AIVehicle.VEHICLE_INVALID)
		{
		DInfo("Failure to buy "+AIEngine.GetName(engineID)+" at "+depot+" err: "+AIError.GetLastErrorString(),1,"cCarrier::CreateTrainsEngine");
		return -1;
		}
	else	{
		DInfo("New "+cCarrier.VehicleGetName(vehID)+" created with "+AIEngine.GetName(engineID),1,"cCarrier::CreateTrainsEngine");
		if (AIVehicle.IsValidVehicle(vehID))	cEngine.Update(vehID);
		INSTANCE.carrier.vehnextprice-=price;
		if (INSTANCE.carrier.vehnextprice < 0)	INSTANCE.carrier.vehnextprice=0;
		}
// get & set refit cost
local testRefit=AIAccounting();
if (!AIVehicle.RefitVehicle(vehID, cargoID))
	{
	DError("We fail to refit the engine, maybe we run out of money ?",1,"cCarrier::CreateTrainsEngine");
	testRefit=null;
	AIVehicle.SellVehicle(vehID);
	return -1;
	}
else	{
	local refitprice=testRefit.GetCosts();
	cEngine.SetRefitCost(engineID, cargoID, refitprice, AIVehicle.GetLength(vehID));
	}
testRefit=null;
return vehID;
}

function cCarrier::AddNewTrain(uid, trainID, wagonNeed, depot, maxLength)
// Add a train or add wagons to an existing train
{
local road=cRoute.GetRouteObject(uid);
if (road==null)	return -1;
local locotype=null;
if (trainID==null)
	{
	locotype=INSTANCE.carrier.ChooseRailEngine(road.source.specialType, road.cargoID);
	if (locotype==null)	return -1;
	}
else	locotype=AIVehicle.GetEngineType(trainID);
local wagontype=INSTANCE.carrier.ChooseRailWagon(road.cargoID, road.source.specialType, locotype);
if (wagontype==null)	return -1;
local confirm=false;
local wagonID=null;
local pullerID=null;
if (trainID==null)	pullerID=INSTANCE.carrier.CreateTrainsEngine(locotype, depot, road.cargoID);
			else	pullerID=trainID;
if (pullerID==-1)	{ DError("Cannot create the train engine "+AIEngine.GetName(locotype),1,"cCarrier::AddNewTrain"); return -1; }
local another=null; // use to get a new wagonID, but this one doesn't need to be buy
PutSign(depot,"Depot");
local wagonlist = AIEngineList(AIVehicle.VT_RAIL);
wagonlist.Valuate(AIEngine.IsBuildable);
wagonlist.KeepValue(1);
wagonlist.Valuate(AIEngine.IsWagon);
wagonlist.KeepValue(1);
wagonlist.Valuate(AIEngine.CanRunOnRail, road.source.specialType);
wagonlist.KeepValue(1);
wagonlist.Valuate(AIEngine.CanRefitCargo, road.cargoID);
wagonlist.KeepValue(1);
local wagonTestList=AIList();
local ourMoney=INSTANCE.bank.GetMaxMoneyAmount();
local lackMoney=false;
while (!confirm)
	{
	local wagonprice=cEngine.GetPrice(wagontype, road.cargoID);
	lackMoney=!cBanker.CanBuyThat(wagonprice);
	cTrain.SetWagonPrice(pullerID, wagonprice);
	wagonTestList.Clear();
	wagonTestList.AddList(wagonlist);
	if (lackMoney)
		{
		DError("We don't have enought money to buy "+cEngine.GetName(wagontype),2,"cCarrier::AddNewTrain");
		return -1;
		}
	else	wagonID=INSTANCE.carrier.CreateTrainsEngine(wagontype, depot, road.cargoID);
		// now that the wagon is create, we know its capacity with any cargo
	if (wagonID==-1)
		{
		DError("Cannot create the wagon "+cEngine.GetName(wagontype),2,"cCarrier::AddNewTrain");
		return -1;
		}
	wagonTestList.Valuate(cEngine.IsCompatible, locotype); // kick out incompatible wagon
	wagonTestList.KeepValue(1);
	wagonTestList.Valuate(cEngine.GetCapacity, road.cargoID);
	wagonTestList.Sort(AIList.SORT_BY_VALUE,false);
	wagonTestList.KeepValue(wagonTestList.GetValue(wagonTestList.Begin())); // keep wagons == to the top capacity
	wagonTestList.Valuate(AIEngine.GetPrice);
	wagonTestList.Sort(AIList.SORT_BY_VALUE, true); // and put cheapest one first
	if (wagonTestList.IsEmpty())	another=null;
					else	another=wagonTestList.Begin();
	if (another==wagontype && another!=null && wagonID>=0) // same == cannot find a better one or we have no more choice
		{
		// try attach it
		local attachtry=AITestMode(); //must enter test mode to prevent the wagon from moving, avoid bug loosing the wagonID
		local atest=AIVehicle.MoveWagon(wagonID, 0, pullerID, AIVehicle.GetNumWagons(pullerID) - 1);
		attachtry=null;
		//INSTANCE.NeedDelay(60);
		if (!atest)
			{
			DError("Wagon "+AIEngine.GetName(wagontype)+" is not usable with "+AIEngine.GetName(locotype),1,"cCarrier::AddNewTrain");
			cEngine.Incompatible(wagontype, locotype);
			confirm=false;
			}
		else	{
			DInfo("Wagon "+AIEngine.GetName(wagontype)+" can be use with "+AIEngine.GetName(locotype),1,"cCarrier::AddNewTrain");
			confirm=true;
			}
		}
	else	wagontype=another;
	if (!AIVehicle.SellVehicle(wagonID))	{ DError("Cannot sell our test wagon",2,"AddNewTrain"); }
	//INSTANCE.NeedDelay(20);
	if (another==null)
		{
		DWarn("Can't find any wagons usable with that train engine "+cEngine.GetName(locotype),2,"cCarrier::AddNewTrain");
		if (pullerID!=null)	AIVehicle.SellVehicle(pullerID);
		if (wagonID!=null)	AIVehicle.SellVehicle(wagonID);
		return -2;
		}
	AIController.Sleep(1); // we should rush that, but it might be too hard without a pause
	}
//if (wagonNeed>10)	wagonNeed=10; // block to buy only 10 wagons max
//INSTANCE.NeedDelay(100);
for (local i=0; i < wagonNeed; i++)
	{
	local nwagonID=INSTANCE.carrier.CreateTrainsEngine(wagontype, depot, road.cargoID);
	//INSTANCE.NeedDelay(70);
	if (nwagonID!=-1)
		{
		if (!AIVehicle.MoveWagonChain(nwagonID, 0, pullerID, AIVehicle.GetNumWagons(pullerID)-1))
			{
			DError("Wagon "+AIEngine.GetName(wagontype)+" cannot be attach to "+AIEngine.GetName(locotype),2,"cCarrier::AddNewTrain");
			}
		else	{
			if (AIVehicle.GetLength(pullerID) > maxLength)
				{ // prevent building too much wagons for nothing and prevent failure that let wagons remain in the depot forever
				DInfo("Stopping adding wagons to train as its length is already too big",2,"cCarrier::AddNewTrain");
				break;
				}
			}
		}
	}
//INSTANCE.NeedDelay(50);
cTrain.Update(pullerID);
return pullerID;
}

function cCarrier::AddWagon(uid, wagonNeed)
// Add wagons to route uid, handle the train engine by buying it if need
// If need we send a train to depot to get more wagons, and we will be called back by the in depot event
// We will return true if we consider the job done (adding wagons)
// This is not always without getting an error, but we will says true per example if we cannot add new wagons because the station cannot support more wagons...
{
if (wagonNeed==0)	DWarn("We are query to build 0 wagons !!!",1,"cCarrier::AddWagon");
local road=cRoute.GetRouteObject(uid);
if (road==null)	return false;
//local totalWagons=cCarrier.GetWagonsInGroup(road.groupID)+wagonNeed;
local vehlist=AIVehicleList_Group(road.groupID);
local numTrains=vehlist.Count();
local stationLen=road.source.locations.GetValue(19)*16; // station depth is @19
local processTrains=[];
local tID=null;
local depotID=cRoute.GetDepot(uid);
PutSign(depotID,"Depot Builder");
local giveup=false;
vehlist.Valuate(AIVehicle.GetState);
vehlist.RemoveValue(AIVehicle.VS_INVALID);
vehlist.RemoveValue(AIVehicle.VS_CRASHED);
foreach (trainID, dummy in vehlist)
	{
	if (!cTrain.IsFull(trainID))	processTrains.push(trainID);
	}
if (processTrains.len()==0 && wagonNeed>0)
	{
	DInfo("No train can hold "+wagonNeed+" new wagons, forcing creation of a new train",2,"cCarrier::AddWagon");
	processTrains.push(-1);
	}
if (processTrains.len()==0)
	{
	DWarn("Giving up creating a new train until a valid query will be done",1,"cCarrier::AddWagon");
	DInfo("processTrains.len()="+processTrains.len()+" wagonNeed="+wagonNeed+" vehlist.Count()="+vehlist.Count(),2,"cCarrier::AddWagon");
	return false;
	}
do	{
	tID=processTrains.pop();
	if (AIVehicle.IsValidVehicle(tID) && AIVehicle.GetState(tID) != AIVehicle.VS_IN_DEPOT)
		{ // call that train to depot
		if (INSTANCE.carrier.ToDepotList.HasItem(tID))
			{
			DInfo("Updating number of wagons need for "+cCarrier.VehicleGetName(tID)+" to "+wagonNeed,1,"cCarrier::AddWagon");
			INSTANCE.carrier.ToDepotList.SetValue(tID, DepotAction.ADDWAGON+wagonNeed);
			if (AIOrder.GetOrderCount(tID)<3)
				{
				INSTANCE.carrier.ToDepotList.RemoveItem(tID);
				INSTANCE.carrier.VehicleSendToDepot(tID, DepotAction.ADDWAGON+wagonNeed);
				}
			}
		else	{
			if (!cBanker.CanBuyThat(cTrain.GetWagonPrice(tID)*wagonNeed)) return false; // don't call it if we lack money
			if (!cTrain.CanModifyTrain(tID))
				{
				DInfo("We already modify this train recently, waiting a few before calling it again",1,"cCarrier::AddWagon");
				return true;
				}
			DInfo("Sending a train to depot to add "+wagonNeed+" more wagons",1,"cCarrier::AddWagon");
			INSTANCE.carrier.VehicleSendToDepot(tID, DepotAction.ADDWAGON+wagonNeed);
			local wagonID=AIVehicle.GetWagonEngineType(tID,1);
			if (AIEngine.IsValidEngine(wagonID))
				INSTANCE.carrier.vehnextprice+=(wagonNeed*AIEngine.GetPrice(wagonID));
			}
		return true;
		}
	if (tID==-1)
		{ // build a new engine loco
		if (!cRoute.CanAddTrainToStation(uid))
			{
			DInfo("Cannot add any trains anymore as one of the station cannot handle one more",1,"cCarrier::AddWagon");
			return true;
			}
		DInfo("Adding a new engine to create a train",0,"cCarrier::AddWagon");
		depotID=cRoute.GetDepot(uid); // because previous CanAddTrainToStation could have move it
		local stop=false;
		while (!stop)
			{
			stop=true;
			tID=INSTANCE.carrier.AddNewTrain(uid, null, 0, depotID, stationLen);
			if (AIVehicle.IsValidVehicle(tID))
				{
				AIGroup.MoveVehicle(road.groupID, tID);
				local topspeed=AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(tID));
				cRoute.AddTrain(uid, tID);
				if (INSTANCE.carrier.speed_MaxTrain < topspeed)
					{
					DInfo("Setting maximum speed for trains to "+topspeed+"km/h",0,"cCarrier::AddWagon");
					INSTANCE.carrier.speed_MaxTrain=topspeed;
					}
				}
			else	if (tID==-2)	stop=false; // loop so we pickup another loco engine
						else	giveup=true;
			}
		}
	if (AIVehicle.IsValidVehicle(tID) && AIVehicle.GetState(tID) == AIVehicle.VS_IN_DEPOT && !giveup)
		{ // now we can add wagons to it
		local beforesize=cCarrier.GetNumberOfWagons(tID);
		depotID=AIVehicle.GetLocation(tID);
		cCarrier.VehicleOrdersReset(tID); // maybe we call that train to come to the depot
		INSTANCE.carrier.TrainSetOrders(tID); // called or not, it need proper orders
		tID=INSTANCE.carrier.AddNewTrain(uid, tID, wagonNeed, depotID, stationLen);
		if (AIVehicle.IsValidVehicle(tID))
			{
			local newwagon=cCarrier.GetNumberOfWagons(tID)-beforesize;
			wagonNeed-=newwagon;
			if (wagonNeed <= 0)	wagonNeed=0;
			cTrain.SetFull(tID, false);
			while (AIVehicle.GetLength(tID) > stationLen)
				{
				DInfo("Selling a wagon to met station length restrictions of "+stationLen,2,"cCarrier::AddWagon");
				local wagondelete=cCarrier.GetWagonFromVehicle(tID);
				if (!AIVehicle.SellWagon(tID, wagondelete))
					{
					DError("Cannot delete that wagon : "+wagondelete,2,"cCarrier::AddWagon");
					break;
					}
				else	{ wagonNeed++; }
				cTrain.SetFull(tID,true);
				}
			cTrain.Update(tID);
			}
		}
	} while (processTrains.len()!=0 && !giveup);
road.RouteUpdateVehicle();
// and now just let them run again
vehlist=AIVehicleList_Group(road.groupID);
vehlist.Valuate(AIVehicle.GetState);
vehlist.KeepValue(AIVehicle.VS_IN_DEPOT);
foreach (train, dummy in vehlist)
	{
	if (cTrain.IsEmpty(train))
		{
		DError("Something bad happen, that train is empty",2,"cCarrier::AddWagon");
		cCarrier.VehicleSell(train,false);
		giveup=true;
		}
	else	{
		DInfo("Starting "+cCarrier.VehicleGetName(train)+"...",0,"cCarrier::AddWagon");
		cTrain.SetDepotVisit(train);
		AIVehicle.StartStopVehicle(train);
		}
	AIController.Sleep(1);
	}
return !giveup;
}

