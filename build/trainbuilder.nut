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
local engine=ChooseRailEngine(rtype, cargo);
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
vehlist.Valuate(AIEngine.IsBuildable);
vehlist.KeepValue(1);
if (rtype != null)
	{
	vehlist.Valuate(AIEngine.HasPowerOnRail, rtype);
	vehlist.KeepValue(1);
	}
vehlist.Valuate(AIEngine.IsWagon);
vehlist.KeepValue(0);
if (cargoID!=null)
	{
	vehlist.Valuate(cEngine.CanPullCargo, cargoID);
	vehlist.KeepValue(1);
	}
vehlist.Valuate(AIEngine.GetMaxSpeed);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
vehlist.KeepValue(vehlist.GetValue(vehlist.Begin()));
vehlist.Valuate(AIEngine.GetPower);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
local veh = null;
if (vehlist.IsEmpty())	DInfo("Cannot find a train engine for that rail type",1,"cCarrier::ChooseRailEngine");
			else	veh=vehlist.Begin();
//print("Selected train engine "+AIEngine.GetName(veh)+" speed:"+AIEngine.GetMaxSpeed(veh));
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
return AIVehicle.GetNumWagons(vehID)-numwagon;
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

function cCarrier::CanAddThatLength(vehID, wagonID)
// return true if we could add another wagonID to vehID
{
if (!AIVehicle.IsValidVehicle(vehID) || !AIVehicle.IsValidVehicle(wagonID))
		{ DError("Invalid vehicleID : "+vehID+" & "+wagonID,2,"cCarrier::GetTrainLength"); return 0; }
local maxlength=16*5;
local vehicleL=AIVehicle.GetLength(vehID);
local wagonL=AIVehicle.GetLength(vehID);
return ((wagonL+vehicleL) <= maxlength);
}

function cCarrier::CreateTrainsEngine(engineID, depot, cargoID)
// Create vehicle engineID at depot
{
if (!AIEngine.IsValidEngine(engineID))	return -1;
local price=cEngine.GetPrice(engineID);
INSTANCE.bank.RaiseFundsBy(price);
if (!INSTANCE.bank.CanBuyThat(price))	DInfo("We lack money to buy "+AIEngine.GetName(engineID)+" : "+price,1,"cCarrier::CreateTrainsEngine");
local vehID=AIVehicle.BuildVehicle(depot, engineID);
if (vehID==AIVehicle.VEHICLE_INVALID)
		{ DInfo("Failure to buy "+AIEngine.GetName(engineID),1,"cCarrier::CreateTrainsEngine"); return -1; }
	else	{
		DInfo("New "+AIVehicle.GetName(vehID)+" created with "+AIEngine.GetName(engineID),1,"cCarrier::CreateTrainsEngine");
		if (AIVehicle.IsValidVehicle(vehID))	cEngine.Update(vehID);
		}
// get & set refit cost
local testRefit=AIAccounting();
if (!AIVehicle.RefitVehicle(vehID, cargoID))
	{
	DError("We fail to refit the engine, maybe we run out of money ?",1,"cCarrier::CreateTrainEngine");
	AIVehicle.SellVehicle(vehID);
	}
else	{
	local refitprice=testRefit.GetCosts();
	cEngine.SetRefitCost(engineID, cargoID, refitprice, AIVehicle.GetLength(vehID));
	}
testRefit=null;
return vehID;
}

function cCarrier::AddNewTrain(uid, trainID, wagonNeed, depot)
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
	lackMoney=!cBanker.CanBuyThat(cEngine.GetPrice(wagontype, road.cargoID));
	wagonTestList.Clear();
	wagonTestList.AddList(wagonlist);
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
	wagonTestList.KeepValue(wagonTestList.GetValue(wagonTestList.Begin())); // keep wagons == to the top capacity
	wagonTestList.Valuate(AIEngine.GetPrice);
	wagonTestList.Sort(AIList.SORT_BY_VALUE, true); // and put cheapest one first
	if (wagonTestList.IsEmpty())	another=null;
					else	another=wagonTestList.Begin();
	if (another==wagontype && another!=null) // same == cannot find a better one or we have no more choice
		{
		// try attach it
		local attachtry=AITestMode(); //must enter test mode to prevent the wagon from moving, avoid bug loosing the wagonID
		local atest=AIVehicle.MoveWagon(wagonID, 0, pullerID, AIVehicle.GetNumWagons(pullerID)-1);
		attachtry=null;
		INSTANCE.NeedDelay(60);
		if (atest==AIVehicle.VEHICLE_INVALID)
			{
			DInfo("Wagon "+AIEngine.GetName(wagontype)+" is not usable with "+AIEngine.GetName(locotype),1,"cCarrier::AddNewTrain");
			cEngine.Incompatible(wagontype, locotype);
			confirm=false;
			}
		else	confirm=true;
		}
	else	wagontype=another;
	if (!AIVehicle.SellVehicle(wagonID))	{ DError("Cannot sold our test wagon",2,"AddWagon"); }
	INSTANCE.NeedDelay(20);
	if (another==null)
		{
		if (lackMoney)	DError("Find some wagons that might work with that train engine "+cEngine.GetName(locotype)+", but cannot try them as we lack money",2,"cCarrier::AddNewTrain");
				else	DError("Can't find any wagons usable with that train engine "+cEngine.GetName(locotype),2,"cCarrier::AddNewTrain");
		if (pullerID!=null)	AIVehicle.SellVehicle(pullerID);
		if (lackMoney)	return -2;
				else	return -3;
		}
	AIController.Sleep(1); // we should rush that, but it might be too hard without a pause
	}
if (wagonNeed>10)	wagonNeed=10; // block to buy only 10 wagons max
INSTANCE.NeedDelay(100);
for (local i=0; i < wagonNeed; i++)
	{
	local nwagonID=INSTANCE.carrier.CreateTrainsEngine(wagontype, depot, road.cargoID);
	INSTANCE.NeedDelay(70);
	if (nwagonID!=-1)
		{
		if (!AIVehicle.MoveWagonChain(nwagonID, 0, pullerID, AIVehicle.GetNumWagons(pullerID) - 1))
			{
			DError("Wagon "+AIEngine.GetName(wagontype)+" cannot be attach to "+AIEngine.GetName(locotype),2,"cCarrier::AddNewTrain");
			}
		}
	}
INSTANCE.NeedDelay(50);
cTrain.Update(pullerID);
return pullerID;
}

function cCarrier::AddWagon(uid, wagonNeed)
// Add wagons to route uid, handle the train engine by buying it if need
// If need we send a train to depot to get add wagons, and we will get called back by the in depot event
{
if (wagonNeed==0)	return false;
local road=cRoute.GetRouteObject(uid);
if (road==null)	return false;
//local totalWagons=cCarrier.GetWagonsInGroup(road.groupID)+wagonNeed;
local vehlist=AIVehicleList_Group(road.groupID);
local numTrains=vehlist.Count();
local stationLen=road.source.locations.GetValue(19)*16; // station depth is @19
local processTrains=[];
local tID=null;
local depotID=cRoute.GetDepot(uid);
foreach (trainID, dummy in vehlist)
	{
	if (AIVehicle.GetState(trainID) != AIVehicle.VS_CRASHED && !cTrain.IsFull(trainID))	processTrains.push(trainID);
	}
if (processTrains.len()==0)
	{
	DInfo("Nothing do to, forcing creation of a new train",2,"AddWagon");
	processTrains.push(-1);
	}
INSTANCE.NeedDelay(100);
do	{
	tID=processTrains.pop();
	if (AIVehicle.IsValidVehicle(tID) && AIVehicle.GetState(tID) != AIVehicle.VS_IN_DEPOT)
		{ // call that train to depot
		if (INSTANCE.carrier.ToDepotList.HasItem(tID))
			{
			DInfo("Updating number of wagons need for "+AIVehicle.GetName(tID)+" to "+wagonNeed,1,"AddWagon");
			INSTANCE.carrier.ToDepotList.SetValue(tID, DepotAction.ADDWAGON+wagonNeed);
			}
		else	{
			DInfo("Sending a train to depot to add "+wagonNeed+" more wagons",1,"AddWagon");
			INSTANCE.carrier.VehicleSendToDepot(tID, DepotAction.ADDWAGON+wagonNeed);
			local wagonID=AIVehicle.GetWagonEngineType(tID,1);
			if (AIEngine.IsValidEngine(wagonID))
				INSTANCE.carrier.vehnextprice+=(wagonNeed*AIEngine.GetPrice(wagonID));
			}
		return;
		}
	if (tID==-1)
		{ // build a new engine loco
		// TODO: ask permission to build a new one first
		DInfo("Adding a new engine to create a train",0,"AddWagon");
		local stop=false;
		while (!stop)
			{
			stop=true;
			tID=INSTANCE.carrier.AddNewTrain(uid, null, 0, depotID);
			if (tID == -3)	stop=false;
			if (AIVehicle.IsValidVehicle(tID))
				{
				AIGroup.MoveVehicle(road.groupID, tID);
				stop=true;
				local topspeed=AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(tID));
				if (INSTANCE.carrier.speed_MaxTrain < topspeed)
					{
					DInfo("Setting maximum speed for trains to "+topspeed+"km/h",0,"cCarrier::CreateRoadVehicle");
					INSTANCE.carrier.speed_MaxTrain=topspeed;
					}
				}
			}
		}
	if (AIVehicle.IsValidVehicle(tID) && AIVehicle.GetState(tID) == AIVehicle.VS_IN_DEPOT)
		{ // now we can add wagons to it
		local beforesize=cCarrier.GetNumberOfWagons(tID);
		cCarrier.VehicleOrdersReset(tID); // maybe we call that train to come to the depot
		INSTANCE.carrier.TrainSetOrders(tID); // called or not, it need proper orders
		tID=INSTANCE.carrier.AddNewTrain(uid, tID, wagonNeed, depotID);
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
/* disable until station can grow
		if (wagonNeed>0 && processTrains.len()==0) // we have no more trains that could get the remain wagons
			processTrains.push(-1);*/
		}
	} while (processTrains.len()!=0);
road.RouteUpdateVehicle();
// and now just let them run again
vehlist=AIVehicleList_Group(road.groupID);
vehlist.Valuate(AIVehicle.GetState);
vehlist.KeepValue(AIVehicle.VS_IN_DEPOT);
foreach (train, dummy in vehlist)
	{
	DInfo("Starting "+AIVehicle.GetName(train)+"...",0,"cCarrier::AddWagon");
	AIVehicle.StartStopVehicle(train);
	AIController.Sleep(1);
	}
return true;
}

