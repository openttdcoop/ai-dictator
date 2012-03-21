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
static	VirtualAirGroup = [-1,-1,0];	// [0]=networkpassenger groupID, [1]=networkmail groupID [2]=total capacity of aircrafts in network

static	function GetRouteObject(UID)
		{
		if (UID in cRoute.database)	return cRoute.database[UID];
						else	{
							cRoute.RouteRebuildIndex();
							return null;
							}
		}

	UID			= null;	// UID for that route, 0/1 for airnetwork, else = the one calc in cJobs
//	name			= null;	// string with the route name
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
	source_RailEntry	= null;	// if rail, do trains use that station entry=true, or exit=false
	target_RailEntry	= null;	// if rail, do trains use that station entry=true, or exit=false
	primary_RailLink	= null;	// true if we have build the main connecting rails from source to target station
	secondary_RailLink= null;	// true if we also buld the alternate path from source to target
	twoway		= null;	// if source station and target station accept but also produce, it's a twoway route

	constructor()
		{ // * are saved variables
		UID			= null;		// *
//		name			= "UNKNOWN";	
		sourceID		= null;		// *
		source_location	= 0;
		source_istown	= false;		// *
		source		= null;		
		targetID		= null;		// *
		target_location	= 0;
		target_istown	= false;		// *
		target		= null;
		vehicle_count	= 0;
		route_type		= null;		// *
		station_type	= null;		// *
		isWorking		= false;		// *
		status		= 0;			// *
		groupID		= null;		// *
		source_entry	= false;
		source_stationID	= null;		// *
		target_entry	= false;
		target_stationID	= null;		// *
		cargoID		= null;		// *
		date_VehicleDelete= 0;
		date_lastCheck	= null;
		source_RailEntry	= null;		// *
		target_RailEntry	= null;		// *
		primary_RailLink	= false;		// *
		secondary_RailLink= false;		// *
		twoway		= false;		// *
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

function cRoute::RouteCheckEntry()
// setup entries infos, this pointed our shortcut to the correct station object and mark them
	{
	this.source_entry = (this.source_stationID != null);
	this.target_entry = (this.target_stationID != null);
	if (this.source_entry)	
			{
			this.source=cStation.GetStationObject(this.source_stationID);
			if (this.source != null)	this.source.ClaimOwner(this.UID);
							else	this.source_entry=false;
			}
		else	this.source=null;
	if (this.target_entry)
			{
			this.target=cStation.GetStationObject(this.target_stationID);
			if (this.target != null)	this.target.ClaimOwner(this.UID);
							else	this.target_entry=false;
			}
		else	this.target=null;
	//DInfo("Route "+this.UID+" source="+this.source+" target="+this.target,1);
	if (this.route_type >= RouteType.AIR)	this.RouteAirportCheck();
	}

function cRoute::RouteAirportCheck(uid=null)
// this function check airports routes and setup some properties as they should be
	{
	local road=null;
	if (uid==null)	road=this;
			else	road=cRoute.GetRouteObject(uid);
	if (road==null || road.route_type < RouteType.AIR)	return;
	local oldtype=road.route_type;
	road.route_type=RouteType.AIR;
	if (road.UID < 2)	road.route_type=RouteType.AIRNET;
	if (road.cargoID == cCargo.GetMailCargo())	road.route_type++;
	if (road.UID > 1 && !cBuilder.AirportAcceptBigPlanes(road.source_stationID) || !cBuilder.AirportAcceptBigPlanes(road.target_stationID))	road.route_type+=4;
	// adding 4 to met small AIR or MAIL
	if (!road.source_istown)	road.route_type=RouteType.CHOPPER;
	if (oldtype != road.route_type)	{ DInfo("Changing aircraft type for route "+cRoute.RouteGetName(road.UID),1,"RouteAirportCheck"); }
	}

function cRoute::RouteUpdateVehicle()
// Recount vehicle at stations & route, update route stations
	{
	if (this.UID < 2)
		{
		local maillist=AIVehicleList_Group(this.GetVirtualAirMailGroup());
		local passlist=AIVehicleList_Group(this.GetVirtualAirPassengerGroup());
		this.vehicle_count=maillist.Count()+passlist.Count();
		return;
		}
	if (this.source_entry)	{ 
					this.source.vehicle_count=AIVehicleList_Station(this.source.stationID).Count();
					this.source.UpdateCapacity();
					}
				else	this.source.vehicle_count=0;
	if (this.target_entry)	{
					this.target.vehicle_count=AIVehicleList_Station(this.target.stationID).Count();
					this.target.UpdateCapacity();
					}
				else	this.target.vehicle_count=0;
	local vehingroup=null;
	if (this.groupID == null)	return;
	vehingroup=AIVehicleList_Group(this.groupID);
	this.vehicle_count=vehingroup.Count();
	}

function cRoute::RouteBuildGroup()
// Build a group for that route
	{
	local rtype=this.route_type;
	if (rtype >= RouteType.AIR)	rtype=RouteType.AIR;
	local gid = AIGroup.CreateGroup(rtype);
	if (!AIGroup.IsValidGroup(gid))	{ DError("Cannot create the group, this is serious error, please report it!",0,"cRoute::RouteBuildGroup()"); return; }
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
	this.source.cargo_produce.AddItem(this.cargoID,0);
	this.target.cargo_accept.AddItem(this.cargoID,0);
	this.source.cargo_accept.AddItem(this.cargoID,0); // that's not true, both next lines could be false, but CheckCangoHandleByStation will clean them if need
	this.target.cargo_produce.AddItem(this.cargoID,0);
	this.RouteSave();
	if (this.source_istown)	cJobs.statueTown.AddItem(this.sourceID,0);
	if (this.target_istown)	cJobs.statueTown.AddItem(this.targetID,0);
	this.RouteAirportCheck();
	if (this.UID>1 && this.target_istown && this.route_type != RouteType.WATER && this.route_type != RouteType.RAIL && (this.cargoID==cCargo.GetPassengerCargo() || this.cargoID==cCargo.GetMailCargo()) )	cJobs.TargetTownSet(this.targetID);
	this.RouteCheckEntry();
	}

function cRoute::RouteSave()
// save that route to the database
	{
	this.RouteCheckEntry();
	if (this.UID in database)	DInfo("ROUTE -> Route "+this.UID+" is already in database",2,"cRoute::RouteSave");
			else		{
					DInfo("ROUTE -> Adding route "+this.UID+" to the route database",2,"cRoute::RouteSave");
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
		case	RouteType.WATER:
			return "Boats";
		case	RouteType.AIR:
		case	RouteType.AIRMAIL:
		case	RouteType.AIRNET:
		case	RouteType.AIRNETMAIL:
			return "Big Aircrafts";
		case	RouteType.SMALLAIR:
		case	RouteType.SMALLMAIL:
			return "Small Aircrafts";
		case	RouteType.CHOPPER:
			return "Choppers";
		}
	return "unkown";
	}

function cRoute::RouteGetName(uid)
// set a string for that route
	{
	local src=null;
	local dst=null;
	local name="#"+uid+" invalid route";
	local road=cRoute.GetRouteObject(uid);
	if (road == null)	return name;
	local rtype=cRoute.RouteTypeToString(road.route_type);
	if (road.UID == 0) // ignore virtual route, use by old savegame
		{
		name="Virtual Air Passenger Network for "+AICargo.GetCargoLabel(cargoID)+" using "+rtype;
		return name;
		}
	if (road.UID == 1)
		{
		name="Virtual Air Mail Network for "+AICargo.GetCargoLabel(cargoID)+" using "+rtype;
		return name;
		}
	if (road.source_entry)	src=cStation.StationGetName(road.source_stationID);
				else	{
					if (road.source_istown)	src=AITown.GetName(road.sourceID);
								else	src=AIIndustry.GetName(road.sourceID);
					}
	if (road.target_entry)	dst=cStation.StationGetName(road.target_stationID);
				else	{
					if (road.target_istown)	dst=AITown.GetName(road.targetID);
								else	dst=AIIndustry.GetName(road.targetID);
					}
	name="#"+road.UID+": From "+src+" to "+dst+" for "+AICargo.GetCargoLabel(road.cargoID)+" using "+rtype;
	return name;
	}

function cRoute::CreateNewRoute(UID)
// Create and add to database a new route with informations taken from cJobs
	{
	local jobs=cJobs.GetJobObject(UID);
	if (jobs == null) return; // workaround to loading savegame where the jobs has disapears
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
			local randcargo=AIBase.RandRange(100);
			if (randcargo >70)	{ this.cargoID=cCargo.GetMailCargo(); this.route_type=RouteType.SMALLMAIL; }
						else	{ this.cargoID=cCargo.GetPassengerCargo(); this.route_type=RouteType.SMALLAIR; }
			DInfo("Airport work, choosen : "+randcargo+" "+AICargo.GetCargoLabel(this.cargoID),1,"CreateNewRoute");
		break;
		}
	this.isWorking = false;
	this.status = 0;
	if (this.source_istown)	source_location=AITown.GetLocation(this.sourceID);
				else	source_location=AIIndustry.GetLocation(this.sourceID);
	if (this.target_istown)	target_location=AITown.GetLocation(this.targetID);
				else	target_location=AIIndustry.GetLocation(this.targetID);
	this.RouteSave();
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
	mailRoute.RouteCheckEntry();
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
	mailRoute.route_type = RouteType.AIRNETMAIL;
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
	DInfo("Marking route "+cRoute.RouteGetName(this.UID)+" undoable !!!",1,"RouteIsNotDoable");
	cJobs.JobIsNotDoable(this.UID);
	local stasrc=this.source_stationID;
	local stadst=this.target_stationID;
	this.RouteCheckEntry();
	INSTANCE.carrier.VehicleGroupSendToDepotAndSell(this.UID);
	this.RouteReleaseStation(stasrc);
	this.RouteReleaseStation(stadst);
	INSTANCE.builder.DeleteStation(this.UID, stasrc);
	INSTANCE.builder.DeleteStation(this.UID, stadst);
	if (this.groupID != null)	AIGroup.DeleteGroup(this.groupID);
	local uidsafe = this.UID;
	if (this.UID in cRoute.database)
		{
		DInfo("ROUTE -> Removing route "+this.UID+" from database",1,"RouteIsNotDoable");
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
		{ DWarn("Adding a bad station #"+scheck+" to route #"+this.UID,1,"cRoute::CreateNewStation"); }
	local station=cStation();
	station.stationID=scheck;
	station.InitNewStation();
	this.RouteCheckEntry();
	this.RouteAirportCheck();
	}

function cRoute::RouteReleaseStation(stationid)
// Release a station for our route and remove us from its owner list
	{
	if (stationid == null)	return ;
	if (this.source_stationID == stationid)
		{
		local ssta=cStation.GetStationObject(this.source_stationID);
		if (ssta != null)	ssta.OwnerReleaseStation(this.UID);
		this.source_stationID = null;
		this.status=1;
		this.isWorking=false;
		INSTANCE.builder.building_route=this.UID;
		}
	if (this.target_stationID == stationid)
		{
		local ssta=cStation.GetStationObject(this.target_stationID);
		if (ssta != null)	ssta.OwnerReleaseStation(this.UID);
		this.target_stationID = null;
		this.status=1;
		this.isWorking=false;
		INSTANCE.builder.building_route=this.UID;
		}
	this.RouteCheckEntry();
	if (INSTANCE.route.RouteDamage.HasItem(this.UID))	INSTANCE.route.RouteDamage.RemoveItem(this.UID);
	INSTANCE.builddelay=false; INSTANCE.bank.canBuild=true;
	}

function cRoute::GetDepot(uid, source=0)
// Return a valid depot we could use, this mean we will seek out both side of the route if we cannot find a proper one
// source: 0- Get any depot we could use, 1- Get source depot, 2- Get target depot
// per default return any valid depot we could found, if source=1 or 2 return an error if the query depot doesn't exist
// return -1 on errors
	{
	local road=cRoute.GetRouteObject(uid);
	if (road==null)	{ DError("Invalid uid : "+uid,2,"cRoute::GetDepot"); return -1; }
	if (road.route_type == RouteType.RAIL)
		{
		local se=road.source.depot;
		local sx=road.source.locations.GetValue(15);
		local de=road.target.depot;
		local dx=road.target.locations.GetValue(15);
		local one, two, three, four=null;
		if (road.source_RailEntry)	{ one=se; three=sx; }
						else	{ one=sx; three=se; }
		if (road.target_RailEntry)	{ two=de; four=dx; }
						else	{ two=dx; four=de; }
		if (source==0 || source==1)
			{
			if (cStation.IsDepot(one))	return one;
			if (cStation.IsDepot(three))	return three;
			}
		if (source==0 || source==2)
			{
			if (cStation.IsDepot(two))	return two;
			if (cStation.IsDepot(four))	return four;
			}
		}
	else	{
		if (source==0 || source==1)	if (cStation.IsDepot(road.source.depot))	return road.source.depot;
		if (source==0 || source==2)	if (cStation.IsDepot(road.target.depot))	return road.target.depot;
		if (road.route_type == RouteType.ROAD)	cBuilder.RouteIsDamage(uid);
		}
	if (source==0)	DError("Route "+cRoute.RouteGetName(road.UID)+" doesn't have any valid depot !",2,"cRoute::GetDepot");
			else	DError("Route "+cRoute.RouteGetName(road.UID)+" doesn't have the request depot ! source="+source,2,"cRoute::GetDepot");
	return -1;
	}

function cRoute::AddTrain(uid, vehID)
// Add a train to that route, callback cTrain to inform it too
// uid : the route UID
// vehID: the train ID to add
	{
	local road=cRoute.GetRouteObject(uid);
	if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Invalid vehicleID: "+vehID,2,"cRoute::AddTrain"); return -1; }
	if (road==null)	{ DError("Invalid uid : "+uid,2,"cRoute::AddTrain"); return -1; }
	cTrain.TrainSetStation(vehID, road.source_stationID, true, road.source_RailEntry, true); // train load at station
	cTrain.TrainSetStation(vehID, road.target_stationID, false, road.target_RailEntry, road.twoway); // if twoway train load at station, else if will only drop
	// hmmm, choices: a two way route == 2 taker that are also dropper train
	// we could then tell stations we have 2 taker == each train will have a platform
	// or 2 dropper == station will have just 1 platform and trains must wait on the line
	// for now i choose saying they are both taker
	road.source.StationAddTrain(true, road.source_RailEntry);
	road.target.StationAddTrain(road.twoway, road.target_RailEntry);
	}

function cRoute::CanAddTrainToStation(uid)
// return true if we can add another train to that rail station
// return false when the station cannot handle it
	{
	local road=cRoute.GetRouteObject(uid);
	if (road==null)	{ DError("Invalid uid : "+uid,2,"cRoute::CanAddTrainToStation"); return -1; }
cBuilder.DumpRoute(uid);
	local canAdd=true;
	DInfo("src="+road.source_RailEntry+" 2way="+road.twoway+" tgt="+road.target_RailEntry,1,"cRoute::CanAddTrainToStation"); INSTANCE.NeedDelay(100);
	canAdd=cBuilder.RailStationGrow(road.source_stationID, road.source_RailEntry, true);
	if (canAdd)	canAdd=cBuilder.RailStationGrow(road.target_stationID, road.target_RailEntry, false);
	return canAdd;
	}
