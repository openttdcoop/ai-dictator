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

import("pathfinder.road", "RoadPathFinder", 3);
import("pathfinder.rail", "RailPathFinder", 1);
require("build/builder.nut");
require("build/vehiclebuilder.nut");
require("handler/routes.nut");
require("handler/events.nut");
require("handler/checks.nut");
require("handler/cargo.nut");
require("handler/vehiclehandler.nut");
require("handler/stationhandler.nut");
require("handler/chemin.nut");
require("build/railbuilder.nut");
require("build/roadbuilder.nut");
require("build/airbuilder.nut");
require("build/stationbuilder.nut");
require("build/stationremover.nut");
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
	fairlevel = null;
	debug = null;
	builddelay=null;
	OneMonth=null;
	SixMonth=null;
	TwelveMonth=null;
	cargo_favorite=null;
	loadedgame = null;
	jobs = null;
	jobs_obj = null;
	route = null;
	buildTimer=null;

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
	fairlevel = 0;
	debug = false;
	builddelay=false;
	OneMonth=0;
	SixMonth=0;
	TwelveMonth=0;
	cargo_favorite=0;
	loadedgame = false;
	jobs = cJobs();
	jobs_obj = null;
	route = cRoute();
	buildTimer=0;
	} 
 }
 
 
function DictatorAI::Start()
{
	DInfo("DicatorAI started.");
	::INSTANCE <- this;
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	AICompany.SetAutoRenewStatus(false);
	CheckCurrentSettings();
	//bank.SaveMoney();
	if (loadedgame) 
		{
		DInfo("We are promoting "+AICargo.GetCargoLabel(cargo_favorite),0);
		DInfo("We have "+(cStation.database.len())+" stations",0);
		DInfo("We have "+(cRoute.database.len())+" routes running",0);
		DInfo(" ");
		jobs.PopulateJobs();
		}
	 else 	{
		AIInit();
		checkHQ();
		bank.SaveMoney();
		route.RouteInitNetwork();
		jobs.PopulateJobs();
		}
	bank.Update();
	while(true)
		{
		this.SetRailType();
		this.CheckCurrentSettings();
		if (use_train) builder.BaseStationRailBuilder(80835);
		DInfo("Running the AI in debug mode slowdown the AI !!!",1);
		bank.CashFlow();
		this.ClearSignsALL();
		//builder.ShowStationCapacity();
		if (bank.canBuild)
				{
				if (builder.building_route == -1)	builder.building_route=jobs.GetNextJob();
				if (builder.building_route != -1)
					{
					builder.DumpTopJobs();
					jobs_obj=cJobs.GetJobObject(builder.building_route);
					route=cRoute(); // reset it
					route.CreateNewRoute(builder.building_route);
					bank.RaiseFundsTo(jobs.moneyToBuild);
//DInfo("dump: "+jobs_obj.sourceID+" "+jobs_obj.targetID);
					builder.TryBuildThatRoute();
					//DInfo(" ");
					// now jump to build stage
					}
				}
			//else { DInfo(" "); }
		
		builder.TrainStationTesting();
		bank.CashFlow();
		eventManager.HandleEvents();
		route.DutyOnRoute();
		builder.QuickTasks();
		AIController.Sleep(10);
		builder.MonthlyChecks();
		}
}

function DictatorAI::Stop()
{
DInfo("DictatorAI is stopped");
ClearSignsALL();
}

function DictatorAI::NeedDelay(delay=30)
{
DInfo("We are waiting: "+delay,2);
if (debug) ::AIController.Sleep(delay);
} 
 
function DictatorAI::Save()
{ // hmmm, some devs might not like all those saved datas
local table = 
	{
	routes = null,
	stations = null,
	cargo = null,
	// virtual_air could be found easy
	vapass=null,
	vamail=null
	}

table.cargo=cargo_favorite;
return table;
}
 
function DictatorAI::Load(version, data)
{
	DInfo("Loading a saved game with DictatorAI. ");
/*	if ("routes" in data) carrier.RList=data.routes;
	if ("stations" in data) carrier.GList=data.stations;
	if ("vapass" in data) carrier.virtual_air_group_pass=data.vapass;
	if ("vamail" in data) carrier.virtual_air_group_mail=data.vamail;
	if ("cargo" in data) cargo_favorite=data.cargo;
*/
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
		AIController.Sleep(25);
		local name = null;
		name = AITown.GetName(centre);
		AILog.Info("Built company headquarters near " + name);
		break;
		}
	}	
}

function DictatorAI::SetRailType()
{
	local railtypes = AIRailTypeList();
	AIRail.SetCurrentRailType(railtypes.Begin());
}

function DictatorAI::CheckCurrentSettings()
{
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
	
local vehiclelist = AIVehicleList();
vehiclelist.Valuate(AIVehicle.GetVehicleType);
vehiclelist.KeepValue(AIVehicle.VT_ROAD);
if (vehiclelist.Count() + 5 > AIGameSettings.GetValue("vehicle.max_roadveh")) use_road = false;
vehiclelist = AIVehicleList();
vehiclelist.Valuate(AIVehicle.GetVehicleType);
vehiclelist.KeepValue(AIVehicle.VT_RAIL);
if (vehiclelist.Count() + 1 > AIGameSettings.GetValue("vehicle.max_trains")) use_train = false;
/*
TODO: find how the internal ttd name vehicle.max_boats vehicle.max_aircrafts
vehiclelist = AIVehicleList();
vehiclelist.Valuate(AIVehicle.GetVehicleType);
vehiclelist.KeepValue(AIVehicle.VT_RAIL);
if (vehiclelist.Count() + 1 > AIGameSettings.GetValue("vehicle.max_boats")) use_train = false;
vehiclelist = AIVehicleList();
vehiclelist.Valuate(AIVehicle.GetVehicleType);
vehiclelist.KeepValue(AIVehicle.VT_RAIL);
if (vehiclelist.Count() + 1 > AIGameSettings.GetValue("vehicle.max_aircrafts")) use_train = false;
*/

switch (fairlevel)
	{
	case 0: // easiest
		carrier.road_max_onroute=4;
		carrier.road_max=2;
		carrier.rail_max=1;
		carrier.water_max=2;
		carrier.air_max=4;
		carrier.airnet_max=4;
	break;
	case 1: 
		carrier.road_max_onroute=6;
		carrier.road_max=3;
		carrier.rail_max=4;
		carrier.water_max=20;
		carrier.air_max=6;
		carrier.airnet_max=6;
	break;
	case 2: 
		carrier.road_max_onroute=12;	// upto 12 bus/truck per route
		carrier.road_max=6;	// upto a 6 size road station
		carrier.rail_max=12; // it's our highest train limit, can't build more than 12 trains per station
		carrier.water_max=60; // there's no real limit for boats
		carrier.air_max=8; // 8 aircrafts / route
		carrier.airnet_max=12; // 12 aircrafts / airport in the air network, ie: 10 airports = 120 aircrafts
	break;
	}

use_boat=false; // we will handle boats later
//use_air=false;
use_train=false;
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

