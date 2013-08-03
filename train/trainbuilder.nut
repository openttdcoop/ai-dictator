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

function cCarrier::ChooseRailCouple(cargo, rtype = -1, depot = -1, forengine = -1)
// This function will choose a wagon to carry that cargo, and a train engine to pull the wagon
// It will return an array : [0] = train_engineID, [1] = wagon_engineID [2] the railtype need for that couple
// empty array
{
	local object = cEngineLib.Infos();
	object.bypass = DictatorAI.GetSetting("use_nicetrain");
	object.cargo_id = cargo;
	object.depot = depot;
	object.engine_type = AIVehicle.VT_RAIL;
	object.engine_roadtype = rtype;
	object.engine_id = forengine;
	cBanker.RaiseFundsBigTime();
	local veh = cEngineLib.GetBestEngine(object, cCarrier.VehicleFilterTrain);
	if (veh[0] != -1)
		{
		DInfo("selected train couple : "+cEngine.GetName(veh[0])+" to pull "+cEngine.GetName(veh[1])+" for "+cCargo.GetCargoLabel(cargo)+" using railtype "+veh[2],1);
		}
	else	{
		DInfo("ChooseRailCouple return error "+AIError.GetLastErrorString()+" * "+cEngineLib.GetAPIError(),2);
		
		}
	return veh;
}

function cCarrier::GetRailTypeNeedForEngine(engineID)
// return the railtype the engine need to work on
{
	if (!AIEngine.IsValidEngine(engineID))	return -1;
	local rtypelist=AIRailTypeList();
	foreach (rtype, dum in rtypelist)
		{
		if (AIEngine.HasPowerOnRail(engineID, rtype) && AIRail.GetMaxSpeed(rtype)==0)	return rtype;
		}
	return -1;
}

function cCarrier::GetWagonsInGroup(groupID)
// return number of wagons present in the group
{
	if (groupID == null)	return 0;
	local vehlist=AIVehicleList_Group(groupID);
	local total=0;
	foreach (veh, dummy in vehlist)	total+=cEngineLib.GetNumberOfWagons(veh);
	return total;
}

function cCarrier::AddNewTrain(uid, trainID, wagonNeed, depot, maxLength, extraEngine)
// Add a train or add wagons to an existing train
{
	local road=cRoute.Load(uid);
	if (!road)	return -1;
	local locotype = -1;
	local wagontype = -1;
	if (trainID == null)
			{
			locotype= cCarrier.ChooseRailCouple(road.CargoID, road.SourceStation.s_SubType, depot, -1);
			if (locotype[0] == -1)	return -1;
						else	{ wagontype = locotype[1]; locotype = locotype[0]; }
			}
		else	locotype=AIVehicle.GetEngineType(trainID);
	if (wagontype == -1)
			{
			wagontype= cCarrier.ChooseRailCouple(road.CargoID, road.SourceStation.s_SubType, -1, locotype);
			if (wagontype[0] == -1)	return -1;
			wagontype = wagontype[1];
			}
	local wagonID = null;
	local pullerID = null;
	if (trainID == null)	pullerID = cEngineLib.CreateVehicle(depot, locotype, road.CargoID);
				else	pullerID = trainID;
	if (pullerID == -1)	{ DError("Cannot create the train engine "+AIEngine.GetName(locotype),1); return -1; }
	if (extraEngine)
		{
		local xengine = cCarrier.ChooseRailCouple(road.CargoID, road.SourceStation.s_SubType, depot, wagontype);
		if (xengine[0] == -1)	xengine = -1;
					else	xengine = xengine[0];
		if (("IsMultiheaded" in AIEngine) && AIEngine.IsMultiheaded(locotype))	return true; // handle new API function
		xengine = cEngineLib.CreateVehicle(depot, xengine, road.CargoID);
		if (xengine==-1)	{ DInfo("Cannot add an extra engine to that train, will redo later",1); return false; }
				else	{
					if (!AIVehicle.MoveWagon(xengine, 0, pullerID, AIVehicle.GetNumWagons(pullerID) - 1)) AIVehicle.SellVehicle(xengine);
					return true;
					}
		}
	for (local i=0; i < wagonNeed; i++)
		{
		local nwagonID = cEngineLib.CreateVehicle(depot, wagontype, road.CargoID);
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
	cTrain.Update(pullerID);
	return pullerID;
}

function cCarrier::AddWagon(uid, wagonNeed)
// Add wagons to route uid, handle the train engine by buying it if need
// If need we send a train to depot to get more wagons, and we will be called back by the in depot event
// We will return true if we consider the job done (adding wagons)
// This is not always without getting an error, but we will says true per example if we cannot add new wagons because the station cannot support more wagons...
{
	local road=cRoute.Load(uid);
	if (!road)	return false;
	local vehlist = AIVehicleList_Station(road.SourceStation.s_ID);
	foreach (veh, dummy in vehlist)
		{
		if (cCarrier.ToDepotList.HasItem(veh) && cCarrier.VehicleSendToDepot_GetReason(cCarrier.ToDepotList.GetValue(veh)) == DepotAction.SIGNALUPGRADE)
					{
					DInfo("Cannot do any action with trains while we're upgrading signals",1);
					return true;
					}
		}
	if (wagonNeed == 0)	return true;
	vehlist=AIVehicleList_Group(road.GroupID);
	local indepot = [];
	local canorder = AIList();
	local stationLen=road.SourceStation.s_Train[TrainType.DEPTH]*16;
	local processTrains=[];
	local tID=null;
	local depotID=cRoute.GetDepot(uid);
	cDebug.PutSign(depotID,"Depot Builder");
	local giveup=false;
	foreach (veh, dummy in vehlist)
		{
		local state = AIVehicle.GetState(veh);
		if (state != AIVehicle.VS_IN_DEPOT && state != AIVehicle.VS_RUNNING)	{ continue; }
		if (state == AIVehicle.VS_IN_DEPOT)	{ indepot.push(veh); continue; } //wait handling
		if (cCarrier.ToDepotList.HasItem(veh) && cCarrier.VehicleSendToDepot_GetReason(cCarrier.ToDepotList.GetValue(veh)) == DepotAction.ADDWAGON)
			{
			DInfo("Updating number of wagons need for "+cCarrier.GetVehicleName(veh)+" to "+wagonNeed,1);
			cCarrier.ToDepotList.SetValue(veh, DepotAction.ADDWAGON+wagonNeed);
			return true;
			}
		if (!cTrain.IsFull(veh))	canorder.AddItem(veh, 0); // can be called
		}
	if (indepot.len() != 0)	processTrains.extend(indepot);
				else	{
					local before = canorder.IsEmpty();
					canorder.Valuate(cTrain.CanModifyTrain);
					canorder.KeepValue(1);
					if (!before && canorder.IsEmpty())	return true; // no one can be called
					if (canorder.IsEmpty())
							{
							DInfo("No train can hold "+wagonNeed+" new wagons, forcing creation of a new train",2);
							processTrains.push(-1);
							}
						else	{
							canorder.Valuate(AIVehicle.GetNumWagons);
							canorder.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
							local veh = canorder.Begin();
							local wagonID = AIVehicle.GetWagonEngineType(veh, 1);
							local wagonprice = 1000;
							if (AIEngine.IsValidEngine(wagonID))	wagonprice = AIEngine.GetPrice(wagonID);
							wagonprice = wagonNeed * wagonprice;
							if (!cBanker.CanBuyThat(wagonprice)) return false; // don't call it if we lack money
							DInfo("Sending a train to depot to add "+wagonNeed+" more wagons",1);
							cCarrier.VehicleSendToDepot(veh, DepotAction.ADDWAGON+wagonNeed);
							INSTANCE.main.carrier.vehnextprice += wagonprice;
							return true; // calling one, give up
							}
					}
	local numTrains = vehlist.Count();
	do	{
		tID=processTrains.pop();
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
					numTrains++;
					AIGroup.MoveVehicle(road.GroupID, tID);
					local topspeed=AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(tID));
					cRoute.AddTrain(uid, tID);
					if (INSTANCE.main.carrier.speed_MaxTrain < topspeed)
						{
						DInfo("Setting maximum speed for trains to "+topspeed+"km/h",0);
						INSTANCE.main.carrier.speed_MaxTrain=topspeed;
						}
					}
				else	{
					if (tID == -2)	stop=false; // loop so we pickup another loco engine
							else	giveup=true;
					}
				}
			}
	
		if (AIVehicle.IsValidVehicle(tID) && !giveup)
			{ // now we can add wagons to it
			local beforesize = cEngineLib.GetNumberOfWagons(tID);
			depotID=AIVehicle.GetLocation(tID);
			local freightlimit=cCargo.IsFreight(road.CargoID);
			if (numTrains > 1 || beforesize+wagonNeed < 5)	tID=INSTANCE.main.carrier.AddNewTrain(uid, tID, wagonNeed, depotID, stationLen, false);
					else	{
						local newwagon=4-beforesize;
						tID=INSTANCE.main.carrier.AddNewTrain(uid, tID, newwagon, depotID, stationLen, false);
						processTrains.push(-1);
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
				local newwagon=cEngineLib.GetNumberOfWagons(tID)-beforesize;
				wagonNeed-=newwagon;
				if (wagonNeed <= 0)	wagonNeed=0;
				while (AIVehicle.GetLength(tID) > stationLen)
					{
					DInfo("Selling a wagon to meet station length restrictions of "+stationLen,2);
					local wagondelete=cEngineLib.GetWagonFromVehicle(tID);
					if (!AIVehicle.SellWagon(tID, wagondelete))
						{
						DError("Cannot delete that wagon : "+wagondelete,2);
						break;
						}
					else	{ wagonNeed++; }
					cTrain.SetFull(tID,true);
					}
				if (cEngineLib.GetNumberOfWagons(tID) == 0)
						{
						DInfo("Train have no wagons... selling it",2);
						AIVehicle.SellVehicle(tID);
						}
					else	{
						cTrain.Update(tID);
						cCarrier.TrainExitDepot(tID);
						cTrain.SetDepotVisit(tID);
						}
				}
			}
		} while (processTrains.len()!=0 && !giveup);
	road.RouteUpdateVehicle();
	return !giveup;
}

