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

class cRoute extends cClass
	{
static	database = {};
static	RouteIndexer = AIList();	// list all UID of routes we are handling
static	GroupIndexer = AIList();	// map a group->UID, item=group, value=UID
static	RouteDamage = AIList(); 	// list of routes that need repairs
static	WorldTiles = AIList();		// tiles we own, hard to get
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
	rail_type		= null;	// type of rails in use, same as the first working station done
	distance		= null;	// farest distance from source station to target station
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
		UID			= null;
		sourceID		= null;
		source_location	= 0;
		source_istown	= false;
		source		= null;		
		targetID		= null;
		target_location	= 0;
		target_istown	= false;
		target		= null;
		vehicle_count	= 0;
		route_type		= null;		// *
		station_type	= null;
		rail_type		= null;
		distance		= 0;
		isWorking		= false;
		status		= 0;			// *
		groupID		= null;		// *
		source_entry	= false;
		source_stationID	= null;		// *
		target_entry	= false;
		target_stationID	= null;		// *
		cargoID		= null;
		date_VehicleDelete= 0;
		date_lastCheck	= null;
		source_RailEntry	= null;		// *
		target_RailEntry	= null;		// *
		primary_RailLink	= false;		// *
		secondary_RailLink= false;		// *
		twoway		= false;
		this.ClassName = "cRoute";
		}
	}

