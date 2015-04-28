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
		static	RouteIndexer = AIList();	// list all UID of routes we are handling
		static	GroupIndexer = AIList();	// map a group->UID, item=group, value=UID
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
        MoreTrain           = null; // if we ask one more train : 0-not yet, 1-asked, 2-accept, 3-refuse

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
            MoreTrain           = 0;
			this.ClassName      = "cRoute";
			}

		function GetRouteObject(UID)
			{
			if (UID in cRoute.database)	{ return cRoute.database[UID]; }
                                else	{ cRoute.RouteRebuildIndex();   return null; }
			}

	}

function cRoute::Load(uid)
// Get a route object
	{
	local thatroute=cRoute.GetRouteObject(uid);
	if (typeof(thatroute) != "instance")	{ return false; }
	if (thatroute instanceof cRoute)	{}
                                else	{ return false; }
	if (thatroute == null)	{ DWarn("Invalid routeID : "+uid+". Cannot get object",1); return false; }
	if (thatroute.Status == RouteStatus.WORKING && thatroute.UID > 1) // in theory a working one
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
			return false;
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
	local road = cRoute.Load(uid);
	if (!road)	{ return "Invalid Route "+uid; }
	return road.Name;
	}

function cRoute::SetRouteName()
// set a string for that route
	{
	local name="### Invalid route";
	local vroute = false;
	local rtype=cRoute.RouteTypeToString(this.VehicleType);
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
	local src=(typeof(this.SourceStation) == "instance");
	local dst=(typeof(this.TargetStation) == "instance");
	if (vroute)	{ this.Name = name; }
        else
                {
                if (src)	{ src=this.SourceStation.s_Name; }
                    else	{ src=this.SourceProcess.Name; }
                if (dst)	{ dst=this.TargetStation.s_Name; }
                    else	{ dst=this.TargetProcess.Name; }
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
                                RouteIndexer.AddItem(this.UID, 1);
                                }
	}


function cRoute::RouteDone()
// called when a route is finish
	{
	if (!cMisc.ValidInstance(this.SourceProcess) || !cMisc.ValidInstance(this.TargetProcess))	{ return; }
	if (!cMisc.ValidInstance(this.SourceStation) || !cMisc.ValidInstance(this.TargetStation))	{ return; }
	this.VehicleCount=0;
	this.Status=RouteStatus.WORKING;
	switch (this.VehicleType)
			{
			case	RouteType.RAIL:
				this.StationType=AIStation.STATION_TRAIN;
				this.RailType = this.SourceStation.s_SubType;
				break;
			case	RouteType.ROAD:
				this.StationType=AIStation.STATION_TRUCK_STOP;
				if (this.CargoID == cCargo.GetPassengerCargo())	{ this.StationType=AIStation.STATION_BUS_STOP; }
				break;
			case	RouteType.WATER:
				this.StationType=AIStation.STATION_DOCK;
				break;
			case	RouteType.AIR:
			case	RouteType.AIRMAIL:
			case	RouteType.AIRNET:
			case	RouteType.AIRNETMAIL:
			case	RouteType.SMALLAIR:
			case	RouteType.SMALLMAIL:
			case	RouteType.CHOPPER:
				this.StationType=AIStation.STATION_AIRPORT;
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
	local srcprod=this.SourceStation.IsCargoProduce(this.CargoID);
	local srcacc=this.SourceStation.IsCargoAccept(this.CargoID);
	local dstprod=this.TargetStation.IsCargoProduce(this.CargoID);
	local dstacc=this.TargetStation.IsCargoAccept(this.CargoID);
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
	local passRoute=cRoute();
	passRoute.UID=0;
	passRoute.CargoID=cCargo.GetPassengerCargo();
	passRoute.VehicleType = RouteType.AIRNET;
	passRoute.StationType = AIStation.STATION_AIRPORT;
	passRoute.Status=RouteStatus.WORKING;
	passRoute.Distance = 1000; // a dummy distance start value
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	passRoute.GroupID=n;
	cRoute.SetRouteGroupName(passRoute.GroupID, 0, 0, true, true, passRoute.CargoID, true, null, null);
	cRoute.VirtualAirGroup[0]=n;
	passRoute.RouteSave();
	local mailRoute=cRoute();
	mailRoute.UID=1;
	mailRoute.CargoID=cCargo.GetMailCargo();
	mailRoute.VehicleType = RouteType.AIRNETMAIL;
	mailRoute.StationType = AIStation.STATION_AIRPORT;
	mailRoute.Status=RouteStatus.WORKING;
	mailRoute.Distance = 1000;
	local n=AIGroup.CreateGroup(AIVehicle.VT_AIR);
	mailRoute.GroupID=n;
	cRoute.SetRouteGroupName(mailRoute.GroupID, 1, 1, true, true, mailRoute.CargoID, true, null, null);
	cRoute.VirtualAirGroup[1]=n;
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
	if (cMisc.ValidInstance(this.SourceProcess))	{ a=this.SourceProcess.Location; }
	if (cMisc.ValidInstance(this.TargetProcess))	{ b=this.TargetProcess.Location; }
	if (cMisc.ValidInstance(this.SourceStation))	{ a=this.SourceStation.s_Location; }
	if (cMisc.ValidInstance(this.TargetStation))	{ b=this.TargetStation.s_Location; }
	if (a > -1 && b > -1)	{ this.Distance=AITile.GetDistanceManhattanToTile(a,b); }
                    else	{ this.Distance=0; }
	}

function cRoute::RouteChangeStation(uid, o_Object, n_Object)
// Route swap its old station with the new nStationObject
	{
	local road = cRoute.Load(uid);
	if (!road)	{ return; }
	if (road.UID < 2) { return; } // don't alter virtuals, let them reclaim it later
	if (road.Status != RouteStatus.WORKING)	{ return; }
	local vsource = cMisc.ValidInstance(road.SourceStation);
	local vtarget = cMisc.ValidInstance(road.TargetStation);
	local start = null;
	if (vsource && o_Object.s_ID == road.SourceStation.s_ID)	{ start = true; }
	if (vtarget && o_Object.s_ID == road.TargetStation.s_ID)	{ start = false; }
	if (start == null)	{ DError("No station match in RouteChangeStation",1); return; } // no station match the old one
	DInfo("Route "+uid+" is changing from station "+o_Object.s_Name+" to "+n_Object.s_Name,1);
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

function cRoute::RouteClaimsTiles(uid = null)
{
	local road;
	if (uid == null)	road = this;
				else	road = cRoute.Load(uid);
	if (!road)	return;
	if (road.UID < 2)	return;
	if (road.StationType != AIStation.STATION_TRAIN)	return;
	local bltiles=AIList();
	bltiles.AddList(cTileTools.TilesBlackList);
	bltiles.KeepValue(0-(100000+road.SourceStation.s_ID));
	cStation.StationClaimTile(bltiles, road.SourceStation.s_ID, -1); // assign tiles to that station
	bltiles.AddList(cTileTools.TilesBlackList);
	bltiles.KeepValue(0-(100000+road.TargetStation.s_ID));
	cStation.StationClaimTile(bltiles, road.TargetStation.s_ID, -1);
	if (INSTANCE.debug)
		{
		local z = AIList();
		local s = road.SourceStation;
		local t = road.TargetStation;
		z.AddList(s.s_Tiles);
		z.AddList(s.s_TilesOther);
		z.AddList(t.s_Tiles);
		z.AddList(t.s_TilesOther);
		print("Station "+cStation.GetStationName(s.s_ID)+" tiles: "+s.s_Tiles.Count()+" other: "+s.s_TilesOther.Count());
		print("Station "+cStation.GetStationName(t.s_ID)+" tiles: "+t.s_Tiles.Count()+" other: "+t.s_TilesOther.Count());
		print("route tiles: "+z.Count());
		cDebug.showLogic(z);
		}
}

function cRoute::CheckRouteProfit(uid)
// Check if a route is profitable and remove it if not
{
	local road = cRoute.GetRouteObject(uid);
	if (!road)	return;
	local vehlist = AIVehicleList_Group(road.GroupID);
	if (vehlist.IsEmpty())	return;
	vehlist.Valuate(AIVehicle.GetAge);
	vehlist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
	local oldest = vehlist.GetValue(vehlist.Begin());
	vehlist.Valuate(AIVehicle.GetProfitLastYear);
	vehlist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
	local totvalue = 0;
	foreach (veh, profit in vehlist)
		{
		totvalue += profit;
		if (totvalue > 100000)	break; // we don't really need to check its real amount
		}
	if (totvalue < 0 && oldest > (365 * 3))	{ DInfo("CheckRouteProfit mark "+road.UID+" undoable -> oldest: "+oldest+" totvalue="+totvalue,1); road.RouteIsNotDoable(); return; }
	// even making some money, we get call because some vehicle aren't
    local badveh = AIList();
    badveh.AddList(vehlist);
    badveh.KeepBelowValue(0);
    foreach (veh, profit in badveh)
		{
		if (vehlist.Count() < 3)	return; // Keep at least 2 vehicle in the group, even they aren't making money
        if (AIVehicle.GetAge(veh) > 365)	{ cCarrier.VehicleSendToDepot(veh, DepotAction.SELL); vehlist.RemoveItem(veh); }
        }
}
