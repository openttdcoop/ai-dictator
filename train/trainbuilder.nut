/* -*- Mode: C++; tab-width: 4 -*- */
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
	object.bypass = !DictatorAI.GetSetting("use_nicetrain");
	object.cargo_id = cargo;
	object.depot = depot;
	object.engine_type = AIVehicle.VT_RAIL;
	object.engine_roadtype = rtype;
	object.engine_id = forengine;
	local veh = cEngineLib.GetBestEngine(object, cCarrier.VehicleFilterTrain);
	if (veh[0] != -1)
			{
            cEngine.CheckMaxSpeed(veh[0]);
			DInfo("selected train couple : "+cEngine.GetEngineName(veh[0])+" to pull "+cEngine.GetEngineName(veh[1])+" for "+cCargo.GetCargoLabel(cargo)+" using railtype "+cEngine.GetRailTrackName(veh[2]),1);
			}
	else
			{
			DInfo("ChooseRailCouple return error "+AIError.GetLastErrorString()+" * "+cEngineLib.GetAPIError(),2);
			}
	return veh;
	}

function cCarrier::GetWagonsInGroup(groupID)
// return number of wagons present in the group
	{
	if (groupID == null)	{ return 0; }
	local vehlist=AIVehicleList_Group(groupID);
	local total=0;
	foreach (veh, dummy in vehlist)	total+=cEngineLib.VehicleGetNumberOfWagons(veh);
	return total;
	}

function cCarrier::ForceAddTrain(uid, wagons)
// Force adding a train to the route without checks
    {
    local road = cRoute.Load(uid);
    if (!road)  { return -1; }
    if (road.Status != RouteStatus.WORKING) { return -1; }
    local depot = cRoute.GetDepot(uid);
    if (depot == -1)    { return -1; }
    local maxlength = road.SourceStation.s_Train[TrainType.DEPTH]*16;
    local tID, t_wagon;
	DInfo("Force building a train with "+wagons+" wagons",1);
	tID = cCarrier.AddNewTrain(uid, null, wagons, depot, maxlength);
	if (!AIVehicle.IsValidVehicle(tID))    { return -1; }
	AIGroup.MoveVehicle(road.GroupID, tID);
	cRoute.AddTrain(uid, tID);
	t_wagon = cEngineLib.VehicleRestrictLength(tID, maxlength);
	t_wagon = cEngineLib.VehicleGetNumberOfWagons(tID);
	if (t_wagon == 0)
			{
			cCarrier.VehicleSell(tID, false);
            return -1;
			}
	cCarrier.TrainExitDepot(tID);
	cTrain.SetDepotVisit(tID);
    }

function cCarrier::AddNewTrain(uid, trainID, wagonNeed, depot, maxLength)
// Add a train or add wagons to an existing train
	{
	local road=cRoute.Load(uid);
	if (!road)	{ return -1; }
	local locotype = -1;
	local wagontype = -1;
	if (trainID == null)
			{
			locotype= cCarrier.ChooseRailCouple(road.CargoID, road.SourceStation.s_SubType, depot, -1);
			if (locotype[0] == -1)	{ return -1; }
                            else	{ wagontype = locotype[1]; locotype = locotype[0]; }
			}
	else	{ locotype=AIVehicle.GetEngineType(trainID); }
	print("wagontype = "+wagontype);
	if (wagontype == -1)
			{
			// Try pickup a new (better) wagontype
			wagontype= cCarrier.ChooseRailCouple(road.CargoID, road.SourceStation.s_SubType, depot, locotype);
			if (wagontype[0] == -1)	{ // couldn't, no better wagon, lack of money for tests...
									if (trainID != null)
										{
										local awagon = cEngineLib.VehicleGetRandomWagon(trainID);
										// Pickup a wagon directly from the train if we cannot manage to find a better one
										if (awagon != -1)	wagontype = AIVehicle.GetWagonEngineType(trainID, awagon);
													else	return -1;
										}
									}
							else	wagontype = wagontype[1];
			}
	local wagonID = null;
	local pullerID = null;
	if (trainID == null)	{
                            pullerID = cEngineLib.VehicleCreate(depot, locotype, road.CargoID);
                            if (pullerID == -1) { INSTANCE.main.carrier.vehicle_cash += cEngineLib.GetPrice(locotype, road.CargoID); }
                                        else    {
                                                INSTANCE.main.carrier.vehicle_cash -= cEngineLib.GetPrice(locotype, road.CargoID);
                                                INSTANCE.main.carrier.highcostTrain = 0;
                                                }
                            }
                    else	{ pullerID = trainID; }
	if (pullerID == -1)	{
                        DError("Cannot create the train engine "+cEngine.GetEngineName(locotype),1);
                        INSTANCE.main.carrier.highcostTrain = cEngineLib.GetPrice(locotype, road.CargoID);
                        return -1;
                        }
	local freightlimit = cCargo.IsFreight(road.CargoID);
	local beforesize = cEngineLib.VehicleGetNumberOfWagons(pullerID);
	for (local i=0; i < wagonNeed; i++)
			{
			local nwagonID = cEngineLib.VehicleCreate(depot, wagontype, road.CargoID);
			print("i="+i+" wagonNeed="+wagonNeed+" nwagonID="+nwagonID);
			if (nwagonID != -1)
					{
					if (!AIVehicle.MoveWagonChain(nwagonID, 0, pullerID, AIVehicle.GetNumWagons(pullerID)-1))
							{
							DError("Wagon "+cEngine.GetEngineName(wagontype)+" cannot be attach to "+cEngine.GetEngineName(locotype),2);
                            AIVehicle.SellVehicle(nwagonID);
                            INSTANCE.main.carrier.vehicle_cash -= cEngineLib.GetPrice(wagontype, road.CargoID);
                            break;
							}
					else
							{
		                   	local guess_locos = cEngineLib.VehicleLackPower(pullerID);
		                   	if (guess_locos) // we need more locos
								{
								DInfo("We need extra engine to hanlde freight",1);
								local xengine = cCarrier.ChooseRailCouple(road.CargoID, road.SourceStation.s_SubType, depot, wagontype);
								if (xengine[0] == -1)	{ xengine = -1; }
												else	{ xengine = xengine[0]; }
								if (xengine != -1)  { xengine = cEngineLib.VehicleCreate(depot, xengine, road.CargoID); }
								if (xengine == -1)	{ DInfo("Cannot add an extra engine to that train, will redo later",1); }
											else   	{
													if (!AIVehicle.MoveWagon(xengine, 0, pullerID, AIVehicle.GetNumWagons(pullerID) - 1))
															{ AIVehicle.SellVehicle(xengine); }
													else    { DInfo("Added an extra engine to pull freight",1); }
													}
								}
							if (AIVehicle.GetLength(pullerID) > maxLength)
									{
									// prevent building too much wagons for nothing and prevent failure that let wagons remain in the depot forever
									DInfo("Stopping adding wagons to train as its length is already too big",2);
									break;
									}
							}
					}
			}
	return pullerID;
	}

function cCarrier::AddWagon(uid, wagonNeed)
// Add wagons to route uid, handle the train engine by buying it if need
// If need we send a train to depot to get more wagons, and we will be called back by the in depot event
// We will return true if we consider the job done (adding wagons)
// This is not always without getting an error, but we will says true per example if we cannot add new wagons because the station cannot support more wagons...
	{
	local road=cRoute.Load(uid);
	if (!road)	{ return false; }
	local vehlist = AIVehicleList_Station(road.SourceStation.s_ID);
	foreach (veh, dummy in vehlist)
		{
		if (cCarrier.ToDepotList.HasItem(veh) && cCarrier.VehicleSendToDepot_GetReason(cCarrier.ToDepotList.GetValue(veh)) == DepotAction.SIGNALUPGRADE)
				{
				DInfo("Cannot do any action with trains while we're upgrading signals",1);
				return true;
				}
		}
	if (wagonNeed == 0)	{ return true; }
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
		print("train "+veh+" state="+state+" full="+cTrain.IsFull(veh));
		if (state != AIVehicle.VS_IN_DEPOT && state != AIVehicle.VS_RUNNING && state != AIVehicle.VS_AT_STATION)	{ continue; }
		if (state == AIVehicle.VS_IN_DEPOT)	{ indepot.push(veh); continue; } //wait handling
		if (cCarrier.ToDepotList.HasItem(veh) && cCarrier.VehicleSendToDepot_GetReason(cCarrier.ToDepotList.GetValue(veh)) == DepotAction.ADDWAGON)
				{
				DInfo("Updating number of wagons need for "+cCarrier.GetVehicleName(veh)+" to "+wagonNeed,1);
				cCarrier.ToDepotList.SetValue(veh, DepotAction.ADDWAGON+wagonNeed);
				return true;
				}
		if (!cTrain.IsFull(veh))	{ canorder.AddItem(veh, 0); } // can be called
		}
	if (indepot.len() != 0)	{ processTrains.extend(indepot); }
	else
			{
			local before = canorder.IsEmpty();
			print("non full train = "+canorder.Count());
			canorder.Valuate(cTrain.CanModifyTrain);
			canorder.KeepValue(1);
			print("callable non full train : "+canorder.Count());
			if (!before && canorder.IsEmpty())	{ return true; } // no one can be called
			if (canorder.IsEmpty())
					{
					DInfo("No train can hold "+wagonNeed+" new wagons, forcing creation of a new train",2);
					processTrains.push(-1);
					}
			else
					{
                    if (road.MoreTrain == 1)
							{
							DInfo("Not calling that train until MoreTrain query is done",1);
                            // There a race condition: if we lack money to finally build the stations, we then cannot call pathfinder
                            // and pathfinder gives us the condition to retry upgrading the station
                            // So if pathfinder isn't yet working, we have no way to check the station health if no train enter it
                            if (cPathfinder.CheckPathfinderTaskIsRunning([road.SourceStation.s_ID, road.TargetStation.s_ID]))	return false;
                            cRoute.CanAddTrainToStation(uid); // don't care the result, we try upgrade stations again to reach pathfinding call
                            return false;
							}
					canorder.Valuate(AIVehicle.GetNumWagons);
					canorder.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
					local veh = canorder.Begin();
					local wagonID = AIVehicle.GetWagonEngineType(veh, cEngineLib.VehicleGetRandomWagon(veh));
					local wagonprice = cEngineLib.GetPrice(wagonID);
					wagonprice = wagonNeed * wagonprice;
					if (!cBanker.CanBuyThat(wagonprice)) { return false; } // don't call it if we lack money
					DInfo("Sending a train to depot to add "+wagonNeed+" more wagons",1);
					cCarrier.VehicleSendToDepot(veh, DepotAction.ADDWAGON+wagonNeed);
					return true; // calling one, give up
					}
			}
	local numTrains = vehlist.Count();
	do
			{
			tID=processTrains.pop();
			if (tID == -1)
					{
					// build a new engine loco
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
							tID=cCarrier.AddNewTrain(uid, null, 1, depotID, stationLen);
							// We must force at least one wagon, else if we lack money to build another engine for that train and the train have no wagon, we couldn't
							// find what kind of wagon it will then need, making the train remain empty.
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
									wagonNeed--; // balance the new wagon attach to this train
									}
							else
									{
									if (tID == -2)	{ stop=false; } // loop so we pickup another loco engine
                                            else	{ giveup=true; }
									}
							}
					}
			if (AIVehicle.IsValidVehicle(tID) && !giveup)
					{
					DInfo(AIVehicle.GetName(tID)+" here for "+wagonNeed+" wagons, he have "+cEngineLib.VehicleGetNumberOfWagons(tID),1);
					// now we can add wagons to it
					local beforesize = cEngineLib.VehicleGetNumberOfWagons(tID);
					depotID=AIVehicle.GetLocation(tID);
					local freightlimit=cCargo.IsFreight(road.CargoID);
					if (road.MoreTrain == 3 || numTrains > 1 || beforesize+wagonNeed < 5)
                            { local res=cCarrier.AddNewTrain(uid, tID, wagonNeed, depotID, stationLen); road.MoreTrain = 3; }
					else
							{
							print("forcing new train");
							if (road.MoreTrain == 0)    { road.MoreTrain = 1; }
                            local couple = [];
                            couple.push(AIVehicle.GetEngineType(tID));
                            couple.push(AIVehicle.GetWagonEngineType(tID, cEngineLib.VehicleGetRandomWagon(tID)));
							local maxwagon = cEngineLib.GetMaxWagons(couple, stationLen); // get how many wagons we could handle at max
                            if (maxwagon == -1) { continue; }
							print("maxwagon = "+maxwagon);
							local balance_train1 = 0;
							local balance_train2 = 0;
							// limit number of wagons to 2 full trains
							if (wagonNeed > maxwagon * 2)	wagonNeed = maxwagon * 2;
							local average = wagonNeed / 2;
							balance_train1 = wagonNeed - average - beforesize;
							if (balance_train1 <= 0)
								{
								balance_train1 = 0;
								if (beforesize < maxwagon - 1)	balance_train1 = 1;
								// if it can hold another wagon we give it one, in case train2 lack money to be build at least we grow up by one at every trys until full.
								}
							balance_train2 = wagonNeed - balance_train1; // will get the reminder for itself
							if (balance_train2 == 0)	{ balance_train2++; balance_train1--; } // but we must keep at least 1 for train2
							print("balance_train1="+balance_train1+" balance_train2="+balance_train2);
							local res=cCarrier.AddNewTrain(uid, tID, balance_train1, depotID, stationLen);
							processTrains.push(-1);
							DInfo("Adding "+balance_train1+" wagons to this train and create another one with "+balance_train2,1);
							}
					if (AIVehicle.IsValidVehicle(tID))
							{
							local newwagon = cEngineLib.VehicleGetNumberOfWagons(tID)-beforesize;
							wagonNeed -= newwagon;
							if (wagonNeed <= 0)	{ wagonNeed=0; }
							local res = cEngineLib.VehicleRestrictLength(tID, stationLen);
							print("res="+res+" newwagon="+newwagon);
                            if (res != -1)  { wagonNeed += res;}
							if (cEngineLib.VehicleGetNumberOfWagons(tID) == 0)
									{
									DInfo("Train have no wagons... selling it",2);
									cCarrier.VehicleSell(tID, false);
									}
							else
									{
									cCarrier.Lower_VehicleWish(road.GroupID, newwagon - wagonNeed);
									cCarrier.TrainExitDepot(tID);
                                    print(cCarrier.GetVehicleName(tID)+" exit depot with "+cEngineLib.VehicleGetNumberOfWagons(tID));
									cTrain.SetDepotVisit(tID);
									}
							}
					}
			}
	while (processTrains.len()!=0 && !giveup);
	road.RouteUpdateVehicle();
	return !giveup;
	}

function cCarrier::GetTrainBalancingStats(uid)
// return an array with number of wagon to build / train
{
//	local uid = cCarrier.VehicleFindRouteIndex(vehicle);
//	if (uid == null)	return;
	if (!cRoute.GroupIndexer.HasItem(uid))	return;
	local groupID = cRoute.GroupIndexer.GetValue(uid);
	local num_train = AIVehicleList_Group(groupID);
	local num_wagon = 0;
	local profit = 0;
	local loosemoney = false;
	local balance = [];
	foreach (veh, _ in num_train)
			{
			num_wagon += cEngineLib.VehicleGetNumberOfWagons(veh);
			local money = AIVehicle.GetProfitThisYear(veh);
			if (money <  0)	loosemoney = true;
			profit += money;
			}
	if (loosemoney)	numwagon -= num_train.Count(); // one is not making money, so we remove 1 wagon on all trains
    local average = num_wagon / num_train.Count();
    if (profit < 0 && average > 1)	{ num_wagon = num_train.Count() * 2; average = 2; } // if we cannot do money, we short all trains to 2 wagons
	foreach (veh, _ in num_train)
		{
		balance.push(uid);
		if (average < num_wagon)	balance.push(average);
							else	balance.push(num_wagon);
		}
	return balance;
}
