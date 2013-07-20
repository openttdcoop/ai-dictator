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

function cRoute::RouteAirportCheck(uid=null)
// this function check airports routes and setup some properties as they should be
	{
	local road=false;
	if (uid == null)	road=this;
			else	road=cRoute.Load(uid);
	if (!road || road.VehicleType < RouteType.AIR)	return;
	local oldtype = road.VehicleType;
	road.VehicleType = RouteType.AIR;
	if (road.UID < 2)	road.VehicleType = RouteType.AIRNET;
	if (road.CargoID == cCargo.GetMailCargo())	road.VehicleType++;
	local srcValid = (typeof(road.SourceStation) == "instance");
	local dstValid = (typeof(road.TargetStation) == "instance");
	if (road.UID > 1 && srcValid && dstValid && (!cBuilder.AirportAcceptBigPlanes(road.SourceStation.s_ID) || !cBuilder.AirportAcceptBigPlanes(road.TargetStation.s_ID)))	road.VehicleType+=4;
	// adding 4 to met small AIR or MAIL
	if (!road.SourceProcess.IsTown)	road.VehicleType = RouteType.CHOPPER;
	if (oldtype != road.VehicleType)	{ DInfo("Changing aircrafts type for route "+road.Name+" to "+cRoute.RouteTypeToString(road.VehicleType),1); road.SetRouteName(); }
	}

function cRoute::RouteUpdateVehicle()
// Recount vehicle at stations & route, update route stations
	{
	if (this.UID < 2)
		{
		local maillist=AIVehicleList_Group(this.GetVirtualAirMailGroup());
		local passlist=AIVehicleList_Group(this.GetVirtualAirPassengerGroup());
		this.VehicleCount=maillist.Count()+passlist.Count();
		return;
		}
	if (!this.Status == RouteStatus.WORKING)	return;
	this.SourceStation.s_VehicleCount = AIVehicleList_Station(this.SourceStation.s_ID).Count();
	this.SourceStation.UpdateCapacity();
	this.TargetStation.s_VehicleCount = AIVehicleList_Station(this.TargetStation.s_ID).Count();
	this.TargetStation.UpdateCapacity();
	local vehingroup = null;
	if (this.GroupID == null)	vehingroup = 0;
					else	vehingroup = AIVehicleList_Group(this.GroupID);
	this.VehicleCount=vehingroup.Count();
	}

function cRoute::SetRouteGroupName(groupID, r_source, r_target, r_stown, r_ttown, r_cargo, isVirtual, sourceStaID, targetStaID)
// This rename a group to a format we can read
	{
	if (groupID == null || !AIGroup.IsValidGroup(groupID))	return "invalid";
	local dummychar="A";
	local dummycount=65; // the ASCII A, as this is also A in unicode
	local st="I";
	if (r_stown)	st="T";
	local dt="I";
	if (r_ttown)	dt="T";
	if (r_source==null)	r_source="B";
	if (r_target==null)	r_target="B";
	local endname="*"+r_cargo+"*"+st+r_source+"*"+dt+r_target+"*"+sourceStaID+"*"+targetStaID;
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
	local rtype=this.VehicleType;
	if (rtype >= RouteType.AIR)	rtype=RouteType.AIR;
	local gid = AIGroup.CreateGroup(rtype);
	if (!AIGroup.IsValidGroup(gid))	{ DError("Cannot create the group, this is serious error, please report it!",0); return; }
	this.GroupID = gid;
	cRoute.SetRouteGroupName(this.GroupID, this.SourceProcess.ID, this.TargetProcess.ID, this.SourceProcess.IsTown, this.TargetProcess.IsTown, this.CargoID, false, this.SourceStation.s_ID, this.TargetStation.s_ID);
	if (this.GroupID in cRoute.GroupIndexer)	cRoute.GroupIndexer.SetValue(this.GroupID, this.UID);
							else	cRoute.GroupIndexer.AddItem(this.GroupID, this.UID);
	}

function cRoute::CreateNewRoute(UID)
// Create and add to database a new route with informations taken from cJobs
	{
	local jobs=cJobs.Load(UID);
	if (!jobs) return; // workaround to loading savegame where the jobs has disapears
	jobs.isUse = true;
	this.UID = jobs.UID;
	this.SourceProcess = jobs.sourceObject;
	this.TargetProcess = jobs.targetObject;
	this.VehicleType	= jobs.roadType;
	this.CargoID = jobs.cargoID;
	switch (this.VehicleType)
		{
		case	RouteType.RAIL:
			this.StationType=AIStation.STATION_TRAIN;
		break;
		case	RouteType.ROAD:
			this.StationType=AIStation.STATION_TRUCK_STOP;
			if (this.CargoID == cCargo.GetPassengerCargo())	this.StationType=AIStation.STATION_BUS_STOP;
		break;
		case	RouteType.WATER:
			this.StationType=AIStation.STATION_DOCK;
		break;
		case	RouteType.AIR:
			this.StationType=AIStation.STATION_AIRPORT;
			local randcargo=AIBase.RandRange(100);
			if (randcargo >60)	{ this.CargoID=cCargo.GetMailCargo(); this.VehicleType=RouteType.SMALLMAIL; }
						else	{ this.CargoID=cCargo.GetPassengerCargo(); this.VehicleType=RouteType.SMALLAIR; }
			if (!this.SourceProcess.IsTown)	{ this.CargoID=cCargo.GetPassengerCargo(); this.VehicleType=RouteType.CHOPPER; }
			DInfo("Airport work, choosen : "+randcargo+" "+cCargo.GetCargoLabel(this.CargoID),1);
		break;
		}
	this.Status = 0;
	this.RouteSetDistance();
	this.RouteSave();
	}

function cRoute::RouteRebuildIndex()
// Rebuild our routes index from our datase
	{
	cRoute.RouteIndexer.Clear();
	foreach (item in cRoute.database)
		{
		cRoute.RouteIndexer.AddItem(item.UID, 1);
		if (item.GroupID in cRoute.GroupIndexer)	cRoute.GroupIndexer.SetValue(item.GroupID, item.UID);
								else	if (item.GroupID != null)	cRoute.GroupIndexer.AddItem(item.GroupID, item.UID);
		}
	}

function cRoute::InRemoveList(uid)
// Add a route to route damage with dead status so it will get clear
{
	local road = cRoute.GetRouteObject(uid);
	if (road == null)	return;
	local good = (road.GroupID != null);
	if (good && AIGroup.IsValidGroup(road.GroupID) && !AIVehicleList_Group(road.GroupID).IsEmpty())	return;
	if (cRoute.RouteDamage.HasItem(uid))	cRoute.RouteDamage.RemoveItem(uid);
	cRoute.RouteDamage.AddItem(uid, RouteStatus.DEAD);
}

function cRoute::RouteIsNotDoable()
// When a route is dead, we remove it this way, in 2 steps, next step is RouteUndoableFreeOfVehicle()
	{
	if (this.UID < 2)	return; // don't touch virtual routes
	DInfo("Marking route "+cRoute.GetRouteName(this.UID)+" undoable !!!",1);
	cJobs.JobIsNotDoable(this.UID);
	this.Status = RouteStatus.DEAD;
	if (!INSTANCE.main.carrier.VehicleGroupSendToDepotAndSell(this.UID))	{ cRoute.InRemoveList(this.UID); }
	}

function cRoute::RouteUndoableFreeOfVehicle(uid)
// This is the last step of marking a route undoable
	{
	local route = cRoute.GetRouteObject(uid); // the Load function will return false has route is mark DEAD
	if (route != null)
		{
		if (route.UID < 2)	return; // don't touch virtual routes
		local stasrc = null;
		local stadst = null;
		if (cMisc.ValidInstance(route.SourceStation)) route.RouteReleaseStation(route.SourceStation.s_ID);
		if (cMisc.ValidInstance(route.TargetStation)) route.RouteReleaseStation(route.TargetStation.s_ID);
		cBuilder.DestroyStation(stasrc);
		cBuilder.DestroyStation(stadst);
		if (route.GroupID != null)	{ AIGroup.DeleteGroup(route.GroupID); cRoute.GroupIndexer.RemoveItem(route.GroupID); }
		if (route.UID in cRoute.database)
			{
			DInfo("BREAK ROUTE -> Removing route "+route.UID+" from database",1);
			cRoute.RouteIndexer.RemoveItem(route.UID);
			delete cRoute.database[route.UID];
			}
		}
	if (cRoute.RouteDamage.HasItem(uid))	cRoute.RouteDamage.RemoveItem(uid);
	}

function cRoute::CreateNewStation(start)
// Create a new station for that route at source or destination
// The stationID must be pass thru SourceStation or TargetStation property
// return null on failure, else the new station object created
	{
	local scheck = null;
	if (start)	scheck = cStation.InitNewStation(this.SourceStation);
		else	scheck = cStation.InitNewStation(this.TargetStation);
	if (scheck == null)	return null;
	this.RouteAirportCheck();
	return scheck;
	}

function cRoute::RouteReleaseStation(stationid)
// Release a station for our route and remove us from its owner list
	{
	if (stationid == null)	return ;
	local ss = (cMisc.ValidInstance(this.SourceStation));
	local sd = (cMisc.ValidInstance(this.TargetStation));

	if (ss && this.SourceStation.s_ID == stationid)
		{
		local ssta=cStation.Load(this.SourceStation.s_ID);
		if (ssta != false)	ssta.OwnerReleaseStation(this.UID);
		this.SourceStation = null;
		this.Status=RouteStatus.DEAD;
		}
	if (sd && this.TargetStation.s_ID == stationid)
		{
		local ssta=cStation.Load(this.TargetStation.s_ID);
		if (ssta != false)	ssta.OwnerReleaseStation(this.UID);
		this.TargetStation = null;
		this.Status=RouteStatus.DEAD;
		}
	if (INSTANCE.main.route.RouteDamage.HasItem(this.UID))	INSTANCE.main.route.RouteDamage.RemoveItem(this.UID);
	INSTANCE.buildDelay=0; INSTANCE.main.bank.canBuild=true;
	}

function cRoute::GetDepot(uid, source=0)
// Return a valid depot we could use, this mean we will seek out both side of the route if we cannot find a proper one
// source: 0- Get any depot we could use, 1- Get source depot, 2- Get target depot
// per default return any valid depot we could found, if source=1 or 2 return an error if the query depot doesn't exist
// return -1 on errors
	{
	local road=cRoute.Load(uid);
	if (!road)	return -1;
	local sdepot=-1;
	local tdepot=-1;
	if (typeof(road.SourceStation) == "instance")	sdepot=road.SourceStation.s_Depot;
	if (typeof(road.TargetStation) == "instance")	tdepot=road.TargetStation.s_Depot;
	if (road.VehicleType == RouteType.RAIL)
		{
		local se, sx, de, dx=-1;
		if (road.SourceStation instanceof cStationRail)
			{
			se=road.SourceStation.s_EntrySide[TrainSide.DEPOT];
			sx=road.SourceStation.s_ExitSide[TrainSide.DEPOT];
			}
		if (road.TargetStation instanceof cStation)
			{
			de=road.TargetStation.s_EntrySide[TrainSide.DEPOT];
			dx=road.TargetStation.s_ExitSide[TrainSide.DEPOT];
			}
		local one, two, three, four=null;
		if (road.Source_RailEntry)	{ one=se; three=sx; }
						else	{ one=sx; three=se; }
		if (road.Target_RailEntry)	{ two=de; four=dx; }
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
		if ((source==0 || source==1)	&& cStation.IsDepot(sdepot))	return sdepot;
		if ((source==0 || source==2)	&& cStation.IsDepot(tdepot))	return tdepot;
		if (road.VehicleType == RouteType.ROAD)	cBuilder.RouteIsDamage(uid);
		}
	if (source==0)	DError("Route "+cRoute.GetRouteName(road.UID)+" doesn't have any valid depot !",2);
			else	DError("Route "+cRoute.GetRouteName(road.UID)+" doesn't have the request depot ! source="+source,2);
	return -1;
	}

function cRoute::AddTrain(uid, vehID)
// Add a train to that route, callback cTrain to inform it too
// uid : the route UID
// vehID: the train ID to add
	{
	local road=cRoute.GetRouteObject(uid);
	if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Invalid vehicleID: "+vehID,2); return -1; }
	if (!road)	{ DError("Invalid uid : "+uid,2); return -1; }
	cTrain.TrainSetStation(vehID, road.SourceStation.s_ID, true, road.Source_RailEntry, true); // train load at station
	cTrain.TrainSetStation(vehID, road.TargetStation.s_ID, false, road.Target_RailEntry, road.Twoway); // if twoway train load at station, else it will only drop
	// hmmm, choices: a two way route == 2 taker that are also dropper train
	// we could then tell stations we have 2 taker == each train will have a platform
	// or 2 dropper == station will have just 1 platform and trains must wait on the line
	// for now i choose saying they are both taker
	road.SourceStation.StationAddTrain(true, road.Source_RailEntry);
	road.TargetStation.StationAddTrain(road.Twoway, road.Target_RailEntry);
	}

function cRoute::CanAddTrainToStation(uid)
// return true if we can add another train to that rail station
// return false when the station cannot handle it
	{
	local road=cRoute.GetRouteObject(uid);
	if (!road)	{ DError("Invalid uid : "+uid,2); return -1; }
	local canAdd=true;
	DInfo("src="+road.Source_RailEntry+" 2way="+road.Twoway+" tgt="+road.Target_RailEntry,1);
	canAdd=cBuilder.RailStationGrow(road.SourceStation.s_ID, road.Source_RailEntry, true);
	if (canAdd)	canAdd=cBuilder.RailStationGrow(road.TargetStation.s_ID, road.Target_RailEntry, false);
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

