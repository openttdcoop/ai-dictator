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

enum RouteType {
	RAIL,		// AIVehicle.VT_RAIL
	ROAD,		// AIVehicle.VT_ROAD
	WATER,	// AIVehicle.VT_WATER
	AIR,		// AIVehicle.VT_AIR
	AIRMAIL,
	AIRNET,
	AIRNETMAIL,
	SMALLAIR,
	SMALLMAIL,
	CHOPPER }
enum AircraftType {
	EFFICIENT,
	BEST,
	CHOPPER
}
enum DepotAction {
	SELL=0,		// to just sell a vehicle
	UPGRADE=1,		// to upgrade a vehicle
	REPLACE=2,		// to replace a vehicle, well this should also upgrade it
	CRAZY=3,		// to get a big amount of money
	REMOVEROUTE=4,	// to remove a route
	LINEUPGRADE=5,	// to upgrade a train line to a newer railtype
	SIGNALUPGRADE=6,	// when a station need build signal on rails
	WAITING=7,		// wait at depot: it's a state to ignore that vehicle already in depot, not to send it and wait at depot
	ADDWAGON=1000	// to add a train or wagons to a route
}


import("pathfinder.road", "RoadPathFinder", 3);
import("pathfinder.rail", "RailPathFinder", 1);

require("require.nut");

class DictatorAI extends AIController
 {
	// settings
	use_road = null;
	use_train = null;
	use_boat = null;
	use_air = null;
	terraform = null;
	fairlevel = null;
	debug = null;
	// other
	minRank = null;
	builddelay=null;
	OneMonth=null;
	OneWeek=null;
	SixMonth=null;
	TwelveMonth=null;
	loadedgame = null;
	buildTimer=null;
	safeStart=null;
	main=null;


   constructor()
   	{
	::INSTANCE <- this;
	main = cMain();
	minRank = 5000;
	fairlevel = 0;
	debug = false;
	builddelay=false;
	OneMonth=0;
	OneWeek=0;
	SixMonth=0;
	TwelveMonth=0;
	loadedgame = false;
	buildTimer=0;
	safeStart=0;
	}
 
 }

function DictatorAI::Start()
{
	this.CheckCurrentSettings();
	main.Init();
	main.DInfo("DicatorAI started.",0);
	AICompany.SetAutoRenewStatus(false);
	if (loadedgame) 
		{
		main.bank.SaveMoney();
		cRoute.DiscoverWorldTiles();
		cBridge.BridgeDiscovery();
		main.jobs.PopulateJobs();
		scp_manager.Check();
		LoadingGame();
		local stationList=AIList();	// check for no more working station if cargo disapears...
		stationList.AddList(AIStationList(AIStation.STATION_ANY));
		foreach (stationID, dummy in stationList)
			{
			cStation.CheckCargoHandleByStation(stationID);
			}
		INSTANCE.main.route.VirtualAirNetworkUpdate();
//		local maptiles=AIList();
//		maptiles.AddList(cRoute.WorldTiles);
//		RailFollower.FindRailOwner(maptiles);
		RailFollower.FindRailOwner(cRoute.WorldTiles);
		DInfo("...Loading game end",0,"Main");
		}
	 else {
		main.bank.SaveMoney();
		main.jobs.PopulateJobs();
		main.jobs.RawJobHandling();
		safeStart=3;
		}
	while(true)
		{
		this.CheckCurrentSettings();
		//if (use_train) main.builder.BaseStationRailBuilder(80835);
		DWarn("Running the AI in debug mode slowdown the AI and can do random issues !!!",1);
		main.bank.CashFlow();
		main.CheckAccount();
		if (main.SCP.IsAllow())	main.SCP.Check();
		if (main.bank.canBuild)
				{
				if (main.builder.building_route == -1)	main.builder.building_route=main.jobs.GetNextJob();
				if (main.builder.building_route != -1)
					{
					main.builder.DumpTopJobs(); // debug
					local jobs_obj=cJobs.Load(main.builder.building_route);
					main.route=cRoute.GetRouteObject(main.builder.building_route);
					if (main.route == null)	{
									main.route=cRoute();
									if (!jobs_obj)	main.builder.building_route=-1;
												else	{
													main.route.CreateNewRoute(main.builder.building_route);
													DInfo("Creating a new route : "+cRoute.RouteGetName(main.builder.building_route),0);
													}
									}
								else	DInfo("Construction of route "+cRoute.RouteGetName(main.builder.building_route)+" is at phase "+main.route.status,1);
					if (main.builder.building_route != -1)
						{
						main.builder.TryBuildThatRoute();
						cMisc.checkHQ();
						}
					}
				}
		main.bank.CashFlow();
		main.event.HandleEvents();
		AIController.Sleep(1);
		cPathfinder.AdvanceAllTasks();
		AIController.Sleep(1);
		main.builder.WeeklyChecks();
		AIController.Sleep(1);
		main.builder.MonthlyChecks();
		AIController.Sleep(1);
		cPathfinder.AdvanceAllTasks();
		AIController.Sleep(1);
		main.jobs.RawJobHandling();
		AIController.Sleep(1);
		cPathfinder.AdvanceAllTasks();
		AIController.Sleep(1);
		cDebug.ClearSigns();
		}
}

function DictatorAI::Stop()
{
	DInfo("DictatorAI is stopped",0);
	ClearSigns();
}

function DictatorAI::NeedDelay(delay=30)
{
	if (!debug)	return;
	DInfo("We are waiting: "+delay,2);
	::AIController.Sleep(delay);
} 

function DictatorAI::Save()
{ // save
	local table = 
		{
		routes = null,
		stations = null,
		vehicle = null,
		busyroute = null,
		virtualpass = null,
		virtualmail = null,
		}
	local all_stations=[];
	local all_routes=[];
	local all_vehicle=[];
	local temparray=[];

	// routes
	foreach (obj in cRoute.database)
		{
		if (obj.UID < 2 || obj.UID == null)	continue; // don't save virtual route
		all_routes.push(obj.route_type);
		all_routes.push(obj.status);
		all_routes.push(obj.groupID);
		all_routes.push(obj.source_stationID);
		all_routes.push(obj.target_stationID);
		all_routes.push(obj.primary_RailLink);
		all_routes.push(obj.secondary_RailLink);
		all_routes.push(obj.source_RailEntry);
		all_routes.push(obj.target_RailEntry);
		}
	// stations
	foreach(obj in cStation.stationdatabase)
		{
		all_stations.push(obj.stationID);
		all_stations.push(obj.specialType);
		all_stations.push(obj.size);
		all_stations.push(obj.depot);
		temparray=ListToArray(obj.locations);
		all_stations.push(temparray.len());
		for (local z=0; z < temparray.len(); z++)	all_stations.push(temparray[z]);
		temparray=ListToArray(obj.platforms);
		all_stations.push(temparray.len());
		for (local z=0; z < temparray.len(); z++)	all_stations.push(temparray[z]);
		}
	// vehicle
	foreach (obj in cTrain.vehicledatabase)
		{
		all_vehicle.push(obj.vehicleID);
		all_vehicle.push(obj.srcStationID);
		all_vehicle.push(obj.dstStationID);
		all_vehicle.push(obj.src_useEntry);
		all_vehicle.push(obj.dst_useEntry);
		all_vehicle.push(obj.stationbit);
		}
	table.routes=all_routes;
	table.stations=all_stations;
	table.vehicle=all_vehicle;
	table.busyroute=main.builder.building_route;
	local netair=cRoute.VirtualAirGroup[0];
	table.virtualpass=netair;
	netair=cRoute.VirtualAirGroup[1];
	table.virtualmail=netair;
	DInfo("Saving game... "+cRoute.database.len()+" routes, "+cStation.stationdatabase.len()+" stations");
	return table;
}
 
function DictatorAI::Load(version, data)
{
	DInfo("Loading a saved game with DictatorAI version "+version,0);
	if ("routes" in data) main.bank.canBuild=data.routes;
	if ("stations" in data) main.bank.unleash_road=data.stations;
	if ("busyroute" in data) main.builder.building_route=data.busyroute;
	if ("vehicle" in data)	SixMonth=data.vehicle;
	if ("virtualmail" in data)	TwelveMonth=data.virtualmail;
	if ("virtualpass" in data)	main.bank.mincash=data.virtualpass;
	main.bank.busyRoute=version;
	loadedgame = true;
}

function DictatorAI::CheckCurrentSettings()
{
// this are settings we should take care of (one day ^^ )
// max_train_length
// max_bridge_length = 64
// max_tunnel_length 
// join_stations = true
// adjacent_stations = true
	debug=true;
	use_road=false;
	use_train=false;
	use_boat=false;
	use_air=false;
	terraform=false;
	if (AIController.GetSetting("debug") == 0) 	debug=false;
	fairlevel = DictatorAI.GetSetting("fairlevel");
	if (AIController.GetSetting("use_road") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_ROAD))	use_road = true;
	if (AIController.GetSetting("use_train") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_RAIL))	use_train = true;
	if (AIController.GetSetting("use_boat") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_WATER))	use_boat = true;
	if (AIController.GetSetting("use_air") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_AIR))	use_air = true;
	if (AIController.GetSetting("use_terraform"))	terraform = true;
	main.carrier.VehicleCountUpdate();
	if (main.carrier.GetVehicleCount(AIVehicle.VT_ROAD) + 5 > AIGameSettings.GetValue("vehicle.max_roadveh")) use_road = false;
	if (main.carrier.GetVehicleCount(AIVehicle.VT_RAIL) + 1 > AIGameSettings.GetValue("vehicle.max_trains")) use_train = false;
	if (main.carrier.GetVehicleCount(AIVehicle.VT_AIR) + 1 > AIGameSettings.GetValue("vehicle.max_aircraft")) use_air = false;
	if (main.carrier.GetVehicleCount(AIVehicle.VT_WATER) + 1 > AIGameSettings.GetValue("vehicle.ships")) use_boat = false;

	if (AIGameSettings.GetValue("ai.ai_disable_veh_train") == 1)	use_train = false;
	if (AIGameSettings.GetValue("ai.ai_disable_veh_roadveh") == 1)	use_road = false;
	if (AIGameSettings.GetValue("ai.ai_disable_veh_aircraft") == 1)	use_air = false;
	if (AIGameSettings.GetValue("ai.ai_disable_veh_ship") == 1)	use_boat = false;

	main.carrier.train_length=5;
	switch (fairlevel)
		{
		case 0: // easiest
			main.carrier.road_max_onroute=8;
			main.carrier.road_max=2;
			main.carrier.road_upgrade=10;
			main.carrier.rail_max=1;
			main.carrier.water_max=2;
			main.carrier.air_max=4;
			main.carrier.airnet_max=2;
			terraform = false; // no terraforming in easy difficulty
		break;
		case 1: 
			main.carrier.road_max_onroute=20;
			main.carrier.road_max=3;
			main.carrier.road_upgrade=10;
			main.carrier.rail_max=4;
			main.carrier.water_max=20;
			main.carrier.air_max=6;
			main.carrier.airnet_max=3;
		break;
		case 2: 
			main.carrier.road_max_onroute=40;	// upto 40 bus/truck per route
			main.carrier.road_max=6;		// upto a 6 size road station
			main.carrier.road_upgrade=10;		// upgrade road station every X vehicles. station can handle so a max that*road_max vehicle
			main.carrier.rail_max=12; 		// it's our highest train limit, can't build more than 12 platforms per station
			main.carrier.water_max=60; 		// there's no real limit for boats
			main.carrier.air_max=8; 		// 8 aircrafts / route
			main.carrier.airnet_max=4;		// 4 aircrafts / airport in the air network, ie: 10 airports = 40 aircrafts
		break;
		}
	local spdcheck=null;
	if (AIGameSettings.IsValid("station_spread"))
		{
		spdcheck=AIGameSettings.GetValue("station_spread");
		if (spdcheck < main.carrier.rail_max)	main.carrier.rail_max=spdcheck;
		}
	use_boat=false; // we will handle boats later
	if (INSTANCE.safeStart >0)
		{ // Keep only road
		use_boat=false;
		use_train=false;
		use_air=false;
		}
}

function DictatorAI::DInfo(putMsg,debugValue=0)
// just output AILog message depending on debug level
{
	if (debugValue >= 10)
		{
		AILog.Info(putMsg);
		return;
		}
	local debugState = INSTANCE.GetSetting("debug");
	local func="Unknown";
	if (debugState > 0)	func+="-> ";
				else	func="";
	if (debugValue <= debugState )
		{
		AILog.Info(func+putMsg);
		}
}

function DictatorAI::DError(putMsg,debugValue=1)
// just output AILog message depending on debug level
{
	if (debugValue >= 10)
		{
		AILog.Error(putMsg);
		return;
		}
	local debugState = DictatorAI.GetSetting("debug");
	debugValue=1; // force error message to always appears when debug is on
	local func="Unknown";
	if (debugState > 0)	func+="-> ";
				else	func="";
	if (debugValue <= debugState )
		{
		AILog.Error(func+putMsg+" Error:"+AIError.GetLastErrorString());
		}
}

function DictatorAI::DWarn(putMsg, debugValue=1)
// just output AILog message depending on debug level
{
	if (debugValue >= 10)
		{
		AILog.Warning(putMsg);
		return;
		}
	local debugState = DictatorAI.GetSetting("debug");
	local func="Unknown";
	if (debugState > 0)	func+="-> ";
				else	func="";
	if (debugValue <= debugState )
		{
		AILog.Warning(func+putMsg);
		}
}

function DictatorAI::ListToArray(list)
{
	local array = [];
	local templist = AIList();
	templist.AddList(list);
	while (templist.Count() > 0) {
		local arrayitem = [templist.Begin(), templist.GetValue(templist.Begin())];
		array.append(arrayitem);
		templist.RemoveTop(1);
	}
	return array;
}

function DictatorAI::ArrayToList(array)
{
	local list = AIList();
	local temparray = [];
	temparray.extend(array);
	while (temparray.len() > 0) {
		local arrayitem = temparray.pop();
		list.AddItem(arrayitem[0], arrayitem[1]);
	}	
	return list;
}

