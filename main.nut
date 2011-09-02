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
	RAIL,	// AIVehicle.VT_RAIL
	ROAD,	// AIVehicle.VT_ROAD
	WATER,	// AIVehicle.VT_WATER
	AIR,	// AIVehicle.VT_AIR
	AIRNET,
	CHOPPER }
enum AircraftType {
	EFFICIENT,
	BEST,
	CHOPPER
}
enum DepotAction {
	SELL,
	UPGRADE,
	REPLACE,
	CRAZY,
	ADDWAGON
}


import("pathfinder.road", "RoadPathFinder", 3);
import("pathfinder.rail", "RailPathFinder", 1);
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
	if (loadedgame) 
		{
		bank.SaveMoney();
		jobs.PopulateJobs();
		// our routes are saved in bank.canBuild & stations in bank.unleash_road
		// and oneMonth=station database size and oneWeek=routedatabase size when saved
		local all_stations=bank.unleash_road;
		DInfo("Restoring stations",0,"main");
		local iter=0;
		for (local i=0; i < all_stations.len(); i++)
			{
			local obj=cStation();
			obj.stationID=all_stations[i];
			obj.stationType=all_stations[i+1];
			obj.specialType=all_stations[i+2];
			obj.size=all_stations[i+3];
			obj.maxsize=all_stations[i+4]; //1000
			obj.depot=all_stations[i+5];
			obj.radius=all_stations[i+6];
			local counter=all_stations[i+7];
			local nextitem=i+8+counter;
			local temparray=[];
			for (local z=0; z < counter; z++)	temparray.push(all_stations[i+8+z]);
			obj.locations=ArrayToList(temparray);
			counter=all_stations[nextitem];
			temparray=[];
			for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]);
			i=nextitem+counter;
			iter++;
			cStation.stationdatabase[obj.stationID] <- obj;
			// add checks for dead stations or tigger that
			}
		DInfo(iter+" stations found.",0,"main");
		DInfo("base size: "+bank.unleash_road.len()+" dbsize="+cStation.stationdatabase.len()+" savedb="+OneMonth,1,"main");
		DInfo("Restoring routes",0,"main");
		iter=0;
		local all_routes=bank.canBuild;
		for (local i=0; i < all_routes.len(); i++)
			{
			local obj=cRoute();
			obj.UID=all_routes[i];
			obj.sourceID=all_routes[i+1];
			obj.source_location=all_routes[i+2];
			obj.source_istown=all_routes[i+3];
			obj.targetID=all_routes[i+4];
			obj.target_location=all_routes[i+5];
			obj.target_istown=all_routes[i+6];
			obj.route_type=all_routes[i+7];
			obj.station_type=all_routes[i+8];
			obj.isWorking=all_routes[i+9];
			obj.status=all_routes[i+10];
			obj.groupID=all_routes[i+11];
			obj.source_stationID=all_routes[i+12];
			obj.target_stationID=all_routes[i+13];
			obj.cargoID=all_routes[i+14];
			i+=14;
			iter++;
			cRoute.database[obj.UID] <- obj;
			obj.RouteUpdate(); // re-enable the link to stations
			cRoute.GroupIndexer.AddItem(obj.groupID,obj.UID);
			if (obj.UID == 0)	cRoute.VirtualAirGroup[0]=obj.groupID;
			if (obj.UID == 1)	cRoute.VirtualAirGroup[1]=obj.groupID;
			}
		cRoute.RouteRebuildIndex();
		DInfo(iter+" routes found.",0,"main");
		DInfo("base size: "+bank.canBuild.len()+" dbsize="+cRoute.database.len()+" savedb="+OneWeek,2,"main");
		OneWeek=0;
		OneMonth=0;
		bank.canBuild=false;
		bank.unleash_road=false;
		DInfo("We are promoting "+AICargo.GetCargoLabel(cargo_favorite),0,"main");
		DInfo("Registering our routes",0,"main");
		foreach (item in cRoute.database)
			{
			local regjob=cJobs.GetJobObject(item.UID);
			if (regjob == null)	continue;
			regjob.isUse=true;
			INSTANCE.Sleep(1);
			}
		local stationList=AIList();	// check for no more working station if cargo disapears...
		stationList.AddList(AIStationList(AIStation.STATION_ANY));
		foreach (stationID, dummy in stationList)
			{
			cStation.CheckCargoHandleByStation(stationID);
			}
		INSTANCE.route.VirtualAirNetworkUpdate();
		}
	 else {
		AIInit();
		bank.SaveMoney();
		//use_boat=true;
		route.RouteInitNetwork();
		jobs.PopulateJobs();
		for (local i=0; i < 3; i++)	jobs.RawJobHandling();
		// feed the ai with some jobs to start play with
		safeStart=3;
		}
	bank.Update();
	print("AIBridge version IsBridgeTile"+cBridge.IsBridgeTile(0x6ac8));
	//print("cBridge version IsBridgeTile"+cBridge.IsBridgeTile(0x5ecb));
	print("speed="+cBridge.GetMaxSpeed(0x6ac8));
	//print("we hack isroad"+cBridge.IsRoadBridge(0x5ecc));
	//print("we hack israil"+cBridge.IsRailBridge(0x5ecc));
	//print("we hack bad"+cBridge.IsRailBridge(0x62ca));
	print("we hack nothing");
	NeedDelay(50);
	INSTANCE.builder.BridgeUpgrader();
	while(true)
		{
		this.CheckCurrentSettings();
		//if (use_train) builder.BaseStationRailBuilder(80835);
		DWarn("Running the AI in debug mode slowdown the AI and can do random issues !!!",1,"main");
		bank.CashFlow();
		this.ClearSignsALL();
		//builder.ShowStationCapacity();
		if (bank.canBuild)
				{
				if (builder.building_route == -1)	builder.building_route=jobs.GetNextJob();
				if (builder.building_route != -1)
					{
					//builder.DumpTopJobs();
					jobs_obj=cJobs.GetJobObject(builder.building_route);
					route=cRoute(); // reset it
					route.CreateNewRoute(builder.building_route);
					if (route == null)
						{ builder.building_route=-1; }
					else	{
						bank.RaiseFundsTo(jobs.moneyToBuild);
						builder.TryBuildThatRoute();
						this.checkHQ();
						}
					//DInfo(" ");
					// now jump to build stage
					}
				}
			//else { DInfo(" "); }
//		builder.TrainStationTesting();
		bank.CashFlow();
		eventManager.HandleEvents();
		builder.QuickTasks();
		//builder.ShowBlackList();
		AIController.Sleep(60);
		builder.WeeklyChecks();
		builder.MonthlyChecks();
		jobs.RawJobHandling();
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
DInfo("We are waiting: "+delay,2,"NeedDelay");
if (debug) ::AIController.Sleep(delay);
} 

function DictatorAI::Save()
{ // save
local table = 
	{
	routes = null,
	stations = null,
	cargo = null,
	busyroute=null,
	virtualgroup=null,
	dbstation=null,
	dbroute=null,
	}

DInfo("Saving game... "+cRoute.database.len()+" routes, "+cStation.stationdatabase.len()+" stations",0,"Save");
local all_stations=[];
local all_routes=[];
local temparray=[];

// routes
foreach (obj in cRoute.database)
	{
	all_routes.push(obj.UID);
	all_routes.push(obj.sourceID);
	all_routes.push(obj.source_location);
	all_routes.push(obj.source_istown);
	all_routes.push(obj.targetID);
	all_routes.push(obj.target_location);
	all_routes.push(obj.target_istown);
	all_routes.push(obj.route_type);
	all_routes.push(obj.station_type);
	all_routes.push(obj.isWorking);
	all_routes.push(obj.status);
	all_routes.push(obj.groupID);
	all_routes.push(obj.source_stationID);
	all_routes.push(obj.target_stationID);
	all_routes.push(obj.cargoID);
	}
// stations
foreach(obj in cStation.stationdatabase)
	{
	all_stations.push(obj.stationID);
	all_stations.push(obj.stationType);
	all_stations.push(obj.specialType);
	all_stations.push(obj.size);
	all_stations.push(obj.maxsize);
	all_stations.push(obj.depot);
	all_stations.push(obj.radius);
	temparray=ListToArray(obj.locations);
	all_stations.push(temparray.len());
	for (local z=0; z < temparray.len(); z++)	all_stations.push(temparray[z]);
	temparray=ListToArray(obj.owner);
	all_stations.push(temparray.len());
	for (local z=0; z < temparray.len(); z++)	all_stations.push(temparray[z]);
	}

table.cargo=cargo_favorite;
table.routes=all_routes;
table.stations=all_stations;
table.busyroute=builder.building_route;
table.virtualgroup=cRoute.VirtualAirGroup[0];
table.dbstation=cStation.stationdatabase.len();
table.dbroute=cRoute.database.len();
DInfo("Saving done...",0,"Save");
return table;
}
 
function DictatorAI::Load(version, data)
{
DInfo("Loading a saved game with DictatorAI. ",0,"Load");
if ("cargo" in data) cargo_favorite=data.cargo;
if ("routes" in data) bank.canBuild=data.routes;
if ("stations" in data) bank.unleash_road=data.stations;
if ("busyroute" in data) builder.building_route=data.busyroute;
if ("dbstation" in data) OneMonth=data.dbstation;
if ("dbroute" in data) OneWeek=data.dbroute;
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
		carrier.road_max_onroute=12;
		carrier.road_max=3;
		carrier.road_upgrade=10;
		carrier.rail_max=4;
		carrier.water_max=20;
		carrier.air_max=6;
		carrier.airnet_max=3;
	break;
	case 2: 
		carrier.road_max_onroute=20;	// upto 12 bus/truck per route
		carrier.road_max=6;		// upto a 6 size road station
		carrier.road_upgrade=10;	// upgarde road station every X vehicles. station can handle so a max that*road_max vehicle
		carrier.rail_max=12; 		// it's our highest train limit, can't build more than 12 trains per station
		carrier.water_max=60; 		// there's no real limit for boats
		carrier.air_max=8; 		// 8 aircrafts / route
		carrier.airnet_max=4;		// 4 aircrafts / airport in the air network, ie: 10 airports = 120 aircrafts
	break;
	}
local spdcheck=null;
if (AIGameSettings.IsValid("station_spread"))
	{
	spdcheck=AIGameSettings.GetValue("station_spread");
	if (spdcheck < carrier.rail_max)	carrier.rail_max=spdcheck;
	}
use_boat=false; // we will handle boats later
//use_train=false;
if (INSTANCE.safeStart >0)
	{ // Keep only road
	use_boat=false;
	use_train=false;
	use_air=false;
	}
//INSTANCE.safeStart=0;
//use_train=true;
//use_road=false;
//use_air=false;
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

