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

function cRoute::RouteUpdateAirPath()
// update the infos for our specials routes for the air network
{
if (cCarrier.VirtualAirRoute.len() < 2)	return;
local oneAirportID=AIStation.GetStationID(cCarrier.VirtualAirRoute[0]);
local twoAirportID=AIStation.GetStationID(cCarrier.VirtualAirRoute[1]);
local network=cRoute.GetRouteObject(0);
network.sourceID=cStation.VirtualAirports.GetValue(oneAirportID);
network.source_location=AITown.GetLocation(network.sourceID);
network.source_stationID=oneAirportID;
network.targetID=cStation.VirtualAirports.GetValue(twoAirportID);
network.target_location=AITown.GetLocation(network.targetID);
network.target_stationID=twoAirportID;
network.CheckEntry(); // claims that airport
INSTANCE.route.VirtualMailCopy();
}

function cRoute::VirtualAirNetworkUpdate()
// update our list of airports that are in the air network
{
local towns=AITownList();
towns.Valuate(AITown.GetPopulation);
towns.RemoveBelowValue(INSTANCE.carrier.AIR_NET_CONNECTOR);
local airports=AIStationList(AIStation.STATION_AIRPORT);
airports.Valuate(AIAirport.GetAirportType);
airports.RemoveValue(AIAirport.AT_SMALL); // don't network small airports, it's too hard for slow aircrafts
airports.Valuate(AIAirport.GetNumHangars); // platform don't have depot
airports.RemoveValue(0);
airports.Valuate(AIStation.GetLocation);
local virtualpath=AIList();
local validairports=AIList();
foreach (airport_id, location in airports)
	{
	local check=AIAirport.GetNearestTown(location, AIAirport.GetAirportType(location));
	if (towns.HasItem(check))
		{
		validairports.AddItem(check, airport_id);
		virtualpath.AddItem(check, towns.GetValue(check));
		}
	}
virtualpath.Sort(AIList.SORT_BY_VALUE, false);
// now validairports = only airports where towns population is > AIR_NET_CONNECTOR, value is airportid
// and virtualpath the town where those airports are, value = population of those towns
local bigtown=virtualpath.Begin();
local bigtown_location=AITown.GetLocation(bigtown);
virtualpath.Valuate(AITown.GetDistanceManhattanToTile, bigtown_location);
virtualpath.Sort(AIList.SORT_BY_VALUE,true);
local impair=false;
local pairlist=AIList();
local impairlist=AIList();
foreach (towns, distances in virtualpath)
	{
	if (impair)	impairlist.AddItem(towns, distances);
		else	pairlist.AddItem(towns, distances);
	impair=!impair;
	}
pairlist.Sort(AIList.SORT_BY_VALUE,true);
impairlist.Sort(AIList.SORT_BY_VALUE,false);
virtualpath.Clear();
INSTANCE.carrier.VirtualAirRoute.clear(); // don't try reassign a static variable!
foreach (towns, dummy in pairlist)	INSTANCE.carrier.VirtualAirRoute.push(AIStation.GetLocation(validairports.GetValue(towns)));
foreach (towns, dummy in impairlist)	INSTANCE.carrier.VirtualAirRoute.push(AIStation.GetLocation(validairports.GetValue(towns)));
if (INSTANCE.carrier.VirtualAirRoute.len() > 1)
	foreach (towns, airportid in validairports)
		{
		INSTANCE.Sleep(1);
		if (!cStation.VirtualAirports.HasItem(airportid))
			{
			cStation.VirtualAirports.AddItem(airportid, towns);
			local stealgroup=AIVehicleList_Station(airportid);
			stealgroup.Valuate(AIEngine.GetPlaneType);
			stealgroup.RemoveValue(AIAirport.PT_HELICOPTER); // don't steal choppers
			stealgroup.Valuate(AIVehicle.GetGroupID);
			stealgroup.RemoveValue(cRoute.GetVirtualAirPassengerGroup());
			stealgroup.RemoveValue(cRoute.GetVirtualAirMailGroup());
			DInfo("Re-assigning "+stealgroup.Count()+" aircrafts to the network",0);
			local thatnetwork=0;
			local vehnumber=0;
			foreach (vehicle, gid in stealgroup)
				{
				if (vehnumber % 6 == 0)	thatnetwork=cRoute.GetVirtualAirMailGroup();
							else	thatnetwork=cRoute.GetVirtualAirPassengerGroup();
				AIGroup.MoveVehicle(thatnetwork, vehicle);
				INSTANCE.carrier.VehicleOrdersReset(vehicle); // reset order, force order change
				vehnumber++;
				}
			}
		}

DInfo("NETWORK -> Airnetwork route length is now : "+INSTANCE.carrier.VirtualAirRoute.len()+" Airports: "+ cCarrier.VirtualAirRoute.len(),1);
INSTANCE.route.RouteUpdateAirPath();
INSTANCE.carrier.AirNetworkOrdersHandler();
}

function cRoute::GetAmountOfCompetitorStationAround(IndustryID)
// Like AIIndustry::GetAmountOfStationAround but doesn't count our stations, so we only grab competitors stations
// return 0 or numbers of stations not own by us near the place
{
local counter=0;
local place=AIIndustry.GetLocation(IndustryID);
local radius=AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
local tiles=AITileList();
local produce=AITileList_IndustryAccepting(IndustryID, radius);
local accept=AITileList_IndustryProducing(IndustryID, radius);
tiles.AddList(produce);
tiles.AddList(accept);
tiles.Valuate(AITile.IsStationTile);
tiles.KeepValue(1); // keep station only
tiles.Valuate(AIStation.GetStationID);
local uniq=AIList();
foreach (i, dummy in tiles)
	{ // remove duplicate id
	if (!uniq.HasItem(dummy))	uniq.AddItem(dummy,i);
	}
uniq.Valuate(AIStation.IsValidStation);
uniq.KeepValue(0);
return uniq.Count();
}

function cRoute::DutyOnAirNetwork()
// handle the traffic for the aircraft network
{
if (INSTANCE.carrier.VirtualAirRoute.len()<2) return;
local vehlist=AIList();
local maillist=AIVehicleList_Group(INSTANCE.route.GetVirtualAirMailGroup());
local passlist=AIVehicleList_Group(INSTANCE.route.GetVirtualAirPassengerGroup());
vehlist.AddList(maillist);
vehlist.AddList(passlist);
local totalcapacity=0;
local onecapacity=0;
local age=0;
local vehneed=0;
local vehnumber=vehlist.Count();
local futurveh=INSTANCE.carrier.ChooseAircraft(cCargo.GetPassengerCargo(),AircraftType.BEST);
if (vehlist.IsEmpty())
	{
	onecapacity=AIEngine.GetCapacity(futurveh);
	age=1000;
	vehneed=2;
	}
else	{
	vehlist.Valuate(AIVehicle.GetCapacity,cCargo.GetPassengerCargo());
	vehlist.Sort(AIList.SORT_BY_VALUE,true);
	local onecapacity=0;
	foreach (vehicle, capacity in vehlist)
		{
		totalcapacity+=capacity;
		if (capacity > 0)	onecapacity=capacity;
		}
	vehlist.Valuate(AIVehicle.GetAge);
	vehlist.Sort(AIList.SORT_BY_VALUE,true); // younger first
	age=vehlist.GetValue(vehlist.Begin());
	if (age < 90) { DInfo("We already buy an aircraft recently for the network: "+age,2); return; }
	}
if (onecapacity == 0)	onecapacity=90; // estimation
DInfo("NETWORK -> Aircrafts in network: "+vehnumber,2);
DInfo("NETWORK -> Total capacity of network: "+totalcapacity,2);
local bigairportlocation=INSTANCE.carrier.VirtualAirRoute[0];
local bigairportID=AIStation.GetStationID(bigairportlocation);
local cargowaiting=AIStation.GetCargoWaiting(bigairportID,cCargo.GetPassengerCargo());
cargowaiting-=totalcapacity;
if (cargowaiting > 0)	vehneed=cargowaiting / onecapacity;
if (vehneed==0 && AIStation.GetCargoRating(bigairportID, cCargo.GetPassengerCargo())<25) vehneed=1;
// one more because poor station rating
PutSign(bigairportlocation,"Network Airport Reference: "+cargowaiting);
if (vehneed > 0)
	{
	local thatnetwork=0;
	for (local k=0; k < vehneed; k++)
		{
		if (vehnumber % 6 == 0)	thatnetwork=1;
					else	thatnetwork=0;
		if (INSTANCE.bank.CanBuyThat(AIEngine.GetPrice(futurveh)) && INSTANCE.carrier.CanAddNewVehicle(0,true))
		if (INSTANCE.carrier.BuildAndStartVehicle(thatnetwork))
			{
			DInfo("Adding an aircraft to the network, "+(vehnumber+1)+" aircrafts run it now",0);
			vehnumber++;
			}
		}
	INSTANCE.carrier.AirNetworkOrdersHandler();
	}
}

function cRoute::VehicleGroupProfitRatio(groupID)
// check a vehicle group and return a ratio representing it's value
// it's just (groupprofit * 1000 / numbervehicle)
{
if (!AIGroup.IsValidGroup(groupID))	return 0;
local vehlist=AIVehicleList_Group(groupID);
vehlist.Valuate(AIVehicle.GetProfitThisYear);
local vehnumber=vehlist.Count();
if (vehnumber == 0) return 0; // avoid / per 0
local totalvalue=0;
foreach (vehicle, value in vehlist)
	{ totalvalue+=value*1000; }
return totalvalue / vehnumber;
}

function cRoute::DutyOnRoute()
// this is where we add vehicle and tiny other things to max our money
{
/*
if (INSTANCE.chemin.under_upgrade)
	{
	INSTANCE.bank.busyRoute=true;
	DInfo("We're upgrading something, buys are blocked...",1);
	return;
	}
*/
//INSTANCE.carrier.VehicleMaintenance();
local firstveh=false;
INSTANCE.bank.busyRoute=false; // setup the flag
local profit=false;
local prevprofit=0;
local vehprofit=0;
local oldveh=false;
local priority=AIList();
local road=null;
local chopper=false;
INSTANCE.route.DutyOnAirNetwork(); // we handle the network load here
foreach (uid, dummy in cRoute.RouteIndexer)
	{
	road=cRoute.GetRouteObject(uid);
	if (road==null)	continue;
	if (road.route_type == RouteType.AIRNET)	continue;
	if (road.source == null)	continue;
	if (road.target == null)	continue;
	if (road.vehicle_count == 0)	{ firstveh=true; } // everyone need at least 2 vehicule on a route
	local maxveh=0;
	local cargoid=road.cargoID;
	if (cargoid == null)	continue;
	local estimateCapacity=1;
	switch (road.route_type)
		{
		case AIVehicle.VT_ROAD:
			maxveh=INSTANCE.carrier.road_max_onroute;
			estimateCapacity=15;
		break;
		case RouteType.CHOPPER:
			chopper=true;
			maxveh=4;
			cargoid=cCargo.GetPassengerCargo();
			INSTANCE.builder.DumpRoute(uid);
		break;
		case AIVehicle.VT_AIR:
			maxveh=INSTANCE.carrier.air_max;
			cargoid=cCargo.GetPassengerCargo(); // for aircraft, force a check vs passenger
			// so mail aircraft runner will be add if passenger is high enough, this only affect routes not in the network
		break;
		case AIVehicle.VT_WATER:
			maxveh=INSTANCE.carrier.water_max;
		break;
		case AIVehicle.VT_RAIL:
			maxveh=1;
			continue; // no train upgrade for now will do later
		break;
		}
	DInfo("Group is null= "+road.groupID,2);
	local vehList=AIVehicleList_Group(road.groupID);
	vehList.Valuate(AIVehicle.GetProfitThisYear);
	vehList.Sort(AIList.SORT_BY_VALUE,true); // poor numbers first
	local vehsample=vehList.Begin();  // one sample in the group
	local vehprofit=vehList.GetValue(vehsample);
	local prevprofit=AIVehicle.GetProfitLastYear(vehsample);
	local capacity=INSTANCE.carrier.VehicleGetFullCapacity(vehsample);
	DInfo("vehicle="+vehsample+" capacity="+capacity+" engine="+AIEngine.GetName(AIVehicle.GetEngineType(vehsample)),2);
	local vehonroute=road.vehicle_count;
	local dstcargowait=AIStation.GetCargoWaiting(road.target.stationID,cargoid);
	local srccargowait=AIStation.GetCargoWaiting(road.source.stationID,cargoid);
	local cargowait=srccargowait;
	if (road.source_istown && dstcargowait < srccargowait) cargowait=dstcargowait;

	local vehneed=0;
	if (capacity > 0)	{ vehneed=cargowait / capacity; }
			else	{// This happen when we don't have a vehicle sample -> 0 vehicle = new route certainly
				vehneed=1;
				local producing=0;
				if (road.source_istown)	{ producing=AITown.GetLastMonthProduction(road.sourceID,cargoid); }
							else	{ producing=AIIndustry.GetLastMonthProduction(road.sourceID,cargoid); }
				if (road.route_type == AIVehicle.VT_ROAD)	{ vehneed= producing / estimateCapacity; }
				}
	if (firstveh) vehneed=2;
	if (firstveh && road.route_type == RouteType.RAIL) { vehneed = 1; }
	if (firstveh && chopper)	{ vehneed = 1; }

	if (vehneed >= vehonroute) vehneed-=vehonroute;
	if (vehneed+vehonroute > maxveh) vehneed=maxveh-vehonroute;
	if (AIStation.GetCargoRating(road.source.stationID,cargoid) < 25 && cargowait==0)	vehneed++;
	local canaddonemore=INSTANCE.carrier.CanAddNewVehicle(uid, true);
	if (!canaddonemore)	vehneed=0; // don't let us buy a new vehicle if we won't be allow to buy it	
	DInfo("CanAddNewVehicle for source station says "+canaddonemore,2);
	canaddonemore=INSTANCE.carrier.CanAddNewVehicle(uid, false);
	DInfo("CanAddNewVehicle for destination station says "+canaddonemore,2);
	if (!canaddonemore)	vehneed=0;
	DInfo("Route="+road.name+" capacity="+capacity+" vehicleneed="+vehneed+" cargowait="+cargowait+" vehicule#="+road.vehicle_count+"/"+maxveh+" firstveh="+firstveh,2);
//	if (vehprofit <=0)	profit=true; // hmmm on new years none is making profit and this fail
//		else		profit=true;
	profit=true; // TODO: fix me, remove or put a real profit check
	vehList.Valuate(AIVehicle.GetAge);
	vehList.Sort(AIList.SORT_BY_VALUE,true);
	if (vehList.GetValue(vehList.Begin()) > 90)	oldveh=true; // ~ 8 months
						else	oldveh=false;
	// adding vehicle
	if (vehneed > 0)
		{
		if (INSTANCE.carrier.vehnextprice > 0)
			{
			DInfo("We're upgrading a vehicle, not adding new vehicle until its done to keep the money... "+INSTANCE.carrier.vehnextprice,1);
			INSTANCE.bank.busyRoute=true;
			vehneed = 0; // no add... while we have an vehicle upgrade on its way
			}
		/*if (vehList.GetValue(vehList.Begin()) > 90)	oldveh=true;
							else	oldveh=false;*/
		if (firstveh) // special cases where we must build the vehicle
			{ profit=true; oldveh=true; }

		if (profit)
			{
			INSTANCE.bank.busyRoute=true;
			if (firstveh && vehneed > 0 && oldveh)
				{
				if (INSTANCE.carrier.BuildAndStartVehicle(uid))
					{
					DInfo("Adding a vehicle to route "+road.name,0);
					firstveh=false; vehneed--;
					}
				}
			if (!firstveh && vehneed > 0)
					{
					priority.AddItem(road.groupID,vehneed);
					continue; // skip to next route, we won't check removing for that turn
					}
			}
		}
	}
// Removing vehicle when station is too crowd & vehicle get stuck
/*
	if (cargowait == 0 && oldveh) // this happen if we load everything at the station
		{
		local busyList=AIVehicleList_Group(road.groupID);
		local runningList=AIList();
		if (busyList.IsEmpty()) continue;
		busyList.Valuate(AIVehicle.GetState);
		runningList.AddList(busyList);
		busyList.KeepValue(AIVehicle.VS_AT_STATION); // the loading vehicle
		runningList.KeepValue(AIVehicle.VS_RUNNING); // healthy vehicle
		if (busyList.IsEmpty())	continue; // no need to continue if noone is at station
		runningList.Valuate(AIVehicle.GetLocation);
		runningList.Valuate(AITile.GetDistanceManhattanToTile,AIStation.GetLocation(stationid));
		runningList.KeepBelowValue(10); // only keep vehicle position < 10 the station
		runningList.Valuate(AIVehicle.GetCurrentSpeed);
		runningList.KeepValue(0); // running but at 0 speed
		if (runningList.IsEmpty())	continue; // all vehicles are moving
		runningList.Valuate(AIVehicle.GetAge); // better sold the oldest one
		runningList.Sort(AIList.SORT_BY_VALUE,true);
		if (runningList.Count() < 2)	continue; // we will not remove last vehicles, upto "profitlost" to remove them
		// now send that one to depot & sell it
		local veh=runningList.Begin();
		DInfo("Vehicle "+veh+"-"+AIVehicle.GetName(veh)+" is not moving and station is busy, selling it for balancing",1);
		INSTANCE.carrier.VehicleSendToDepot(veh);
		AIVehicle.ReverseVehicle(veh); // try to make it move away from the queue
		}
	}
*/
// now we can try add others needed vehicles here but base on priority

if (priority.IsEmpty())	return;
local priosave=AIList();
priosave.AddList(priority); // save it because value is = number of vehicle we need
priority.Valuate(INSTANCE.route.VehicleGroupProfitRatio);
priority.Sort(AIList.SORT_BY_VALUE,false);
local vehneed=0;
local vehvalue=0;
foreach (groupid, ratio in priority)
	{
	if (priosave.HasItem(groupid))	vehneed=priosave.GetValue(groupid);
						else	vehneed=0;
	if (vehneed == 0) continue;
	local vehvaluegroup=AIVehicleList_Group(groupid);	
	vehvalue=AIEngine.GetPrice(AIVehicle.GetEngineType(vehvaluegroup.Begin()));
	local uid=INSTANCE.route.GroupIndexer.GetValue(groupid);
	for (local z=0; z < vehneed; z++)
		{
		if (INSTANCE.bank.CanBuyThat(vehvalue))
			if (INSTANCE.carrier.BuildAndStartVehicle(uid))
				{
				DInfo("Adding a vehicle to route #"+uid,0);
				INSTANCE.Sleep(30);
				}
		}
	}
}

