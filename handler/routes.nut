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

class cRoute
	{
static	database = {};
static	RouteIndexer = AIList(); // list all uniqID of routes we are handling
static	function GetRouteObject(uniqID)
		{
		return uniqID in cRoute.database ? cRoute.database[uniqID] : null;
		}

	uniqID		= null; // uniqID for that route, 0/1 for airnetwork, else = the one calc in cJobs
	name		= null;	// string with the route name
	sourceID	= null;	// id of source town/industry
	source_istown	= null;	// if source is town
	source		= null; // shortcut to the source station object
	targetID	= null;	// id of target town/industry
	target_istown	= null;	// if target is town
	target		= null; // shortcut to the target station object
	vehicle_count	= null; // numbers of vehicle using it
	route_type	= null; // type of vehicle using that route (It's enum RouteType)
	isWorking	= null; // true if the route is working
	status		= null; // current status of the route
				// 0 - need a destination pickup
				// 1 - source/destination find compatible station or create new
				// 2 - need build source station
				// 3 - need build destination station
				// 4 - need do pathfinding
				// 5 - need checks
				// 100 - all done, finish route
//	distance	= null; // distance from source station -> target station
	groupID		= null; // groupid of the group for that route
	source_entry	= null;	// true if we have a working station
	source_stationID= null; // source station id
	target_entry	= null;	// true if we have a working station
	target_stationID= null;	// target station id
	cargoID		= null;	// the cargo id
	date_VehicleDel	= null;	// date of last time we remove a vehicle
	date_lastCheck	= null;	// date of last time we check route health
	}

function cRoute::CheckEntry()
// setup entries infos
	{
	this.source_entry = (source_stationID != null);
	this.target_entry = (target_stationID != null);
	if (this.source_entry)	source=cStation.GetObject(this.source_stationID);
			else	source=null;
	if (this.target_entry)	target=cStation.GetObject(this.target_stationID);
			else	target=null;
	}

function cRoute::RouteBuildGroup()
// Build a group for that route
	{
	local gid = AIGroup.CreateGroup(this.route_type);
	if (!AIGroup.IsValidGroup(gid))	return;
	local groupname = AICargo.GetCargoLabel(this.cargoID)+"*"+this.sourceID+"*"+this.targetID;
	if (groupname.len() > 29) groupname = groupname.slice(0, 28);
	this.groupID = gid;
	AIGroup.SetName(this.groupID, groupname);
	}

function cRoute::RouteSave()
// save that route to the database
	{
	this.RouteGetName();
	DInfo("Init a new route. "+this.name,0);
	if (this.uniqID in database)	DWarn("ROUTE -> Route "+this.uniqID+" is already in database",2);
			else		{
					DInfo("ROUTE -> Adding route "+this.uniqID+" to the route database",2);
					database[this.uniqID] <- this;
					RouteIndexer.AddItem(this.uniqID, 1);
					}
	}

function cRoute::RouteTypeToString(that_type)
// return a string for that_type road type
	{
	switch (that_type)
		{
		case	RouteType.RAIL:
			return "Trains";
		case	RouteType.ROAD:
			return "Bus & Trucks";
		case	RouteType.AIR:
			return "Aircrafts";
		case	RouteType.WATER:
			return "Boats";
		case	RouteType.AIRNET:
			return "Aircrafts";
		}
	}

function cRoute::RouteGetName()
// set a string for that route
	{
	local src=null;
	local dst=null;
	local toret=null;
	local rtype=RouteTypeToString(this.route_type);
	if (this.route_type == RouteType.AIRNET)
		{
		this.name="Virtual Air Network for "+AICargo.GetCargoLabel(cargoID)+" using "+rtype;
		return;
		}
	if (source_entry)	src=AIStation.GetName(source_stationID);
			else	{
				if (source_istown)	src=AITown.GetName(sourceID);
						else	src=AIIndustry.GetName(sourceID);
				}
	if (target_entry)	dst=AIStation.GetName(target_stationID);
			else	{
				if (source_istown)	src=AITown.GetName(sourceID);
						else	src=AIIndustry.GetName(sourceID);
				}
	this.name="From "+src+" to "+dst+" for "+AICargo.GetLabel(cargoID)+" using "+rtype;
	}

function cRoute::CreateNewRoute(uniqID)
// Create and add to database a new route with informations taken from cJobs
	{
	local jobs=cJobs.GetJobObject(uniqID);
	DInfo("jobs="+jobs+" uniqID="+uniqID);
	jobs.isUse = true;
	this.uniqID = jobs.uniqID;
	this.sourceID = jobs.sourceID;
	this.source_istown = jobs.source_istown;
	this.targetID = jobs.targetID;
	this.target_istown = jobs.target_istown;
	this.vehicle_count = 0;
	this.route_type	= jobs.roadType;
	this.isWorking = false;
	this.status = 0;
	this.cargoID = jobs.cargoID;
	this.CheckEntry();
	//this.RouteSave();
	}

function cRoute::RouteInitNetwork()
// Add the network routes to the database
	{
	local mailRoute=cRoute();
	mailRoute.cargoID=cCargo.GetMailCargo();
	mailRoute.source_entry=false;
	mailRoute.target_entry=false;
	mailRoute.isWorking=true;
	mailRoute.uniqID=0;
	mailRoute.route_type = RouteType.AIRNET;
	mailRoute.status=100;
	mailRoute.vehicle_count=0;
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	if (AIGroup.IsValidGroup(n))	this.groupID=n;
				else	DWarn("Cannot create group !",1);
	AIGroup.SetName(n, "Virtual Network Mail");
	mailRoute.RouteSave();

	local passRoute=cRoute();
	passRoute.cargoID=cCargo.GetPassengerCargo();
	passRoute.source_entry=false;
	passRoute.target_entry=false;
	passRoute.isWorking=true;
	passRoute.uniqID=1;
	passRoute.route_type = RouteType.AIRNET;
	passRoute.status=100;
	passRoute.vehicle_count=0;
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	if (AIGroup.IsValidGroup(n))	this.groupID=n;
				else	DWarn("Cannot create group !",1);
	AIGroup.SetName(n, "Virtual Network Passenger");
	passRoute.RouteSave();
	}

function cRoute::RouteRebuildIndex()
// Rebuild our routes index from our datase
	{
	RouteIndexer.Clear();
	foreach (item in database)
		RouteIndex.AddItem(item, 1);	
	}
