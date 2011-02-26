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


import("pathfinder.road", "RoadPathFinder", 3);
import("pathfinder.rail", "RailPathFinder", 1);
require("build/builder.nut");
require("build/railbuilder.nut");
require("build/roadbuilder.nut");
require("build/vehiclebuilder.nut");
require("build/airbuilder.nut");
require("build/stationbuilder.nut");
require("build/stationremover.nut");
require("handler/events.nut");
require("handler/checks.nut");
require("handler/cargo.nut");
require("handler/vehiclehandler.nut");
require("utils/banker.nut");
require("utils/misc.nut");
require("handler/chemin.nut");
require("handler/array.nut");
require("handler/jobs.nut");
require("utils/debug.nut");
require("utils/tile.nut");



 
class DictatorAI extends AIController
 {
	pathfinder = null;
	builder = null;
	manager = null;

	bank = null;
	chemin=null;
	minRank = null;
	eventManager = null;
	carrier=null;

	use_road = null;
	use_train = null;
	use_boat = null;
	use_air = null;
	fairlevel = null;
	debug = null;
	secureStart=null;
	builddelay=null;
	
	OneMonth=null;
	SixMonth=null;
	TwelveMonth=null;
	
	lastroute = null;
	loadedgame = null;

	jobs = null;
	jobs_obj = null;

   constructor()
   	{
	chemin=cChemin(this);
	minRank = 5000;		// ranking below that are drop jobs
	secureStart= 2;		// we secure # routes with road before allowing other transport, it's an anti-bankrupt option
	bank = cBanker(this);
	eventManager= cEvents(this);
	builder=cBuilder(this);
	carrier=cCarrier(this);
	builddelay=false;
	loadedgame = false;
	OneMonth=0;		// this one is use to set a monthly check for some operations
	SixMonth=0;		// same as OneMonth but every half year
	TwelveMonth=0;		// again for year
	jobs=cJobs();
	} 
 }
 
 
function DictatorAI::Start()
{
	DInfo("DicatorAI started.");
	::INSTANCE <- this;
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	AICompany.SetAutoRenewStatus(false);
	this.CheckCurrentSettings();
	bank.SaveMoney();

	//local dontcare=chemin.GetTransportDistance(AIVehicle.VT_ROAD,true); // don't care, just to have min&max distance set
	if (loadedgame) 
		{
		DInfo("We are promoting "+AICargo.GetCargoLabel(chemin.cargo_fav),0);
		DInfo("We have "+(chemin.GListGetSize()-1)+" stations",0);
		DInfo("We know "+(chemin.RListGetSize()-1)+" routes",0);
		DInfo(" ");
		chemin.RemapGroupsToRoutes();
		if (!chemin.map_group_to_route.Count.IsEmpty())	secureStart=0;
		chemin.RouteMaintenance();
		}
	 else 	{
		AIInit();
		//chemin.RouteCreateALL();
		}
	bank.Update();
	jobs.PopulateJobs();
	while(true)
		{
		local oneid=jobs.GetNextJob();
		local oneobj=jobs.GetJobObject(oneid);
		DInfo("Before: oneobj.moneyToBuild  = "+oneobj.moneyToBuild);
		oneobj.moneyToBuild=666;
		local twoobj=jobs.GetJobObject(oneid);
		DInfo("Before: oneobj.moneyToBuild  = "+oneobj.moneyToBuild+" twoobj.moneytobuild="+twoobj.moneyToBuild);
		this.SetRailType();
		this.CheckCurrentSettings();
		if (use_train) builder.BaseStationRailBuilder(80835);
		DInfo("Running the AI in debug mode slowdown the AI !!!",1);
		//bank.CashFlow();
		this.ClearSignsALL();
		chemin.ShowStationCapacity();
		if (bank.canBuild)
				{
				if (chemin.nowRoute==-1)	chemin.nowRoute=jobs.GetNextJob();
				if (chemin.nowRoute > -1)
					{
					jobs_obj=cJobs.GetJobObject(chemin.nowRoute);
					//local costsbuild=bank.GetConstructionsCosts(chemin.nowRoute);
					bank.RaiseFundsTo(jobs.moneyToBuild);
					DInfo("Route #"+chemin.nowRoute+" estimate costs to build : "+jobs_obj.moneyToBuild,1);
DInfo("dump: "+jobs_obj.sourceID+" "+jobs_obj.targetID);



					//if (builder.route_start >= 0)	{ costsbuild=-1000000; } // continue building the same route
					if (bank.CanBuyThat(jobs_obj.moneyToBuild))	builder.TryBuildThatRoute(chemin.nowRoute);
									else	{
										DInfo("Route is too expansive for us",1);
										jobs_obj.isdoable=false;
										}
					DInfo(" ");
					// now jump to build stage
					}
				}
			else { DInfo(" "); }
		
		builder.TrainStationTesting();
		bank.CashFlow();
		eventManager.HandleEvents();
		//chemin.FewRouteDump();
		chemin.global_malus+=(5*chemin.IDX_HELPER);
		chemin.DutyOnRoute();
		builder.QuickTasks();
		//if (debug) chemin.RListDumpALL();
		//if (debug) chemin.RListStatus();
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
if (debug) AIController.Sleep(delay);
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

table.routes = chemin.RList;
table.stations = chemin.GList;
table.cargo=chemin.cargo_fav;
table.vapass=chemin.virtual_air_group_pass;
table.vamail=chemin.virtual_air_group_mail;
return table;
}
 
function DictatorAI::Load(version, data)
{
	DInfo("Loading a saved game with DictatorAI. ");
	if ("routes" in data) chemin.RList=data.routes;
	if ("stations" in data) chemin.GList=data.stations;
	if ("vapass" in data) chemin.virtual_air_group_pass=data.vapass;
	if ("vamail" in data) chemin.virtual_air_group_mail=data.vamail;
	if ("cargo" in data) chemin.cargo_fav=data.cargo;
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
		chemin.road_max_onroute=4;
		chemin.rail_max=1;
		chemin.water_max=2;
		chemin.air_max=4;
		chemin.airnet_max=4;
	break;
	case 1: 
		chemin.road_max_onroute=6;
		chemin.rail_max=4;
		chemin.water_max=20;
		chemin.air_max=6;
		chemin.airnet_max=6;
	break;
	case 2: 
		chemin.road_max_onroute=12; // upto 12 bus/truck per route
		chemin.rail_max=12; // it's our highest train limit, can't build more than 12 trains per station
		chemin.water_max=60; // there's no real limit for boats
		chemin.air_max=8; // 8 aircrafts / route
		chemin.airnet_max=12; // 12 aircrafts / airport in the air network, ie: 10 airports = 120 aircrafts
	break;
	}
chemin.road_max=chemin.road_max_onroute*3;	// limit a station to be able to handle upto 3 full routes

use_boat=false; // we will handle boats later
//use_air=false;
//use_train=false;
if (!use_road)	secureStart=0; // sadly we can't use road vehicle, disabling secureStart so
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

