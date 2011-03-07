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
class cStation
{
static	stationdatabase = {};
//static	routeParent = AIList();	// map route uid to stationid (as value)
static	VirtualAirports = AIList();	// stations in the air network as item, value=towns
static	function GetStationObject(stationID)
		{
		return stationID in cStation.stationdatabase ? cStation.stationdatabase[stationID] : null;
		}

	stationID		= null;	// id of industry/town
	stationType		= null;	// AIStation.StationType
	specialType		= null;	// for boat = nothing
						// for trains = AIRail.RailType
						// for road = AIRoad::RoadVehicleType
						// for airport: AirportType
	size			= null;	// size of station: road = number of stations, trains=width, airport=width*height
	maxsize		= null; 	// maximum size a station could be
	locations		= null;	// locations of station tiles
						// for road, value = front tile location
						// for airport, 1st value = 0- big planes, 1- small planes, 2- chopper
	depot			= null;	// depot position and id are the same
	rating		= null;	// item=cargos, value=rating
	cargo_produce	= null;	// cargos ID, amount waiting as value
	cargo_rating	= null;	// cargos ID, rating as value
	cargo_accept	= null;	// cargos ID, amount as value of cargos the station handle
	radius		= null;	// radius of the station
	vehicle_count	= null;	// vehicle using that station
	vehicle_max		= null;	// max vehicle that station could handle
	owner			= null;	// list routes that own that station
	
	constructor()
		{
		stationID		= null;
		stationType		= null;
		specialType		= null;
		size			= 1;
		maxsize		= 1;
		locations		= AIList();
		depot			= null;
		rating		= AIList();
		cargo_produce	= AIList();
		cargo_rating	= AIList();
		cargo_accept	= AIList();
		radius		= 0;
		vehicle_count	= 0;	
		vehicle_max		= 0;	
		owner			= AIList();
		}
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

function cStation::CanUpgradeStation()
// check if station could be upgrade
// just return canUpgrade value or for airports true or false if we find a better airport
	{
	switch (this.stationType)
		{
		case	AIStation.STATION_DOCK:
			this.vehicle_max=INSTANCE.carrier.water_max;
			return false;
		break;
		case	AIStation.STATION_TRAIN:
			this.vehicle_max=this.size;
			if (this.size >= this.maxsize)	return false;
		break;
		case	AIStation.STATION_AIRPORT:
			local newairport = cBuilder.GetAirportType();
			// the per airport type limit doesn't apply to network aircrafts that bypass this check
			if (newairport > this.specialType)	return true;
								else	return false;
		break;
		default: // bus or truck
			this.vehicle_max=this.size*INSTANCE.carrier.road_max_onroute;
			if (this.size >= this.maxsize)	return false;
						else	return true;
		break;		
		}
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

function cStation::DeleteStation(stationid)
// Delete the station from database & airport ref
	{
	if (stationid in cStation.stationdatabase)
		{
		local statprop=cStation.GetStationObject(stationid);
		if (statprop.owner.Count() == 0) // no more own by anyone
			{
			DInfo("STATION -> Removing station #"+stationid+" from station database",1);
			delete cStation.stationdatabase[stationid];
			cStation.VirtualAirports.RemoveItem(stationid);
			}
		}
	}

function cStation::GetRoadStationEntry(entrynum=-1)
// return the front road station entrynum
	{
	if (entrynum == -1)	entrynum=this.locations.Begin();
	return this.locations.GetValue(entrynum);
	}

function cStation::ClaimOwner(uid)
// Route claims orwnership of that station
	{
/*	DInfo("Dumping owner");
	foreach (ruid, dummy in this.owner)	{ DInfo("station "+this.stationID+" owner="+ruid,1); }*/
	if (!this.owner.HasItem(uid))
		{
		this.owner.AddItem(uid,1);
		DInfo("STATIONS -> Route #"+uid+" claims station #"+this.stationID+". "+this.owner.Count()+" routes are sharing it",1);
		}
	}

function cStation::CheckAirportLimits()
// Set limits for airports
	{
	this.specialType=AIAirport.GetAirportType(this.locations.Begin());
	this.radius=AIAirport.GetAirportCoverageRadius(this.specialType);
	local planetype=0;	// big planes
	if (this.specialType == AIAirport.AT_SMALL)	planetype=1; // small planes
	this.locations.SetValue(this.locations.Begin(), planetype);
	this.depot=AIAirport.GetHangarOfAirport(this.locations.Begin());
	local virtualized=(cStation.VirtualAirports.Count() > 1 && cStation.VirtualAirports.HasItem(this.stationID));
	// get out of airnetwork if the network is too poor
	this.vehicle_max=INSTANCE.carrier.AirportTypeLimit[this.specialType];
	if (virtualized)	this.vehicle_max=INSTANCE.carrier.airnet_max * cStation.VirtualAirports.Count();
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
	if (this.stationType != AIStation.STATION_AIRPORT)	this.radius=AIStation.GetCoverageRadius(this.stationType);
	// avoid getting the warning message for coverage of airport with that function
	switch	(this.stationType)
		{
		case	AIStation.STATION_TRAIN:		// TODO: fix & finish
			this.specialType=AIRail.GetRailType(locations.Begin()); // set rail type the station use
			this.maxsize=INSTANCE.carrier.rail_max; this.size=1;
		break;
		case	AIStation.STATION_DOCK:		// TODO: do it
			this.maxsize=1; this.size=1;
		break;
		case	AIStation.STATION_BUS_STOP:
		case	AIStation.STATION_TRUCK_STOP:
			this.maxsize=INSTANCE.carrier.road_max;
			this.size=locations.Count();
			if (AIRoad.HasRoadType(locations.Begin(), AIRoad.ROADTYPE_ROAD))
				{
				this.specialType=AIRoad.ROADTYPE_ROAD;	// set road type the station use
				}
			foreach(loc, dummy in this.locations)	this.locations.SetValue(loc, AIRoad.GetRoadStationFrontTile(loc));
		break;
		case	AIStation.STATION_AIRPORT:
			this.maxsize=1000; // airport size is limited by airport avaiability
			this.size=this.locations.Count();
			this.specialType=AIAirport.GetAirportType(this.locations.Begin());
			this.radius=AIAirport.GetAirportCoverageRadius(this.specialType);
			local planetype=0;	// big planes
			if (this.specialType == AIAirport.AT_SMALL)	planetype=1; // small planes
			this.locations.SetValue(this.locations.Begin(), planetype);
			this.depot=AIAirport.GetHangarOfAirport(this.locations.Begin());
		break;
		}
	// for everyone, the cargos
	this.vehicle_count=0;
	this.CargosUpdate();
	local dummy=this.CanUpgradeStation(); // just to set max_vehicle
	this.StationSave();
	}

