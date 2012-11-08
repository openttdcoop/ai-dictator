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

function cRoute::RouteSetDistance()
// setup a route distance
	{
	local a, b= -1;
	if (this.source != null)	a=this.source_location;
	if (this.target != null)	b=this.target_location;
	if (this.source_stationID != null && AIStation.IsValidStation(source_stationID))	a=AIStation.GetLocation(source_stationID);
	if (this.target_stationID != null && AIStation.IsValidStation(target_stationID))	b=AIStation.GetLocation(target_stationID);
	if (a > -1 && b > -1)	this.distance=AITile.GetDistanceManhattanToTile(a,b);
				else	this.distance=0;
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
	if (road.UID > 1 && (!cBuilder.AirportAcceptBigPlanes(road.source_stationID) || !cBuilder.AirportAcceptBigPlanes(road.target_stationID)))	road.route_type+=4;
	// adding 4 to met small AIR or MAIL
	if (!road.source_istown)	road.route_type=RouteType.CHOPPER;
	if (oldtype != road.route_type)	{ DInfo("Changing aircraft type for route "+cRoute.RouteGetName(road.UID),1); }
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
	if (!this.isWorking)	return;
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

function cRoute::SetRouteGroupName(groupID, r_source, r_target, r_stown, r_ttown, r_cargo, isVirtual)
// This rename a group to a format we can read
	{
	if (!AIGroup.IsValidGroup(groupID))	return "invalid";
	local dummychar="A";
	local dummycount=65; // the ASCII A, as this is also A in unicode
	local st="I";
	if (r_stown)	st="T";
	local dt="I";
	if (r_ttown)	dt="T";
	if (r_source==null)	r_source="B";
	if (r_target==null)	r_target="B";
	local endname="*"+r_cargo+"*"+st+r_source+"*"+dt+r_target;
	if (isVirtual)	endname="-NETWORK "+AICargo.GetCargoLabel(r_cargo);
	dummychar=dummycount.tochar();
	local groupname=dummychar+endname;
	while (!AIGroup.SetName(groupID, groupname))
		{
		dummycount++;
		dummychar=dummycount.tochar();
		groupname=dummychar+endname;
		}
	}

function cRoute::RouteBuildGroup()
// Build a group for that route
	{
	local rtype=this.route_type;
	if (rtype >= RouteType.AIR)	rtype=RouteType.AIR;
	local gid = AIGroup.CreateGroup(rtype);
	if (!AIGroup.IsValidGroup(gid))	{ DError("Cannot create the group, this is serious error, please report it!",0); return; }
	this.groupID = gid;
	cRoute.SetRouteGroupName(this.groupID, this.sourceID, this.targetID, this.source_istown, this.target_istown, this.cargoID, false);
	if (this.groupID in cRoute.GroupIndexer)	cRoute.GroupIndexer.SetValue(this.groupID, this.UID);
							else	cRoute.GroupIndexer.AddItem(this.groupID, this.UID);
	}

function cRoute::RouteDone()
// called when a route is finish
	{
	this.vehicle_count=0;
	this.status=100;
	this.isWorking=true;
	this.RouteSave();
	if (this.source_istown)	cProcess.statueTown.AddItem(this.sourceID,0);
	if (this.target_istown)	cProcess.statueTown.AddItem(this.targetID,0);
	this.RouteAirportCheck();
	if (this.UID>1 && this.target_istown && this.route_type != RouteType.WATER && this.route_type != RouteType.RAIL && (this.cargoID==cCargo.GetPassengerCargo() || this.cargoID==cCargo.GetMailCargo()) )	cJobs.TargetTownSet(this.targetID);
	this.RouteCheckEntry();
	if (this.source_entry)
		{
		this.source.cargo_produce.AddItem(this.cargoID,0);
		this.source.cargo_accept.AddItem(this.cargoID,0); // that's not true, both next lines could be false, but CheckCangoHandleByStation will clean them if need
		}
	if (this.target_entry)
		{
		this.target.cargo_accept.AddItem(this.cargoID,0);
		this.target.cargo_produce.AddItem(this.cargoID,0);
		}
	this.RouteSetDistance();
	}

function cRoute::RouteSave()
// save that route to the database
	{
	if (this.UID in database)	DInfo("Route "+this.UID+" is already in database",2);
			else		{
					DInfo("Adding route "+this.UID+" to the route database",2);
					database[this.UID] <- this;
					RouteIndexer.AddItem(this.UID, 1);
					}
	this.RouteCheckEntry();
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
		name="Virtual Air Passenger Network for "+AICargo.GetCargoLabel(road.cargoID)+" using "+rtype;
		return name;
		}
	if (road.UID == 1)
		{
		name="Virtual Air Mail Network for "+AICargo.GetCargoLabel(road.cargoID)+" using "+rtype;
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
	local jobs=cJobs.Load(UID);
	if (!jobs) return; // workaround to loading savegame where the jobs has disapears
	jobs.isUse = true;
	this.UID = jobs.UID;
	this.sourceID = jobs.sourceObject.ID;
	this.source_istown = jobs.sourceObject.IsTown;
	if (this.source_istown)	cTileTools.SeduceTown(this.sourceID);
	this.targetID = jobs.targetObject.ID;
	this.target_istown = jobs.targetObject.IsTown;
	if (this.target_istown)	cTileTools.SeduceTown(this.targetID);
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
			DInfo("Airport work, choosen : "+randcargo+" "+cCargo.GetCargoLabel(this.cargoID),1);
		break;
		}
	this.isWorking = false;
	this.status = 0;
	this.source_location = jobs.sourceObject.Location;
	this.target_location = jobs.targetObject.Location;
	this.RouteSetDistance();
	this.RouteBuildGroup();
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
	mailRoute.distance=passRoute.distance;
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
	passRoute.route_type = RouteType.AIR;
	passRoute.station_type = AIStation.STATION_AIRPORT;
	passRoute.status=100;
	passRoute.vehicle_count=0;
	passRoute.RouteSetDistance(); // a dummy distance start value
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	passRoute.groupID=n;
	cRoute.SetRouteGroupName(passRoute.groupID, 0, 0, true, true, passRoute.cargoID, true);
	cRoute.VirtualAirGroup[0]=n;
	passRoute.groupID=n;
	passRoute.RouteSave();

	local mailRoute=cRoute();
	mailRoute.cargoID=cCargo.GetMailCargo();
	mailRoute.source_istown=true;
	mailRoute.target_istown=true;
	mailRoute.isWorking=true;
	mailRoute.UID=1;
	mailRoute.route_type = RouteType.AIR;
	mailRoute.station_type = AIStation.STATION_AIRPORT;
	mailRoute.status=100;
	mailRoute.vehicle_count=0;
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	mailRoute.groupID=n;
	cRoute.SetRouteGroupName(mailRoute.groupID, 1, 1, true, true, mailRoute.cargoID, true);
	cRoute.VirtualAirGroup[1]=n;
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
// When a route is dead, we remove it this way, in 2 steps, next step is RouteUndoableFreeOfVehicle()
	{
	if (this.UID < 2)	return; // don't touch virtual routes
	DInfo("Marking route "+cRoute.RouteGetName(this.UID)+" undoable !!!",1);
	cJobs.JobIsNotDoable(this.UID);
	this.isWorking=false;
	this.RouteCheckEntry();
	if (!INSTANCE.main.carrier.VehicleGroupSendToDepotAndSell(this.UID))	{ this.RouteUndoableFreeOfVehicle(); }
	}

function cRoute::RouteUndoableFreeOfVehicle()
// This is the last step of marking a route undoable
	{
	if (this.UID < 2)	return; // don't touch virtual routes
	local stasrc=this.source_stationID;
	local stadst=this.target_stationID;
	this.RouteReleaseStation(stasrc);
	this.RouteReleaseStation(stadst);
	INSTANCE.main.builder.DeleteStation(this.UID, stasrc);
	INSTANCE.main.builder.DeleteStation(this.UID, stadst);
	if (this.groupID != null)	{ AIGroup.DeleteGroup(this.groupID); cRoute.GroupIndexer.RemoveItem(this.groupID); }
	local uidsafe = this.UID;
	if (this.UID in cRoute.database)
		{
		DInfo("ROUTE -> Removing route "+this.UID+" from database",1);
		cRoute.RouteIndexer.RemoveItem(this.UID);
		cRoute.RouteDamage.RemoveItem(this.UID);
		delete cRoute.database[this.UID];
		}
	cJobs.DeleteJob(uidsafe);
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
		INSTANCE.main.builder.building_route=this.UID;
		}
	if (this.target_stationID == stationid)
		{
		local ssta=cStation.GetStationObject(this.target_stationID);
		if (ssta != null)	ssta.OwnerReleaseStation(this.UID);
		this.target_stationID = null;
		this.status=1;
		this.isWorking=false;
		INSTANCE.main.builder.building_route=this.UID;
		}
	this.RouteCheckEntry();
	if (INSTANCE.main.route.RouteDamage.HasItem(this.UID))	INSTANCE.main.route.RouteDamage.RemoveItem(this.UID);
	INSTANCE.builddelay=false; INSTANCE.main.bank.canBuild=true;
	}

function cRoute::GetDepot(uid, source=0)
// Return a valid depot we could use, this mean we will seek out both side of the route if we cannot find a proper one
// source: 0- Get any depot we could use, 1- Get source depot, 2- Get target depot
// per default return any valid depot we could found, if source=1 or 2 return an error if the query depot doesn't exist
// return -1 on errors
	{
	local road=cRoute.GetRouteObject(uid);
	if (road==null)	{ DError("Invalid uid : "+uid,2); return -1; }
	local sdepot=-1;
	local tdepot=-1;
	if (road.source != null && road.source instanceof cStation)	sdepot=road.source.depot;
	if (road.target != null && road.target instanceof cStation)	tdepot=road.target.depot;
	if (road.route_type == RouteType.RAIL)
		{
		local se, sx, de, dx=-1;
		if (road.source instanceof cStation)
			{
			se=sdepot;
			sx=road.source.locations.GetValue(15);
			}
		if (road.target instanceof cStation)
			{
			de=tdepot;
			dx=road.target.locations.GetValue(15);
			}
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
		if (source==0 || source==1)	if (cStation.IsDepot(sdepot))	return sdepot;
		if (source==0 || source==2)	if (cStation.IsDepot(tdepot))	return tdepot;
		if (road.route_type == RouteType.ROAD)	cBuilder.RouteIsDamage(uid);
		}
	if (source==0)	DError("Route "+cRoute.RouteGetName(road.UID)+" doesn't have any valid depot !",2);
			else	DError("Route "+cRoute.RouteGetName(road.UID)+" doesn't have the request depoted ! source="+source,2);
	return -1;
	}

function cRoute::AddTrain(uid, vehID)
// Add a train to that route, callback cTrain to inform it too
// uid : the route UID
// vehID: the train ID to add
	{
	local road=cRoute.GetRouteObject(uid);
	if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Invalid vehicleID: "+vehID,2); return -1; }
	if (road==null)	{ DError("Invalid uid : "+uid,2); return -1; }
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
	if (road==null)	{ DError("Invalid uid : "+uid,2); return -1; }
	local canAdd=true;
	DInfo("src="+road.source_RailEntry+" 2way="+road.twoway+" tgt="+road.target_RailEntry,1);
	canAdd=cBuilder.RailStationGrow(road.source_stationID, road.source_RailEntry, true);
	if (canAdd)	canAdd=cBuilder.RailStationGrow(road.target_stationID, road.target_RailEntry, false);
	return canAdd;
	}

function cRoute::DiscoverWorldTiles()
// look at the map and discover what we own, use after loading
{
	DInfo("Looking for our properties, game may get frozen for some times on huge maps, be patient",0);
	local allmap=AITileList();
	local maxTile=AIMap.GetTileIndex(AIMap.GetMapSizeX()-2, AIMap.GetMapSizeY()-2);
	INSTANCE.Sleep(1);
	allmap.AddRectangle(AIMap.GetTileIndex(1,1), maxTile);
	INSTANCE.Sleep(1);
	allmap.Valuate(AITile.GetOwner);
	INSTANCE.Sleep(1);
	local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
	allmap.KeepValue(weare);
	cRoute.WorldTiles.AddList(allmap);
}

