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

enum TrainSide
{
	IN,
	OUT,
	CROSSING,
	IN_LINK,
	OUT_LINK,
	DEPOT
}

enum	TrainType
{
	STATIONBIT,
	TET,
	TXT,
	TED,
	TXD,
	START_POINT,
	END_POINT,
	DIRECTION,
	DEPTH,
	PLATFORM_LEFT,
	PLATFORM_RIGHT,
	OWNER,
	GOODPLATFORM
}


class cStation extends cClass
{
	static	stationdatabase = {};
	static	VirtualAirports = AIList();	// stations in the air network as item, value=towns
	static	function GetStationObject(stationID)
	{
	return stationID in cStation.stationdatabase ? cStation.stationdatabase[stationID] : null;
	}

s_ID		    	= null;	// id of station
s_Type		        = null;	// AIStation.StationType
s_SubType		    = null;	// Special subtype of station (depend on station), -2 if the station is virtual (own by industry platform...)
s_Location		    = null;	// Location of station
s_Depot	    	    = null;	// depot position and id are the same
s_Size		        = null;	// size of station: road = number of stations, trains=width, airport=width*height
s_MaxSize		    = null; // maximum size a station could be
s_CargoProduce	    = null;	// cargos ID produce at station, value = amount waiting
s_CargoAccept	    = null;	// cargos ID accept at station, value = cargo rating
s_Radius	    	= null;	// radius of the station
s_VehicleCount  	= null;	// vehicle using that station
s_VehicleMax	    = null;	// max vehicle that station could handle. For rail : -1 open, -2 close, >0 pathfinder task # is running
s_VehicleCapacity   = null;	// total capacity of all vehicle using the station, item=cargoID, value=capacity
s_Owner		        = null;	// list routes that own that station
s_DateLastUpdate	= null;	// record last date we update infos for the station
s_DateLastUpgrade	= null;	// record last date we try upgrade the station
s_MoneyUpgrade  	= null;	// money we need for upgrading the station
s_Name      		= null;	// station name
s_Tiles		        = null;	// Tiles where the station is
s_TilesOther	    = null;	// Tiles own by station that aren't station tiles
s_DateBuilt	    	= null;	// Date we add this station as an object
s_UpgradeTry	    = null;	// Number of trys remaining to upgrade a station

constructor()
	{
	// * are saved variables
	this.ClassName          = "cStation";
	this.s_ID			    = -1;						// *
	this.s_Type			    = -1;
	this.s_SubType		    = -1;
	this.s_Location		    = -1;
	this.s_Depot		    = -1;
	this.s_Size			    = 1;
	this.s_MaxSize		    = 1;
	this.s_CargoProduce	    = AIList();
	this.s_CargoAccept	    = AIList();
	this.s_Radius		    = 0;
	this.s_VehicleCount	    = 0;
	this.s_VehicleMax		= 0;
	this.s_VehicleCapacity	= AIList();
	this.s_Owner		    = AIList();
	this.s_DateLastUpdate	= null;
	this.s_DateLastUpgrade	= null;
	this.s_MoneyUpgrade	    = 0;
	this.s_Name			    = "Default Station Name";
	this.s_Tiles		    = AIList();
	this.s_TilesOther		= AIList();
	this.s_DateBuilt		= AIDate.GetCurrentDate();
	this.s_UpgradeTry		= 3;
	//this.s_Virtual          = false;
	}
}

// public

function cStation::GetStationName(_stationID)
// Return station name
	{
	local thatstation=cStation.Load(_stationID);
	if (!thatstation)	{ return "invalid StationID(#"+_stationID+")"; }
	return thatstation.s_Name;
	}

function cStation::Load(_stationID)
// Get a station object
	{
	local thatstation=cStation.GetStationObject(_stationID);
	if (thatstation == null)	{ DWarn("Invalid stationID : "+_stationID+" Cannot get object",1); return false; }
	if (!AIStation.IsValidStation(thatstation.s_ID))
			{
			DWarn("Invalid station in base : "+thatstation.s_ID,1);
			}
	return thatstation;
	}

function cStation::Save()
// Save the station in the database
	{
	if (this.s_ID == null)	{ DInfo("Not adding station #"+this.s_ID+" in database "+cStation.stationdatabase.len(),2);  return; }
	if (this.s_ID in cStation.stationdatabase)
			{
			DInfo("Station "+this.s_Name+" properties have been changed",2);
			local sta=cStation.stationdatabase[this.s_ID];
			local keepowner=AIList();
			keepowner.AddList(sta.s_Owner);
			delete cStation.stationdatabase[this.s_ID];
			cStation.VirtualAirports.RemoveItem(this.s_ID);
			this.s_Owner.AddList(keepowner);
			this.s_DateLastUpgrade = AIDate.GetCurrentDate(); // block upgrade of the new station
			}
	this.SetStationName();
	DInfo("Adding station : "+this.s_Name+" to station database",2);
	cStation.stationdatabase[this.s_ID] <- this;
	}

function cStation::DeleteStation(stationid)
// Delete the station from database if unused and old enough
	{
	local s = cStation.Load(stationid);
	if (!s)	{ return false; }
	if (s.s_Owner.Count() == 0) // no more own by anyone
			{
			DInfo("Removing station "+s.s_Name+" from station database",1);
			foreach (tile, _ in s.s_Tiles)	{ cTileTools.UnBlackListTile(tile); }
			delete cStation.stationdatabase[s.s_ID];
			cStation.VirtualAirports.RemoveItem(s.s_ID);
			return true;
			}
	else	{ DInfo("Keeping station "+s.s_Name+" as the station is still use by "+s.s_Owner.Count()+" routes",1); }
	return false;
	}

function cStation::FindStationType(stationid)
// return the first station type we found for that station
// -1 on error
	{
	if (!AIStation.IsValidStation(stationid))	{ return -1; }
	local stationtype=-1;
	stationtype=AIStation.STATION_DOCK; // testing dock first, so platform are handle by cStationWater
    if (AIStation.HasStationType(stationid, stationtype))	{ return stationtype; }
    stationtype=AIStation.STATION_AIRPORT;
	if (AIStation.HasStationType(stationid, stationtype))	{ return stationtype; }
	stationtype=AIStation.STATION_TRAIN;
	if (AIStation.HasStationType(stationid, stationtype))	{ return stationtype; }
	stationtype=AIStation.STATION_TRUCK_STOP;
	if (AIStation.HasStationType(stationid, stationtype))	{ return stationtype; }
	stationtype=AIStation.STATION_BUS_STOP;
	if (AIStation.HasStationType(stationid, stationtype))	{ return stationtype; }
	return -1;
	}

function cStation::OwnerClaimStation(uid)
// Route UID claims ownership for that station
	{
	if (!this.s_Owner.HasItem(uid))
			{
			this.s_Owner.AddItem(uid, 1);
			DInfo("Route "+cRoute.GetRouteName(uid)+" claims station "+this.s_Name+". "+this.s_Owner.Count()+" routes are sharing it",1);
			this.UpdateStationInfos()
			}
	}

function cStation::OwnerReleaseStation(uid)
// Route unclaims the ownership for that station, ask to destroy the station if no more owner own it
	{
	if (this.s_Owner.HasItem(uid))
			{
			this.s_Owner.RemoveItem(uid);
			DInfo("Route "+cRoute.GetRouteName(uid)+" release station "+this.s_Name+". "+this.s_Owner.Count()+" routes are sharing it",1);
			this.UpdateStationInfos();
			}
	}

function cStation::InitNewStation(stationID)
// Create a station object depending on station type. Add the station to base and return the station object or null on error.
	{
	if (!AIStation.IsValidStation(stationID))
		{
		DError("Station #"+stationID+" doesn't exist");
		return null;
		}
	local _StationType = cStation.FindStationType(stationID);
	if (_StationType == -1)	{ DWarn("Couldn't determine station type use by station #"+stationID); }
	local _Location = AIStation.GetLocation(stationID);
	local _oldstation = cStation.GetStationObject(stationID); // lookout if we knows this one already
	local _station = null;
	local nothing = 0; // make sure no foreach bug is bugging us, keep this here to prevent it
	switch (_StationType)
			{
			case	AIStation.STATION_TRAIN:
				_station = cStationRail();
				_station.s_Tiles = cTileTools.FindStationTiles(_Location);
				_station.s_Radius = AIStation.GetCoverageRadius(_StationType);
				break;
			case	AIStation.STATION_DOCK:
				_station = cStationWater();
				_station.s_MaxSize = 1;
				_station.s_Tiles = cTileTools.FindStationTiles(_Location);
				_station.s_Size = 1;
				_station.s_SubType = -1;
				_station.s_Radius = AIStation.GetCoverageRadius(_StationType);
				break;
			case	AIStation.STATION_BUS_STOP:
			case	AIStation.STATION_TRUCK_STOP:
				_station = cStationRoad();
				_station.s_MaxSize = INSTANCE.main.carrier.road_max;
				_station.s_Tiles = cTileTools.FindStationTiles(_Location);
				_station.s_Size = _station.s_Tiles.Count();
				_station.s_SubType = AIRoad.ROADTYPE_ROAD;
				if (AIRoad.HasRoadType(_Location, AIRoad.ROADTYPE_TRAM))	{ _station.s_SubType = AIRoad.ROADTYPE_TRAM; }
				_station.s_Tiles.Valuate(AIRoad.GetRoadStationFrontTile);
				_station.s_Radius = AIStation.GetCoverageRadius(_StationType);
				break;
			case	AIStation.STATION_AIRPORT:
				_station = cStationAir();
				_station.s_MaxSize = 1000; // airport size is limited by airport avaiability
				_station.s_Tiles = cTileTools.FindStationTiles(_Location);
				_station.s_Size = _station.s_Tiles.Count();
				_station.s_SubType = AIAirport.GetAirportType(_Location);
				_station.s_Radius = AIAirport.GetAirportCoverageRadius(_station.s_SubType);
				_station.s_Depot = AIAirport.GetHangarOfAirport(_Location);
				break;
			}
	// now common properties
	_station.s_Location = _Location;
	_station.s_Type = _StationType;
	_station.s_ID = stationID;
	_station.s_DateBuilt = AIDate.GetCurrentDate();
	_station.s_VehicleMax = 500;
	_station.Save();
	cStation.StationClaimTile(_station.s_Tiles, _station.s_ID);
	if (_station instanceof cStationRail)	{ _station.GetRailStationMiscInfo(); }
	return _station;
	}

function cStation::CanUpgradeStation()
// check if station could be upgrade
// just return canUpgrade value or for airports true or false if we find a better airport
	{
	if (!cBanker.CanBuyThat(AICompany.GetLoanInterval()))	{ return false; }
	local now = AIDate.GetCurrentDate();
	if (this.s_DateLastUpgrade != null && now - this.s_DateLastUpgrade < 60)	{ return false; }
	// if last time we try to upgrade we have fail and it was < 60 days, give up
	if (!cBanker.CanBuyThat(this.s_MoneyUpgrade))	{ return false; }
	// we fail because we need that much money and we still don't have it
	if (this.s_UpgradeTry < 1)	{ return false; }
	switch (this.s_Type)
			{
			case	AIStation.STATION_DOCK:
				this.s_VehicleMax = INSTANCE.main.carrier.water_max;
				return false;
				break;
			case	AIStation.STATION_TRAIN:
				if (this.s_Size >= this.s_MaxSize)	{ return false; }
				return true;
				break;
			case	AIStation.STATION_AIRPORT:
				local canupgrade=false;
				local newairport = cBuilder.GetAirportType();
				// the per airport type limit doesn't apply to network aircrafts that bypass this check
				local vehlist=AIVehicleList_Station(this.s_ID);
				local townID=AIAirport.GetNearestTown(this.s_Location, this.s_SubType);
				local townpop=AITown.GetPopulation(townID);
				if (newairport > this.s_SubType && !vehlist.IsEmpty() && townpop >= (newairport*200))
						{ canupgrade=true; DInfo("NEW AIRPORT AVAILABLE ! "+newairport,2); }
				if (this.s_Tiles.Count()==1)	{ return false; } // plaforms have 1 size only
				return canupgrade;
				break;
			default: // bus or truck
				this.s_VehicleMax = this.s_Size * INSTANCE.main.carrier.road_upgrade;
				if (this.s_Size >= this.s_MaxSize)	{ return false; }
                                            else	{ return true; }
				break;
			}
	return false;
	}

function cStation::UpdateStationInfos()
// Update informations for that station if informations are old enough
	{
	local now = AIDate.GetCurrentDate();
	if (this.s_DateLastUpdate != null && now - this.s_DateLastUpdate < 20)	{ DInfo("Station "+this.s_Name+" infos are fresh",2); return; }
	DInfo("Refreshing station "+this.s_Name+" infos",2);
	this.s_DateLastUpdate = now;
	this.UpdateCapacity();
	this.UpdateCargos();
	}

function cStation::IsDepot(tile)
// return true if we have a depot at tile
	{
	if (tile == null)	{ return false; }
	local isDepot=(AIMarine.IsWaterDepotTile(tile) || AIRoad.IsRoadDepotTile(tile) || AIRail.IsRailDepotTile(tile) || AIAirport.IsHangarTile(tile));
	return isDepot;
	}

// private functions
function cStation::SetStationName()
// set name of a station
	{
	if (!AIStation.IsValidStation(this.s_ID))	{ this.s_Name = "Invalid Station (#"+this.s_ID+")"; return false; }
	local n_type = "UNKNOWN";
	switch (this.s_Type)
			{
			case	AIStation.STATION_TRAIN:
				n_type = "Train";
				break;
			case	AIStation.STATION_TRUCK_STOP:
				n_type = "Truck";
				break;
			case	AIStation.STATION_BUS_STOP:
				n_type = "Bus";
				break;
			case	AIStation.STATION_AIRPORT:
				n_type = "Airport";
				break;
			case	AIStation.STATION_DOCK:
				n_type = "Dock";
				break;
			}
	this.s_Name = AIStation.GetName(this.s_ID)+"("+n_type+"#"+this.s_ID+")";
	return true;
	}

function cStation::StationClaimTile(tile, stationID, useEntry = -1)
/**
/* Add a tile or a list of tiles as own by StationID
/* @param tile : a tile or an AIList of tiles
/* @param stationID : the stationID to work with
/* @param useEntry : -1 to not care, true for entry, false for exit
**/
	{
	local station = cStation.Load(stationID);
	if (!station)	{ return; }
	local wlist = AIList();
	if (cMisc.IsAIList(tile))	{ wlist.AddList(tile); }
						else	{ wlist.AddItem(tile, 0); }
	if (wlist.IsEmpty())	{ return; }
	local value = -1;
	if (useEntry != -1)
		{
		if (useEntry)	{ value = 1; }
				else	{ value = 0; }
		}
	foreach (t, _ in wlist)
		{
		cTileTools.BlackListTile(t, stationID);
		if (AITile.IsStationTile(t))	{ station.s_Tiles.AddItem(t, value); }
								else	{ station.s_TilesOther.AddItem(t, value); }
		}
	}

function cStation::StationReleaseTile(tile, stationID)
/**
/* Remove a tile as own by StationID
/* @param tile : a tile or an AIList of tiles
/* @param stationID : the stationID to work with
/* @param useEntry : -1 to not care, true for entry, false for exit
**/
	{
	local station = cStation.Load(stationID);
	if (!station)	{ return; }
	local wlist = AIList();
	if (cMisc.IsAIList(tile))	{ wlist.AddList(tile); }
						else	{ wlist.AddItem(tile, 0); }
	if (wlist.IsEmpty())	{ return; }
	foreach (t, _ in wlist)
		{
		cTileTools.UnBlackListTile(t);
		if (AITile.IsStationTile(t))	{ station.s_Tiles.RemoveItem(t); }
								else	{ station.s_TilesOther.RemoveItem(t); }
		}
	}

function cStation::UpdateCargos(stationID=null)
// Update Cargos waiting & rating at station
// This function doesn't produce real cargo production/acceptance at station, but only the ones we care about
	{
	local thatstation=false;
	if (stationID == null)	{ thatstation=this; }
	else	{ thatstation=cStation.Load(stationID); }
	if (!thatstation)	{ return; }
	local allcargos=AIList();
	allcargos.AddList(thatstation.s_CargoProduce);
	allcargos.AddList(thatstation.s_CargoAccept);
	foreach (cargo, value in allcargos)
		{
		if (thatstation.s_CargoProduce.HasItem(cargo))
				{
				local waiting=AIStation.GetCargoWaiting(thatstation.s_ID, cargo);
				thatstation.s_CargoProduce.SetValue(cargo, waiting);
				DInfo("Station "+thatstation.s_Name+" produce "+cCargo.GetCargoLabel(cargo)+" with "+waiting+" units",2);
				}
		if (thatstation.s_CargoAccept.HasItem(cargo))
				{
				local rating=AIStation.GetCargoRating(thatstation.s_ID, cargo);
				thatstation.s_CargoAccept.SetValue(cargo, rating);
				DInfo("Station "+thatstation.s_Name+" accept "+cCargo.GetCargoLabel(cargo)+" with "+rating+" rating",2);
				}
		local pause = cLooper();
		}
	}

function cStation::UpdateCapacity(stationID=null)
// Update the capacity of vehicles using the station
	{
	local thatstation=false;
	if (stationID == null)	{ thatstation=this; }
	else	{ thatstation=cStation.Load(stationID); }
	if (!thatstation)	{ return; }
	local vehlist=AIVehicleList_Station(thatstation.s_ID);
	local allcargos=AICargoList();
	local tmpcargos = AICargoList();
	local mail = cCargo.GetMailCargo();
	local pass = cCargo.GetPassengerCargo();
	foreach (cargoID, dummy in tmpcargos)
		{
		local newcap = 0;
		local short_list = [];
		foreach (vehID, value in vehlist)	if (value != -1)	{ short_list.push(vehID); }
		foreach (vehID in short_list)
			{
			local capacity = AIVehicle.GetCapacity(vehID, cargoID);
			if (capacity > 0)
					{
					// We will speedup checks, lowering vehicle list on each found cargo. It will then create a lost of cargo for multi-cargo vehicle
					// like aircrafts that use mail/passenger, only mail or passenger will be count as the vehicle is removed from list.
					// That's why we kept the vehicle for these cargos.
					newcap += capacity;
					if (cargoID != mail && cargoID != pass)	{ vehlist.SetValue(vehID, -1); }
					}
			local sleeper = cLooper();
			}
		allcargos.SetValue(cargoID, newcap);
		if (newcap != thatstation.s_VehicleCapacity.GetValue(cargoID))
				{
				DInfo("Station "+thatstation.s_Name+" new total capacity set to "+newcap+" for "+cCargo.GetCargoLabel(cargoID),2);
				}
		}
	thatstation.s_VehicleCapacity.Clear();
	thatstation.s_VehicleCapacity.AddList(allcargos);
	}

function cStation::IsCargoProduce(cargoID, stationID=null)
// return true/false if cargo is produce at that station
	{
	local thatstation=false;
	if (stationID == null)	{ thatstation=this; }
                    else	{ thatstation=cStation.Load(stationID); }
	if (!thatstation)	{ return false; }
	foreach (tiles, sdummy in thatstation.s_Tiles)
		{
		local value=AITile.GetCargoProduction(tiles, cargoID, 1, 1, thatstation.s_Radius);
		if (value > 0)	{ return true; }
		}
	return false;
	}

function cStation::IsCargoAccept(cargoID, stationID=null)
// return true/false if cargo is accept at that station
	{
	local thatstation=false;
	if (stationID == null)	{ thatstation=this; }
	else	{ thatstation=cStation.Load(stationID); }
	if (!thatstation)	{ return false; }
	local cargoaccept = AICargoList_StationAccepting(thatstation.s_ID);
	return cargoaccept.HasItem(cargoID);
	}

function cStation::CheckCargoHandleByStation(stationID=null)
// Check what cargo is accept or produce at station
// This doesn't really check if all cargos are produce/accept, but only if the station know that cargo should be accept/produce
// This so, doesn't include any cargos no route handle, so station report only in use ones
// Use cStation.IsCargoAccept && cStation.IsCargoProduce for a real answers
// That function is there to faster checks (as it answer only cargo we care not all cargo the station can use), not to gave true answer
	{
	local thatstation = false;
	if (stationID == null)	{ thatstation=this; }
	else	{ thatstation=cStation.Load(stationID); }
	if (!thatstation)	{ return; }
	local test = AICargoList_StationAccepting(thatstation.s_ID);
	if (thatstation.s_CargoAccept.Count() != test.Count())
			{
			thatstation.s_CargoAccept.Clear();
			thatstation.s_CargoAccept.AddList(test);
			DInfo("Station "+thatstation.s_Name+" cargo accepting list change : "+thatstation.s_CargoAccept.Count()+" cargos",1);
			}
	test = AIList();
	foreach (cargo_id, cdummy in thatstation.s_CargoProduce)
		{
		foreach (tiles, sdummy in thatstation.s_Tiles)
			{
			local produce = AITile.GetCargoProduction(tiles, cargo_id, 1, 1, thatstation.s_Radius);
			if (produce > 0)	{ test.AddItem(cargo_id, AIStation.GetCargoWaiting(thatstation.s_ID, cargo_id)); break; }
			}
		local pause = cLooper();
		}
	if (thatstation.s_CargoProduce.Count() != test.Count())	{ DInfo("Station "+thatstation.s_Name+" cargo producing list change : "+test.Count()+" cargos",1); }
	thatstation.s_CargoProduce.Clear();
	thatstation.s_CargoProduce.AddList(test);
	}

function cStation::GetLocation(stationID=null)
// avoid errors, return station location
	{
	local thatstation=null;
	if (stationID == null)	{ thatstation=this; }
					else	{ thatstation=cStation.Load(stationID); }
	if (!thatstation)	{ return -1; }
	if (thatstation.s_Type == AIStation.STATION_TRAIN)	{ return thatstation.s_Train[TrainType.START_POINT]; }
	return AIStation.GetLocation(thatstation.s_ID);
	}


