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
require("handler/vehiclehandler.nut");
require("utils/banker.nut");
require("utils/misc.nut");
require("handler/chemin.nut");
require("handler/array.nut");
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
	idleCounter=null;
	softStart=null;
	
	checker=null;	
	
	lastroute = null;
	loadedgame = null;
	buildingstage = null;
	inauguration = null;
	removelist = null;
	toremove = { vehtype = null,
		     stasrc = null,
		     stadst = null,
		     list = null};
   constructor()
   	{
	chemin=cChemin(this);
	minRank = 5000;		// ranking bellow that are drop jobs
	bank = cBanker(this);
	eventManager= cEvents(this);
	builder=cBuilder(this);
	carrier=cCarrier(this);

	loadedgame = false;
	idleCounter = 0;
	softStart = 0;
	checker=0;		// this one is use to set a monthly check for some operations
//	buildingstage = 0;
//	inauguration = 0;
	removelist = [];
	} 
 }
 
 
function DictatorAI::Start()
{

	DInfo("DicatorAI started.");
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	AICompany.SetAutoRenewStatus(false);
	bank.Update();
	if (loadedgame) 
		{
		chemin.RouteMaintenance();
		softStart=8;
		}
	 else 	{
		AIInit();
		chemin.RouteCreateALL();
		}
	while(true)
		{
		this.SetRailType();
		this.CheckCurrentSettings();
		if (use_train) builder.BaseStationRailBuilder(80835);
		DInfo("Running the AI in debug mode slowdown the AI !!!",1);
		if (softStart < 3) // set the game to use only road for 3 turns
			{
			softStart++;
			}
		bank.CashFlow();
		this.ClearSignsALL();
		if (this.HasWaitingTimePassed())
			{
			if (bank.canBuild)
					{
					chemin.ShowStationCapacity();
					chemin.nowRoute=chemin.StartingJobFinder();
					if (chemin.nowRoute>-1)
						{
						builder.TryBuildThatRoute(chemin.nowRoute);
						DInfo(" ");
						// now jump to build stage
						}
					}
				else { DInfo("Waiting for more cash..."); }
			}
		
		builder.TrainStationTesting();
		//chemin.RouteDelete(3);
		bank.CashFlow();
		eventManager.HandleEvents();
		//chemin.FewRouteDump();
		chemin.RouteMaintenance();
		chemin.DutyOnRoute();
		builder.QuickTasks();
		//if (debug) chemin.RListDumpALL();
		if (debug) chemin.RListStatus();
		AIController.Sleep(20);
		builder.MonthlyChecks();
		if (idleCounter > 5 && chemin.nowRoute >-1)
				{ idleCounter=0; chemin.nowRoute=-1; }
			else	{ idleCounter++; DInfo("Idle: "+idleCounter,2); }
		}
}

function DictatorAI::Stop()
{
}

function DictatorAI::NeedDelay(delay=30)
{
DInfo("We are waiting",2);
if (debug) AIController.Sleep(delay);
} 
 
function DictatorAI::Save()
{
//eventManager.GetEvents(); // Get latests events to save them
local table = 
	{
//	aa = null,
	cA = [],
	gA = null
	}

table.cA = chemin.RList;
table.gA = chemin.GList;
//table.eL = eventManager.eventList;
// can't save instance, and eventList is an array of instance
// should convert the array, but a boring list of convert functions to do that.
// let's just loose events for now
//table.gM=bank.gotMoney;
//table.aa="save test";
//DInfo("tableCA size="+table.cA.len());
return table;
}
 
function DictatorAI::Load(version, data)
{
	DInfo("Loading a saved game with DictatorAI. ");
	if ("cA" in data) chemin.RList=data.cA;
	if ("gA" in data) chemin.GList=data.cA;
/*	if ("cA" in data) 
		{ DInfo("Found cA !"+data.cA);
		for (local i=0; i < data.cA.len(); i++)	{ DInfo("i:"+i+" data:"+data.cA[i]); }
		}*/
	//if ("eL" in data) eventManager.eventList=data.eL;
//let's just loose events for now
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
		chemin.road_max=6;
		chemin.rail_max=1;
		chemin.water_max=2;
		chemin.air_max=6;
		chemin.airnet_max=3;
		chemin.road_max_onroute=4;
	break;
	case 1: 
		chemin.road_max=16;
		chemin.rail_max=4;
		chemin.water_max=20;
		chemin.air_max=10;
		chemin.airnet_max=6;
		chemin.road_max_onroute=6;
	break;
	case 2: 
		chemin.road_max=32; // upto 32 bus/truck per station
		chemin.road_max_onroute=10; // upto 10 bus/truck per route
		chemin.rail_max=12; // it's our highest train limit, can't build more than 12 trains per station
		chemin.water_max=60; // there's no real limit for boats
		chemin.air_max=16; // 16 aircrafts, hmmm, looks a bit high
		chemin.airnet_max=12; // 12 aircrafts / airport in the air network, ie: 10 airports = 120 aircrafts
	break;
	}

use_boat=false; // we will handle boats later
//use_air=false;
//use_train=false;
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

function DictatorAI::HasWaitingTimePassed()
{
	local date = AIDate.GetCurrentDate();
	// local waitingtime = AIController.GetSetting("waiting_time") + (AIDate.GetYear(date) - inauguration) * AIController.GetSetting("slowdown") * 4;
	//if (date - lastroute > waitingtime) return true; else return false;
	return true;
}

/*function DictatorAI::RemoveUnfinishedRoute()
{
	AILog.Info("Removing the unfinished route after loading...");
	if (toremove.vehtype == AIVehicle.VT_ROAD) {
		cBuilder.DeleteRoadStation(toremove.stasrc);
		cBuilder.DeleteRoadStation(toremove.stadst);
	} else {
		builder = cBuilder(this);
		builder.DeleteRailStation(toremove.stasrc);
		builder.DeleteRailStation(toremove.stadst);
		builder.RemoveRailLine(toremove.list[0]);
		builder.RemoveRailLine(toremove.list[1]);
		builder = null;
	}
}*/
