/* -*- Mode: C++; tab-width: 4 -*- */
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

class cRoute extends cClass
	{
		static	database = {};
		static	RouteIndexer = AIList();	// list all UID of routes we are handling, item=UID, value=GroupID
		static	GroupIndexer = AIList();	// map a group->UID, item=GroupID, value=UID
		static	RouteDamage = AIList(); 	// list of routes that need repairs
		static	VirtualAirGroup = [-1,-1,0];// [0]=networkpassenger groupID, [1]=networkmail groupID [2]=total capacity of aircrafts in network

		UID			        = null;	// UID for that route, 0/1 for airnetwork, else = the one calc in cJobs
		Name			    = null;	// Name of the route
		SourceProcess	    = null;	// link to source process
		TargetProcess	    = null;	// link to target process
		SourceStation	    = null;	// link to source station
		TargetStation   	= null;	// link to target station
		VehicleCount    	= null;	// numbers of vehicle using it
		VehicleType		    = null;	// type of vehicle using that route (It's enum RouteType)
		StationType	    	= null;	// type of station (it's AIStation.StationType)
		Distance    		= null;	// farest distance from source station to target station
		Status	    	    = null;	// current status of the route, see main.RouteStatus enum
		GroupID		        = null;	// groupid of the group for that route
		CargoID	        	= null;	// the cargo id
		DateVehicleDelete   = null;	// date of last time we remove a vehicle
		DateHealthCheck	    = null;	// date of last time we check route health
		Source_RailEntry	= null;	// * if rail, do trains use that station entry=true, or exit=false
		Target_RailEntry	= null;	// * if rail, do trains use that station entry=true, or exit=false
		Primary_RailLink	= null;	// * true if we have build the main connecting rails from source to target station
		Secondary_RailLink  = null;	// * true if we also build the alternate path from source to target
        RailType		    = null;	// type of rails in use, same as the first working station done
		Twoway		        = null;	// if source station and target station accept but also produce, it's a twoway route

		// the state of * are store within the group name to help loading game
		constructor()
			{
			// * are saved variables
			UID		        	= null;
			Name		    	= "UNKNOWN route";
			SourceProcess   	= null;
			TargetProcess   	= null;
			SourceStation   	= null;
			TargetStation	    = null;
			VehicleCount	    = 0;
			VehicleType		    = null;		// *
			StationType		    = null;
			RailType		    = -1;
			Distance	    	= 0;
			Status		        = 0;
			GroupID	        	= null;		// *
			CargoID	        	= null;
			DateVehicleDelete   = 0;
			DateHealthCheck 	= 0;
			Source_RailEntry	= null;
			Target_RailEntry	= null;
			Primary_RailLink	= false;
			Secondary_RailLink  = false;
			Twoway	        	= false;
			this.ClassName      = "cRoute";
			}

		function GetRouteObject(UID)
			{
			if (UID in cRoute.database)	{ return cRoute.database[UID]; }
                                else	{ return null; }
			}
		function IsValidRoute(routeobj);
		function LoadRoute(uid, force = false);
		function RouteTypeToString(that_type);
		function GetRouteName(uid);
		function SetRouteName();
		function RouteSave();
		function RouteDone();
		function RouteInitNetwork();
		function GetVirtualAirMailGroup();
		function GetVirtualAirPassengerGroup();
		function RouteSetDistance();
		function RouteChangeStation(uid, o_Object, n_Object);
		function RouteClaimsTiles(uid = null);
		function CheckRouteProfit(uid);
		function RouteAirportCheck(uid = null);
		function RouteUpdateVehicle(routeobj);
		function SetRouteGroupName(groupID, r_source, r_target, r_stown, r_ttown, r_cargo, isVirtual, sourceStaID, targetStaID);
		function Route_GroupNameSave();
		function RouteBuildGroup();
		function CreateNewRoute(UID);
		function RouteRebuildIndex();
		function InRemoveList(uid);
		function RouteIsNotDoable();
		function RouteRailGetPathfindingLine(uid, mainline)	{ deprecated(); }
		function RouteUndoableFreeOfVehicle(uid);
		function CreateNewStation(start)RouteReleaseStation(stationid);
		function GetDepot(uid, source=0);
		function CanAddTrainToStation(uid);
		function DiscoverWorldTiles();
	}

function cRoute::IsValidRoute(routeobj)
{
	if (!cMisc.ValidInstance(routeobj) || !(routeobj instanceof cRoute))	{ DWarn("routeobj is not a cRoute object", 1); return false; }
	return true;
}

function cRoute::LoadRoute(uid, force = false)
// Get a route object
	{
	local thatroute = cRoute.GetRouteObject(uid);
	if (thatroute == null)	{ DWarn("Invalid routeID : "+uid+". Cannot get object",1); return false; }
	if (!force && thatroute.Status == RouteStatus.WORKING && thatroute.UID > 1) // in theory a working one
			{
			local damage = false;
			if (!cMisc.ValidInstance(thatroute.SourceStation))	{ damage=true; }
			if (!damage && !cMisc.ValidInstance(thatroute.TargetStation))	{ damage=true; }
			if (!damage && !AIStation.IsValidStation(thatroute.SourceStation.s_ID))	{ damage=true; }
			if (!damage && !AIStation.IsValidStation(thatroute.TargetStation.s_ID))	{ damage=true; }
			if (damage)
					{
					DWarn("Route "+thatroute.Name+" is damage...",1);
					if (thatroute.VehicleType == RouteType.ROAD)    {
                                                                    INSTANCE.main.route.RouteDamage.AddItem(uid,0);
                                                                    thatroute.Status = RouteStatus.DAMAGE;
                                                                    }
                                                            else    { thatroute.Status = RouteStatus.DEAD; }
					}
			}
	if (thatroute.Status != RouteStatus.WORKING)	{ DWarn("route "+thatroute.Name+" have a non working status : "+thatroute.Status,1); }
	if (thatroute.Status == RouteStatus.DEAD)	// callback the end of destruction
			{
			cRoute.InRemoveList(thatroute.UID);
			if (!force)	return false;
			}
	return thatroute;
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

function cRoute::GetRouteName(uid)
	{
	local road = cRoute.LoadRoute(uid);
	if (!road)	{ return "Invalid Route "+uid; }
	return road.Name;
	}

function cRoute::SetRouteName()
// set a string for that route
	{
	local name="### Invalid route";
	local vroute = false;
	local rtype = cRoute.RouteTypeToString(this.VehicleType);
	if (this.UID == 0) // ignore virtual route, use by old savegame
			{
			name="Virtual Air Passenger Network for "+cCargo.GetCargoLabel(this.CargoID)+" using "+rtype;
			vroute=true;
			}
	if (this.UID == 1)
			{
			name="Virtual Air Mail Network for "+cCargo.GetCargoLabel(this.CargoID)+" using "+rtype;
			vroute=true;
			}
	local src = cMisc.ValidInstance(this.SourceStation);
	local dst = cMisc.ValidInstance(this.TargetStation);
	if (vroute)	{ this.Name = name; }
        else
                {
                if (src)	{ src = this.SourceStation.s_Name; }
                    else	{ src = this.SourceProcess.Name; }
                if (dst)	{ dst = this.TargetStation.s_Name; }
                    else	{ dst = this.TargetProcess.Name; }
                this.Name="#"+this.UID+": From "+src+" to "+dst+" for "+cCargo.GetCargoLabel(this.CargoID)+" using "+rtype;
                }
	}

function cRoute::RouteSave()
// save that route to the database
	{
	this.SetRouteName();
	if (this.UID in database)	{ DInfo("Route "+this.Name+" is already in database",2); }
                        else
                                {
                                DInfo("Adding route "+this.Name+" to the route database",2);
                                database[this.UID] <- this;
                                RouteIndexer.AddItem(this.UID, -1);
                                }
	}


function cRoute::RouteDone()
// called when a route is finish
	{
	if (!cMisc.ValidInstance(this.SourceProcess) || !cMisc.ValidInstance(this.TargetProcess))	{ return; }
	if (!cMisc.ValidInstance(this.SourceStation) || !cMisc.ValidInstance(this.TargetStation))	{ return; }
	this.VehicleCount = 0;
	this.Status = RouteStatus.WORKING;
	switch (this.VehicleType)
			{
			case	RouteType.RAIL:
				this.StationType = AIStation.STATION_TRAIN;
				this.RailType = this.SourceStation.s_SubType;
				break;
			case	RouteType.ROAD:
				this.StationType = AIStation.STATION_TRUCK_STOP;
				if (this.CargoID == cCargo.GetPassengerCargo())	{ this.StationType = AIStation.STATION_BUS_STOP; }
				break;
			case	RouteType.WATER:
				this.StationType = AIStation.STATION_DOCK;
				break;
			case	RouteType.AIR:
			case	RouteType.AIRMAIL:
			case	RouteType.AIRNET:
			case	RouteType.AIRNETMAIL:
			case	RouteType.SMALLAIR:
			case	RouteType.SMALLMAIL:
			case	RouteType.CHOPPER:
				this.StationType = AIStation.STATION_AIRPORT;
				break;
			}
	this.RouteSave();
	this.RouteSetDistance();
	if (this.SourceProcess.IsTown)	{ cProcess.statueTown.AddItem(this.SourceProcess.ID,0); }
	if (this.TargetProcess.IsTown)	{ cProcess.statueTown.AddItem(this.TargetProcess.ID,0); }
	this.RouteAirportCheck();
	if (this.UID > 1)
		{
		this.SourceProcess.UsedBy.AddItem(this.UID,0);
		this.TargetProcess.UsedBy.AddItem(this.UID,0);
		}
	local srcprod = this.SourceStation.IsCargoProduce(this.CargoID);
	local srcacc = this.SourceStation.IsCargoAccept(this.CargoID);
	local dstprod = this.TargetStation.IsCargoProduce(this.CargoID);
	local dstacc = this.TargetStation.IsCargoAccept(this.CargoID);
	if (srcprod)	{ this.SourceStation.s_CargoProduce.AddItem(this.CargoID,0); }
	if (srcacc)	{ this.SourceStation.s_CargoAccept.AddItem(this.CargoID,0); }
	if (dstprod)	{ this.TargetStation.s_CargoProduce.AddItem(this.CargoID,0); }
	if (dstacc)	{ this.TargetStation.s_CargoAccept.AddItem(this.CargoID,0); }
	if (srcprod && srcacc && dstprod && dstacc)	{ this.Twoway=true; }
										else	{ this.Twoway=false; }
	}

function cRoute::RouteInitNetwork()
// Add the network routes to the database
	{
	local passRoute = cRoute();
	passRoute.UID = 0;
	passRoute.CargoID = cCargo.GetPassengerCargo();
	passRoute.VehicleType = RouteType.AIRNET;
	passRoute.StationType = AIStation.STATION_AIRPORT;
	passRoute.Status = RouteStatus.WORKING;
	passRoute.Distance = 1000; // a dummy distance start value
	local n = AIGroup.CreateGroup(AIVehicle.VT_AIR);
	passRoute.GroupID = n;
	cRoute.SetRouteGroupName(passRoute.GroupID, 0, 0, true, true, passRoute.CargoID, true, null, null);
	cRoute.VirtualAirGroup[0] = n;
	passRoute.RouteSave();
	local mailRoute = cRoute();
	mailRoute.UID = 1;
	mailRoute.CargoID = cCargo.GetMailCargo();
	mailRoute.VehicleType = RouteType.AIRNETMAIL;
	mailRoute.StationType = AIStation.STATION_AIRPORT;
	mailRoute.Status = RouteStatus.WORKING;
	mailRoute.Distance = 1000;
	local n = AIGroup.CreateGroup(AIVehicle.VT_AIR);
	mailRoute.GroupID = n;
	cRoute.SetRouteGroupName(mailRoute.GroupID, 1, 1, true, true, mailRoute.CargoID, true, null, null);
	cRoute.VirtualAirGroup[1] = n;
	GroupIndexer.AddItem(cRoute.GetVirtualAirPassengerGroup(),0);
	GroupIndexer.AddItem(cRoute.GetVirtualAirMailGroup(),1);
	mailRoute.SourceStation = passRoute.SourceStation;
	mailRoute.TargetStation = passRoute.TargetStation;
	mailRoute.RouteSave();
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

function cRoute::RouteSetDistance()
// Setup a route distance
	{
	local a, b= -1;
	if (cMisc.ValidInstance(this.SourceProcess))	{ a = this.SourceProcess.Location; }
	if (cMisc.ValidInstance(this.TargetProcess))	{ b = this.TargetProcess.Location; }
	if (cMisc.ValidInstance(this.SourceStation))	{ a = this.SourceStation.s_Location; }
	if (cMisc.ValidInstance(this.TargetStation))	{ b = this.TargetStation.s_Location; }
	if (a > -1 && b > -1)	{ this.Distance = AITile.GetDistanceManhattanToTile(a, b); }
                    else	{ this.Distance = 0; }
	}

function cRoute::RouteChangeStation(uid, o_Object, n_Object)
// Route swap its old station with the new nStationObject
	{
	local road = cRoute.LoadRoute(uid);
	if (!road)	{ return; }
	if (road.UID < 2) { return; } // don't alter virtuals, let them reclaim it later
	if (road.Status != RouteStatus.WORKING)	{ return; }
	local vsource = cMisc.ValidInstance(road.SourceStation);
	local vtarget = cMisc.ValidInstance(road.TargetStation);
	local start = null;
	if (vsource && o_Object.s_ID == road.SourceStation.s_ID)	{ start = true; }
	if (vtarget && o_Object.s_ID == road.TargetStation.s_ID)	{ start = false; }
	if (start == null)	{ DError("No station match in RouteChangeStation",1); return; } // no station match the old one
	DInfo("Route " + uid + " is changing from station " + o_Object.s_Name + " to " + n_Object.s_Name, 1);
	if (start)
			{
			road.SourceStation.OwnerReleaseStation(uid);
			road.SourceStation = n_Object;
			road.SourceStation.OwnerClaimStation(uid);
			}
	else
			{
			road.TargetStation.OwnerReleaseStation(uid);
			road.TargetStation = n_Object;
			road.TargetStation.OwnerClaimStation(uid);
			}
	road.SetRouteName();
	cRoute.SetRouteGroupName(road.GroupID, road.SourceProcess.ID, road.TargetProcess.ID, road.SourceProcess.IsTown, road.TargetProcess.IsTown, road.CargoID, false, road.SourceStation.s_ID, road.TargetStation.s_ID);
	road.RouteAirportCheck();
	}

function cRoute::RouteClaimsTiles(routeobj)
{
	if (routeobj.UID < 2)	return;
	if (routeobj.StationType != AIStation.STATION_TRAIN)	return;
	local bltiles = AIList();
	bltiles.AddList(cTileTools.TilesBlackList);
	bltiles.KeepValue(0- (100000 + routeobj.SourceStation.s_ID));
	cStation.StationClaimTile(bltiles, routeobj.SourceStation.s_ID); // assign tiles to that station
	bltiles.AddList(cTileTools.TilesBlackList);
	bltiles.KeepValue(0-(100000 + routeobj.TargetStation.s_ID));
	cStation.StationClaimTile(bltiles, routeobj.TargetStation.s_ID);
	if (INSTANCE.debug)
		{
		local z = AIList();
		local s = routeobj.SourceStation;
		local t = routeobj.TargetStation;
		z.AddList(s.s_Tiles);
		z.AddList(s.s_TilesOther);
		z.AddList(t.s_Tiles);
		z.AddList(t.s_TilesOther);
		print("Station "+cStation.GetStationName(s.s_ID)+" tiles: "+s.s_Tiles.Count()+" other: "+s.s_TilesOther.Count());
		print("Station "+cStation.GetStationName(t.s_ID)+" tiles: "+t.s_Tiles.Count()+" other: "+t.s_TilesOther.Count());
		print("route tiles: "+z.Count());
		cDebug.showLogic(z);
		}
	cStationRail.DefinePlatform(routeobj.SourceStation);
	cStationRail.DefinePlatform(routeobj.TargetStation);
	cStationRail.DefineMaxTrain(routeobj.SourceStation);
	routeobj.TargetStation.s_VehicleMax = routeobj.SourceStation.s_VehicleMax;
}

function cRoute::CheckRouteProfit(uid)
// Check if a route is profitable and remove it if not
{
	local road = cRoute.LoadRoute(uid);
	if (!road)	return;
	local vehlist = AIVehicleList_Group(road.GroupID);
	if (vehlist.IsEmpty())	return;
	vehlist.Valuate(AIVehicle.GetAge);
	vehlist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
	local oldest = vehlist.GetValue(vehlist.Begin());
	vehlist.Valuate(AIVehicle.GetProfitLastYear);
	vehlist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
	local totvalue = 0;
	if (uid > 1)  // don't test network
		{
		foreach (veh, profit in vehlist)
			{
			totvalue += profit + AIVehicle.GetProfitThisYear(veh);
			if (totvalue > 100000)	break; // we don't really need to check its real amount
			}
		if (totvalue < 0 && oldest > (365 * 3))
				{
				DInfo("CheckRouteProfit mark " + road.UID + " undoable -> oldest: " + oldest + " totvalue=" + totvalue, 1);
				road.RouteIsNotDoable();
				return;
				}
		}
	// even making some money, we get call because some vehicle aren't
    local badveh = AIList();
    badveh.AddList(vehlist);
    foreach (veh, profit in badveh)
		{
		if (profit > 0)	break; // no need futher tests, other are positive too then
		if (vehlist.Count() < 3)	return; // Keep at least 2 vehicle in the group, even they aren't making money
        if (AIVehicle.GetAge(veh) > 365)	{ cCarrier.VehicleSendToDepot(veh, DepotAction.SELL); vehlist.RemoveItem(veh); }
        }
	if (!vehlist.IsEmpty())	cCarrier.CheckOneVehicleOrGroup(vehlist.Begin(), true); // check the whole group for trouble
}

function cRoute::RouteAirportCheck(uid = null)
// this function check airports routes and setup some properties as they should be
	{
	local road = false;
	if (uid == null)	road=this;
				else	road=cRoute.LoadRoute(uid);
	if (!road || road.VehicleType < RouteType.AIR)	return;
	local oldtype = road.VehicleType;
	road.VehicleType = RouteType.AIR;
	if (road.UID < 2)	road.VehicleType = RouteType.AIRNET;
	if (road.CargoID == cCargo.GetMailCargo())	road.VehicleType++;
	local srcValid = cMisc.ValidInstance(road.SourceStation);
	local dstValid = cMisc.ValidInstance(road.TargetStation);
	if (road.UID > 1 && srcValid && dstValid && (!cBuilder.AirportAcceptBigPlanes(road.SourceStation.s_ID) || !cBuilder.AirportAcceptBigPlanes(road.TargetStation.s_ID)))	road.VehicleType += 4;
	// adding 4 to met small AIR or MAIL
	if (!road.SourceProcess.IsTown)	road.VehicleType = RouteType.CHOPPER;
	if (oldtype != road.VehicleType)
			{
			DInfo("Changing aircrafts type for route " + road.Name + " to " + cRoute.RouteTypeToString(road.VehicleType), 1);
			road.SetRouteName();
			}
	}

function cRoute::RouteUpdateVehicle(routeobj)
// Recount vehicle at stations & route, update route stations
	{
	if (routeobj.UID < 2)
		{
		local maillist = AIVehicleList_Group(cRoute.GetVirtualAirMailGroup());
		local passlist = AIVehicleList_Group(cRoute.GetVirtualAirPassengerGroup());
		routeobj.VehicleCount = maillist.Count() + passlist.Count();
		return;
		}
	if (routeobj.Status != RouteStatus.WORKING)	return;
	cStation.UpdateVehicleCount(routeobj.SourceStation);
	routeobj.SourceStation.UpdateCapacity();
	cStation.UpdateVehicleCount(routeobj.TargetStation);
	routeobj.TargetStation.UpdateCapacity();
	local vehingroup = AIVehicleList_Group(routeobj.GroupID);
	routeobj.VehicleCount = vehingroup.Count();
	}

function cRoute::SetRouteGroupName(groupID, r_source, r_target, r_stown, r_ttown, r_cargo, isVirtual, sourceStaID, targetStaID)
// This rename a group to a format we can read
	{
	if (groupID == null || !AIGroup.IsValidGroup(groupID))	return "invalid";
	local dummychar = "A";
	local dummycount = 65; // the ASCII A, as this is also A in unicode
	local st="I";
	if (r_stown)	st="T";
	local dt="I";
	if (r_ttown)	dt="T";
	if (r_source == null)	r_source="B";
	if (r_target == null)	r_target="B";
	local endname = "*" + r_cargo + "*" + st + r_source + "*" + dt + r_target + "*" + sourceStaID + "*" + targetStaID + "*0"; // *0 reserved for saving purpose
	if (isVirtual)	endname = "-NETWORK " + AICargo.GetCargoLabel(r_cargo);
	dummychar = dummycount.tochar();
	local groupname = dummychar + endname;
	while (!AIGroup.SetName(groupID, groupname))
		{
		dummycount++;
		dummychar = dummycount.tochar();
		groupname = dummychar + endname;
		}
	}

function cRoute::Route_GroupNameSave()
// This update groupname with new state of the 4 properites we save in its name
// "this" must be an instance of cRoute
{
	local newstate = this instanceof cRoute;
	if (!newstate)	{ DError("must be called by an instance of cRoute",1);	return false; }
	if (this.GroupID == null || !AIGroup.IsValidGroup(this.GroupID))	return false;
	newstate = 0;
	newstate = this.Source_RailEntry ? newstate=cMisc.SetBit(newstate, 0) : newstate=cMisc.ClearBit(newstate, 0);
	newstate = this.Target_RailEntry ? newstate=cMisc.SetBit(newstate, 1) : newstate=cMisc.ClearBit(newstate, 1);
	newstate = this.Primary_RailLink ? newstate=cMisc.SetBit(newstate, 2) : newstate=cMisc.ClearBit(newstate, 2);
	newstate = this.Secondary_RailLink ? newstate=cMisc.SetBit(newstate, 3) : newstate=cMisc.ClearBit(newstate, 3);
	local gname = AIGroup.GetName(GroupID);
	gname = gname.slice(0, gname.len()-1) + newstate; // replace last char
	return AIGroup.SetName(this.GroupID, gname);
}

function cRoute::RouteBuildGroup()
// Build a group for that route
	{
	local rtype = this.VehicleType;
	if (rtype >= RouteType.AIR)	rtype = RouteType.AIR;
	local gid = AIGroup.CreateGroup(rtype);
	if (!AIGroup.IsValidGroup(gid))	{ DError("Cannot create the group", 0); return; }
	this.GroupID = gid;
	cRoute.SetRouteGroupName(this.GroupID, this.SourceProcess.ID, this.TargetProcess.ID, this.SourceProcess.IsTown, this.TargetProcess.IsTown, this.CargoID, false, this.SourceStation.s_ID, this.TargetStation.s_ID);
	if (cRoute.GroupIndexer.HasItem(this.GroupID))	cRoute.GroupIndexer.RemoveItem(this.GroupID);
	cRoute.GroupIndexer.AddItem(this.GroupID, this.UID);
	}

function cRoute::CreateNewRoute(UID)
// Create and add to database a new route with informations taken from cJobs
	{
	local jobs = cJobs.Load(UID);
	if (!jobs) return; // workaround to loading savegame where the jobs has disapears
	jobs.isUse = true;
	this.UID = jobs.UID;
	this.SourceProcess = jobs.SourceProcess;
	this.TargetProcess = jobs.TargetProcess;
	this.VehicleType = jobs.roadType;
	this.CargoID = jobs.cargoID;
	switch (this.VehicleType)
		{
		case	RouteType.RAIL:
			this.StationType = AIStation.STATION_TRAIN;
		break;
		case	RouteType.ROAD:
			this.StationType = AIStation.STATION_TRUCK_STOP;
			if (this.CargoID == cCargo.GetPassengerCargo())	this.StationType = AIStation.STATION_BUS_STOP;
		break;
		case	RouteType.WATER:
			this.StationType = AIStation.STATION_DOCK;
		break;
		case	RouteType.AIR:
			this.StationType = AIStation.STATION_AIRPORT;
			local randcargo = AIBase.RandRange(100);
			if (randcargo >60)	{ this.CargoID = cCargo.GetMailCargo(); this.VehicleType = RouteType.SMALLMAIL; }
						else	{ this.CargoID = cCargo.GetPassengerCargo(); this.VehicleType = RouteType.SMALLAIR; }
			if (!this.SourceProcess.IsTown)	{ this.CargoID = cCargo.GetPassengerCargo(); this.VehicleType = RouteType.CHOPPER; }
			DInfo("Airport work, choosen : " + randcargo + " " + cCargo.GetCargoLabel(this.CargoID),1);
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
	cRoute.GroupIndexer.AddItem(cRoute.GetVirtualAirPassengerGroup(),0);
	cRoute.GroupIndexer.AddItem(cRoute.GetVirtualAirMailGroup(),1);
	foreach (item in cRoute.database)
		{
		cRoute.RouteIndexer.AddItem(item.UID, -1);
		if (item.GroupID != null)	cRoute.GroupIndexer.AddItem(item.GroupID, item.UID);
		}
		DInfo("route indexer: "+cRoute.RouteIndexer.Count()+" base: "+cRoute.database.len(), 2);
		DInfo("group indexer: "+cRoute.GroupIndexer.Count()+ "group: "+AIGroupList().Count(), 2);
	}

function cRoute::InRemoveList(uid)
// Add a route to route damage with dead status so it will get clear
{
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
	cRoute.InRemoveList(this.UID);
	}

function cRoute::RouteUndoableFreeOfVehicle(uid)
// This is the last step of marking a route undoable
	{
	if (uid < 2)	return; // don't touch virtuals
	local route = cRoute.LoadRoute(uid, true);
	if (route != false)
		{
		local vehlist = AIList();
		if (route.GroupID != null && AIGroup.IsValidGroup(route.GroupID))
			{
			vehlist = AIVehicleList_Group(route.GroupID);
			vehlist.Valuate(AIVehicle.GetState);
			vehlist.KeepValue(AIVehicle.VS_IN_DEPOT);
			foreach (veh, _ in vehlist)	cCarrier.VehicleSell(veh, false);
			vehlist = AIVehicleList_Group(route.GroupID);
			foreach (veh, _ in vehlist)
				{
				if (!cEngineLib.VehicleIsGoingToStopInDepot(veh))
					{
					cCarrier.ToDepotList.RemoveItem(veh);
					cEngineLib.VehicleOrderClear(veh);
					cCarrier.VehicleSendToDepot(veh, DepotAction.REMOVEROUTE);
					}
				}
			}
		if (!vehlist.IsEmpty())	return;
		local stasrc = null;
		local stadst = null;
		if (cMisc.ValidInstance(route.SourceProcess))	{ route.SourceProcess.UsedBy.RemoveItem(route.UID); }
		if (cMisc.ValidInstance(route.TargetProcess))	{ route.TargetProcess.UsedBy.RemoveItem(route.UID); }
		if (cMisc.ValidInstance(route.SourceStation))	{ stasrc = route.SourceStation.s_ID; route.RouteReleaseStation(route.SourceStation.s_ID); }
		if (cMisc.ValidInstance(route.TargetStation))	{ stadst = route.TargetStation.s_ID; route.RouteReleaseStation(route.TargetStation.s_ID); }
		cBuilder.DestroyStation(stasrc);
		cBuilder.DestroyStation(stadst);
		if (route.GroupID != null)	{ AIGroup.DeleteGroup(route.GroupID); cRoute.GroupIndexer.RemoveItem(route.GroupID); }
		if (route.UID in cRoute.database)
			{
			DInfo("-> Removing route " + route.UID + " from database",1);
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
	local ss = cMisc.ValidInstance(this.SourceStation);
	local sd = cMisc.ValidInstance(this.TargetStation);

	if (ss && this.SourceStation.s_ID == stationid)
		{
		local ssta = cStation.Load(this.SourceStation.s_ID);
		if (ssta != false)	ssta.OwnerReleaseStation(this.UID);
		this.SourceStation = null;
		this.Status = RouteStatus.DEAD;
		}
	if (sd && this.TargetStation.s_ID == stationid)
		{
		local ssta = cStation.Load(this.TargetStation.s_ID);
		if (ssta != false)	ssta.OwnerReleaseStation(this.UID);
		this.TargetStation = null;
		this.Status = RouteStatus.DEAD;
		}
	if (INSTANCE.main.route.RouteDamage.HasItem(this.UID))	INSTANCE.main.route.RouteDamage.RemoveItem(this.UID);
	INSTANCE.buildDelay=0; INSTANCE.main.bank.canBuild = true;
	}

function cRoute::GetDepot(uid, source = 0)
// Return a valid depot we could use, this mean we will seek out both side of the route if we cannot find a proper one
// source: 0- Get any depot we could use, 1- Get source depot, 2- Get target depot
// per default return any valid depot we could found, if source=1 or 2 return an error if the query depot doesn't exist
// return -1 on errors
	{
	local road = cRoute.LoadRoute(uid);
	if (!road)	return -1;
	local sdepot = cStation.GetStationDepot(road.SourceStation.s_ID);
	local tdepot = cStation.GetStationDepot(road.TargetStation.s_ID);
	if (source == 0 || source == 1)	return sdepot;
	if (source == 0 || source == 2)	return tdepot;
    if (road.VehicleType == RouteType.ROAD && road.Status == RouteStatus.WORKING)	cBuilder.RouteIsDamage(uid);
	if (road.VehicleType == RouteType.WATER && road.Status == RouteStatus.WORKING)  cBuilder.RepairWaterRoute(uid);
	if (source == 0)	DError("Route " + cRoute.GetRouteName(road.UID) + " doesn't have any valid depot !", 2);
				else	DError("Route " + cRoute.GetRouteName(road.UID) + " doesn't have the request depot ! source=" + source, 2);
	return -1;
	}

function cRoute::AddTrainToRoute(uid, vehid)
// Add a train to a route
{
	local road = cRoute.LoadRoute(uid);
	if (!road)	return;
    cTrain.TrainSetStation(vehid, road.SourceStation.s_ID, true);
    cTrain.TrainSetStation(vehid, road.TargetStation.s_ID, false);
    cRoute.RouteUpdateVehicle(road);
}

function cRoute::CanAddTrainToStation(uid)
// return true if we can add another train to that rail station
// return false when the station cannot handle it
	{
	if (!INSTANCE.use_train)	return false;
	local road = cRoute.LoadRoute(uid);
	if (!road)	return false;
	local canAdd = true;
//	DInfo("src=" + road.Source_RailEntry + " 2way=" + road.Twoway + " tgt=" + road.Target_RailEntry, 1);
	canAdd = cStationRail.RailStationGrow(road.SourceStation);
	// we always allow any amount of train on destination station if the station is just use as dropoff
	if (canAdd)	canAdd = cStationRail.RailStationGrow(road.TargetStation);
//		if (!road.Twoway)	canAdd = true;
	return canAdd;
	}

function cRoute::DiscoverWorldTiles()
// look at the map and discover what we own, use after loading
{
	DInfo("Looking for our properties, game may get frozen for some times on huge maps, be patient",0);
	local weare = AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);

	const tilesPerStep = 100000;
	local mapWidth = AIMap.GetMapSizeX();
	local mapHeight = AIMap.GetMapSizeY();
	local chunkHeight = tilesPerStep / mapWidth;

	for (local y1 = 0; y1 < mapHeight; y1 += chunkHeight)
	{
		local y2 = min(y1 + chunkHeight, mapHeight);
		local chunk = AITileList();
		AIController.Sleep(1);
		chunk.AddRectangle(AIMap.GetTileIndex(0, y1), AIMap.GetTileIndex(mapWidth - 1, y2 - 1));
		AIController.Sleep(1);
		chunk.Valuate(AITile.GetOwner);
		AIController.Sleep(1);
		chunk.KeepValue(weare);
		cRoute.RouteDamage.AddList(chunk);
	}
}
