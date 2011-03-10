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

function cBuilder::MonthlyChecks()
{
local month=AIDate.GetMonth(AIDate.GetCurrentDate());
if (INSTANCE.OneMonth!=month)	{ INSTANCE.OneMonth=month; INSTANCE.SixMonth++;}
		else	return false;
DInfo("Montly checks run...",1);
INSTANCE.route.VirtualAirNetworkUpdate();
INSTANCE.builder.RouteNeedRepair();
if (INSTANCE.SixMonth == 6)	INSTANCE.builder.HalfYearChecks();
//if (bank.canBuild && builder.building_route == -1)
if (INSTANCE.builddelay)	INSTANCE.buildTimer++;
if (INSTANCE.buildTimer == 4)
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
cJobs.RefreshAllValue();
}

function cBuilder::AirportStationsBalancing()
// Look at airport for busy loading and if busy & some waiting force the aircraft to move on
{
local airID=AIStationList(AIStation.STATION_AIRPORT);
foreach (i, dummy in airID)
	{
	if (cStation.VirtualAirports.HasItem(i))	continue; // don't balance airport from the network
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
// speed up
// station source check (crowd)
// station target check (only to see if current cargo is accept)
// vehicle check only 1st of group for many op
local busstation = AIStationList(AIStation.STATION_BUS_STOP);
foreach (stations, dummy in busstation)
	{
	DInfo("BUS - Station check #"+stations+" "+AIStation.GetName(stations),1);
	local vehlist=cCarrier.VehicleNearStation(stations);
	vehlist=cCarrier.VehicleList_KeepStuckVehicle(vehlist);
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

local truckstation = AIStationList(AIStation.STATION_TRUCK_STOP);
if (truckstation.IsEmpty())	return;
foreach (stations, dummy in truckstation)
	{
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
					}
				}
			}
		else	{ // only getter are waiting, too many vehicle so
			local vehicle=truck_getter_waiting.Begin();
			if (truck_getter_waiting.Count() >0 && AIStation.GetCargoWaiting(stations,truck_getter_waiting.GetValue(vehicle)) ==0)
				{
				DInfo("Selling vehicle "+INSTANCE.carrier.VehicleGetFormatString(vehicle)+" to balance station",1);
				INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
				AIVehicle.ReverseVehicle(vehicle);
				}
			}
		}
	}
}

function cBuilder::QuickTasks()
// functions list here should be only function with a vital thing to do
{
INSTANCE.builder.AirportStationsBalancing();
INSTANCE.builder.RoadStationsBalancing();
}
