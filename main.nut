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
require("handler/pathfinder.nut");
require("handler/bridgehandler.nut");
require("build/builder.nut");
require("build/stationbuilder.nut");
require("build/airportbuilder.nut");
require("build/waterbuilder.nut");
require("build/railbuilder.nut");
require("build/roadbuilder.nut");
require("build/stationremover.nut");
require("build/vehiclebuilder.nut");
require("build/aircraftbuilder.nut");
require("build/trainbuilder.nut");
require("build/truckbuilder.nut");
require("build/boatbuilder.nut");
require("handler/routes.nut");
require("handler/events.nut");
require("handler/checks.nut");
require("handler/cargo.nut");
require("handler/vehiclehandler.nut");
require("handler/ordershandler.nut");
require("handler/stationhandler.nut");
require("handler/chemin.nut");
require("handler/railchemin.nut");
require("handler/enginehandler.nut");
require("handler/trainhandler.nut");
require("utils/banker.nut");
require("utils/misc.nut");
require("handler/jobs.nut");
require("utils/debug.nut");
require("utils/tile.nut");
require("utils/railfollower.nut");

class DictatorAI extends AIController
 {
	pathfinder = null;
	builder = null;
	bank = null;
	minRank = null;
	eventManager = null;
	carrier=null;
	use_road = null;
	use_train = null;
	use_boat = null;
	use_air = null;
	terraform = null;
	fairlevel = null;
	debug = null;
	builddelay=null;
	OneMonth=null;
	OneWeek=null;
	SixMonth=null;
	TwelveMonth=null;
	cargo_favorite=null;
	loadedgame = null;
	jobs = null;
	jobs_obj = null;
	route = null;
	buildTimer=null;
	safeStart=null;
	bridgeInit=null;

   constructor()
   	{
	pathfinder = null;
	builder = cBuilder();
	bank = cBanker();
	minRank = 5000;
	eventManager = cEvents();
	carrier=cCarrier();
	use_road = false;
	use_train = false;
	use_boat = false;
	use_air = false;
	terraform = false;
	fairlevel = 0;
	debug = false;
	builddelay=false;
	OneMonth=0;
	OneWeek=0;
	SixMonth=0;
	TwelveMonth=0;
	cargo_favorite=0;
	loadedgame = false;
	jobs = cJobs();
	jobs_obj = null;
	route = cRoute();
	buildTimer=0;
	safeStart=0;
	bridgeInit=cBridge();
	} 
 }
 
function DictatorAI::Start()
{
	::INSTANCE <- this;
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	CheckCurrentSettings();
	builder.SetRailType();
	DInfo("DicatorAI started.",0,"main");
	AICompany.SetAutoRenewStatus(false);
	cEngine.EngineCacheInit();
	route.RouteInitNetwork();
	if (loadedgame) 
		{
		//cBridge.BridgeDiscovery();
		bank.SaveMoney();
		jobs.PopulateJobs();
		LoadingGame();
		local stationList=AIList();	// check for no more working station if cargo disapears...
		stationList.AddList(AIStationList(AIStation.STATION_ANY));
		foreach (stationID, dummy in stationList)
			{
			cStation.CheckCargoHandleByStation(stationID);
			}
		INSTANCE.route.VirtualAirNetworkUpdate();
		DInfo("...Loading game end",0,"Main");
		}
	 else {
		AIInit();
		bank.SaveMoney();
		jobs.PopulateJobs();
		jobs.RawJobHandling();
		safeStart=3;
		}
	bank.Update();
	while(true)
		{
		this.CheckCurrentSettings();
		//if (use_train) builder.BaseStationRailBuilder(80835);
		DWarn("Running the AI in debug mode slowdown the AI and can do random issues !!!",1,"main");
		bank.CashFlow();
		this.ClearSignsALL();
		if (bank.canBuild)
				{
				if (builder.building_route == -1)	builder.building_route=jobs.GetNextJob();
				if (builder.building_route != -1)
					{
					builder.DumpTopJobs();
					jobs_obj=cJobs.GetJobObject(builder.building_route);
					route=cRoute.GetRouteObject(builder.building_route);
					if (route == null)	{
									route=cRoute();
									if (jobs_obj==null)	builder.building_route=-1;
												else	{
													route.CreateNewRoute(builder.building_route);
													DInfo("Creating a new route : "+cRoute.RouteGetName(builder.building_route),0,"main");
													}
									}
								else	DInfo("Construction of route "+cRoute.RouteGetName(builder.building_route)+" is at phase "+route.status,1,"main");
					if (builder.building_route!=-1)
						{
						builder.TryBuildThatRoute();
						this.checkHQ();
						}
					}
				}
		bank.CashFlow();
		eventManager.HandleEvents();
		cPathfinder.AdvanceAllTasks();
		AIController.Sleep(10);
		builder.WeeklyChecks();
		builder.MonthlyChecks();
		cPathfinder.AdvanceAllTasks();
		jobs.RawJobHandling();
		cPathfinder.AdvanceAllTasks();
		this.ClearSignsALL();
		}
}

function DictatorAI::Stop()
{
DInfo("DictatorAI is stopped",0,"main");
ClearSignsALL();
}

function DictatorAI::NeedDelay(delay=30)
{
if (!debug)	return;
DInfo("We are waiting: "+delay,2,"NeedDelay");
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
table.busyroute=builder.building_route;
local netair=cRoute.VirtualAirGroup[0];
table.virtualpass=netair;
netair=cRoute.VirtualAirGroup[1];
table.virtualmail=netair;
print("Saving game... "+cRoute.database.len()+" routes, "+cStation.stationdatabase.len()+" stations");
return table;
}
 
function DictatorAI::Load(version, data)
{
DInfo("Loading a saved game with DictatorAI version "+version,0,"Load");
if ("routes" in data) bank.canBuild=data.routes;
if ("stations" in data) bank.unleash_road=data.stations;
if ("busyroute" in data) builder.building_route=data.busyroute;
if ("vehicle" in data)	SixMonth=data.vehicle;
if ("virtualmail" in data)	TwelveMonth=data.virtualmail;
if ("virtualpass" in data)	bank.mincash=data.virtualpass;
bank.busyRoute=version;
loadedgame = true;
}

function DictatorAI::BuildHQ(centre)
{
local tilelist = null;
tilelist = cTileTools.GetTilesAroundTown(centre);
tilelist.Valuate(AIBase.RandItem);
foreach (tile, dummy in tilelist)
	{
	if (AICompany.BuildCompanyHQ(tile))
		{
		local name = AITown.GetName(AITile.GetClosestTown(tile));
		DInfo("Built company headquarters near " + name,0,"BuildHQ");
		return;
		}
	AIController.Sleep(1);
	}	
}

function DictatorAI::CheckCurrentSettings()
{
// this are settings we should take care of (one day ^^ )
// max_train_length
// max_bridge_length = 64
// max_tunnel_length 
// join_stations = true
// adjacent_stations = true

if (AIController.GetSetting("debug") == 0) 
	debug=false;
else	debug=true;
fairlevel = DictatorAI.GetSetting("fairlevel");
if (AIController.GetSetting("use_road") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_ROAD))
	use_road = true;
else	use_road = false;
if (AIController.GetSetting("use_train") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_RAIL))
	use_train = true;
else	use_train = false;
if (AIController.GetSetting("use_boat") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_WATER))
	use_boat = true;
else	use_boat = false;
if (AIController.GetSetting("use_air") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_AIR))
	use_air = true;
else	use_air = false;
if (AIController.GetSetting("use_terraform"))	terraform = true;
							else	terraform = false;
local allvehiclelist = AIVehicleList();
allvehiclelist.Valuate(AIVehicle.GetVehicleType);
local vehiclelist=AIList();
vehiclelist.AddList(allvehiclelist);
vehiclelist.KeepValue(AIVehicle.VT_ROAD);
if (vehiclelist.Count() + 5 > AIGameSettings.GetValue("vehicle.max_roadveh")) use_road = false;
vehiclelist.Clear();
vehiclelist.AddList(allvehiclelist);
vehiclelist.KeepValue(AIVehicle.VT_RAIL);
if (vehiclelist.Count() + 1 > AIGameSettings.GetValue("vehicle.max_trains")) use_train = false;
vehiclelist.Clear();
vehiclelist.AddList(allvehiclelist);
vehiclelist.KeepValue(AIVehicle.VT_AIR);
if (vehiclelist.Count() + 1 > AIGameSettings.GetValue("vehicle.max_aircraft")) use_air = false;
vehiclelist.Clear();
vehiclelist.AddList(allvehiclelist);
vehiclelist.KeepValue(AIVehicle.VT_WATER);
if (vehiclelist.Count() + 1 > AIGameSettings.GetValue("vehicle.ships")) use_boat = false;

if (AIGameSettings.GetValue("ai.ai_disable_veh_train") == 1)	use_train = false;
if (AIGameSettings.GetValue("ai.ai_disable_veh_roadveh") == 1)	use_road = false;
if (AIGameSettings.GetValue("ai.ai_disable_veh_aircraft") == 1)	use_air = false;
if (AIGameSettings.GetValue("ai.ai_disable_veh_ship") == 1)	use_boat = false;

carrier.train_length=5;
switch (fairlevel)
	{
	case 0: // easiest
		carrier.road_max_onroute=8;
		carrier.road_max=2;
		carrier.road_upgrade=10;
		carrier.rail_max=1;
		carrier.water_max=2;
		carrier.air_max=4;
		carrier.airnet_max=2;
		terraform = false; // no terraforming in easy difficulty
	break;
	case 1: 
		carrier.road_max_onroute=15;
		carrier.road_max=3;
		carrier.road_upgrade=10;
		carrier.rail_max=4;
		carrier.water_max=20;
		carrier.air_max=6;
		carrier.airnet_max=3;
	break;
	case 2: 
		carrier.road_max_onroute=30;	// upto 12 bus/truck per route
		carrier.road_max=6;		// upto a 6 size road station
		carrier.road_upgrade=10;	// upgrade road station every X vehicles. station can handle so a max that*road_max vehicle
		carrier.rail_max=12; 		// it's our highest train limit, can't build more than 12 platforms per station
		carrier.water_max=60; 		// there's no real limit for boats
		carrier.air_max=8; 		// 8 aircrafts / route
		carrier.airnet_max=4;		// 4 aircrafts / airport in the air network, ie: 10 airports = 40 aircrafts
	break;
	}
local spdcheck=null;
if (AIGameSettings.IsValid("station_spread"))
	{
	spdcheck=AIGameSettings.GetValue("station_spread");
	if (spdcheck < carrier.rail_max)	carrier.rail_max=spdcheck;
	}
use_boat=false; // we will handle boats later
if (INSTANCE.safeStart >0)
	{ // Keep only road
	use_boat=false;
	use_train=false;
	use_air=false;
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

