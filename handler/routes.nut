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
static	RouteIndexer = AIList();	// list all UID of routes we are handling
static	GroupIndexer = AIList();	// map a group->UID, item=group, value=UID
static	RouteDamage = AIList(); 	// list of routes that need repairs
static	VirtualAirGroup = [];		// 0=mail & 1=passenger

static	function GetRouteObject(UID)
		{
		return UID in cRoute.database ? cRoute.database[UID] : null;
		}

	UID		= null; // UID for that route, 0/1 for airnetwork, else = the one calc in cJobs
	name		= "UNKNOWN";	// string with the route name
	sourceID	= null;	// id of source town/industry
	source_location	= null;	// location of source
	source_istown	= null;	// if source is town
	source		= null; // shortcut to the source station object
	targetID	= null;	// id of target town/industry
	target_location	= null;	// location of target
	target_istown	= null;	// if target is town
	target		= null; // shortcut to the target station object
	vehicle_count	= 0; // numbers of vehicle using it
	route_type	= null; // type of vehicle using that route (It's enum RouteType)
	station_type	= null; // type of station (it's AIStation.StationType)
	isWorking	= false; // true if the route is working
	status		= 0; // current status of the route
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

function cRoute::GetVirtualAirMailGroup()
// return the groupID for the mail virtual air group
	{
	return cRoute.VirtualAirGroup[0];
	}

function cRoute::GetVirtualAirPassengerGroup()
// return the groupID for the passenger virtual air group
	{
	return cRoute.VirtualAirGroup[0];
	}

function cRoute::CheckEntry()
// setup entries infos, this pointed our shortcut to the correct station object and mark them
	{
	this.source_entry = (this.source_stationID != null);
	this.target_entry = (this.target_stationID != null);
	if (this.source_entry)	this.source=cStation.GetStationObject(this.source_stationID);
			else	this.source=null;
	if (this.target_entry)	this.target=cStation.GetStationObject(this.target_stationID);
			else	this.target=null;
	}

function cRoute::RouteAddVehicle()
// Add a new vehicle to the route, update route stations with it too
	{
	this.vehicle_count++;
	if (this.source_entry)	this.source.vehicle_count++;
	if (this.target_entry)	this.target.vehicle_count++;
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
	GroupIndexer.AddItem(this.groupID, this.UID);
	}

function cRoute::RouteDone()
// called when a route is finish
	{
	this.RouteBuildGroup();
	this.vehicle_count=0;
	this.status=100;
	this.isWorking=true;
	this.RouteSave();
	}

function cRoute::RouteUpdate()
// when something change, update the route
	{
	this.CheckEntry();
	this.RouteGetName();
	DInfo("ROUTE -> Route "+name+" has been update",2);
	}

function cRoute::RouteSave()
// save that route to the database
	{
	this.RouteUpdate();
	DInfo("Saving a new route. "+this.name,0);
	if (this.UID in database)	DWarn("ROUTE -> Route "+this.UID+" is already in database",2);
			else		{
					DInfo("ROUTE -> Adding route "+this.UID+" to the route database",2);
					database[this.UID] <- this;
					RouteIndexer.AddItem(this.UID, 1);
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
	this.name="#"+this.UID+": From "+src+" to "+dst+" for "+AICargo.GetCargoLabel(cargoID)+" using "+rtype;
	}

function cRoute::CreateNewRoute(UID)
// Create and add to database a new route with informations taken from cJobs
	{
	local jobs=cJobs.GetJobObject(UID);
	jobs.isUse = true;
	this.UID = jobs.UID;
	this.sourceID = jobs.sourceID;
	this.source_istown = jobs.source_istown;
	this.targetID = jobs.targetID;
	this.target_istown = jobs.target_istown;
	this.vehicle_count = 0;
	this.route_type	= jobs.roadType;
	DInfo("ROUTE : JOBS report roadType: "+this.route_type);
	this.cargoID = jobs.cargoID;
	switch (this.route_type)
		{
		case	RouteType.RAIL:
			this.station_type=AIStation.STATION_TRAIN;
		break;
		case	RouteType.ROAD:
			this.station_type=AIStation.STATION_TRUCK_STOP;
			if (this.cargoID == cCargo.GetPassengerCargo())	this.station_type=AIStation.STATION_BUS_STOP;
		break;
		case	RouteType.WATER:
			this.station_type=AIStation.STATION_DOCK;
		break;
		case	RouteType.AIR:
			this.station_type=AIStation.STATION_AIRPORT;
		break;
		}
	DInfo("ROUTE : ROUTE report route_type: "+this.route_type+" station_type: "+this.station_type);
	this.isWorking = false;
	this.status = 0;
	if (source_istown)	source_location=AITown.GetLocation(sourceID);
			else	source_location=AIIndustry.GetLocation(sourceID);
	if (target_istown)	target_location=AITown.GetLocation(targetID);
			else	target_location=AIIndustry.GetLocation(targetID);
	this.CheckEntry();
	}

function cRoute::GetRouteDepot()
// Return a depot, try return source depot, if it fail backup to target depot
// Platform are the kind of route that can make source depot fail
	{
	if (this.source.depot != null)	return	this.source.depot;
				else	return	this.target.depot;
	}
function cRoute::RouteInitNetwork()
// Add the network routes to the database
	{
	local mailRoute=cRoute();
	mailRoute.cargoID=cCargo.GetMailCargo();
	mailRoute.source_entry=false;
	mailRoute.target_entry=false;
	mailRoute.isWorking=true;
	mailRoute.UID=0;
	mailRoute.route_type = RouteType.AIRNET;
	mailRoute.station_type = AIStation.STATION_AIRPORT;
	mailRoute.status=100;
	mailRoute.vehicle_count=0;
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	if (AIGroup.IsValidGroup(n))	this.groupID=n;
				else	DWarn("Cannot create group !",1);
	AIGroup.SetName(n, "Virtual Network Mail");
	VirtualAirGroup.push(n);
	mailRoute.RouteSave();

	local passRoute=cRoute();
	passRoute.cargoID=cCargo.GetPassengerCargo();
	passRoute.source_entry=false;
	passRoute.target_entry=false;
	passRoute.isWorking=true;
	passRoute.UID=1;
	passRoute.route_type = RouteType.AIRNET;
	passRoute.station_type = AIStation.STATION_AIRPORT;
	passRoute.status=100;
	passRoute.vehicle_count=0;
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	if (AIGroup.IsValidGroup(n))	this.groupID=n;
				else	DWarn("Cannot create group !",1);
	AIGroup.SetName(n, "Virtual Network Passenger");
	VirtualAirGroup.push(n);
	passRoute.RouteSave();
	}

function cRoute::RouteRebuildIndex()
// Rebuild our routes index from our datase
	{
	RouteIndexer.Clear();
	foreach (item in database)
		RouteIndex.AddItem(item, 1);	
	}

function cRoute::RouteIsNotDoable()
// When a route is dead, we remove it this way
	{
	if (this.vehicle_count > 0)	{ DWarn("Can't delete route still have "+this.vehicle_count+" running on it !",1); return false }
	cJobs.JobIsNotDoable(this.UID);
	if (this.groupID != null)	AIGroup.DeleteGroup(this.groupID);
	if (this.source_stationID != null)	cStation.DeleteStation(this.source_stationID);
	if (this.target_stationID != null)	cStation.DeleteStation(this.target_stationID);
	if (this.UID in database)
		{
		delete database[this.UID];
		RouteIndexer.RemoveItem(this.UID);
		}	
	}

function cRoute::CreateNewStation(start)
// Create a new station for that route at source or destination
	{
	local scheck=this.source_stationID;
	if (!start)	scheck=this.target_stationID;
	if (!AIStation.IsValidStation(scheck))
		{ DWarn("Adding a bad station #"+scheck+" to route #"+this.UID,1); }
	local station=cStation();
	station.stationID=scheck;
	station.InitNewStation();
	this.RouteUpdate();
	}
