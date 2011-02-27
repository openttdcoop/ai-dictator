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
class cStation
{
static	database = {};
//static	routeParent = AIList();	// map route uid to stationid (as value)
static	function GetStationObject(stationID)
		{
		return stationID in cStation.database ? cStation.database[stationID] : null;
		}

	stationID	= null;	// id of industry/town
	stationType	= null;	// AIStation.StationType
	specialType	= null;	// for boat = nothing
				// for trains = AIRail.RailType
				// for road = AIRoad.RoadType
				// for airport: AirportType
	size		= null;	// size of station: road = number of stations, trains=width, airport=width*height
	canUpgrade	= true;	// false if we cannot upgrade it more
	locations	= AIList();	// locations of station, value = front tile
	depot		= null;	// depot position and id are the same
	rating		= AIList(); // item=cargos, value=rating
	cargos		= AIList(); // cargos ID, amount as value of cargos the station handle
	radius		= null;	// radius of the station
}

function cStation::StationSave()
// Save the station in the database
	{
	if (!this.stationID in cStation.database)
		{
		DInfo("STATIONS -> Adding station : "+this.stationID+" to station database",2);
		database[this.stationID] <- this;
		}

/* 
function cStation::StationOwnByRoute(uid)	// TODO: not sure it's useful, will see, until then, in that form it's not useful 
// add that station as use by route uid
	{
	if (!this.routeParent.HasItem(uid))	this.routeParent.AddItem(uid, stationid);
	}

function cStation::IsUseByRoute(uid)
// return true if that uid route use that station
// route must claim it first thru cStation.StationOwnByRoute
	{
	return (routeParent.HasItem(uid) && routeParent.GetValue(uid)==this.stationID);
	}
*/
function cStation::CanUpgradeStation()
// check if station could be upgrade
// just return canUpgrade value or for airports true or false if we find a better airport
	{
	if (this.stationType >= StationType.STATION_AIRPORT_SMALL)
		{ // it's an airport
		local newairport = cBuilder.GetAirportType();
		if (newairport > this.stationType)	this.canUpgrade=true;
						else	this.canUpgrade=false;
		}
	if (this.stationType == StationType.STATION_PLATFORM)	this.canUpgrade=false;
	}

function cStation::FindStationType(stationID)
// return the first station type we found for that station
// -1 on error
	{
	if (!AIStation.IsValidStation(stationid))	return -1;
	local stationtype=-1;
	stationtype=AIStation.STATION_AIRPORT;
	if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
	stationtype=AIStation.STATION_TRAIN;
	if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
	stationtype=AIStation.STATION_DOCK;
	if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
	stationtype=AIStation.STATION_TRUCK_STOP;
	if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
	stationtype=AIStation.STATION_BUS_STOP;
	if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
	return -1;
	}

function cStation::InitNewStation()
// Autofill most values for a station. stationID must be set
	{
	if (this.stationID == null)	return;
	this.stationType = cStation.FindStationType(this.stationID);
	local loc=AIStation.GetLocation(this.stationID);
	locations=cTileTools.FindStationTiles(loc);
	this.size=locations.Count();
	this.radius=AIStation.GetCoverageRadius(this.stationType);
	switch	(this.stationType)
		{
		case	AIStation.STATION_TRAIN:		// TODO:
		break;
		case	AIStation.STATION_DOCK:		// TODO:
		break;
		case	AIStation.STATION_BUS_STOP:
			foreach(loc, dummy in this.locations)	front.AddItem(
		break;
		case	AIStation.STATION_TRUCK_STOP:
		break;
		case	AIStation.STATION_AIRPORT:
			this.specialType=AIAirport.GetAirportType(this.locations.Begin());
			this.radius=AIAirport.GetCoverageRadius(this.specialType);
			this.front.Clear();
			if (this.specialType == AIAirport.AT_SMALL)	this.front.AddItem(0,0);
								else	this.front.AddItem(1,1);
		break;
		}
	}
/*
	specialType	= null;	// for boat = nothing
				// for trains = AIRail.RailType
				// for road = AIRoad.RoadType
				// for airport: 0-Airport big, 1-Airport small plane, 2-Platform
	front		= AIList();	// front tile of station if any
	depot		= null;	// depot position and id are the same
	cargos		= AIList(); // cargos ID, amount as value of cargos the station handle
*/
	// find stationType
	if 
