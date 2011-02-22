// this file handle events we check 1 time per month
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
root.chemin.VirtualAirNetworkUpdate();
DInfo("Checking if any airport need to be upgrade...",2);
local newairporttype=root.builder.GetAirportType();
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	local road=root.chemin.RListGetItem(i);
	if (road.ROUTE.kind!=AIVehicle.VT_AIR)	continue;
	if (!road.ROUTE.isServed) continue;
	local stationtype=0;
	local src=root.chemin.GListGetItem(road.ROUTE.src_station);
	local dst=root.chemin.GListGetItem(road.ROUTE.dst_station);
	local upgrade=false;
	if (src.STATION.type < newairporttype)
		{
		DInfo("stationt type="+src.STATION.type+" newairporttype="+newairporttype,2);
		root.builder.AirportNeedUpgrade(i,true);
		upgrade=true;
		}
	if (dst.STATION.type < newairporttype)
		{
		DInfo("stationt type="+src.STATION.type+" newairporttype="+newairporttype,2);
		root.builder.AirportNeedUpgrade(i,false);
		upgrade=true;
		}
	if (upgrade) break;
	}
}

function cBuilder::MonthlyChecks()
{
local month=AIDate.GetMonth(AIDate.GetCurrentDate());
if (root.OneMonth!=month)	{ root.OneMonth=month; root.SixMonth++;}
		else	return false;
DInfo("Montly checks run...",1);
root.builder.CheckAirportUpgrade();
root.builder.RouteNeedRepair();
if (root.SixMonth % 3 == 0) root.builddelay=false; // Wait 3 months, now allow us to build again
if (root.SixMonth == 6)	root.builder.HalfYearChecks();
//if (bank.canBuild && chemin.nowRoute == -1)	
}

function cBuilder::HalfYearChecks()
{
root.SixMonth=0;
root.TwelveMonth++;
DInfo("Half year checks run...",1);
if (root.chemin.airnet_count > 0) DInfo("Aircraft network have "+root.chemin.airnet_count+" aircrafts running",0);
if (root.TwelveMonth == 2)	root.builder.YearlyChecks();
}

function cBuilder::RouteIsDamage(idx)
// Set the route idx as damage
{
local road=root.chemin.RListGetItem(idx);
if (road == -1) return;
if (road.ROUTE.kind != AIVehicle.VT_ROAD)	return;
if (!road.ROUTE.isServed)	return;
if (!root.chemin.repair_routes.HasItem(idx))	root.chemin.repair_routes.AddItem(idx,0);
}

function cBuilder::RouteNeedRepair()
{
DInfo("Damage routes: "+root.chemin.repair_routes.Count(),1);
if (root.chemin.repair_routes.IsEmpty()) return;
local deletethatone=-1;
foreach (routes, dummy in root.chemin.repair_routes)
	{
	local trys=dummy;
	trys++;
	DInfo("Trying to repair route #"+routes+" for the "+trys+" time",1);
	local test=root.builder.CheckRoadHealth(routes);
	if (test)	root.chemin.repair_routes.SetValue(routes, -1)
		else	root.chemin.repair_routes.SetValue(routes, trys);
	if (trys >= 12)	{ deletethatone=routes }
	}
root.chemin.repair_routes.RemoveValue(-1);
if (deletethatone != -1)	{ root.builder.RouteIsInvalid(deletethatone); }
}


function cBuilder::YearlyChecks()
{
root.TwelveMonth=0;
DInfo("Yearly checks run...",1);
root.carrier.do_profit.Clear();
root.carrier.vehnextprice=0; // Reset vehicle upgrade 1 time / year in case of something strange happen
}

function cBuilder::AirportStationsBalancing()
// Look at airport for busy loading and if busy & some waiting force the aircraft to move on
{
local airID=AIStationList(AIStation.STATION_AIRPORT);
foreach (i, dummy in airID)
	{
	local vehlist=root.carrier.VehicleListBusyAtAirport(i);
	local count=vehlist.Count();
	//DInfo("Airport "+AIStation.GetName(i)+" is busy with "+vehlist.Count(),2);
	if (vehlist.Count() < 2)	continue;
	local passcargo=root.carrier.GetPassengerCargo(); // i don't care mail
	local cargowaiting=AIStation.GetCargoWaiting(i,passcargo);
	if (cargowaiting > 100)
		{
		DInfo("Airport "+AIStation.GetName(i)+" is busy but can handle it : "+cargowaiting,2); 
		continue;
		}
	foreach (i, dummy in vehlist)
		{
		local percent=root.carrier.VehicleGetLoadingPercent(i);
		//DInfo("Vehicle "+i+" load="+percent,2);
		if (percent > 4 && percent < 90)
			{ // we have a vehicle with more than 20% cargo in it
			root.carrier.VehicleOrderSkipCurrent(i);
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
local truckstation = AIStationList(AIStation.STATION_TRUCK_STOP);
if (truckstation.IsEmpty())	return;
foreach (stations, dummy in truckstation)
	{
	DInfo("Station check #"+stations+" "+AIStation.GetName(stations),1);
	local truck_atstation=cCarrier.VehicleNearStation(stations);
	if (truck_atstation.Count() < 2)	continue;
	local truck_loading=cCarrier.VehicleList_KeepLoadingVehicle(truck_atstation);
	local truck_waiting=cCarrier.VehicleList_KeepStuckVehicle(truck_atstation);
	local truck_getter_loading=AIList();
	local truck_getter_waiting=AIList();
	local truck_dropper_loading=AIList();
	local truck_dropper_waiting=AIList();
	local station_tile=cTileTools.FindRoadStationTiles(AIStation.GetLocation(stations));
	DInfo("Station tiles found: "+station_tile.Count(),1);
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
	DInfo("Station infos: produce="+station_produce_cargo.Count()+" accept="+station_accept_cargo.Count(),1);
	// pfff, now we know what cargo that station can use (accept or produce)
	station_produce_cargo.Valuate(AICargo.GetTownEffect);
	station_produce_cargo.RemoveValue(AICargo.TE_PASSENGERS);
	station_produce_cargo.RemoveValue(AICargo.TE_MAIL);
	station_accept_cargo.Valuate(AICargo.GetTownEffect);
	station_accept_cargo.RemoveValue(AICargo.TE_PASSENGERS);
	station_accept_cargo.RemoveValue(AICargo.TE_MAIL);
	// now we can found what vehicle is trying to do
	
	foreach (cargotype, dummy in station_produce_cargo)
		{
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
	DInfo("Station "+AIStation.GetName(stations)+" have "+numload+" vehicle loading, "+numunload+" vehicle unloading, "+truck_getter_waiting.Count()+" vehicle waiting to load, "+truck_dropper_waiting.Count()+" waiting to unload",1);
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
		}
	}
}

function cBuilder::QuickTasks()
// functions list here should be only function with a vital thing to do
{
root.builder.AirportStationsBalancing();
root.builder.RoadStationsBalancing();
}
