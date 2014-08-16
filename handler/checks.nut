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


// all operations here are cBuilder even the file itself do handling work
// operations here are time eater

function cBuilder::WeeklyChecks()
{
	local week=AIDate.GetCurrentDate();
	if (week - INSTANCE.OneWeek < 7)	return false;
	INSTANCE.OneWeek=AIDate.GetCurrentDate();
	DInfo("Weekly checks run...",1);
	cCarrier.Process_VehicleWish();
}

function cBuilder::MonthlyChecks()
{
	local month=AIDate.GetMonth(AIDate.GetCurrentDate());
	if (INSTANCE.OneMonth!=month)	{ INSTANCE.OneMonth=month; INSTANCE.SixMonth++; }
					else	return false;
	DInfo("Montly checks run...",1);
	INSTANCE.main.route.VirtualAirNetworkUpdate();
	INSTANCE.main.builder.RouteNeedRepair();
	if (INSTANCE.buildDelay > 0)	INSTANCE.buildDelay--; // lower delaying timer
	INSTANCE.main.carrier.CheckOneVehicleOfGroup(false); // add 1 vehicle of each group
	INSTANCE.main.carrier.VehicleMaintenance();
	INSTANCE.main.builder.RoadStationsBalancing();
	cRoute.DutyOnRoute();
	if (INSTANCE.SixMonth == 2)	INSTANCE.main.builder.BoostedBuys();
	if (INSTANCE.SixMonth == 2)	INSTANCE.main.builder.BridgeUpgrader();
	if (INSTANCE.SixMonth == 6)	INSTANCE.main.builder.HalfYearChecks();
}

function cBuilder::HalfYearChecks()
{
	INSTANCE.SixMonth=0;
	INSTANCE.TwelveMonth++;
	DInfo("Half year checks run...",1);
	if (cCarrier.VirtualAirRoute.len() > 1)
		{
		local maillist=AIVehicleList_Group(cRoute.GetVirtualAirMailGroup());
		local passlist=AIVehicleList_Group(cRoute.GetVirtualAirPassengerGroup());
		local totair=maillist.Count()+passlist.Count();
		DInfo("Aircraft network have "+totair+" aircrafts running on "+cCarrier.VirtualAirRoute.len()+" airports",0);
		}
	INSTANCE.main.builder.CheckRouteStationStatus();
	if (INSTANCE.TwelveMonth == 2)	INSTANCE.main.builder.YearlyChecks();
}

function cBuilder::RouteIsDamage(idx)
// Set the route idx as damage
{
	local road=cRoute.Load(idx);
	if (!road) return;
	if (road.VehicleType != AIVehicle.VT_ROAD)	return;
	if (road.Status != RouteStatus.WORKING)	return;
	if (!INSTANCE.main.route.RouteDamage.HasItem(idx))	INSTANCE.main.route.RouteDamage.AddItem(idx,0);
}

function cBuilder::RouteNeedRepair()
{
	DInfo("Damage routes: "+INSTANCE.main.route.RouteDamage.Count(),1);
	if (INSTANCE.main.route.RouteDamage.IsEmpty()) return;
	local deletethatone=-1;
	local runLimit=2; // number of routes to repair per run
	local temp_dmg = AIList();
	temp_dmg.AddList(cRoute.RouteDamage);
	foreach (routes, state in temp_dmg)
		{
		if (state == RouteStatus.DEAD)	continue; // dead route state
		runLimit--;
		local trys=state;
		trys++;
		DInfo("Trying to repair route #"+routes+" for the "+trys+" time",1);
		local test=INSTANCE.main.builder.CheckRoadHealth(routes);
		if (test)	INSTANCE.main.route.RouteDamage.SetValue(routes, -1)
			else	INSTANCE.main.route.RouteDamage.SetValue(routes, trys);
		if (trys >= 3)	{
					DInfo("Sending all vehicles to depot");
					cCarrier.VehicleSendToDepotAndSell(routes);
					}
		if (trys == 4)	{
					DInfo("Removing all depots to rebuild them",1);
					cTrack.DestroyDepot(cRoute.GetDepot(routes, 1));
					cTrack.DestroyDepot(cRoute.GetDepot(routes, 2));
					}
		if (trys >= 6)	{ deletethatone=routes }
		if (runLimit <= 0)	break;
		}
	INSTANCE.main.route.RouteDamage.RemoveValue(-1);
	if (deletethatone != -1)
		{
		local trys=cRoute.GetRouteObject(deletethatone);
		if (trys != null && trys instanceof cRoute)
                            {
							DInfo("RouteNeedRepair mark "+trys.UID+" undoable",1);
							trys.RouteIsNotDoable();
							}
		}
}

function cBuilder::YearlyChecks()
{
	INSTANCE.TwelveMonth=0;
	DInfo("Yearly checks run...",1);
	INSTANCE.main.jobs.CheckTownStatue();
//	INSTANCE.main.carrier.do_profit.Clear(); // TODO: Keep or remove that, it's not use yet
	INSTANCE.main.carrier.CheckOneVehicleOfGroup(true); // send all vehicles to maintenance check
}

function cBuilder::CheckRouteStationStatus(onlythisone=null)
// This check that our routes are still working, a dead station might prevent us to keep the job done
// pass a stationID to onlythisone to only check that station ID
{
	local allstations=AIStationList(AIStation.STATION_ANY);
	if (onlythisone != null)	allstations.KeepValue(onlythisone);
	local healthy = true;
	foreach (stationID, dummy in allstations)
		{
		local pause1 = cLooper();
		local stobj = cStation.Load(stationID);
		if (!stobj)	continue;
		if (stobj.s_Owner.IsEmpty())	{ DInfo("Trying to remove unused station "+stobj.s_Name,1); cBuilder.DestroyStation(stationID); continue; }
		foreach (uid, odummy in stobj.s_Owner)
			{
			local pause2 = cLooper();
			local road=cRoute.Load(uid);
			if (!road)	continue;
			if (road.Status != RouteStatus.WORKING)	continue; // avoid non finish routes
			local cargoID=road.CargoID;
			if (road.VehicleType >= RouteType.AIR)	cargoID=cCargo.GetPassengerCargo(); // always check passenger to avoid mail cargo
			if (road.SourceStation.s_ID == stobj.s_ID)
				{
				if (!stobj.IsCargoProduce(cargoID))
					{ // we need that cargo produce but it's not
					DInfo("Station "+stobj.s_Name+" no longer produce "+cCargo.GetCargoLabel(cargoID),0);
					DInfo("CheckRouteStationStatus mark "+road.UID+" undoable",1);
					road.RouteIsNotDoable();
					healthy = false;
					continue;
					}
				}
			if (road.TargetStation.s_ID == stobj.s_ID)
				{
				if (!stobj.IsCargoAccept(cargoID))
					{ // we need that cargo accept but it's not
					DInfo("Station "+stobj.s_Name+" no longer accept "+cCargo.GetCargoLabel(cargoID),0);
					DInfo("CheckRouteStationStatus mark "+road.UID+" undoable",1);
					road.RouteIsNotDoable();
					healthy = false;
					continue;
					}
				}
			}
		}
	return healthy;
}

function cBuilder::RoadStationsBalancing()
// Look at road stations for busy loading and balance it by sending vehicle to servicing
// Because vehicle could block the station waiting to load something, while others carrying products can't enter it
{
	local allstations = AIStationList(AIStation.STATION_TRUCK_STOP);
	if (allstations.IsEmpty())	return;
	foreach (stations, _ in allstations)
		{
		local pause = cLooper();
		local s = cStation.Load(stations);
		if (!s)	continue;
		DInfo("Checking station "+s.s_Name,1);
		local truck_atstation=cCarrier.VehicleNearStation(stations); // find if anyone is near the station
		if (truck_atstation.Count() < 2)	continue;
		local truck_loading=AIList();
		local truck_waiting=AIList();
		truck_loading.AddList(truck_atstation);
		truck_waiting.AddList(truck_atstation);
		truck_loading=cCarrier.VehicleList_KeepLoadingVehicle(truck_loading);
		truck_waiting=cCarrier.VehicleList_KeepStuckVehicle(truck_waiting);
		local truck_getter_loading=AIList();
		local truck_getter_waiting=AIList();
		local truck_dropper_loading=AIList();
		local truck_dropper_waiting=AIList();
		DInfo("                 Size: "+s.s_Tiles.Count(),1);
		s.UpdateStationInfos();
		DInfo("                 infos: produce="+s.s_CargoProduce.Count()+" accept="+s.s_CargoAccept.Count(),1);
		if (s.s_CargoProduce.Count()==0 && s.s_CargoAccept.Count()==0)	{ cBuilder.CheckRouteStationStatus(stations); continue; }
		// pfff, now we know what cargo that station can use (accept or produce)
//	station_produce_cargo.Valuate(AICargo.GetTownEffect);
//	station_produce_cargo.RemoveValue(AICargo.TE_PASSENGERS);
//	station_accept_cargo.Valuate(AICargo.GetTownEffect);
//	station_accept_cargo.RemoveValue(AICargo.TE_PASSENGERS);

		// now we can found what vehicles are trying to do
		foreach (cargotype, _cdummy in s.s_CargoProduce)
			{
			local cpause = cLooper();
			truck_loading.Valuate(AIVehicle.GetCapacity, cargotype);
			foreach (vehicle, capacity in truck_loading)
				{
				local crg=AIVehicle.GetCargoLoad(vehicle, cargotype);
				if (capacity > 0 && !truck_getter_loading.HasItem(vehicle)) truck_getter_loading.AddItem(vehicle, crg);
				}
			truck_waiting.Valuate(AIVehicle.GetCapacity,cargotype);
			foreach (vehicle, capacity in truck_waiting)
				{
				local crg=AIVehicle.GetCargoLoad(vehicle, cargotype);
				if (capacity > 0 && !truck_getter_waiting.HasItem(vehicle))	truck_getter_waiting.AddItem(vehicle, crg);
				}
			}
		// redo with acceptance
		foreach (cargotype, dummy in s.s_CargoAccept)
			{
			local apause = cLooper();
			truck_loading.Valuate(AIVehicle.GetCapacity,cargotype);
			foreach (vehicle, capacity in truck_loading)
				{
				local crg=AIVehicle.GetCargoLoad(vehicle, cargotype);
				if (capacity > 0 && !truck_dropper_loading.HasItem(vehicle)) 	truck_dropper_loading.AddItem(vehicle, crg);
				// badly name, a dropper loading at station is in fact unloading :p
				}
			truck_waiting.Valuate(AIVehicle.GetCapacity,cargotype);
			foreach (vehicle, capacity in truck_waiting)
				{
				local crg=AIVehicle.GetCargoLoad(vehicle, cargotype);
				if (capacity > 0 && !truck_dropper_waiting.HasItem(vehicle))	truck_dropper_waiting.AddItem(vehicle, crg);
				}
			}
		// we have our 4 lists now, let's play with them
		// case 1, station got loader, more loaders are waiting, not harmful -> also vehicle handling will sell them
		// case 2, station got loader, and dropper are waiting, bad
		// case 3, station got dropper, and loader are waiting, not harmful
		// case 4, station got dropper, more dropper are waiting, not harmful
		local all_getter=AIList();
		all_getter.AddList(truck_getter_loading);
		all_getter.AddList(truck_getter_waiting);
		local numwait=truck_getter_waiting.Count()+truck_dropper_waiting.Count();
		local numload=truck_getter_loading.Count();
		local numunload=truck_dropper_loading.Count();
		local numdrop=truck_dropper_loading.Count();
		DInfo("                 Station "+s.s_Name+" have "+numload+" vehicle loading, "+numunload+" vehicle unloading, "+truck_getter_waiting.Count()+" vehicle waiting to load, "+truck_dropper_waiting.Count()+" waiting to unload",1);
		if (truck_getter_loading.Count() > 0)
			{
			if (truck_dropper_waiting.Count() > 0)
				{ // send all loader to depot to free space for droppers
				foreach (vehicle, load in all_getter)
					{
					local anotherpause = cLooper();
					if (load == 0)
						{ // don't push the vehicle that is loading
						DInfo("Pushing vehicle "+cCarrier.GetVehicleName(vehicle)+" out of the station to free space for unloaders",1);
						AIVehicle.SendVehicleToDepotForServicing(vehicle);
						AIVehicle.ReverseVehicle(vehicle);
						continue; // stop checks as droppers are waiting because station is busy with getters
						}
					}
				}
			}
		if (truck_getter_waiting.Count() > 0)
			foreach (stacargo, amount_wait in s.s_CargoProduce)
				{
				local anotherpause = cLooper();
				DInfo("Station "+s.s_Name+" produce "+cCargo.GetCargoLabel(stacargo)+" with "+amount_wait+" units waiting",1);
				foreach (vehicle, vehcargo in truck_getter_waiting)
					{
					if (amount_wait > 0) continue; // no action if we have cargo waiting at the station
					local aapause = cLooper();
					if (AIVehicle.GetCapacity(vehicle, stacargo)==0)	continue; // not a vehicle using that cargo
					if (AIVehicle.GetAge(vehicle) < 30) continue; // ignore young vehicle
					if (DictatorAI.GetSetting("station_balance"))
							{
							DInfo("Selling vehicle "+cCarrier.GetVehicleName(vehicle)+" to balance station",1);
							cCarrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
							}
					}
				}
		}
}

function cBuilder::BoostedBuys()
// this function check if we can boost a buy by selling our road vehicles
{
	local airportList=AIStationList(AIStation.STATION_AIRPORT);
	local waitingtimer=0;
	local vehlist = AIVehicleList();
	vehlist.RemoveList(cCarrier.ToDepotList);
	local goalairport=cJobs.CostTopJobs[AIVehicle.VT_AIR];
	if (airportList.Count() < 2 && vehlist.Count() > 45)
		{ // try to boost a first air route creation
		DWarn("Waiting to get an aircraft job. Current ="+INSTANCE.main.carrier.warTreasure+" Goal="+goalairport,1);
		if (INSTANCE.main.carrier.warTreasure > goalairport && goalairport > 0)
			{
			local money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
			local money_goal=money+goalairport
			DInfo("Trying to get an aircraft job done",1);
			INSTANCE.main.carrier.CrazySolder(goalairport);
			do	{
				AIController.Sleep(74);
				INSTANCE.main.carrier.VehicleIsWaitingInDepot(true);
				waitingtimer++;
				money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
				DInfo("Still "+(money_goal - money)+" to raise",1);
				}
			while (waitingtimer < 200 && !cBanker.CanBuyThat(goalairport));
			if (waitingtimer < 200)	DInfo("Operation should success...",1);
			INSTANCE.main.carrier.VehicleIsWaitingInDepot(true);
			INSTANCE.buildDelay=0; // remove any build blockers
			INSTANCE.main.carrier.vehicle_cash = 0;
			INSTANCE.main.carrier.vehicle_wishlist.Clear();
			}
		return;
		}
	local trainList=AIStationList(AIStation.STATION_TRAIN);
	local goaltrain=cJobs.CostTopJobs[AIVehicle.VT_RAIL];
	if (vehlist.Count()>45 && goaltrain > 0 && trainList.Count() < 2)
		{	// try boost train job buys
		DWarn("Waiting to build a train job. Current ="+INSTANCE.main.carrier.warTreasure+" Goal="+goaltrain,1);
		local money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
		local money_goal=money+goaltrain;
		if (INSTANCE.main.carrier.warTreasure > goaltrain && goaltrain > 0)
			{
			DInfo("Trying to raise money to buy a new train job",1);
			INSTANCE.main.carrier.CrazySolder(goaltrain);
			do	{
				AIController.Sleep(74);
				INSTANCE.main.carrier.VehicleIsWaitingInDepot(true);
				money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
				DInfo("Still "+(money_goal - money)+" to raise",1);
				waitingtimer++;
				}
			while (waitingtimer < 200 && !cBanker.CanBuyThat(goaltrain));
			INSTANCE.main.carrier.VehicleIsWaitingInDepot(true);
			INSTANCE.buildDelay=0; // remove any build blockers
			INSTANCE.main.carrier.vehicle_cash = 0;
			INSTANCE.main.carrier.vehicle_wishlist.Clear();
			}
		return;
		}
	local aircraftnumber=AIVehicleList();
	aircraftnumber.Valuate(AIVehicle.GetVehicleType);
	aircraftnumber.KeepValue(AIVehicle.VT_AIR);
	if (aircraftnumber.Count() < 6 && airportList.Count() > 1 && vehlist.Count()>45)
		{ // try boost aircrafts buys until we have 6
		local goal=INSTANCE.main.carrier.highcostAircraft+(INSTANCE.main.carrier.highcostAircraft * 0.1);
		local money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
		local money_goal=money+goal;
		DWarn("Waiting to buy of new aircraft. Current ="+INSTANCE.main.carrier.warTreasure+" Goal="+goal,1);
		if (INSTANCE.main.carrier.warTreasure > goal && goal > 0)
			{
			DInfo("Trying to buy a new aircraft",1);
			INSTANCE.main.carrier.CrazySolder(goal);
			do	{
				AIController.Sleep(74);
				INSTANCE.main.carrier.VehicleIsWaitingInDepot(true);
				money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
				DInfo("Still "+(money_goal - money)+" to raise",1);
				waitingtimer++;
				}
			while (waitingtimer < 200 && !cBanker.CanBuyThat(goal));
			INSTANCE.main.carrier.VehicleIsWaitingInDepot(true);
			INSTANCE.main.carrier.vehicle_cash = INSTANCE.main.carrier.highcostAircraft;
			}
		return;
		}
	local goaltrain=INSTANCE.main.carrier.highcostTrain;
	if (vehlist.Count()>45 && goaltrain > 0)
		{	// try boost train buys
		DWarn("Waiting to buy a new train. Current ="+INSTANCE.main.carrier.warTreasure+" Goal="+goaltrain,1);
		local money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
		local money_goal=money+goaltrain;
		if (INSTANCE.main.carrier.warTreasure > goaltrain)
			{
			DInfo("Trying to raise money to buy a new train job",1);
			INSTANCE.main.carrier.CrazySolder(goaltrain);
			do	{
				AIController.Sleep(74);
				INSTANCE.main.carrier.VehicleIsWaitingInDepot(true);
				money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
				DInfo("Still "+(money_goal - money)+" to raise",1);
				waitingtimer++;
				}
			while (waitingtimer < 200 && !cBanker.CanBuyThat(goaltrain));
			INSTANCE.main.carrier.VehicleIsWaitingInDepot(true);
			INSTANCE.buildDelay=0; // remove any build blockers
			INSTANCE.main.carrier.vehicle_cash = INSTANCE.main.carrier.highcostTrain;
			}
		}
}

function cBuilder::BridgeUpgrader()
// Upgrade bridge we own and if it's need
	{
	local RoadBridgeList=AIList();
	RoadBridgeList.AddList(cBridge.BridgeList);
	RoadBridgeList.Valuate(cBridge.GetMaxSpeed);
	local RailBridgeList=AIList();
	RailBridgeList.AddList(RoadBridgeList);
	RoadBridgeList.Valuate(cBridge.IsRoadBridge);
	RoadBridgeList.KeepValue(1);
	RailBridgeList.Valuate(cBridge.IsRailBridge);
	RailBridgeList.KeepValue(1);
	local numRail=RailBridgeList.Count();
	local numRoad=RoadBridgeList.Count();
	RoadBridgeList.KeepBelowValue(INSTANCE.main.carrier.speed_MaxRoad); // Keep only too slow bridges
	RailBridgeList.KeepBelowValue(INSTANCE.main.carrier.speed_MaxTrain);
	local workBridge=AIList();
	local twice=false;
	local neededSpeed=0;
	local btype=0;
	local everyone = AIController.GetSetting("upgrade_townbridge");
	local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
	local updateCount = 0;
	DInfo("We knows "+numRail+" rail bridges and "+numRoad+" road bridges",0);
	do	{
		workBridge.Clear();
		if (!twice)	{ workBridge.AddList(RoadBridgeList); neededSpeed=INSTANCE.main.carrier.speed_MaxRoad; btype=AIVehicle.VT_ROAD; }
			else	{ workBridge.AddList(RailBridgeList); neededSpeed=INSTANCE.main.carrier.speed_MaxTrain; btype=AIVehicle.VT_RAIL; }
		foreach (bridgeUID, speed in workBridge)
			{
			local thatbridge=cBridge.Load(bridgeUID);
			if (thatbridge.owner != -1 && thatbridge.owner != weare)	continue;
			// only upgrade our or town bridge
			if (thatbridge.owner == -1 && !everyone)	continue;
			// don't upgrade all bridges in one time, we're kind but we're not l'abbé Pierre!
			local speederBridge=cBridge.GetCheapBridgeID(btype, thatbridge.length, false);
			local oldbridge=AIBridge.GetName(thatbridge.bridgeID);
			if (speederBridge != -1)
				{
				local nbridge=AIBridge.GetName(speederBridge);
				local nspeed=AIBridge.GetMaxSpeed(speederBridge);
				INSTANCE.main.bank.RaiseFundsBy(AIBridge.GetPrice(speederBridge,thatbridge.length));
				if (AIBridge.BuildBridge(btype, speederBridge, thatbridge.firstside, thatbridge.otherside))
					{
					DInfo("Upgrade "+oldbridge+" to "+nbridge+". We can now handle upto "+nspeed+"km/h",0);
					if (thatbridge.owner != weare)	everyone = false;
					updateCount++;
					}
				}
            if (updateCount == 4)  { break; }
			}
		twice=!twice;
		} while (twice);
	}
