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
foreach (airID, dummy in airports)
	{
	INSTANCE.Sleep(1);
	airports.SetValue(airID,1);
	if (AIAirport.GetAirportType(AIStation.GetLocation(airID)) == AIAirport.AT_SMALL)	airports.SetValue(airID, 0);
	if (AIAirport.GetNumHangars(AIStation.GetLocation(airID)) == 0)	airports.SetValue(airID, 0);
	}
airports.RemoveValue(0); // don't network small airports & platform, it's too hard for slow aircrafts
if (airports.IsEmpty())	return;
			else	DInfo("NETWORK -> Found "+airports.Count()+" valid airports for network",1);
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
if (INSTANCE.carrier.vehnextprice > 0 && INSTANCE.carrier.vehnextprice < INSTANCE.carrier.highcostAircraft)
	{
	INSTANCE.bank.busyRoute=true;
	DInfo("We're upgrading something, buys are blocked...",1);
	return;
	}
local firstveh=false;
INSTANCE.bank.busyRoute=false; // setup the flag
local priority=AIList();
local road=null;
local chopper=false;
local dual=false;
INSTANCE.route.DutyOnAirNetwork(); // we handle the network load here
foreach (uid, dummy in cRoute.RouteIndexer)
	{
	firstveh=false;
	road=cRoute.GetRouteObject(uid);
	if (road==null)	continue;
	if (!road.isWorking)	continue;
	if (road.route_type == RouteType.AIRNET)	continue;
	if (road.source == null)	continue;
	if (road.target == null)	continue;
	local maxveh=0;
	local cargoid=road.cargoID;
	if (cargoid == null)	continue;
	local futur_engine=INSTANCE.carrier.GetVehicle(uid);
	local futur_engine_capacity=1;
	if (futur_engine != null)	futur_engine_capacity=AIEngine.GetCapacity(futur_engine);
	switch (road.route_type)
		{
		case AIVehicle.VT_ROAD:
			maxveh=INSTANCE.carrier.road_max_onroute;
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
	road.source.UpdateStationInfos();
	road.target.UpdateStationInfos();
	local vehneed=0;
	if (road.vehicle_count == 0)	{ firstveh=true; } // everyone need at least 2 vehicle on a route
	if (firstveh)	DInfo("# vehicle"+road.vehicle_count,2);
	local vehonroute=road.vehicle_count;
	local cargowait=0;
	local capacity=0;
//road.source.vehicle_capacity.GetValue(cargoID);
	dual=road.source_istown; // we need to check both side if source is town we're on a dual route (pass or mail)
	cargowait=road.source.cargo_produce.GetValue(cargoid);
	capacity=road.source.vehicle_capacity.GetValue(cargoid);
	if (capacity==0)
		{
		if (road.source_istown)	cargowait=AITown.GetLastMonthProduction(road.sourceID, cargoid);
					else	cargowait=AIIndustry.GetLastMonthProduction(road.sourceID, cargoid);
		capacity=futur_engine_capacity;
		}
	if (dual)
		{
		local src_capacity=capacity;
		local dst_capacity= road.target.vehicle_capacity.GetValue(cargoid);
		local src_wait = cargowait;
		local dst_wait = road.target.cargo_produce.GetValue(cargoID);
		if (dst_capacity == 0)	{ dst_wait=AITown.GetLastMonthProduction(road.targetID,cargoid); dst_capacity=futur_engine_capacity; }
		if (src_wait < dst_wait)	cargowait=src_wait; // keep the lowest cargo amount
						else	cargowait=dst_wait;
		if (src_capacity < dst_capacity)	capacity=dst_capacity; // but keep the highest capacity we have
							else	capacity=src_capacity;
		DInfo("Source capacity="+src_capacity+" wait="+src_wait+" --- Target capacity="+dst_capacity+" wait="+dst_wait,2);
		}
	local remain = cargowait - capacity;
	if (remain < 0)	vehneed=0;
			else	vehneed = (cargowait / capacity)+1;
	DInfo("Capacity ="+capacity+" wait="+cargowait+" remain="+remain+" needbycapacity="+vehneed,2);
	if (vehneed >= vehonroute) vehneed-=vehonroute;
	if (vehneed+vehonroute > maxveh) vehneed=maxveh-vehonroute;
	if (AIStation.GetCargoRating(road.source.stationID,cargoid) < 25 && cargowait==0)	vehneed++;
	if (firstveh)
		{
		if (road.route_type == RouteType.ROAD || road.route_type == RouteType.AIR)
			{ // force 2 vehicle if none exists yet for truck/bus & aircraft
			if (road.source.owner.Count()==1 && road.target.owner.Count()==1 && vehneed < 2)	vehneed=2;
			}
		else	vehneed=1; // everyones else is block to 1 vehicle
		if (vehneed > road.source.vehicle_max)	vehneed=road.source.vehicle_max;
		}
	if (vehneed > 4)	vehneed=4; // max 4 at a time
	local canaddonemore=INSTANCE.carrier.CanAddNewVehicle(uid, true);
	if (!canaddonemore)	vehneed=0; // don't let us buy a new vehicle if we won't be allow to buy it	
	DInfo("CanAddNewVehicle for source station says "+canaddonemore,2);
	canaddonemore=INSTANCE.carrier.CanAddNewVehicle(uid, false);
	DInfo("CanAddNewVehicle for destination station says "+canaddonemore,2);
	if (!canaddonemore)	vehneed=0;
	DInfo("Route="+road.name+" capacity="+capacity+" vehicleneed="+vehneed+" cargowait="+cargowait+" vehicule#="+road.vehicle_count+"/"+maxveh+" firstveh="+firstveh,2);
	// adding vehicle
	if (vehneed > 0)
		{
		INSTANCE.bank.busyRoute=true;
		priority.AddItem(road.groupID,vehneed); // we record all groups needs for vehicle
		road.source.vehicle_capacity.SetValue(cargoid, road.source.vehicle_capacity.GetValue(cargoid)+(vehneed*futur_engine_capacity));
		road.target.vehicle_capacity.SetValue(cargoid, road.target.vehicle_capacity.GetValue(cargoid)+(vehneed*futur_engine_capacity));
		}
	}

// now we can try add others needed vehicles here but base on priority
// and priority = aircraft before anyone, then others, in both case, we range from top group profit to lowest
DInfo("Priority list size : "+priority.Count(),2);
if (priority.IsEmpty())	return;
local priosave=AIList();
priosave.AddList(priority);
local airgp=AIList();
local othergp=AIList();
airgp.AddList(priority);
airgp.Valuate(AIGroup.GetVehicleType);
othergp.AddList(airgp);
airgp.KeepValue(AIVehicle.VT_AIR);
othergp.RemoveValue(AIVehicle.VT_AIR);
airgp.Valuate(INSTANCE.route.VehicleGroupProfitRatio);
airgp.Sort(AIList.SORT_BY_VALUE,false);
othergp.Valuate(INSTANCE.route.VehicleGroupProfitRatio);
othergp.Sort(AIList.SORT_BY_VALUE,false);
priority.Clear();
priority.AddList(airgp);
priority.AddList(othergp);
local vehneed=0;
local vehvalue=0;
local topvalue=0;
INSTANCE.carrier.highcostAircraft=0;
DInfo("Priority list="+priority.Count()+" Saved list="+priosave.Count(),1);
foreach (groupid, ratio in priority)
	{
	if (priosave.HasItem(groupid))	{ vehneed=priosave.GetValue(groupid); DInfo("BUYS -> Group #"+groupid+" "+AIGroup.GetName(groupid)+" need "+vehneed+" vehicle",1); }
						else	{ vehneed=0; DWarn("Group #"+groupid++" "+AIGroup.GetName(groupid)+" not found in priority list!",1); }
	if (vehneed == 0) continue;
	local uid=cRoute.GroupIndexer.GetValue(groupid);
	local rtype=AIGroup.GetVehicleType(groupid);
	local vehmodele=INSTANCE.carrier.GetVehicle(uid);
	local vehvalue=0;
	if (vehmodele != null)	vehvalue=AIEngine.GetPrice(vehmodele);
	for (local z=0; z < vehneed; z++)
		{
		if (rtype == AIVehicle.VT_AIR && !INSTANCE.bank.CanBuyThat(vehvalue))
			{
			if (INSTANCE.carrier.highcostAircraft < vehvalue)	INSTANCE.carrier.highcostAircraft=vehvalue;
			}
		if (INSTANCE.bank.CanBuyThat(vehvalue))
			if ((INSTANCE.carrier.highcostAircraft >= INSTANCE.carrier.vehnextprice) || (INSTANCE.carrier.vehnextprice == 0))
				if (INSTANCE.carrier.BuildAndStartVehicle(uid))
					{
					local rinfo=cRoute.GetRouteObject(uid);
					DInfo("Adding a vehicle "+AIEngine.GetName(vehmodele)+" to route "+rinfo.name,0);
					INSTANCE.carrier.vehnextprice=0; INSTANCE.carrier.highcostAircraft=0;
					}
		}
	}
}

