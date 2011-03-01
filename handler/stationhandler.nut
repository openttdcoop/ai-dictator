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
static	stationdatabase = {};
//static	routeParent = AIList();	// map route uid to stationid (as value)
static	virtual_airport = AIList();	// list stations currently in the air network
static	function GetStationObject(stationID)
		{
		return stationID in cStation.stationdatabase ? cStation.stationdatabase[stationID] : null;
		}

	stationID	= null;	// id of industry/town
	stationType	= null;	// AIStation.StationType
	specialType	= null;	// for boat = nothing
				// for trains = AIRail.RailType
				// for road = AIRoad.RoadType
				// for airport: AirportType
	virtualized	= false;// true if in the virtual network
	size		= null;	// size of station: road = number of stations, trains=width, airport=width*height
	canUpgrade	= true;	// false if we cannot upgrade it more
	locations	= AIList();	// locations of station tiles
					// for road, value = front tile location
					// for airport, 1st value = 0- big planes, 1- small planes, 2- chopper
	depot		= null;	// depot position and id are the same
	rating		= AIList(); // item=cargos, value=rating
	cargo_produce	= AIList(); // cargos ID, amount waiting as value
	cargo_rating	= AIList(); // cargos ID, rating as value
	cargo_accept	= AIList(); // cargos ID, amount as value of cargos the station handle
	radius		= null;	// radius of the station
	vehicle_count	= null;	// vehicle using that station
}

function cStation::StationSave()
// Save the station in the database
	{
	if (this.stationID in cStation.stationdatabase)
		{ DInfo("STATIONS -> Station #"+this.stationID+" already in database "+cStation.stationdatabase.len(),2); }
	else	{
		DInfo("STATIONS -> Adding station : "+this.stationID+" to station database",2);
		cStation.stationdatabase[this.stationID] <- this;
		}

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

function cStation::FindStationType(stationid)
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

function cStation::CargosUpdate()
// Update information for cargos
	{
	this.cargo_produce.Clear();
	this.cargo_accept.Clear();
	this.cargo_rating.Clear();
	local cargolist=AICargoList();
	foreach (cargo_id, dummy in cargolist)
		{
		local accept=AITile.GetCargoAcceptance(this.locations.Begin(), cargo_id, 1, 1, this.radius);
		local produce=AITile.GetCargoProduction(this.locations.Begin(), cargo_id, 1, 1, this.radius);
		if (accept > 7)	this.cargo_accept.AddItem(cargo_id, accept);
		if (produce > 0)	
			{
			this.cargo_produce.AddItem(cargo_id, AIStation.GetCargoWaiting(this.stationID, cargo_id));
			this.cargo_rating.AddItem(cargo_id, AIStation.GetCargoRating(this.stationID, cargo_id));
			}
		}
	
	}

function cStation::GetRoadStationEntry(entrynum=-1)
// return the front road station entrynum
	{
	if (entrynum == -1)	entrynum=this.locations.Begin();
	return this.locations.GetValue(entrynum);
	}

function cStation::InitNewStation()
// Autofill most values for a station. stationID must be set
// Should not be call as-is, cRoute.CreateNewStation is there for that task
	{
	if (this.stationID == null)	{ DWarn("InitNewStation() Bad station id : null",1); return; }
	this.stationType = cStation.FindStationType(this.stationID);
	//if (this.stationType == -1)	{ DError("BUG ! Don't call cStation::InitNewStation() without a real station !",1); return; }
	local loc=AIStation.GetLocation(this.stationID);
	locations=cTileTools.FindStationTiles(loc);
	this.size=locations.Count();
	if (this.stationType != AIStation.STATION_AIRPORT)	this.radius=AIStation.GetCoverageRadius(this.stationType);
	// avoid getting the warning message for coverage of airport with that function
	switch	(this.stationType)
		{
		case	AIStation.STATION_TRAIN:		// TODO:
			this.specialType=AIRail.GetRailType(locations.Begin()); // set rail type the station use
		break;
		case	AIStation.STATION_DOCK:		// TODO:
		break;
		case	AIStation.STATION_BUS_STOP:
		case	AIStation.STATION_TRUCK_STOP:
			if (AIRoad.HasRoadType(locations.Begin(), AIRoad.ROADTYPE_ROAD))
				{
				this.specialType=AIRoad.ROADTYPE_ROAD;	// set road type the station use
				}
			foreach(loc, dummy in this.locations)	this.locations.SetValue(loc, AIRoad.GetRoadStationFrontTile(loc));
		break;
		case	AIStation.STATION_AIRPORT:
			this.specialType=AIAirport.GetAirportType(this.locations.Begin());
			this.radius=AIAirport.GetCoverageRadius(this.specialType);
			local planetype=0;	// big planes
			if (this.specialType == AIAirport.AT_SMALL)	planetype=1; // small planes
			this.locations.SetValue(this.locations.Begin(), planetype);
			this.depot=AIAirport.GetHangarOfAirport(this.locations.Begin());
		break;
		}
	// for everyone, the cargos
	this.vehicle_count=0;
	this.CargosUpdate();
	DInfo("STATIONS-> save going");
	this.StationSave();
	}

