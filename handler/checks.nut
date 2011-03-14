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

function cBuilder::CheckAirportUpgrade()
{
INSTANCE.route.VirtualAirNetworkUpdate();
DInfo("Checking if any airport need to be upgrade...",2);
local newairporttype=INSTANCE.builder.GetAirportType();
for (local i=0; i < INSTANCE.route.RListGetSize(); i++)
	{
	local road=INSTANCE.route.RListGetItem(i);
	if (road.ROUTE.kind!=AIVehicle.VT_AIR)	continue;
	if (!road.ROUTE.isServed) continue;
	local stationtype=0;
	local src=INSTANCE.route.GListGetItem(road.ROUTE.src_station);
	local dst=INSTANCE.route.GListGetItem(road.ROUTE.dst_station);
	local upgrade=false;
	if (src.STATION.type < newairporttype)
		{
		DInfo("stationt type="+src.STATION.type+" newairporttype="+newairporttype,2);
		INSTANCE.builder.AirportNeedUpgrade(i,true);
		upgrade=true;
		}
	if (dst.STATION.type < newairporttype)
		{
		DInfo("stationt type="+src.STATION.type+" newairporttype="+newairporttype,2);
		INSTANCE.builder.AirportNeedUpgrade(i,false);
		upgrade=true;
		}
	if (upgrade) break;
	}
}

function cBuilder::WeeklyChecks()
{
local week=AIDate.GetCurrentDate();
if (week - INSTANCE.OneWeek < 7)	return false;
INSTANCE.OneWeek=AIDate.GetCurrentDate();
DInfo("Weekly checks run...",1);
INSTANCE.builder.RoadStationsBalancing();
}

function cBuilder::MonthlyChecks()
{
local month=AIDate.GetMonth(AIDate.GetCurrentDate());
if (INSTANCE.OneMonth!=month)	{ INSTANCE.OneMonth=month; INSTANCE.SixMonth++; }
				else	return false;
DInfo("Montly checks run...",1);
INSTANCE.route.VirtualAirNetworkUpdate();
INSTANCE.builder.RouteNeedRepair();
//if (bank.canBuild && builder.building_route == -1)
if (INSTANCE.builddelay)	INSTANCE.buildTimer++;
if (INSTANCE.buildTimer == 3)
	{
	INSTANCE.builddelay=false;
	INSTANCE.buildTimer=0;
	}
if (!INSTANCE.carrier.ToDepotList.IsEmpty())
	{
	foreach (vehicle, dateinlist in INSTANCE.carrier.ToDepotList)
		{
		local today=AIDate.GetCurrentDate();
		if ((today - dateinlist) > 180)	INSTANCE.carrier.ToDepotList.RemoveItem(vehicle);
		}
	}
INSTANCE.carrier.VehicleMaintenance();
INSTANCE.route.DutyOnRoute();
if (INSTANCE.SixMonth == 6)	INSTANCE.builder.HalfYearChecks();
}

function cBuilder::HalfYearChecks()
{
INSTANCE.builddelay=false; // Wait 6 months, now allow us to build again
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
if (INSTANCE.TwelveMonth == 2)	INSTANCE.builder.YearlyChecks();
INSTANCE.builder.BoostedBuys();
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
DInfo("Damage routes: "+INSTANCE.route.RouteDamage.Count(),1);
if (INSTANCE.route.RouteDamage.IsEmpty()) return;
local deletethatone=-1;
foreach (routes, dummy in INSTANCE.route.RouteDamage)
	{
	local trys=dummy;
	trys++;
	DInfo("Trying to repair route #"+routes+" for the "+trys+" time",1);
	local test=INSTANCE.builder.CheckRoadHealth(routes);
	if (test)	INSTANCE.route.RouteDamage.SetValue(routes, -1)
		else	INSTANCE.route.RouteDamage.SetValue(routes, trys);
	if (trys >= 12)	{ deletethatone=routes }
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
DInfo("Yearly checks run...",1);
INSTANCE.carrier.do_profit.Clear();
INSTANCE.carrier.vehnextprice=0; // Reset vehicle upgrade 1 time / year in case of something strange happen
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
	//DInfo("Airport "+AIStation.GetName(i)+" is busy with "+vehlist.Count(),2);
	if (vehlist.Count() < 2)	continue;
	local passcargo=cCargo.GetPassengerCargo(); // i don't care mail
	local cargowaiting=AIStation.GetCargoWaiting(i,passcargo);
	if (cargowaiting > 100)
		{
		DInfo("Airport "+AIStation.GetName(i)+" is busy but can handle it : "+cargowaiting,2); 
		continue;
		}
	foreach (i, dummy in vehlist)
		{
		local percent=INSTANCE.carrier.VehicleGetLoadingPercent(i);
		//DInfo("Vehicle "+i+" load="+percent,2);
		if (percent > 4 && percent < 90)
			{ // we have a vehicle with more than 20% cargo in it
			INSTANCE.carrier.VehicleOrderSkipCurrent(i);
			DInfo("Forcing vehicle "+AIVehicle.GetName(i)+" to get out of the station with "+i+" load",1);
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

function cBuilder::RoadStationsBalancing()
// Look at road stations for busy loading and balance it by sending vehicle to servicing
// Because vehicle could block the station waiting to load something, while others carrying products can't enter it
{
local busstation = AIStationList(AIStation.STATION_BUS_STOP);
local truckstation = AIStationList(AIStation.STATION_TRUCK_STOP);
local allstations=AIList(); // check if the station still use that cargo
allstations.AddList(busstation);
allstations.AddList(truckstation);
foreach (stationID, dummy in allstations)
	{
	INSTANCE.Sleep(1);
	local stobj=cStation.GetStationObject(stationID);
	if (stobj == null) continue;
	stobj.CargosUpdate();
	foreach (uid, dummy in stobj.owner)
		{
		INSTANCE.Sleep(1);
		local road=cRoute.GetRouteObject(uid);
		if (road == null)	continue; // might happen if the route isn't saved because not finished yet
		if (road.source_stationID == stobj.stationID)	continue;
		if (road.target_stationID == stobj.stationID)
			{
			if (!stobj.cargo_accept.HasItem(road.cargoID))
				{
				DWarn("Station "+AIStation.GetName(stationID)+" no longer accept "+AICargo.GetCargoLabel(road.cargoID),0);
				road.RouteReleaseStation(stationID)
				}
			}
		}
	}
/*
foreach (stations, dummy in busstation)
	{
	INSTANCE.Sleep(1);
	DInfo("BUS - Station check #"+stations+" "+AIStation.GetName(stations),1);
	local vehlist=cCarrier.VehicleNearStation(stations);
	vehlist=cCarrier.VehicleList_KeepStuckVehicle(vehlist);
	vehlist.Valuate(AIVehicle.GetAge);
	vehlist.KeepAboveValue(30);
	if (!vehlist.IsEmpty())
		{
		local produce=AIStation.GetCargoWaiting(stations, cCargo.GetPassengerCargo());
		if (produce == 0) // bus are waiting and station have 0 passengers
			{
			local vehicle=vehlist.Begin();
			DInfo("Selling vehicle "+INSTANCE.carrier.VehicleGetFormatString(vehicle)+" to balance station",1);
			INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
			AIVehicle.ReverseVehicle(vehicle);
			}
		}
	}
*/
truckstation.AddList(busstation);
if (truckstation.IsEmpty())	return;
foreach (stations, dummy in truckstation)
	{
	INSTANCE.Sleep(1);
	DInfo("TRUCK - Station check #"+stations+" "+AIStation.GetName(stations),1);
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
	DInfo("         Size: "+station_tile.Count(),1);
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
	DInfo("         infos: produce="+station_produce_cargo.Count()+" accept="+station_accept_cargo.Count(),1);
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
	DInfo("         Station "+AIStation.GetName(stations)+" have "+numload+" vehicle loading, "+numunload+" vehicle unloading, "+truck_getter_waiting.Count()+" vehicle waiting to load, "+truck_dropper_waiting.Count()+" waiting to unload",1);
	if (truck_getter_loading.Count() > 0)
		{
		if (truck_dropper_waiting.Count() > 0)
			{ // send all loader to depot to free space for droppers
			foreach (vehicle, load in all_getter)
				{
				if (load == 0)
					{ // don't push the vehicle that is loading, TODO: might fail if 2 vehicles with a bit of cargo enter the station, better found a way to test station. But it's a rare case
					DInfo("Pushing vehicle "+vehicle+"-"+AIVehicle.GetName(vehicle)+" out of the station to free space for unloaders",1);
					AIVehicle.ReverseVehicle(vehicle);
					AIVehicle.SendVehicleToDepotForServicing(vehicle);
					return; // stop checks as droppers are waiting because station is busy with getters
					}
				}
			}
		}
	if (truck_getter_waiting.Count() > 0)
		foreach (stacargo, dummy in station_produce_cargo)
			{
			local amount_wait=AIStation.GetCargoWaiting(stations, stacargo);
			DInfo("Station "+AIStation.GetName(stations)+" produce "+AICargo.GetCargoLabel(stacargo)+" with "+amount_wait+" units waiting",1);
			foreach (vehicle, vehcargo in truck_getter_waiting)
				{
				if (amount_wait > 0) continue; // no action if we have cargo waiting at the station
				if (AIVehicle.GetAge(vehicle) < 30) continue; // ignore young vehicle
				DInfo("Selling vehicle "+INSTANCE.carrier.VehicleGetFormatString(vehicle)+" to balance station",1);
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
// this function check if we can boost a buy by selling our road vehicle
{
if (!INSTANCE.use_air)	return;
local airportList=AIStationList(AIStation.STATION_AIRPORT);
local waitingtimer=0;
if (airportList.Count() < 2)
	{ // try to boost a first air route creation
	local goalairport=cJobs.CostTopJobs[AIVehicle.VT_AIR];
	DWarn("Waiting to get an aircraft job. Current ="+INSTANCE.carrier.warTreasure+" Goal="+goalairport,1);
	if (INSTANCE.carrier.warTreasure > goalairport && goalairport > 0)
		{
		local money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
		local money_goal=money+goalairport
		DInfo("Trying to get an aircraft job done",1);
		INSTANCE.carrier.CrazySolder(goalairport);
		do	{
			INSTANCE.Sleep(74);
			INSTANCE.carrier.VehicleIsWaitingInDepot();
			waitingtimer++;
			money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
			DInfo("Still "+(money_goal - money)+" to raise",1);
			}
		while (waitingtimer < 120 && !cBanker.CanBuyThat(goalairport));
		if (waitingtimer < 120)	DInfo("Operation should success...",1);
		INSTANCE.carrier.VehicleIsWaitingInDepot();
		INSTANCE.bank.canBuild=true; INSTANCE.bank.busyRoute=false; INSTANCE.builddelay=false; // remove any build blockers
		}
	}
waitingtimer=0;
local aircraftnumber=AIVehicleList();
aircraftnumber.Valuate(AIVehicle.GetVehicleType);
aircraftnumber.KeepValue(AIVehicle.VT_AIR);
if (aircraftnumber.Count() < 6 && airportList.Count() > 1)
	{ // try boost aircrafts buys until we have 6
	local goal=INSTANCE.carrier.highcostAircraft+(INSTANCE.carrier.highcostAircraft * 0.1);
	local money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	local money_goal=money+goal;
	DWarn("Waiting to buy of new aircraft. Current ="+INSTANCE.carrier.warTreasure+" Goal="+goal,1);
	if (INSTANCE.carrier.warTreasure > goal && goal > 0)
		{
		DInfo("Trying to buy a new aircraft",1);
		INSTANCE.carrier.CrazySolder(goal);
		do	{
			INSTANCE.Sleep(74);
			INSTANCE.carrier.VehicleIsWaitingInDepot();
			money=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
			DInfo("Still "+(money_goal - money)+" to raise",1);
			waitingtimer++;
			}
		while (waitingtimer < 120 && !cBanker.CanBuyThat(goal));
		INSTANCE.carrier.vehnextprice=INSTANCE.carrier.highcostAircraft; // reserve the money to buy the aircraft
		}

	}
}

