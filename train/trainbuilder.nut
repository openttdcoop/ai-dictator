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
	//wagonlist.Valuate(AIEngine.GetMaxSpeed);
	//wagonlist.KeepValue(wagonlist.GetValue(wagonlist.Begin()));
	wagonlist.Valuate(cEngine.GetCapacity, cargo);
	wagonlist.Sort(AIList.SORT_BY_VALUE,false);
	//wagonlist.KeepValue(wagonlist.GetValue(wagonlist.Begin()));
	//wagonlist.Valuate(cEngine.GetPrice, cargo);
	//wagonlist.Sort(AIList.SORT_BY_VALUE,true);
	local puller=null;
	if (compengine!=null)	puller=cEngine.GetName(compengine);
	if (wagonlist.IsEmpty()) 
		{
		if (compengine==null)	DError("No wagons can transport that cargo "+AICargo.GetCargoLabel(cargo),1);
					else	DError("The engine "+puller+" cannot handle any wagons that could transport "+AICargo.GetCargoLabel(cargo),1);
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
	local engine=ChooseRailEngine(rtype, cargo, true); // pickup a valid engine, even we can't build it
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
	if (engineID == null)	return -1;
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
	vehlist.Valuate(cCarrier.GetEngineLocoEfficiency,cargoID, !INSTANCE.main.bank.unleash_road);
	vehlist.Sort(AIList.SORT_BY_VALUE, true);
	// before railtype filtering, add this engine as topengine using any railtype
	if (!vehlist.IsEmpty())	cEngine.RailTypeIsTop(vehlist.Begin(), cargoID, true);
	if (rtype != null)
		{
		vehlist.Valuate(AIEngine.HasPowerOnRail, rtype);
		vehlist.KeepValue(1);
		vehlist.Valuate(cCarrier.GetEngineLocoEfficiency,cargoID, !INSTANCE.main.bank.unleash_road);
		vehlist.Sort(AIList.SORT_BY_VALUE, true);
		}
	else	rtype = AIRail.GetCurrentRailType();
	if (!vehlist.IsEmpty() && cargoID != null)	cEngine.EngineIsTop(vehlist.Begin(), cargoID, true); // set top engine for trains
	if (!cheap)
		foreach (engID, eff in vehlist)
			{
			local price=AIEngine.GetPrice(engID);
			if (!cBanker.CanBuyThat(price))	vehlist.RemoveItem(engID);
			}
	local veh = null;
	if (vehlist.IsEmpty())	DWarn("Cannot find a train engine for that rail type",1);
				else	veh=vehlist.Begin();
	return veh;
}

function cCarrier::GetNumberOfWagons(vehID)
// Count only part that are wagons, and not engine locomotive
{
	if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Invalid vehicleID : "+vehID,2); return 0; }
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
	if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Invalid vehicleID : "+vehID,2); return -1; }
	local numengine=AIVehicle.GetNumWagons(vehID);
	for (local z=0; z < numengine; z++)
		if (AIEngine.IsWagon(AIVehicle.GetWagonEngineType(vehID,z)))	return z;
}

function cCarrier::GetWagonsInGroup(groupID)
// return number of wagons present in the group
{
	if (groupID == null)	return 0;
	local vehlist=AIVehicleList_Group(groupID);
	local total=0;
	foreach (veh, dummy in vehlist)	total+=cCarrier.GetNumberOfWagons(veh);
	return total;
}

function cCarrier::CreateTrainsEngine(engineID, depot, cargoID)
// Create vehicle engineID at depot
// return vehicleID
// return -1 when we lack money
{
	if (engineID == null)	return -1;
	if (!AIEngine.IsValidEngine(engineID))	return -1;
	local price=cEngine.GetPrice(engineID);
	INSTANCE.main.bank.RaiseFundsBy(price);
	if (!INSTANCE.main.bank.CanBuyThat(price))	DInfo("We lack money to buy "+AIEngine.GetName(engineID)+" : "+price,1);
	local vehID=AIVehicle.BuildVehicle(depot, engineID);
	if (vehID==AIVehicle.VEHICLE_INVALID)
		{
		DInfo("Failure to buy "+AIEngine.GetName(engineID)+" at "+depot+" err: "+AIError.GetLastErrorString(),1);
		INSTANCE.main.carrier.highcostTrain=price;
		INSTANCE.main.carrier.vehnextprice+=price;
		return -1;
		}
	else	{
		DInfo("New "+cCarrier.GetVehicleName(vehID)+" created with "+cEngine.GetName(engineID),1);
		if (AIVehicle.IsValidVehicle(vehID))	cEngine.Update(vehID);
		INSTANCE.main.carrier.vehnextprice-=price;
		if (INSTANCE.main.carrier.vehnextprice < 0)	INSTANCE.main.carrier.vehnextprice=0;
		INSTANCE.main.carrier.highcostTrain=price;
		}
	// get & set refit cost
	local testRefit=AIAccounting();
	if (!AIVehicle.RefitVehicle(vehID, cargoID))
		{
		testRefit=null;
		if (cEngine.IsWagon(engineID))	
			{		// we will keep it if it's a loco engine
			DError("We fail to refit the engine to handle "+cCargo.GetCargoLabel(cargoID)+" ",1);
			AIVehicle.SellVehicle(vehID);
			return -1;
			}
		}
	else	{
		local refitprice=testRefit.GetCosts();
		cEngine.SetRefitCost(engineID, cargoID, refitprice, AIVehicle.GetLength(vehID));
		}
	testRefit=null;
	return vehID;
}

function cCarrier::AddNewTrain(uid, trainID, wagonNeed, depot, maxLength, extraEngine)
// Add a train or add wagons to an existing train
{
	local road=cRoute.Load(uid);
	if (!road)	return -1;
	local locotype=null;
	if (trainID==null)
		{
		locotype=INSTANCE.main.carrier.ChooseRailEngine(road.SourceStation.s_SubType, road.CargoID, true);
		if (locotype==null)	return -1;
		}
	else	locotype=AIVehicle.GetEngineType(trainID);
	local xengine = INSTANCE.main.carrier.ChooseRailEngine(road.SourceStation.s_SubType, road.CargoID, false); // allow buy a cheaper engine
	local wagontype=INSTANCE.main.carrier.ChooseRailWagon(road.CargoID, road.SourceStation.s_SubType, locotype);
	if (wagontype==null)	return -1;
	local confirm=false;
	local wagonID=null;
	local pullerID=null;
	if (trainID==null)	pullerID=INSTANCE.main.carrier.CreateTrainsEngine(locotype, depot, road.CargoID);
				else	pullerID=trainID;
	if (pullerID==-1)	{ DError("Cannot create the train engine "+AIEngine.GetName(locotype),1); return -1; }
	if (extraEngine)
		{
		if (("IsMultiheaded" in AIEngine) && AIEngine.IsMultiheaded(locotype))	return true; // handle new API function
		xengine=INSTANCE.main.carrier.CreateTrainsEngine(xengine, depot, road.CargoID);
		if (xengine==-1)	{ DInfo("Cannot add an extra engine to that train, will redo later",1); return false; }
				else	{ AIVehicle.MoveWagon(xengine, 0, pullerID, AIVehicle.GetNumWagons(pullerID) - 1); return true; }
		}
	local another=null; // use to get a new wagonID, but this one doesn't need to be buy
	local wagonlist = AIEngineList(AIVehicle.VT_RAIL);
	wagonlist.Valuate(AIEngine.IsBuildable);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.IsWagon);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.CanRunOnRail, road.SourceStation.s_SubType);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.CanRefitCargo, road.CargoID);
	wagonlist.KeepValue(1);
	local wagonTestList=AIList();
	local ourMoney=INSTANCE.main.bank.GetMaxMoneyAmount();
	local lackMoney=false;
	while (!confirm)
		{
		local wagonprice=cEngine.GetPrice(wagontype, road.CargoID);
		lackMoney=!cBanker.CanBuyThat(wagonprice);
		cTrain.SetWagonPrice(pullerID, wagonprice);
		wagonTestList.Clear();
		wagonTestList.AddList(wagonlist);
		if (lackMoney)
			{
			DError("We don't have enough money to buy "+cEngine.GetName(wagontype),2);
			if (pullerID != trainID)	AIVehicle.SellVehicle(pullerID); // sell the train loco engine on failure to buy a wagon before returning
			return -1;
			}
		else	wagonID=INSTANCE.main.carrier.CreateTrainsEngine(wagontype, depot, road.CargoID);
		// now that the wagon is create, we know its capacity with any cargo
		if (wagonID==-1)
			{
			DError("Cannot create the wagon "+cEngine.GetName(wagontype),2);
			AIVehicle.SellVehicle(pullerID); // sell the train loco engine on failure to buy a wagon before returning
			return -1;
			}
		wagonTestList.Valuate(cEngine.IsCompatible, locotype); // kick out incompatible wagon
		wagonTestList.KeepValue(1);
		wagonTestList.Valuate(cEngine.GetCapacity, road.CargoID);
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
			INSTANCE.NeedDelay(60);
			if (!atest)
				{
				DError("Wagon "+AIEngine.GetName(wagontype)+" is not usable with "+AIEngine.GetName(locotype),1);
				cEngine.Incompatible(wagontype, locotype);
				confirm=false;
				}
			else	{
				DInfo("Wagon "+AIEngine.GetName(wagontype)+" can be use with "+AIEngine.GetName(locotype),1);
				confirm=true;
				}
			}
		else	wagontype=another;
		if (!AIVehicle.SellVehicle(wagonID))	{ DError("Cannot sell our test wagon",2); }
		//INSTANCE.NeedDelay(20);
		if (another==null)
			{
			DWarn("Can't find any wagons usable with that train engine "+cEngine.GetName(locotype),2);
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
		local nwagonID=INSTANCE.main.carrier.CreateTrainsEngine(wagontype, depot, road.CargoID);
		//INSTANCE.NeedDelay(70);
		if (nwagonID!=-1)
			{
			if (!AIVehicle.MoveWagonChain(nwagonID, 0, pullerID, AIVehicle.GetNumWagons(pullerID)-1))
				{
				DError("Wagon "+AIEngine.GetName(wagontype)+" cannot be attach to "+AIEngine.GetName(locotype),2);
				}
			else	{
				if (AIVehicle.GetLength(pullerID) > maxLength)
					{ // prevent building too much wagons for nothing and prevent failure that let wagons remain in the depot forever
					DInfo("Stopping adding wagons to train as its length is already too big",2);
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
	if (wagonNeed==0)	DWarn("We are query to build 0 wagons !!!",1);
	local road=cRoute.Load(uid);
	if (!road)	return false;
	local vehlist = AIVehicleList_Station(road.SourceStation.s_ID);
	foreach (veh, dummy in vehlist)
		if (cCarrier.ToDepotList.HasItem(veh) && cCarrier.VehicleSendToDepot_GetReason(cCarrier.ToDepotList.GetValue(veh)) == DepotAction.SIGNALUPGRADE)
					{
					DInfo("Cannot do any action with trains while we're upgrading signals",1);
					return true;
					}

	vehlist=AIVehicleList_Group(road.GroupID);
	local numTrains=vehlist.Count();
	local stationLen=road.SourceStation.s_Train[TrainType.DEPTH]*16;
	local processTrains=[];
	local tID=null;
	local depotID=cRoute.GetDepot(uid);
	cDebug.PutSign(depotID,"Depot Builder");
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
		DInfo("No train can hold "+wagonNeed+" new wagons, forcing creation of a new train",2);
		processTrains.push(-1);
		}
	if (processTrains.len()==0)
		{
		DWarn("Giving up creating a new train until a valid query will be done",1,"cCarrier::AddWagon");
		DInfo("processTrains.len()="+processTrains.len()+" wagonNeed="+wagonNeed+" vehlist.Count()="+vehlist.Count(),2);
		return false;
		}
	do	{
		tID=processTrains.pop();
		if (AIVehicle.IsValidVehicle(tID) && AIVehicle.GetState(tID) != AIVehicle.VS_IN_DEPOT)
			{ // call that train to depot
			if (INSTANCE.main.carrier.ToDepotList.HasItem(tID))
				{
				DInfo("Updating number of wagons need for "+cCarrier.GetVehicleName(tID)+" to "+wagonNeed,1);
				INSTANCE.main.carrier.ToDepotList.SetValue(tID, DepotAction.ADDWAGON+wagonNeed);
				if (AIOrder.GetOrderCount(tID)<3)
					{
					INSTANCE.main.carrier.ToDepotList.RemoveItem(tID);
					INSTANCE.main.carrier.VehicleSendToDepot(tID, DepotAction.ADDWAGON+wagonNeed);
					}
				}
			else	{
				if (!cBanker.CanBuyThat(cTrain.GetWagonPrice(tID)*wagonNeed)) return false; // don't call it if we lack money
				if (!cTrain.CanModifyTrain(tID))
					{
					DInfo("We already modify this train recently, waiting a few before calling it again",1);
					return true;
					}
				DInfo("Sending a train to depot to add "+wagonNeed+" more wagons",1);
				INSTANCE.main.carrier.VehicleSendToDepot(tID, DepotAction.ADDWAGON+wagonNeed);
				local wagonID=AIVehicle.GetWagonEngineType(tID,1);
				if (AIEngine.IsValidEngine(wagonID))
					INSTANCE.main.carrier.vehnextprice+=(wagonNeed*AIEngine.GetPrice(wagonID));
				}
			return true;
			}
		if (tID == -1)
			{ // build a new engine loco
			if (!cRoute.CanAddTrainToStation(uid))
				{
				DInfo("Cannot add any trains anymore as one of the station cannot handle one more",1);
				return true;
				}
			DInfo("Adding a new engine to create a train",0);
			depotID=cRoute.GetDepot(uid); // because previous CanAddTrainToStation could have move it
			local stop=false;
			while (!stop)
				{
				stop=true;
				tID=INSTANCE.main.carrier.AddNewTrain(uid, null, 0, depotID, stationLen, false);
				if (AIVehicle.IsValidVehicle(tID))
					{
					AIGroup.MoveVehicle(road.GroupID, tID);
					local topspeed=AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(tID));
					cRoute.AddTrain(uid, tID);
					if (INSTANCE.main.carrier.speed_MaxTrain < topspeed)
						{
						DInfo("Setting maximum speed for trains to "+topspeed+"km/h",0);
						INSTANCE.main.carrier.speed_MaxTrain=topspeed;
						}
					}
				else	if (tID == -2)	stop=false; // loop so we pickup another loco engine
							else	giveup=true;
				}
			if (stop)	numTrains++;
			}
	
		if (AIVehicle.IsValidVehicle(tID) && AIVehicle.GetState(tID) == AIVehicle.VS_IN_DEPOT && !giveup)
			{ // now we can add wagons to it
			local beforesize=cCarrier.GetNumberOfWagons(tID);
			depotID=AIVehicle.GetLocation(tID);
			local freightlimit=cCargo.IsFreight(road.CargoID);
			if (numTrains > 1 || beforesize+wagonNeed < 5)	tID=INSTANCE.main.carrier.AddNewTrain(uid, tID, wagonNeed, depotID, stationLen, false);
					else	{
						local newwagon=4-beforesize;
						tID=INSTANCE.main.carrier.AddNewTrain(uid, tID, newwagon, depotID, stationLen, false);
						processTrains.push(-1);
						numTrains++;
						DInfo("Adding "+newwagon+" wagons to this train and create another one with "+(wagonNeed-newwagon),1);
						}
			if (freightlimit > -1 && !cTrain.IsFreight(tID) && beforesize+wagonNeed > freightlimit)
					{
					if (INSTANCE.main.carrier.AddNewTrain(uid, tID, 0, depotID, stationLen, true))
						{
						cTrain.SetExtraEngine(tID);
						DInfo("Added an extra engine to pull freight",1);
						}
					}
			if (AIVehicle.IsValidVehicle(tID))
				{
				local newwagon=cCarrier.GetNumberOfWagons(tID)-beforesize;
				wagonNeed-=newwagon;
				if (wagonNeed <= 0)	wagonNeed=0;
				cTrain.SetFull(tID, false);
				while (AIVehicle.GetLength(tID) > stationLen)
					{
					DInfo("Selling a wagon to meet station length restrictions of "+stationLen,2);
					local wagondelete=cCarrier.GetWagonFromVehicle(tID);
					if (!AIVehicle.SellWagon(tID, wagondelete))
						{
						DError("Cannot delete that wagon : "+wagondelete,2);
						break;
						}
					else	{ wagonNeed++; }
					cTrain.SetFull(tID,true);
					}
				cTrain.Update(tID);
				cCarrier.TrainExitDepot(tID);
				cTrain.SetDepotVisit(tID);
				}
			}
		} while (processTrains.len()!=0 && !giveup);
	road.RouteUpdateVehicle();
	return !giveup;
}

