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

class cRoute
	{
static	database = {};
static	RouteIndexer = AIList();	// list all UID of routes we are handling
static	GroupIndexer = AIList();	// map a group->UID, item=group, value=UID
static	RouteDamage = AIList(); 	// list of routes that need repairs
static	VirtualAirGroup = [-1,-1];		// 0=passenger & 1=mail groups for network

static	function GetRouteObject(UID)
		{
		if (UID in cRoute.database)	return cRoute.database[UID];
						else	{
							cRoute.RouteRebuildIndex();
							return null;
							}
		}

	UID			= null;	// UID for that route, 0/1 for airnetwork, else = the one calc in cJobs
	name			= null;	// string with the route name
	sourceID		= null;	// id of source town/industry
	source_location	= null;	// location of source
	source_istown	= null;	// if source is town
	source		= null;	// shortcut to the source station object
	targetID		= null;	// id of target town/industry
	target_location	= null;	// location of target
	target_istown	= null;	// if target is town
	target		= null;	// shortcut to the target station object
	vehicle_count	= null;	// numbers of vehicle using it
	route_type		= null;	// type of vehicle using that route (It's enum RouteType)
	station_type	= null;	// type of station (it's AIStation.StationType)
	isWorking		= null;	// true if the route is working
	status		= null;	// current status of the route
						// 0 - need a destination pickup
						// 1 - source/destination find compatible station or create new
						// 2 - need build source station
						// 3 - need build destination station
						// 4 - need do pathfinding
						// 5 - need checks
						// 100 - all done, finish route
	groupID		= null;	// groupid of the group for that route
	source_entry	= null;	// true if we have a working station
	source_stationID	= null;	// source station id
	target_entry	= null;	// true if we have a working station
	target_stationID	= null;	// target station id
	cargoID		= null;	// the cargo id
	date_VehicleDelete= null;	// date of last time we remove a vehicle
	date_lastCheck	= null;	// date of last time we check route health

	constructor()
		{
		UID			= null;
		name			= "UNKNOWN";
		sourceID		= null;
		source_location	= 0;
		source_istown	= false;
		source		= null;
		targetID		= null;
		target_location	= 0;
		target_istown	= false;
		target		= null;
		vehicle_count	= 0;
		route_type		= null;
		station_type	= null;
		isWorking		= false;
		status		= 0;
		groupID		= null;
		source_entry	= false;
		source_stationID	= null;
		target_entry	= false;
		target_stationID	= null;
		cargoID		= null;
		date_VehicleDelete= 0;
		date_lastCheck	= null;
		}
	}

function cRoute::GetVirtualAirMailGroup()
// return the groupID for the mail virtual air group
	{
	return cRoute.VirtualAirGroup[1];
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
	if (this.source_entry)	{ this.source=cStation.GetStationObject(this.source_stationID); this.source.ClaimOwner(this.UID); }
				else	this.source=null;
	if (this.target_entry)	{ this.target=cStation.GetStationObject(this.target_stationID); this.target.ClaimOwner(this.UID); }
				else	this.target=null;
	//DInfo("Route "+this.UID+" source="+this.source+" target="+this.target,1);
	}

function cRoute::RouteUpdateVehicle()
// Recount vehicle at stations & route, update route stations
	{
	if (this.route_type == RouteType.AIRNET)
		{
		local maillist=AIVehicleList_Group(this.GetVirtualAirMailGroup());
		local passlist=AIVehicleList_Group(this.GetVirtualAirPassengerGroup());
		this.vehicle_count=maillist.Count()+passlist.Count();
		return;
		}
	if (this.source_entry)	this.source.vehicle_count=AIVehicleList_Station(this.source.stationID).Count();
				else	this.source.vehicle_count=0;
	if (this.target_entry)	this.target.vehicle_count=AIVehicleList_Station(this.target.stationID).Count();
				else	this.target.vehicle_count=0;
	local vehingroup=AIVehicleList_Group(this.groupID);
	this.vehicle_count=vehingroup.Count();
	//DInfo("ROUTE -> "+this.vehicle_count+" vehicle on "+this.name,2);
	}

function cRoute::RouteBuildGroup()
// Build a group for that route
	{
	local rtype=this.route_type;
	if (this.route_type == RouteType.CHOPPER)	rtype=AIVehicle.VT_AIR;
	local gid = AIGroup.CreateGroup(rtype);
	if (!AIGroup.IsValidGroup(gid))	return;
	local st="I";
	if (this.source_istown)	st="T";
	local dt="I";
	if (this.target_istown)	dt="T";
	local groupname = AICargo.GetCargoLabel(this.cargoID)+"*"+st+this.sourceID+"*"+dt+this.targetID;
	if (groupname.len() > 29) groupname = groupname.slice(0, 28);
	this.groupID = gid;
	AIGroup.SetName(this.groupID, groupname);
	if (this.groupID in cRoute.GroupIndexer)	cRoute.GroupIndexer.SetValue(this.groupID, this.UID);
							else	cRoute.GroupIndexer.AddItem(this.groupID, this.UID);
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
		case	RouteType.CHOPPER:
			return "Choppers";
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
	this.isWorking = false;
	this.status = 0;
	if (source_istown)	source_location=AITown.GetLocation(sourceID);
			else	source_location=AIIndustry.GetLocation(sourceID);
	if (target_istown)	target_location=AITown.GetLocation(targetID);
			else	target_location=AIIndustry.GetLocation(targetID);
	this.CheckEntry();
	//this.RouteSave();
	}

function cRoute::GetRouteDepot()
// Return a depot, try return source depot, if it fail backup to target depot
// Platform are the kind of route that can make source depot fail
	{
	if (this.source_entry && this.source.depot != null)	return	this.source.depot;
	if (this.target_entry && this.target.depot != null)	return	this.target.depot;
	return null;
	}

function cRoute::VirtualMailCopy()
// this function copy infos from virtual passenger route to the mail one
	{
	local mailRoute=cRoute.GetRouteObject(1);
	local passRoute=cRoute.GetRouteObject(0);
	mailRoute.source_entry=passRoute.source_entry; // mailroute will follow passroute values
	mailRoute.target_entry=passRoute.target_entry;
	mailRoute.source_stationID=passRoute.source_stationID;
	mailRoute.target_stationID=passRoute.target_stationID;
	mailRoute.sourceID=passRoute.sourceID;
	mailRoute.targetID=passRoute.targetID;
	mailRoute.source=passRoute.source;
	mailRoute.target=passRoute.target;
	mailRoute.source_location=passRoute.source_location;
	mailRoute.target_location=passRoute.target_location;
	mailRoute.source_istown=passRoute.source_istown;
	mailRoute.target_istown=passRoute.target_istown;
	mailRoute.CheckEntry();
	}

function cRoute::RouteInitNetwork()
// Add the network routes to the database
	{
	local passRoute=cRoute();
	passRoute.cargoID=cCargo.GetPassengerCargo();
	passRoute.source_istown=true;
	passRoute.target_istown=true;
	passRoute.source_entry=false;
	passRoute.target_entry=false;
	passRoute.isWorking=true;
	passRoute.UID=0;
	passRoute.route_type = RouteType.AIRNET;
	passRoute.station_type = AIStation.STATION_AIRPORT;
	passRoute.status=100;
	passRoute.vehicle_count=0;
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	if (AIGroup.IsValidGroup(n))	this.groupID=n;
					else	DWarn("Cannot create group !",1);
	AIGroup.SetName(n, "Virtual Network Passenger");
	VirtualAirGroup[0]=n;
	passRoute.groupID=n;
	passRoute.RouteSave();

	local mailRoute=cRoute();
	mailRoute.cargoID=cCargo.GetMailCargo();
	mailRoute.source_istown=true;
	mailRoute.target_istown=true;
	mailRoute.isWorking=true;
	mailRoute.UID=1;
	mailRoute.route_type = RouteType.AIRNET;
	mailRoute.station_type = AIStation.STATION_AIRPORT;
	mailRoute.status=100;
	mailRoute.vehicle_count=0;
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	if (AIGroup.IsValidGroup(n))	this.groupID=n;
					else	DWarn("Cannot create group !",1);
	AIGroup.SetName(n, "Virtual Network Mail");
	VirtualAirGroup[1]=n;
	mailRoute.groupID=n;
	GroupIndexer.AddItem(cRoute.GetVirtualAirPassengerGroup(),0);
	GroupIndexer.AddItem(cRoute.GetVirtualAirMailGroup(),1);
	mailRoute.RouteSave();
	}

function cRoute::RouteRebuildIndex()
// Rebuild our routes index from our datase
	{
	cRoute.RouteIndexer.Clear();
	foreach (item in cRoute.database)
		cRoute.RouteIndexer.AddItem(item.UID, 1);	
	}

function cRoute::RouteIsNotDoable()
// When a route is dead, we remove it this way
	{
	if (this.UID < 2)	return; // don't touch virtual routes
	DInfo("Marking route "+this.name+" undoable !!!",1);
	cJobs.JobIsNotDoable(this.UID);
	this.CheckEntry();
	if (this.source_stationID != null)	
		{
		if (this.source != null)	if (this.source.owner.HasItem(this.UID))	this.source.owner.RemoveItem(this.UID);
		INSTANCE.builder.DeleteStation(this.UID, this.source_stationID);
		// Better just try to remove it and if fail don't care, might be re-use (or already re-use) anyway
		}
	if (this.target_stationID != null)	
		{
		if (this.target != null)	if (this.target.owner.HasItem(this.UID))	this.target.owner.RemoveItem(this.UID);
		INSTANCE.builder.DeleteStation(this.UID, this.target_stationID);
		}
	if (this.groupID != null)	AIGroup.DeleteGroup(this.groupID);
	local uidsafe = this.UID;
	if (this.UID in cRoute.database)
		{
		DInfo("ROUTE -> Removing route "+this.UID+" from database",1);
		cRoute.RouteIndexer.RemoveItem(this.UID);
		cRoute.RouteDamage.RemoveItem(this.UID);
		delete cRoute.database[this.UID];
		}
	cJobs.DeleteJob(uidsafe);
	INSTANCE.builder.building_route=-1;
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

function cRoute::RouteReleaseStation(stationid)
// Release a station for our route and remove us from its owner list
	{
	if (stationid == null)	return ;
	if (this.source_stationID == stationid)
		{
		local ssta=cStation.GetStationObject(this.source_stationID);
		ssta.OwnerReleaseStation(this.UID);
		this.source_stationID = null;
		this.status=1;
		this.isWorking=false;
		INSTANCE.builder.building_route=this.UID;
		}
	if (this.target_stationID == stationid)
		{
		local ssta=cStation.GetStationObject(this.target_stationID);
		ssta.OwnerReleaseStation(this.UID);
		this.target_stationID = null;
		this.status=1;
		this.isWorking=false;
		INSTANCE.builder.building_route=this.UID;
		}
	this.CheckEntry();
	if (INSTANCE.route.RouteDamage.HasItem(this.UID))	INSTANCE.route.RouteDamage.RemoveItem(this.UID);
	INSTANCE.builddelay=false; INSTANCE.bank.canBuild=true;
	}

