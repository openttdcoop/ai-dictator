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
			print("cargo: "+cCargo.GetCargoLabel(object.cargo_id));
			print("loco: "+cEngine.GetName(object.engine_id));
			print("RT: "+cEngine.GetRailTrackName(object.engine_roadtype));
			local EUID = cEngine.GetEUID(2000 + object.engine_roadtype, object.cargo_id);
			print("EUID: "+EUID);
			print("best engine #"+EUID+" -> "+cEngine.GetName(cEngine.BestEngineList.GetValue(EUID)));
//			AIController.Break("train fail");
			}
	local dloc = AIMap.GetTileIndex(1,4);
	print("dloc "+cMisc.Locate(dloc));
	if (cEngineLib.IsDepotTile(dloc))	cEngineLib.DumpLibStats();
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
    local road = cRoute.LoadRoute(uid);
    if (!road)  { return -1; }
    if (road.Status != RouteStatus.WORKING) { return -1; }
    local depot = cRoute.GetDepot(uid);
    if (depot == -1)    { return -1; }
    local maxlength = road.SourceStation.s_Depth * 16;
    local tID, t_wagon;
	DInfo("Force building a train with " + wagons + " wagons",1);
	tID = cCarrier.AddNewTrain(uid, null, wagons, depot, maxlength);
	if (!AIVehicle.IsValidVehicle(tID))    { return -1; }
	AIGroup.MoveVehicle(road.GroupID, tID);
	t_wagon = cEngineLib.VehicleRestrictLength(tID, maxlength);
	t_wagon = cEngineLib.VehicleGetNumberOfWagons(tID);
	if (t_wagon == 0)
			{
			cCarrier.VehicleSell(tID, false);
            return -1;
			}
	cCarrier.VehicleExitDepot(tID);
	cTrain.SetDepotVisit(tID);
    }

function cCarrier::AddNewTrain(uid, trainID, wagonNeed, depot, maxLength)
// Add a train or add wagons to an existing train
	{
	local road = cRoute.LoadRoute(uid);
	if (!road)	{ return -1; }
	local locotype = -1;
	local wagontype = -1;
	if (trainID == null)
			{
			locotype = cCarrier.ChooseRailCouple(road.CargoID, road.SourceStation.s_SubType, depot, -1);
			if (locotype[0] == -1)	{ return -1; }
                            else	{ wagontype = locotype[1]; locotype = locotype[0]; }
			}
	else	{ locotype = AIVehicle.GetEngineType(trainID); }
	print("wagontype = " + wagontype);
	if (wagontype == -1)
			{
			// Try pickup a new (better) wagontype
			wagontype = cCarrier.ChooseRailCouple(road.CargoID, road.SourceStation.s_SubType, depot, locotype);
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
                            AIGroup.MoveVehicle(road.GroupID, pullerID);
                            cRoute.AddTrainToRoute(road.UID, pullerID);
                            if (pullerID != -1)	{
                                                INSTANCE.main.carrier.vehicle_cash -= AIEngine.GetPrice(locotype);
                                                INSTANCE.main.carrier.highcostTrain = 0;
                                                }
                            }
                    else	{ pullerID = trainID; }
	if (pullerID == -1)	{
                        DError("Cannot create the train engine " + cEngine.GetEngineName(locotype),1);
                        INSTANCE.main.carrier.highcostTrain = AIEngine.GetPrice(locotype);
                        INSTANCE.main.carrier.vehicle_cash += AIEngine.GetPrice(locotype);
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
                            INSTANCE.main.carrier.vehicle_cash -= AIEngine.GetPrice(wagontype);
                            break;
							}
					else
							{
		                   	local guess_locos = cEngineLib.VehicleLackPower(pullerID);
		                   	if (guess_locos && cEngineLib.VehicleGetNumberOfLocomotive(pullerID) < 3) // we need more locos
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

function cCarrier::AddWagon(uid)
// Add wagons to route uid, handle the train engine by buying it if need
// If need we send a train to depot to get more wagons, and we will be called back by the in depot event
// We will return true if we consider the job done (adding wagons)
// This is not always without getting an error, but we will says true per example if we cannot add new wagons because the station cannot support more wagons...
{
	print("AddWagon: "+uid);
	local road = cRoute.LoadRoute(uid);
	if (!road)	return false;
	local veh_stats = AIList();
	local vehlist = AIVehicleList_Group(road.GroupID);
	vehlist.Valuate(cEngineLib.VehicleGetNumberOfWagons);
	local _pending_new_wagons = 0;
	local processTrains = [];
	//local usableTrains = AIList();
	local releaseTrains = AIList();
	local max_wagon_to_full = 50;
	foreach (veh, num_wagon in vehlist)
		{
		local reason = -1;
		local value = 0;
		if (cCarrier.ToDepotList.HasItem(veh))
				{
				local cmd = cCarrier.ToDepotList.GetValue(veh);
				local reason = cCarrier.VehicleSendToDepot_GetReason(cmd);
				if (reason == DepotAction.SIGNALUPGRADE || reason == DepotAction.LINEUPGRADE || reason == DepotAction.REMOVEROUTE)
					{
					DInfo("Cannot do any action with trains while we're upgrading signals or the railtype",1);
					return true;
					}
				local param = cCarrier.VehicleSendToDepot_GetParam(cmd);
				if (reason == DepotAction.REMOVEWAGON)	param = -param;
				value = param;
				}
		if (value < 0 && AIVehicle.GetState(veh) == AIVehicle.VS_IN_DEPOT)
				{ // remove the wagons
				cCarrier.RemoveWagon(veh, abs(value));
				cCarrier.ToDepotList.RemoveItem(veh);
				value = 0;
				veh_stats.AddItem(veh, cEngineLib.VehicleGetNumberOfWagons(veh));
				}
		else	veh_stats.AddItem(veh, num_wagon + value);
		_pending_new_wagons += value;
		local isfull = cTrain.IsFull(veh);
		if (isfull && max_wagon_to_full > num_wagon)	{ max_wagon_to_full = num_wagon; }
		// if not full or if it need more engine, we can use this one
		//if (!isfull || (cEngineLib.VehicleLackPower(veh) && cEngineLib.VehicleGetNumberOfLocomotive(veh) < 3))	usableTrains.AddItem(veh, 0);
		// but if the train is at depot already, that's not need
		if (AIVehicle.GetState(veh) == AIVehicle.VS_IN_DEPOT)
				{
				processTrains.push(veh);
				releaseTrains.AddItem(veh, 0);
				}
		}
	local stationLen = road.SourceStation.s_Depth * 16;
	local tID = null;
	local depotID = cRoute.GetDepot(uid);
	cDebug.PutSign(depotID,"Depot Builder");
	local giveup = 0;
	local balance_change = false;
	local _num_trains = vehlist.Count();
	local _wagons_ask = 0;
	if (INSTANCE.main.carrier.vehicle_wishlist.HasItem(road.GroupID))
		{
		_wagons_ask = INSTANCE.main.carrier.vehicle_wishlist.GetValue(road.GroupID);
		if (_wagons_ask >= 1000)	_wagons_ask -= 1000;
		}
	print("_wagons_ask= "+_wagons_ask+" _pending_new_wagons= "+_pending_new_wagons+" _num_train= "+ _num_trains + " processTrains= "+processTrains.len() + " sample="+cCarrier.GetVehicleName(vehlist.Begin()));
	_wagons_ask -= _pending_new_wagons; // remove pending wagons that will be created
	//if (_wagons_ask < 0)	_wagons_ask = 0;
	print("BREAK");
    local rawbalance = AIList();
    rawbalance.AddList(veh_stats);
    if (!rawbalance.IsEmpty())
		{
		local eng = [];
		eng.push(AIVehicle.GetEngineType(rawbalance.Begin()));
		eng.push(AIVehicle.GetWagonEngineType(rawbalance.Begin(), cEngineLib.VehicleGetRandomWagon(rawbalance.Begin())));
		print("max_wagon_to_full=" + max_wagon_to_full);
		if (max_wagon_to_full == 50)	max_wagon_to_full = cEngineLib.GetMaxWagons(eng, stationLen, road.CargoID);
		if (max_wagon_to_full == -1)	max_wagon_to_full = 50;
		print("Adjusting new max_wagon_to_full=" + max_wagon_to_full);
		}
    if (_wagons_ask > 0) // only > 0 when we process one bigger than _pending_new_wagons
		{
		while (_wagons_ask > 0 && !rawbalance.IsEmpty())
			{
			rawbalance.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
			local vlen = rawbalance.GetValue(rawbalance.Begin());
			if (vlen + 1 <= max_wagon_to_full)
						{
						vlen++;
						veh_stats.SetValue(rawbalance.Begin(), vlen);
						rawbalance.SetValue(rawbalance.Begin(), vlen);
						_wagons_ask--; _pending_new_wagons++;
						}
				else	rawbalance.RemoveItem(rawbalance.Begin());
			}
		if (rawbalance.IsEmpty())
				{
				DInfo("No train can hold "+_wagons_ask+" new wagons, forcing creation of a new train",2);
				processTrains.push(-1);
				}
		}
	while (giveup < 1)
		{
		while (processTrains.len() != 0)
			{
			tID = processTrains.pop();
			if (tID == -1)
					{
					// build a new engine loco
					if (!cRoute.CanAddTrainToStation(uid))
							{
							DInfo("Cannot add any trains as one of the station cannot handle one more",1);
							giveup = 1;
							continue;
							}
					DInfo("Adding a new engine to create a train",0);
					depotID = cRoute.GetDepot(uid); // because previous CanAddTrainToStation could have move it
					tID = cCarrier.AddNewTrain(uid, null, 1, depotID, stationLen);
					// We must force at least one wagon, else if we lack money to build another engine for that train and the train have no wagon, we couldn't
					// find what kind of wagon it will then need, making the train remain empty.
					if (AIVehicle.IsValidVehicle(tID))
						{
						local topspeed = AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(tID));
						if (INSTANCE.main.carrier.speed_MaxTrain < topspeed)
								{
								DInfo("Setting maximum speed for trains to "+topspeed+"km/h",0);
								INSTANCE.main.carrier.speed_MaxTrain=topspeed;
								}
						local n_wagon = cEngineLib.VehicleGetNumberOfWagons(tID);
						veh_stats.AddItem(tID, _wagons_ask); // give it the remain asked wagons
						_pending_new_wagons += (_wagons_ask - n_wagon); // add them as pending wagons
						_wagons_ask = 0;
						vehlist.AddItem(tID, 0);
						releaseTrains.AddItem(tID, 0);
						}
					}
			if (AIVehicle.IsValidVehicle(tID))
					{
					local num_before = cEngineLib.VehicleGetNumberOfWagons(tID);
					local one_need = veh_stats.GetValue(tID) - num_before;
					//if (veh_stats.HasItem(tID) && veh_stats.GetValue(tID) != 0) one_need = veh_stats.GetValue(tID);
					DInfo(cCarrier.GetVehicleName(tID) + " is here for " + one_need + " wagons, it have " + num_before,1);
					print("_wagons_ask="+_wagons_ask+" _pending="+_pending_new_wagons);
					if (one_need == 0)	continue;
					_wagons_ask += one_need;
					_pending_new_wagons -= one_need; // transfert pending query to ask query
					depotID = AIVehicle.GetLocation(tID);
					local freightlimit = cCargo.IsFreight(road.CargoID);
					local need_more_train = (vehlist.Count() == 1);
					if (need_more_train)	need_more_train = cBanker.CanBuyThat(AIEngine.GetPrice(AIVehicle.GetEngineType(tID)));
					print("need_more_train: "+need_more_train);
					if (one_need > 0)
								{ // add more wagon
								if (!need_more_train || num_before + one_need < 4)
											{ local res = cCarrier.AddNewTrain(uid, tID, one_need, depotID, stationLen); }
									else	{
											DInfo("Forcing a new train", 2);
											if (cRoute.CanAddTrainToStation(uid))	processTrains.push(-1);
											veh_stats.SetValue(tID, num_before); // force the train to get no wagons at all
											continue;
											}
								}
						else    cCarrier.RemoveWagon(tID, abs(one_need)); // remove wagons
					// restrict length
					local lost = cEngineLib.VehicleRestrictLength(tID, stationLen);
					print("lost = "+lost);
					// get new number of wagons after creation and length restriction
					local num_after = cEngineLib.VehicleGetNumberOfWagons(tID);
					local n_wagon = (num_after - num_before);
					_wagons_ask -= n_wagon;
//					_pending_new_wagons -= n_wagon;
					print("newwagon = " + n_wagon+" new_size = " + num_after);
					print("_wagons_ask="+_wagons_ask+" _pending="+_pending_new_wagons);
					veh_stats.SetValue(tID, num_after);
					cTrain.TrainUpdate(tID);
					}
				} // while processTrains
			print("_num_trains= " + _num_trains+" vehlist.Count= "+vehlist.Count()+" giveup= "+giveup+" _wagons_ask= "+_wagons_ask+" _pending_new_wagons= "+_pending_new_wagons);
			if (_num_trains != vehlist.Count() && _num_trains > 0)
				{ // _num_trains no more == if we have add a new train while looping
				giveup = -1;
				// what remain in _wagons_ask are all wagons we couldn't had built (lack money, length restriction...)
				print("Rebalancing trains : "+(_wagons_ask + _pending_new_wagons));
				// and _pending_new_wagons are the ones we ask to built but weren't built (train is still running)
				local balancing = cCarrier.GetTrainBalancingStats(road.GroupID, _wagons_ask + _pending_new_wagons, 0);
				for (local i = 0; i < balancing.len(); i++)
						{
						local g_id = balancing[i];
						local v_id = balancing[i + 1];
						local w_nu = balancing[i + 2];
						i += 2;
						//local v_wagon = cEngineLib.VehicleGetNumberOfWagons(v_id);
						veh_stats.SetValue(v_id, w_nu);
						if (AIVehicle.GetState(v_id) == AIVehicle.VS_IN_DEPOT)	processTrains.push(v_id);
						print("Rebalancing "+cCarrier.GetVehicleName(v_id) + "to "+w_nu+" wagons");
						}
				// Last clear out any vehicle wish as we have handle them all.
				INSTANCE.main.carrier.vehicle_wishlist.RemoveItem(road.GroupID);
                // clear out the asked wagons
                _wagons_ask = 0;
                _num_trains = vehlist.Count();
				}
		giveup++;
		} // while !giveup
	print("after balancing & handling _wagons_ask= "+_wagons_ask + " veh_stats= "+veh_stats.Count());
		print("BREAK");
/*	if (_wagons_need > 0) // we still need to add some
				{
				if (!vehlist.IsEmpty())
						{
						// give the remain wagons to the one with lowest num of wagons
						vehlist.Valuate(cEngineLib.VehicleGetNumberOfWagons);
						vehlist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
						veh_stats.SetValue(vehlist.Begin(), _wagons_need);
						print("putting the ask remain query "+_wagons_need+" to "+cCarrier.GetVehicleName(vehlist.Begin()));
						}
				INSTANCE.main.carrier.vehicle_wishlist.SetValue(road.GroupID, _wagons_need);
				}
		else	INSTANCE.main.carrier.vehicle_wishlist.RemoveItem(road.GroupID);*/
	local total_ask_now = 0;
	foreach (veh, stats in veh_stats)
		{
		print("veh="+veh+" stats="+stats);
		if (releaseTrains.HasItem(veh))
					{
					cCarrier.VehicleExitDepot(veh);
					cTrain.SetDepotVisit(veh);
					}
		//if (cCarrier.ToDepotList.HasItem(veh))	cCarrier.ToDepotList.RemoveItem(veh);
		local wagon = stats - cEngineLib.VehicleGetNumberOfWagons(veh);
		if (wagon == 0)	continue;
		local wagon_prize = AIEngine.GetPrice(cEngineLib.VehicleGetRandomWagon(veh));
		if (wagon > 0)	{ // don't call it if we have no money to buys wagons
						if (cBanker.CanBuyThat(wagon_prize * wagon))
								{
								cCarrier.VehicleSendToDepot(veh, DepotAction.ADDWAGON + wagon);
								total_ask_now += wagon;
								}
						}
				else	cCarrier.VehicleSendToDepot(veh, DepotAction.REMOVEWAGON + abs(wagon));
		}
	INSTANCE.main.carrier.vehicle_wishlist.RemoveItem(road.GroupID);
	print("_wagons_ask= "+_wagons_ask+" total_ask_now= "+total_ask_now+" new_ask = "+abs(_wagons_ask + total_ask_now));
	_wagons_ask = abs(_wagons_ask + total_ask_now); // add what we didn't built
	if (_wagons_ask != 0)	INSTANCE.main.carrier.vehicle_wishlist.AddItem(road.GroupID, 1000 + _wagons_ask);
	print("BREAK TWO");
	cRoute.RouteUpdateVehicle(road);
	return !giveup;
}

function cCarrier::RemoveWagon(vehicle_id, num_delete)
{
	local num_wagon = cEngineLib.VehicleGetNumberOfWagons(vehicle_id);
	for (local i = 0; i < num_delete; i++)
		{
		if (num_wagon == 1)	break; // at least keep one wagon attach
		local id = cEngineLib.VehicleGetRandomWagon(vehicle_id);
        if (!AIVehicle.SellWagon(vehicle_id, id))	break;
											else	num_wagon--;
		}
}

function cCarrier::GetTrainBalancingStats(groupID, add_wagon, add_train)
// return an array with number of wagon to build / train
{
	local group_train = AIVehicleList_Group(groupID);
	local uid = cRoute.GroupIndexer.GetValue(groupID);
	local num_wagon = 0;
	local num_train = group_train.Count();
	local profit = 0;
	local loosemoney = false;
	local balance = [];
	local balancing = AIList();
	foreach (veh, _ in group_train)
			{
			local z = cEngineLib.VehicleGetNumberOfWagons(veh);
			balancing.AddItem(veh, z);
			num_wagon += z;
			local money = AIVehicle.GetProfitThisYear(veh);
			if (money <  0)	loosemoney = true;
			profit += money + AIVehicle.GetProfitLastYear(veh);
			}
	if (add_wagon > 0)	num_wagon += add_wagon;
	if (add_train)	{ num_train++; balancing.AddItem(-666, 0); group_train.AddItem(-666, 0); }
	if (loosemoney)	num_wagon -= num_train; // one is not making money, so we remove 1 wagon on all trains
    local average = num_wagon / num_train;
    if (average < 1)	{ num_wagon = num_train; average = 1; }
    if (profit < 0 && average > 1)	{ num_wagon = num_train * 2; average = 2; } // if we cannot do money, we short all trains to 2 wagons
    print("num_train="+num_train+" num_wagon="+num_wagon);
	foreach (veh, _ in balancing)
		{
        group_train.SetValue(veh, average);
        num_wagon -= average;
		}
	balancing.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
	foreach (veh, _ in balancing)
		{
        if (num_wagon == 0)	break;
		group_train.SetValue(veh, group_train.GetValue(veh) + 1);
		num_wagon--;
		}
	foreach (veh, number in group_train)	{ balance.push(uid); balance.push(veh); balance.push(number); }
	foreach (item in balance)	{ print("balance item="+item); }
	return balance;
}
