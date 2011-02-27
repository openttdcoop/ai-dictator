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
static	function GetStationObject(stationID)
		{
		return stationID in cStation.database ? cStation.database[stationID] : null;
		}

	stationID	= null;	// id of industry/town
	stationType	= null;	// cStationType
	specialType	= null;	// for boat = nothing
				// for trains = AIRail.RailType
				// for road = AIRoad.RoadType
				// for airport: 0-Airport big, 1-Airport small plane, 2-Platform
	size		= null;	// size of station: road = number of stations, trains=width, airport=width*height
	canUpgrade	= true;	// false if we cannot upgrade it more
	locations	= AIList();	// locations of station
	front		= AIList();	// front tile of station if any
	depot		= null;	// depot position and id are the same
	cargos		= AIList(); // cargos ID, amount as value of cargos the station handle
	radius		= null;	// radius of the station
	routeParent	= AIList(); // list of all uniqID for routes that use that station
}

function cStation::StationSave()
// Save the station in the database
	{
	if (!this.stationID in cStation.database)
		{
		DInfo("STATIONS -> Adding station : "+this.stationID+" to station database",2);
		database[this.stationID] <- this;
		}

function cStation::IsUseByRoute(uid)
// return true if that uid route use that station
	{
	return (routeParent.HasItem(uid));
	}

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

