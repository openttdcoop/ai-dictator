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
network.RouteCheckEntry(); // claims that airport
INSTANCE.main.route.VirtualMailCopy();
}

function cRoute::VirtualAirNetworkUpdate()
// update our list of airports that are in the air network
{
local virtroad=cRoute.GetRouteObject(0); // 0 is always the passenger one
virtroad.distance=0;
local towns=AITownList();
towns.Valuate(AITown.GetPopulation);
towns.RemoveBelowValue(INSTANCE.main.carrier.AIR_NET_CONNECTOR);
DInfo("NETWORK > Found "+towns.Count()+" towns for network",1);
if (towns.Count()<2)	return; // give up
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
if (virtualpath.IsEmpty())	return;
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
INSTANCE.main.carrier.VirtualAirRoute.clear(); // don't try reassign a static variable!
foreach (towns, dummy in pairlist)	INSTANCE.main.carrier.VirtualAirRoute.push(AIStation.GetLocation(validairports.GetValue(towns)));
foreach (towns, dummy in impairlist)	INSTANCE.main.carrier.VirtualAirRoute.push(AIStation.GetLocation(validairports.GetValue(towns)));
local lastdistance=AITile.GetDistanceManhattanToTile(INSTANCE.main.carrier.VirtualAirRoute[0], INSTANCE.main.carrier.VirtualAirRoute[INSTANCE.main.carrier.VirtualAirRoute.len()-1]);
for (local i=0; i < INSTANCE.main.carrier.VirtualAirRoute.len(); i++)
	{
	local step=0;
	if (i == 0)	step = lastdistance;
		else	step = AITile.GetDistanceManhattanToTile(INSTANCE.main.carrier.VirtualAirRoute[i], INSTANCE.main.carrier.VirtualAirRoute[i-1]);
	if (virtroad.distance < step)	virtroad.distance=step; // setup newGRF distance limit
	}
local vehlist=AIList();
local maillist=AIVehicleList_Group(INSTANCE.main.route.GetVirtualAirMailGroup());
local passlist=AIVehicleList_Group(INSTANCE.main.route.GetVirtualAirPassengerGroup());
vehlist.AddList(maillist);
vehlist.AddList(passlist);
local vehnumber=vehlist.Count();
if (INSTANCE.main.carrier.VirtualAirRoute.len() > 1)
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
			stealgroup.RemoveTop(1);
			if (stealgroup.IsEmpty())	continue;
			DInfo("Reassigning "+stealgroup.Count()+" aircrafts to the network",0);
			local thatnetwork=0;
			foreach (vehicle, gid in stealgroup)
				{
				if (vehnumber % 6 == 0)	thatnetwork=cRoute.GetVirtualAirMailGroup();
							else	thatnetwork=cRoute.GetVirtualAirPassengerGroup();
				AIGroup.MoveVehicle(thatnetwork, vehicle);
				INSTANCE.main.carrier.VehicleOrdersReset(vehicle); // reset order, force order change
				vehnumber++;
				}
			}
		}

DInfo("NETWORK -> Airnetwork route length is now : "+INSTANCE.main.carrier.VirtualAirRoute.len()+" Airports: "+ cCarrier.VirtualAirRoute.len()+" max distance="+virtroad.distance,1);
INSTANCE.main.route.RouteUpdateAirPath();
INSTANCE.main.carrier.AirNetworkOrdersHandler();
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
if (INSTANCE.main.carrier.VirtualAirRoute.len()<2) return;
local virtroad=cRoute.GetRouteObject(0);
local vehlist=AIList();
local passengerID=cCargo.GetPassengerCargo();
local maillist=AIVehicleList_Group(INSTANCE.main.route.GetVirtualAirMailGroup());
local passlist=AIVehicleList_Group(INSTANCE.main.route.GetVirtualAirPassengerGroup());
vehlist.AddList(passlist);
local totalcapacity=0;
local onecapacity=0;
local age=0;
local vehneed=0;
local vehnumber=maillist.Count()+passlist.Count();
DInfo("NETWORK: Aircrafts in network: "+vehnumber+" max dist: "+virtroad.distance,1);
local futurveh=INSTANCE.main.carrier.ChooseAircraft(cCargo.GetMailCargo(), virtroad.distance, AircraftType.BEST); // force discovery of new engine for the virtual mail network
futurveh=INSTANCE.main.carrier.ChooseAircraft(passengerID, virtroad.distance, AircraftType.BEST);
if (futurveh == null)	return; // when aircrafts are disable, return null
if (vehlist.IsEmpty())
	{
	onecapacity=AIEngine.GetCapacity(futurveh);
	age=1000;
	vehneed=1;
	}
else	{
	vehlist.Valuate(AIVehicle.GetCapacity,cCargo.GetPassengerCargo());
	vehlist.Sort(AIList.SORT_BY_VALUE,true);
	onecapacity=0;
	foreach (vehicle, capacity in vehlist)
		{
		totalcapacity+=capacity;
		if (capacity > 0)	onecapacity=capacity;
		}
	cRoute.VirtualAirGroup[2]=totalcapacity;
	vehlist.Valuate(AIVehicle.GetAge);
	vehlist.Sort(AIList.SORT_BY_VALUE,true); // younger first
	age=vehlist.GetValue(vehlist.Begin());
	if (age < 60) { DInfo("We already buy an aircraft recently for the network: "+age,2); return; }
	}
if (onecapacity == 0)	onecapacity=90; // estimation
DInfo("NETWORK: Total capacity of network: "+totalcapacity,1);
local bigairportlocation=INSTANCE.main.carrier.VirtualAirRoute[0];
local bigairportID=AIStation.GetStationID(bigairportlocation);
local bigairportObj=cStation.GetStationObject(bigairportID);
if (bigairportObj == null)	return;
bigairportObj.UpdateStationInfos();
local cargowaiting=bigairportObj.cargo_produce.GetValue(passengerID);
if ((cargowaiting-totalcapacity) > 0)	vehneed=cargowaiting / onecapacity;
local overcharge=AITown.GetLastMonthProduction(AITile.GetClosestTown(bigairportlocation), passengerID) / 2;
if (vehneed==0 && AIStation.GetCargoRating(bigairportID, passengerID)<45 && totalcapacity < overcharge)
	{
	vehneed=1;
	DInfo("NETWORK: overcharging network capacity to increase rating",1);
	}
// one because poor station rating
if (vehnumber < (cCarrier.VirtualAirRoute.len() / 2))	vehneed=(cCarrier.VirtualAirRoute.len() /2) - vehnumber;
DInfo("NETWORK: need="+vehneed,1);
PutSign(bigairportlocation,"Network Airport Reference: "+cargowaiting);
if (vehneed > 6)	vehneed=6; // limit to 6 aircrafts add per trys
if (vehneed > 0)
	{
	local thatnetwork=0;
	for (local k=0; k < vehneed; k++)
		{
		if (vehnumber % 6 == 0)	thatnetwork=1;
					else	thatnetwork=0;
		if (vehnumber == 0)	thatnetwork=0;
		if (INSTANCE.main.bank.CanBuyThat(AIEngine.GetPrice(futurveh)) && INSTANCE.main.carrier.CanAddNewVehicle(0,true,1))
		if (INSTANCE.main.carrier.BuildAndStartVehicle(thatnetwork))
			{
			DInfo("Adding an aircraft to the network, "+(vehnumber+1)+" aircrafts runs it now",0);
			vehnumber++;
			}
		}
	INSTANCE.main.carrier.AirNetworkOrdersHandler();
	}
}

function cRoute::VehicleGroupProfitRatio(groupID)
// check a vehicle group and return a ratio representing it's value
// it's just (groupprofit * 1000 / numbervehicle)
{
if (!AIGroup.IsValidGroup(groupID))	return 0;
local vehlist=AIVehicleList_Group(groupID);
local vehnumber=vehlist.Count();
local vehtype=AIGroup.GetVehicleType(groupID);
if (vehtype==AIVehicle.VT_AIR)
if (vehnumber == 0) return 1000000; // avoid / per 0 and set high value to group without vehicle
local totalvalue=0;
vehlist.Valuate(AIVehicle.GetProfitThisYear);
foreach (vehicle, value in vehlist)
	{ totalvalue+=value*1000; }
return totalvalue / vehnumber;
}

function cRoute::DutyOnRoute()
// this is where we add vehicle and tiny other things to max our money
{
/*if (INSTANCE.main.carrier.vehnextprice > 0 && INSTANCE.main.carrier.vehnextprice < INSTANCE.main.carrier.highcostAircraft)
	{
	INSTANCE.main.bank.busyRoute=true;
	DInfo("We're upgrading something, buys are blocked...",1,"DutyOnRoute");
	return;
	}*/
local firstveh=false;
local priority=AIList();
local road=null;
local chopper=false;
local dual=false;
INSTANCE.main.bank.busyRoute=false;
INSTANCE.main.route.DutyOnAirNetwork(); // we handle the network load here
foreach (uid, dummy in cRoute.RouteIndexer)
	{
	firstveh=false;
	road=cRoute.GetRouteObject(uid);
	if (road==null)	continue;
	if (!road.isWorking)	continue;
	if (road.route_type == RouteType.AIRNET || road.route_type == RouteType.AIRNETMAIL)	continue;
	if (road.source == null)	continue;
	if (road.target == null)	continue;
	if (road.route_type == RouteType.RAIL)	{ INSTANCE.main.route.DutyOnRailsRoute(uid); continue; }
	local maxveh=0;
	local cargoid=road.cargoID;
	if (cargoid == null)	continue;
	local futur_engine=INSTANCE.main.carrier.GetVehicle(uid);
	local futur_engine_capacity=1;
	if (futur_engine != null)	futur_engine_capacity=AIEngine.GetCapacity(futur_engine);
					else	continue;
	switch (road.route_type)
		{
		case AIVehicle.VT_ROAD:
			maxveh=INSTANCE.main.carrier.road_max_onroute;
		break;
		case RouteType.CHOPPER:
			chopper=true;
			maxveh=4;
			cargoid=cCargo.GetPassengerCargo();
			INSTANCE.main.builder.DumpRoute(uid);
		break;
		case RouteType.AIR:
		case RouteType.AIRMAIL:
		case RouteType.SMALLAIR:
		case RouteType.SMALLMAIL:
			maxveh=INSTANCE.main.carrier.air_max;
			cargoid=cCargo.GetPassengerCargo(); // for aircraft, force a check vs passenger
			// so mail aircraft runner will be add if passenger is high enough, this only affect routes not in the network
		break;
		case AIVehicle.VT_WATER:
			maxveh=INSTANCE.main.carrier.water_max;
		break;
		}
	road.source.UpdateStationInfos();
	DInfo("Route "+cRoute.RouteGetName(uid)+" distance "+road.distance,2,"DutyOnRoute");
	local vehneed=0;
	if (road.vehicle_count == 0)	{ firstveh=true; } // everyone need at least 2 vehicle on a route
	local vehonroute=road.vehicle_count;
	local cargowait=0;
	local capacity=0;
	dual=road.source_istown; // we need to check both side if source is town we're on a dual route (pass or mail)
	cargowait=road.source.cargo_produce.GetValue(cargoid);
	capacity=road.source.vehicle_capacity.GetValue(cargoid);
	if (cStation.IsStationVirtual(road.source.stationID))	capacity-=cRoute.VirtualAirGroup[2];
	if (capacity==0)
		{
		if (road.source_istown)	cargowait=AITown.GetLastMonthProduction(road.sourceID, cargoid);
					else	cargowait=AIIndustry.GetLastMonthProduction(road.sourceID, cargoid);
		capacity=futur_engine_capacity;
		}
	if (dual)
		{
		road.target.UpdateStationInfos();
		local src_capacity=capacity;
		local dst_capacity= road.target.vehicle_capacity.GetValue(cargoid);
		local src_wait = cargowait;
		local dst_wait = road.target.cargo_produce.GetValue(cargoid);
		if (cStation.IsStationVirtual(road.target.stationID))	dst_capacity-=cRoute.VirtualAirGroup[2];
		if (dst_capacity == 0)	{ dst_wait=AITown.GetLastMonthProduction(road.targetID,cargoid); dst_capacity=futur_engine_capacity; }
		if (src_wait < dst_wait)	cargowait=src_wait; // keep the lowest cargo amount
						else	cargowait=dst_wait;
		if (src_capacity < dst_capacity)	capacity=dst_capacity; // but keep the highest capacity we have
							else	capacity=src_capacity;
		DInfo("Source capacity="+src_capacity+" wait="+src_wait+" --- Target capacity="+dst_capacity+" wait="+dst_wait,2);
		}
	local remain = cargowait - capacity;
	if (remain < 1)	vehneed=0;
			else	vehneed = (cargowait / capacity)+1;
	DInfo("Capacity ="+capacity+" wait="+cargowait+" remain="+remain+" needbycapacity="+vehneed,2);
	if (vehneed >= vehonroute) vehneed-=vehonroute;
	if (vehneed+vehonroute > maxveh) vehneed=maxveh-vehonroute;
	if (AIStation.GetCargoRating(road.source.stationID,cargoid) < 25 && vehonroute < 4)	vehneed++;
	if (firstveh)
		{
		if (road.route_type==RouteType.ROAD || road.route_type==RouteType.AIR || road.route_type==RouteType.AIRMAIL || road.route_type==RouteType.SMALLAIR || road.route_type==RouteType.SMALLMAIL)
			{ // force 2 vehicle if none exists yet for truck/bus & aircraft
			if (vehneed < 2)	vehneed=2;
			}
		else	vehneed=1; // everyones else is block to 1 vehicle
		if (vehneed > 4)	vehneed=4; // max 4 at a time
		}
	vehneed=INSTANCE.main.carrier.CanAddNewVehicle(uid, true, vehneed);
	DInfo("CanAddNewVehicle for source station says "+vehneed,2);
	vehneed=INSTANCE.main.carrier.CanAddNewVehicle(uid, false, vehneed);
	DInfo("CanAddNewVehicle for destination station says "+vehneed,2);
	DInfo("Capacity="+capacity+" vehicleneed="+vehneed+" cargowait="+cargowait+" vehicule#="+road.vehicle_count+"/"+maxveh+" firstveh="+firstveh,2);
	// adding vehicle
	if (vehneed > 0)
		{
		priority.AddItem(road.groupID,vehneed); // we record all groups needs for vehicle
		road.source.vehicle_capacity.SetValue(cargoid, road.source.vehicle_capacity.GetValue(cargoid)+(vehneed*futur_engine_capacity));
		road.target.vehicle_capacity.SetValue(cargoid, road.target.vehicle_capacity.GetValue(cargoid)+(vehneed*futur_engine_capacity));
		}
	}

// now we can try add others needed vehicles here but base on priority
// and priority = aircraft before anyone, then others, in both case, we range from top group profit to lowest
local allneed=0;
local allbuy=0;
if (priority.IsEmpty())	return;
local priocount=AIList();
priocount.AddList(priority);
priority.Valuate(AIGroup.GetVehicleType);
priority.Sort(AIList.SORT_BY_VALUE,false);
local vehneed=0;
local vehvalue=0;
local topvalue=0;
INSTANCE.main.carrier.highcostAircraft=0;
DInfo("Priority list="+priority.Count()+" Saved list="+priocount.Count(),1);
foreach (groupid, ratio in priority)
	{
	vehneed=priocount.GetValue(groupid); DInfo("BUYS -> Group #"+groupid+" "+AIGroup.GetName(groupid)+" need "+vehneed+" vehicles",1);
	allneed+=vehneed;
	if (vehneed == 0) continue;
	local uid=cRoute.GroupIndexer.GetValue(groupid);
	local rtype=AIGroup.GetVehicleType(groupid);
	local vehmodele=INSTANCE.main.carrier.GetVehicle(uid);
	local vehvalue=0;
	local goodbuy=false;
	if (vehmodele != null)	vehvalue=AIEngine.GetPrice(vehmodele);
	for (local z=0; z < vehneed; z++)
		{
		DInfo("process vehicle "+z+" for group #"+groupid,2);
		if (INSTANCE.main.bank.CanBuyThat(vehvalue))
			{
			if (INSTANCE.main.bank.CanBuyThat(vehvalue+INSTANCE.main.carrier.vehnextprice))	goodbuy=INSTANCE.main.carrier.BuildAndStartVehicle(uid);
			if (goodbuy)
				{
				local rinfo=cRoute.GetRouteObject(uid);
				DInfo("Adding a vehicle "+AIEngine.GetName(vehmodele)+" to route "+cRoute.RouteGetName(rinfo.UID),0);
				allbuy++;
				}
			}
		else	{
			DInfo("Not enough money to buy "+cEngine.GetName(vehmodele)+" cost: "+vehvalue,2);
			if (INSTANCE.main.carrier.highcostAircraft < vehvalue)	INSTANCE.main.carrier.highcostAircraft=vehvalue;
			}
		}
	}
if (allbuy < allneed)	INSTANCE.main.bank.busyRoute=true;
}

