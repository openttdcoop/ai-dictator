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


// all operations here are cBuilder even the file itself do handling work
// operations here are time eater

function cBuilder::WeeklyChecks()
{
local week=AIDate.GetCurrentDate();
if (week - INSTANCE.OneWeek < 7)	return false;
INSTANCE.OneWeek=AIDate.GetCurrentDate();
DInfo("Weekly checks run...",1,"Checks");
INSTANCE.builder.RoadStationsBalancing();
}

function cBuilder::MonthlyChecks()
{
local month=AIDate.GetMonth(AIDate.GetCurrentDate());
if (INSTANCE.OneMonth!=month)	{ INSTANCE.OneMonth=month; INSTANCE.SixMonth++; }
					else	return false;
DInfo("Montly checks run...",1,"Checks");
INSTANCE.route.VirtualAirNetworkUpdate();
INSTANCE.builder.RouteNeedRepair();
if (INSTANCE.builddelay)	INSTANCE.buildTimer++;
if (INSTANCE.buildTimer == 2) // delaying a build for 2 months
	{
	INSTANCE.builddelay=false;
	INSTANCE.buildTimer=0;
	}
INSTANCE.carrier.CheckOneVehicleOfGroup(false); // add 1 vehicle of each group
INSTANCE.carrier.VehicleMaintenance();
INSTANCE.route.DutyOnRoute();
if (INSTANCE.SixMonth == 2)	INSTANCE.builder.BoostedBuys();
if (INSTANCE.SixMonth == 2)	INSTANCE.builder.BridgeUpgrader();
if (INSTANCE.SixMonth == 6)	INSTANCE.builder.HalfYearChecks();
}

function cBuilder::HalfYearChecks()
{
INSTANCE.SixMonth=0;
INSTANCE.TwelveMonth++;
DInfo("Half year checks run...",1,"Checks");
if (cCarrier.VirtualAirRoute.len() > 1) 
	{
	local maillist=AIVehicleList_Group(cRoute.GetVirtualAirMailGroup());
	local passlist=AIVehicleList_Group(cRoute.GetVirtualAirPassengerGroup());
	local totair=maillist.Count()+passlist.Count();
	DInfo("Aircraft network have "+totair+" aircrafts running on "+cCarrier.VirtualAirRoute.len()+" airports",0,"Checks");
	}
if (INSTANCE.TwelveMonth == 2)	INSTANCE.builder.YearlyChecks();
local stationList=AIList();	// check for no more working station if cargo disapears...
stationList.AddList(AIStationList(AIStation.STATION_ANY));
foreach (stationID, dummy in stationList)
	{
	INSTANCE.Sleep(1);
	cStation.CheckCargoHandleByStation(stationID);
	}
if (cCarrier.ToDepotList.IsEmpty())	INSTANCE.carrier.vehnextprice=0; // avoid strange result from vehicle crash...
}

function cBuilder::RouteIsDamage(idx)
// Set the route idx as damage
{
local road=cRoute.GetRouteObject(idx);
if (road == null) return;
if (road.route_type != AIVehicle.VT_ROAD)	return;
if (!road.isWorking)	return;
if (!INSTANCE.route.RouteDamage.HasItem(idx))	INSTANCE.route.RouteDamage.AddItem(idx,0);
}

function cBuilder::RouteNeedRepair()
{
DInfo("Damage routes: "+INSTANCE.route.RouteDamage.Count(),1,"RouteNeedRepair");
if (INSTANCE.route.RouteDamage.IsEmpty()) return;
local deletethatone=-1;
local runLimit=2; // number of routes to repair per run
foreach (routes, dummy in INSTANCE.route.RouteDamage)
	{
	runLimit--;
	local trys=dummy;
	trys++;
	DInfo("Trying to repair route #"+routes+" for the "+trys+" time",1,"RouteNeedRepair");
	local test=INSTANCE.builder.CheckRoadHealth(routes);
	if (test)	INSTANCE.route.RouteDamage.SetValue(routes, -1)
		else	INSTANCE.route.RouteDamage.SetValue(routes, trys);
	if (trys >= 12)	{ deletethatone=routes }
	if (runLimit <= 0)	break;
	}
INSTANCE.route.RouteDamage.RemoveValue(-1);
if (deletethatone != -1)
	{
	local trys=cRoute.GetRouteObject(deletethatone);
	trys.RouteIsNotDoable();
	}
}

function cBuilder::YearlyChecks()
{
INSTANCE.TwelveMonth=0;
DInfo("Yearly checks run...",1,"Checks");

INSTANCE.builder.CheckRouteStationStatus();
INSTANCE.jobs.CheckTownStatue();
INSTANCE.carrier.do_profit.Clear(); // TODO: Keep or remove that, it's not use yet
INSTANCE.carrier.vehnextprice=0; // Reset vehicle upgrade 1 time / year in case of something strange happen
INSTANCE.carrier.CheckOneVehicleOfGroup(true); // send all vehicles to maintenance check
}

function cBuilder::AirportStationsBalancing()
// Look at airport for busy loading and if busy & some waiting force the aircraft to move on
{
local airID=AIStationList(AIStation.STATION_AIRPORT);
foreach (i, dummy in airID)
	{
	INSTANCE.Sleep(1);
//	if (cStation.VirtualAirports.HasItem(i))	continue; // don't balance airport from the network
	local vehlist=INSTANCE.carrier.VehicleListBusyAtAirport(i);
	local count=vehlist.Count();
	//DInfo("Airport "+cStation.StationGetName(i)+" is busy with "+vehlist.Count(),2);
	if (vehlist.Count() < 2)	continue;
	local passcargo=cCargo.GetPassengerCargo(); // i don't care mail
	local cargowaiting=AIStation.GetCargoWaiting(i,passcargo);
	if (cargowaiting > 30)
		{
		DInfo("Airport "+cStation.StationGetName(i)+" is busy but can handle it : "+cargowaiting,2); 
		continue;
		}
	foreach (i, dummy in vehlist)
		{
		local percent=INSTANCE.carrier.VehicleGetLoadingPercent(i);
		//DInfo("Vehicle "+i+" load="+percent,2);
		local orderflags=AIOrder.GetOrderFlags(i, AIOrder.ORDER_CURRENT);
		local order_full=( (orderflags & AIOrder.OF_FULL_LOAD_ANY) == AIOrder.OF_FULL_LOAD_ANY);
		if (percent > 4 && percent < 90 && order_full)
			{ // we have a vehicle with more than 20% cargo in it
			INSTANCE.carrier.VehicleOrderSkipCurrent(i);
			DInfo("Forcing vehicle "+cCarrier.VehicleGetName(i)+" to get out of the station with "+i+" load",1);
			break;
			}
		}
	}
}

function cBuilder::GetCargoListProduceAtTile(tile)
// return list of cargo that tile is producing
{
local cargo_list=AICargoList();
local radius=AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
foreach (cargo, dummy in cargo_list)
	{
	local produce=AITile.GetCargoProduction(tile, cargo, 1, 1, radius);
	cargo_list.SetValue(cargo, produce);
	}
cargo_list.KeepAboveValue(0);
return cargo_list;
}

function cBuilder::GetCargoListAcceptAtTile(tile)
// return list of cargo that tile is accepting
{
local cargo_list=AICargoList();
local radius=AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
foreach (cargo, dummy in cargo_list)
	{
	local accept=AITile.GetCargoAcceptance(tile, cargo, 1, 1, radius);
	cargo_list.SetValue(cargo, accept);
	}
cargo_list.KeepAboveValue(7); // doc says below 8 means no acceptance
return cargo_list;
}

function cBuilder::CheckRouteStationStatus(onlythisone=null)
// This check that our routes are still working, a dead station might prevent us to keep the job done
// pass a stationID to onlythisone to only check that station ID
{
local allstations=AIStationList(AIStation.STATION_ANY);
if (onlythisone != null)	allstations.KeepValue(onlythisone);
foreach (stationID, dummy in allstations)
	{
	local stobj=cStation.GetStationObject(stationID);
	if (stobj == null)	continue;
	foreach (uid, dummy in stobj.owner)
		{
		local road=cRoute.GetRouteObject(uid);
		if (road == null || !road.isWorking)	continue; // avoid non finish routes
		local cargoID=road.cargoID;
		if (road.station_type == AIStation.STATION_AIRPORT)	cargoID=cCargo.GetPassengerCargo(); // always check passenger to avoid mail cargo
		if (road.source_stationID == stobj.stationID)
			{
			if (stobj.IsCargoProduce(cargoID))	{ stobj.cargo_produce.AddItem(cargoID, 0); }// rediscover cargo
			else	{
				DWarn("Station "+cStation.StationGetName(stationID)+" no longer produce "+AICargo.GetCargoLabel(road.cargoID),0,"CheckRouteStationStatus");
				road.RouteIsNotDoable();
				continue;
				}
			if (stobj.IsCargoAccept(cargoID))	stobj.cargo_accept.AddItem(cargoID, 0);
			}
		if (road.target_stationID == stobj.stationID)
			{
			if (stobj.IsCargoAccept(cargoID))	stobj.cargo_accept.AddItem(cargoID, 0); // rediscover cargo
			else	{
				DWarn("Station "+cStation.StationGetName(stationID)+" no longer accept "+AICargo.GetCargoLabel(road.cargoID),0,"CheckRouteStationStatus");
				road.RouteIsNotDoable();
				}
			}
		}
	AIController.Sleep(1);
	}
}

function cBuilder::RoadStationsBalancing()
// Look at road stations for busy loading and balance it by sending vehicle to servicing
// Because vehicle could block the station waiting to load something, while others carrying products can't enter it
{
local busstation = AIStationList(AIStation.STATION_BUS_STOP);
local truckstation = AIStationList(AIStation.STATION_TRUCK_STOP);
local allstations=AIList(); // check if the station still use that cargo
allstations.AddList(busstation);
allstations.AddList(truckstation);

truckstation.AddList(busstation);
if (truckstation.IsEmpty())	return;
foreach (stations, dummy in truckstation)
	{
	INSTANCE.Sleep(1);
	DInfo("TRUCK - Station check #"+stations+" "+cStation.StationGetName(stations),1,"RoadStationsBalancing");
	local truck_atstation=cCarrier.VehicleNearStation(stations);
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
	local station_tile=cTileTools.FindStationTiles(AIStation.GetLocation(stations));
	DInfo("         Size: "+station_tile.Count(),1,"RoadStationsBalancing");
	local station_accept_cargo=AIList();
	local station_produce_cargo=AIList();
	local cargo_produce=null;
	local cargo_accept=null;
	foreach (tiles, dummy in station_tile)
		{
		INSTANCE.Sleep(1);
		cargo_produce=cBuilder.GetCargoListProduceAtTile(tiles);
		cargo_accept=cBuilder.GetCargoListAcceptAtTile(tiles);
		foreach (cargotype, dummy in cargo_produce)
			{
			if (!station_produce_cargo.HasItem(cargotype))	station_produce_cargo.AddItem(cargotype,0);
			}
		foreach (cargotype, dummy in cargo_accept)
			{
			if (!station_accept_cargo.HasItem(cargotype))	station_accept_cargo.AddItem(cargotype,0);
			}
		}
	DInfo("         infos: produce="+station_produce_cargo.Count()+" accept="+station_accept_cargo.Count(),1,"RoadStationsBalancing");
	if (station_produce_cargo.Count()==0 && station_accept_cargo.Count()==0)	{ cBuilder.CheckRouteStationStatus(stations); continue; }
	// pfff, now we know what cargo that station can use (accept or produce)
	station_produce_cargo.Valuate(AICargo.GetTownEffect);
	station_produce_cargo.RemoveValue(AICargo.TE_PASSENGERS);
	station_accept_cargo.Valuate(AICargo.GetTownEffect);
	station_accept_cargo.RemoveValue(AICargo.TE_PASSENGERS);
	// now we can found what vehicle is trying to do
	
	foreach (cargotype, dummy in station_produce_cargo)
		{
		INSTANCE.Sleep(1);
		truck_loading.Valuate(AIVehicle.GetCapacity,cargotype);
		foreach (vehicle, capacity in truck_loading)
			{
			local crg=AIVehicle.GetCargoLoad(vehicle, cargotype);
			if (capacity > 0 && !truck_getter_loading.HasItem(vehicle)) 	truck_getter_loading.AddItem(vehicle, crg);
			}
		truck_waiting.Valuate(AIVehicle.GetCapacity,cargotype);
		foreach (vehicle, capacity in truck_waiting)
			{
			local crg=AIVehicle.GetCargoLoad(vehicle, cargotype);
			if (capacity > 0 && !truck_getter_waiting.HasItem(vehicle))	truck_getter_waiting.AddItem(vehicle, crg);
			}
		}
	// redo with acceptance
	foreach (cargotype, dummy in station_accept_cargo)
		{
		INSTANCE.Sleep(1);
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
	
	// case 1, station got loader, more loaders are waiting, not harmul -> also vehicle handling will sell them
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
	DInfo("         Station "+cStation.StationGetName(stations)+" have "+numload+" vehicle loading, "+numunload+" vehicle unloading, "+truck_getter_waiting.Count()+" vehicle waiting to load, "+truck_dropper_waiting.Count()+" waiting to unload",1,"RoadStationsBalancing");
	if (truck_getter_loading.Count() > 0)
		{
		if (truck_dropper_waiting.Count() > 0)
			{ // send all loader to depot to free space for droppers
			foreach (vehicle, load in all_getter)
				{
				if (load == 0)
					{ // don't push the vehicle that is loading, TODO: might fail if 2 vehicles with a bit of cargo enter the station, better found a way to test station. But it's a rare case
					DInfo("Pushing vehicle "+vehicle+"-"+cCarrier.VehicleGetName(vehicle)+" out of the station to free space for unloaders",1,"RoadStationsBalancing");
					AIVehicle.ReverseVehicle(vehicle);
					AIVehicle.SendVehicleToDepotForServicing(vehicle);
					continue; // stop checks as droppers are waiting because station is busy with getters
					}
				}
			}
		}
	if (truck_getter_waiting.Count() > 0)
		foreach (stacargo, dummy in station_produce_cargo)
			{
			local amount_wait=AIStation.GetCargoWaiting(stations, stacargo);
			DInfo("Station "+cStation.StationGetName(stations)+" produce "+AICargo.GetCargoLabel(stacargo)+" with "+amount_wait+" units waiting",1,"RoadStationsBalancing");
			foreach (vehicle, vehcargo in truck_getter_waiting)
				{
				if (AIVehicle.GetCapacity(vehicle, stacargo)==0)	continue; // not a vehicle using that cargo
				if (amount_wait > 0) continue; // no action if we have cargo waiting at the station
				if (AIVehicle.GetAge(vehicle) < 30) continue; // ignore young vehicle
				DInfo("Selling vehicle "+INSTANCE.carrier.VehicleGetName(vehicle)+" to balance station",1,"RoadStationsBalancing");
				INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
				AIVehicle.ReverseVehicle(vehicle);
				}
			}
		
	}
}

function cBuilder::QuickTasks()
// functions list here should be only function with a vital thing to do
{
INSTANCE.builder.AirportStationsBalancing();

}

function cBuilder::BoostedBuys()
// this function check if we can boost a buy by selling our road vehicles
{
local airportList=AIStationList(AIStation.STATION_AIRPORT);
local waitingtimer=0;
local vehlist=AIVehicleList();
foreach (veh, dummy in vehlist) // remove vehicle going to depot already
		if (cCarrier.ToDepotList.HasItem(veh))	vehlist.SetValue(veh,1);
								else	vehlist.SetValue(veh,0);
vehlist.KeepValue(0);
if (airportList.Count() < 2 && vehlist.Count()>45)
	{ // try to boost a first air route creation
	local goalairport=cJobs.CostTopJobs[AIVehicle.VT_AIR];
	DWarn("Waiting to get an aircraft job. Current ="+INSTANCE.carrier.warTreasure+" Goal="+goalairport,1,"BoostedBuys");
	if (INSTANCE.carrier.warTreasure > goalairport && goalairport > 0)
		{
		local money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
		local money_goal=money+goalairport
		DInfo("Trying to get an aircraft job done",1,"BoostedBuys");
		INSTANCE.carrier.CrazySolder(goalairport);
		do	{
			INSTANCE.Sleep(74);
			INSTANCE.carrier.VehicleIsWaitingInDepot(true);
			waitingtimer++;
			money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
			DInfo("Still "+(money_goal - money)+" to raise",1,"BoostedBuys");
			}
		while (waitingtimer < 200 && !cBanker.CanBuyThat(goalairport));
		if (waitingtimer < 200)	DInfo("Operation should success...",1,"BoostedBuys");
		INSTANCE.carrier.VehicleIsWaitingInDepot(true);
		INSTANCE.bank.canBuild=true; INSTANCE.bank.busyRoute=false; INSTANCE.builddelay=false; // remove any build blockers
		}
	return;
	}
local trainList=AIStationList(AIStation.STATION_TRAIN);
local goaltrain=cJobs.CostTopJobs[AIVehicle.VT_RAIL];
if (vehlist.Count()>45 && goaltrain > 0 && trainList.Count() < 2)
	{	// try boost train job buys
	DWarn("Waiting to build a train job. Current ="+INSTANCE.carrier.warTreasure+" Goal="+goaltrain,1,"BoostedBuys");
	local money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	local money_goal=money+goaltrain;
	if (INSTANCE.carrier.warTreasure > goaltrain && goaltrain > 0)
		{
		DInfo("Trying to raise money to buy a new train job",1,"BoostedBuys");
		INSTANCE.carrier.CrazySolder(goaltrain);
		do	{
			INSTANCE.Sleep(74);
			INSTANCE.carrier.VehicleIsWaitingInDepot(true);
			money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
			DInfo("Still "+(money_goal - money)+" to raise",1,"BoostedBuys");
			waitingtimer++;
			}
		while (waitingtimer < 200 && !cBanker.CanBuyThat(goaltrain));
		INSTANCE.carrier.VehicleIsWaitingInDepot(true);
		INSTANCE.bank.canBuild=true; INSTANCE.bank.busyRoute=false; INSTANCE.builddelay=false; // remove any build blockers
		}
	return;
	}
local aircraftnumber=AIVehicleList();
aircraftnumber.Valuate(AIVehicle.GetVehicleType);
aircraftnumber.KeepValue(AIVehicle.VT_AIR);
if (aircraftnumber.Count() < 6 && airportList.Count() > 1 && vehlist.Count()>45)
	{ // try boost aircrafts buys until we have 6
	local goal=INSTANCE.carrier.highcostAircraft+(INSTANCE.carrier.highcostAircraft * 0.1);
	local money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	local money_goal=money+goal;
	DWarn("Waiting to buy of new aircraft. Current ="+INSTANCE.carrier.warTreasure+" Goal="+goal,1,"BoostedBuys");
	if (INSTANCE.carrier.warTreasure > goal && goal > 0)
		{
		DInfo("Trying to buy a new aircraft",1,"BoostedBuys");
		INSTANCE.carrier.CrazySolder(goal);
		do	{
			INSTANCE.Sleep(74);
			INSTANCE.carrier.VehicleIsWaitingInDepot(true);
			money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
			DInfo("Still "+(money_goal - money)+" to raise",1,"BoostedBuys");
			waitingtimer++;
			}
		while (waitingtimer < 200 && !cBanker.CanBuyThat(goal));
		INSTANCE.carrier.VehicleIsWaitingInDepot(true);
		}
	return;
	}
local goaltrain=INSTANCE.carrier.highcostTrain;
if (vehlist.Count()>45 && goaltrain > 0)
	{	// try boost train buys
	DWarn("Waiting to buy a new train. Current ="+INSTANCE.carrier.warTreasure+" Goal="+goaltrain,1,"BoostedBuys");
	local money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	local money_goal=money+goaltrain;
	if (INSTANCE.carrier.warTreasure > goaltrain)
		{
		DInfo("Trying to raise money to buy a new train job",1,"BoostedBuys");
		INSTANCE.carrier.CrazySolder(goaltrain);
		do	{
			INSTANCE.Sleep(74);
			INSTANCE.carrier.VehicleIsWaitingInDepot(true);
			money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
			DInfo("Still "+(money_goal - money)+" to raise",1,"BoostedBuys");
			waitingtimer++;
			}
		while (waitingtimer < 200 && !cBanker.CanBuyThat(goaltrain));
		INSTANCE.carrier.VehicleIsWaitingInDepot(true);
		INSTANCE.bank.canBuild=true; INSTANCE.bank.busyRoute=false; INSTANCE.builddelay=false; // remove any build blockers
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
	RoadBridgeList.KeepBelowValue(INSTANCE.carrier.speed_MaxRoad); // Keep only too slow bridges
	RailBridgeList.KeepBelowValue(INSTANCE.carrier.speed_MaxTrain);
	local workBridge=AIList();
	local twice=false;
	local neededSpeed=0;
	local btype=0;
	local justOne=false;
	if (!AIController.GetSetting("upgrade_townbridge"))	justOne=true;
	local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
	DInfo("We knows "+numRail+" rail bridges and "+numRoad+" road bridges",0,"cBuilder::BridgeUpgrader");
	do	{
		workBridge.Clear();
		if (!twice)	{ workBridge.AddList(RoadBridgeList); neededSpeed=INSTANCE.carrier.speed_MaxRoad; btype=AIVehicle.VT_ROAD; }
			else	{ workBridge.AddList(RailBridgeList); neededSpeed=INSTANCE.carrier.speed_MaxTrain; btype=AIVehicle.VT_RAIL; }
		foreach (bridgeUID, speed in workBridge)
			{
			local thatbridge=cBridge.Load(bridgeUID);
			if (thatbridge.owner != -1 && thatbridge.owner != weare)	continue;
			// only upgrade our or town bridge
			if (thatbridge.owner == -1 && justOne)	continue;
			// don't upgrade all bridges in one time, we're kind but we're not l'abbé Pierre!
			local speederBridge=cBridge.GetCheapBridgeID(btype, thatbridge.length, false);
			local oldbridge=AIBridge.GetName(thatbridge.bridgeID);
			if (speederBridge != -1)
				{
				local nbridge=AIBridge.GetName(speederBridge);
				local nspeed=AIBridge.GetMaxSpeed(speederBridge);
				INSTANCE.bank.RaiseFundsBy(AIBridge.GetPrice(speederBridge,thatbridge.length));
				if (AIBridge.BuildBridge(btype, speederBridge, thatbridge.firstside, thatbridge.otherside))
					{
					DInfo("Upgrade "+oldbridge+" to "+nbridge+". We can now handle upto "+nspeed+"km/h",0,"cBuilder::BridgeUpgrader");
					if (thatbridge.owner==-1)	justOne=true;
					}
				}
			}
		twice=!twice;
		} while (twice);
	}

