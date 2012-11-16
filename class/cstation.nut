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

class cStation extends cClass
{
static	stationdatabase = {};
static	VirtualAirports = AIList();	// stations in the air network as item, value=towns
static	function GetStationObject(stationID)
		{
		return stationID in cStation.stationdatabase ? cStation.stationdatabase[stationID] : null;
		}

	s_ID			= null;	// id of station
	s_Type		= null;	// AIStation.StationType
	s_SubType		= null;	// Special subtype of station (depend on station)
	s_DateBuilt		= null;	// Date when the station was built
	s_Location		= null;	// Location of station
	s_Depot		= null;	// depot position and id are the same
	s_Size		= null;	// size of station: road = number of stations, trains=width, airport=width*height
	s_MaxSize		= null; 	// maximum size a station could be
	s_CargoProduce	= null;	// cargos ID produce at station, value = amount waiting
	s_CargoAccept	= null;	// cargos ID accept at station, value = cargo rating
	s_CargoUpdate	= null;	// Last time we update cargo info
	s_Radius		= null;	// radius of the station
	s_VehicleCount	= null;	// vehicle using that station
	s_VehicleMax	= null;	// max vehicle that station could handle
	s_VehicleCapacity	= null;	// total capacity of all vehicle using the station, item=cargoID, value=capacity
	s_Owner		= null;	// list routes that own that station
	s_LastUpdate	= null;	// record last date we update infos for the station
	s_MoneyUpgrade	= null;	// money we need for upgrading the station
	s_Name		= null;	// station name
	s_Tiles		= null;	// Tiles own by station

	constructor()
		{ // * are saved variables
		this.ClassName="cStation";
		this.s_ID			= null;
		this.s_Type		= null;
		this.s_SubType		= null;
		this.s_DateBuilt		= null;
		this.s_Location		= null;
		this.s_Depot		= null;
		this.s_Size		= 1;
		this.s_MaxSize		= 1;
		this.s_CargoProduce	= AIList();
		this.s_CargoAccept	= AIList();
		this.s_CargoUpdate	= null;
		this.s_Radius		= 0;
		this.s_VehicleCount	= 0;
		this.s_VehicleMax	= 0;
		this.s_VehicleCapacity	= AIList();
		this.s_Owner		= AIList();
		this.s_LastUpdate	= null;
		this.s_MoneyUpgrade	= 0;
		this.s_Name		= "Default Station Name";
		this.s_Tiles		= AIList();
		}
}

// public

function cStation::GetStationName(_stationID)
// Return station name
{
	local thatstation=cStation.Load(_stationID);
	if (!thatstation)	return "invalid StationID(#"+_stationID+")";
	return thatstation.s_Name;
}

function cStation::Load(_stationID)
// Get a station object
{
	local thatstation=cStation.GetStationObject(_stationID);
	if (thatstation == null)	{ DWarn("Invalid stationID : "+_stationID+" Cannot get object",1); return false; }
	return thatstation;
}

function cStation::Save()
// Save the station in the database
	{
	if (this.s_ID in cStation.stationdatabase || this.s_ID == null)
		{ DInfo("Not adding station #"+this.s_ID+" in database "+cStation.stationdatabase.len(),2); }
	else	{
		this.SetStationName();
		DInfo("Adding station : "+this.s_Name+" to station database",2);
		cStation.stationdatabase[this.s_ID] <- this;
		}
	}

function cStation::DeleteStation(stationid)
// Delete the station from database & airport ref
	{
	local s = cStation.Load(stationid);
	if (!s)	return;
	if (s.s_Owner.Count() == 0) // no more own by anyone
		{
		DInfo("Removing station "+s.s_Name+" from station database",1);
		foreach (tile, _ in s.Tiles)	{ cTileTools.UnBlackListTile(tile); }
		delete cStation.stationdatabase[s.ID];
		cStation.VirtualAirports.RemoveItem(s.ID);
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

function cStation::GetStationName(stationID)
// Return station name
{
	local s = cStation.Load(stationID);
	if (!s)	return "Invalid Station #"+stationID;
	return s.s_Name;
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
	if (_StationType == -1)	{ DError("Couldn't determine station type use by station #"+stationID); return null; }
	local _Location = AIStation.GetLocation(stationID);
	local _station = null;
	local nothing = 0; // make sure no foreach bug is bugging us
	switch (_StationType)
		{
		case	AIStation.STATION_TRAIN:
			_station = cStationRail();
			_station.s_SubType = AIRail.GetRailType(_Location); // set rail type the station use
			_station.s_MaxSize = INSTANCE.main.carrier.rail_max;
			for (local zz=0; zz < 23; zz++)	_station.s_TrainSpecs.AddItem(zz,-1); // create special cases for train usage
			for (local zz=7; zz < 11; zz++)	_station.s_TrainSpecs.SetValue(zz,0);
			_station.s_TrainSpecs.SetValue(0,1+2); // enable IN && OUT for the new station
			_station.s_Tiles = cTileTools.FindStationTiles(_Location);
			_station.s_Radius = AIStation.GetCoverageRadius(_StationType);
			_station.GetRailStationMiscInfo();
		break;
		case	AIStation.STATION_DOCK:		// TODO: do boat
			_station = cStationWater();
		break;
		case	AIStation.STATION_BUS_STOP:
		case	AIStation.STATION_TRUCK_STOP:
			_station = cStationRoad();
			_station.s_MaxSize = INSTANCE.main.carrier.road_max;
			_station.s_Tiles = cTileTools.FindStationTiles(_Location);
			_station.s_Size = _station.s_Tiles.Count();
			_station.s_SubType = AIRoad.ROADTYPE_ROAD;
			if (AIRoad.HasRoadType(_Location, AIRoad.ROADTYPE_TRAM))	_station.s_SubType = AIRoad.ROADTYPE_TRAM;
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
	_station.s_DateBuilt = AIBaseStation.GetConstructionDate(stationID);
	_station.s_ID = stationID;
	foreach (tile, _ in _station.s_Tiles)	cStation.StationClaimTile(tile, stationID);
	_station.Save();
	_station.CanUpgradeStation(); // just to set max_vehicle
	return _station;
}

function cStation::CanUpgradeStation()
// check if station could be upgrade
// just return canUpgrade value or for airports true or false if we find a better airport
	{
	if (!cBanker.CanBuyThat(AICompany.GetLoanInterval()))	return false;
	switch (this.s_Type)
		{
		case	AIStation.STATION_DOCK:
			this.s_VehicleMax=INSTANCE.main.carrier.water_max;
			return false;
		break;
		case	AIStation.STATION_TRAIN:
			if (this.s_Size >= this.s_MaxSize)	return false;
			return true;
		break;
		case	AIStation.STATION_AIRPORT:
			local canupgrade=false;
			local newairport = cBuilder.GetAirportType();
			// the per airport type limit doesn't apply to network aircrafts that bypass this check
			local vehlist=AIVehicleList_Station(this.s_ID);
			local townID=AIAirport.GetNearestTown(this.s_Location, this.SubType);
			local townpop=AITown.GetPopulation(townID);
			if (newairport > this.SubType && !vehlist.IsEmpty() && townpop >= (newairport*200))
				{ canupgrade=true; DInfo("NEW AIRPORT AVAILABLE ! "+newairport,2); }
			if (this.s_Tiles.Count()==1)	return false; // plaforms have 1 size only
			return canupgrade;
		break;
		default: // bus or truck
			this.s_VehicleMax=this.s_Size * INSTANCE.main.carrier.road_upgrade;
			if (this.s_Size >= this.s_MaxSize)	return false;
								else	return true;
		break;		
		}
	return false;
	}

function cStation::UpdateStationInfos()
// Update informations for that station if informations are old enough
	{
	local now = AIDate.GetCurrentDate();
	if (this.s_LastUpdate != null && now - this.s_LastUpdate < 20)	{ DInfo("Station "+this.s_Name+" infos are fresh",2); return; }
	DInfo("Refreshing station "+this.s_Name+" infos",2);
	this.s_LastUpdate = now;
	this.UpdateCapacity();
	this.UpdateCargos();
	}

function cStation::IsDepot(tile)
// return true if we have a depot at tile
	{
	if (tile == null)	return false;
	local isDepot=(AIMarine.IsWaterDepotTile(tile) || AIRoad.IsRoadDepotTile(tile) || AIRail.IsRailDepotTile(tile) || AIAirport.IsHangarTile(tile));
	return isDepot;
	}

function cStation::IsStationVirtual(stationID)
// return true if the station is part of the airnetwork
	{
	return (cCarrier.VirtualAirRoute.len() > 1 && cStation.VirtualAirports.HasItem(stationID));
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

function cStation::StationClaimTile(tile, stationID)
// Add a tile as own by stationID
{
	cTileTools.BlackListTile(tile, stationID);
}

function cStation::UpdateCargos(stationID=null)
// Update Cargos waiting & rating at station
// This function doesn't produce real cargo production/acceptance at station, but only the ones we care about
	{
	local thatstation=false;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.Load(stationID);
	if (!thatstation)	return;
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
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.Load(stationID);
	if (!thatstation)	return;
	local vehlist=AIVehicleList_Station(thatstation.s_ID);
	local allcargos=AICargoList();
	local mail = cCargo.GetMailCargo();
	local pass = cCargo.GetPassengerCargo();
	foreach (cargoID, dummy in allcargos)
		{
		local newcap = 0;
		vehlist.Valuate(AIVehicle.GetCapacity, cargoID);
		foreach (vehID, capacity in vehlist)
			{
			if (capacity > 0)
				{
				// We will speedup checks, lowering vehicle list on each found cargo. It will then create a lost of cargo for multi-cargo vehicle
				// like aircrafts that use mail/passenger, only mail or passenger will be count as the vehicle is removed from list.
				// That's why we kept the vehicle for these cargos.
				newcap += capacity;
				if (cargoID != mail && cargoID != pass)	vehlist.RemoveItem(vehID);
				}
			local sleeper = cLooper();
			}
		allcargos.SetValue(cargoID, newcap);
		if (newcap != thatstation.s_VehicleCapacity.GetValue(cargoID))
			DInfo("Station "+thatstation.s_Name+" new total capacity set to "+newcap+" for "+cCargo.GetCargoLabel(cargoID),2);
		}
	thatstation.s_VehicleCapacity.Clear();
	thatstation.s_VehicleCapacity.AddList(allcargos);
	}


// old to check

function cStation::IsCargoProduceAccept(cargoID, produce_query, stationID=null)
// Warper to anwer to cStation::IsCargoProduce and IsCargoAccept
// produce_query to true to answer produce, false to answer accept
	{
	local thatstation=false;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.Load(stationID);
	if (!thatstation)	return false;
//	local staloc=cTileTools.FindStationTiles(AIStation.GetLocation(thatstation.stationID));
	foreach (tiles, sdummy in thatstation.s_Tiles)
		{
		local success=false;
		local value=0;
		if (produce_query)
			{
			value=AITile.GetCargoProduction(tiles, cargoID, 1, 1, thatstation.s_Radius);
			success=(value > 0);
			}
		else	{
			value=AITile.GetCargoAcceptance(tiles, cargoID, 1, 1, thatstation.s_Radius);
			success=(value > 7);
			}
		if (success)	return true;
		}
	return false;
	}

function cStation::IsCargoProduce(cargoID, stationID=null)
// Check if a cargo is produce at that station
	{
	local thatstation=false;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.Load(stationID);
	return thatstation.IsCargoProduceAccept(cargoID, true, stationID);
	}

function cStation::IsCargoAccept(cargoID, stationID=null)
// Check if a cargo is accept at that station
	{
	local thatstation=false;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.Load(stationID);
	return thatstation.IsCargoProduceAccept(cargoID, false, stationID);
	}

function cStation::CheckCargoHandleByStation(stationID=null)
// Check what cargo is accept or produce at station
// This doesn't really check if the cargo is produce/accept, but only if the station know that cargo should be accept/produce
// This so, doesn't include unknown cargos that the station might handle but is not aware of
// Use cStation::IsCargoProduceAccept for a real answer
// That function is there to faster checks, not to gave true answer
	{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.GetStationObject(stationID);
	if (thatstation == null)	return;
	local cargolist=AIList();
	cargolist.AddList(thatstation.cargo_accept);
	cargolist.AddList(thatstation.cargo_produce);
	local cargomail=cCargo.GetMailCargo();
	local cargopass=cCargo.GetPassengerCargo();
	local staloc=cTileTools.FindStationTiles(AIStation.GetLocation(thatstation.stationID));
	foreach (cargo_id, cdummy in cargolist)
		{
		local valid_produce=false;
		local valid_accept=false;
		foreach (tiles, sdummy in staloc)
			{
			if (valid_accept && valid_produce)	break;
			local accept=AITile.GetCargoAcceptance(tiles, cargo_id, 1, 1, thatstation.radius);
			local produce=AITile.GetCargoProduction(tiles, cargo_id, 1, 1, thatstation.radius);
			if (!valid_produce && produce > 0)	valid_produce=true;
			if (!valid_accept && accept > 7)	valid_accept=true;
			}
		if (!valid_produce && thatstation.cargo_produce.HasItem(cargo_id))
			{
			DInfo("Station "+thatstation.name+" no longer produce "+AICargo.GetCargoLabel(cargo_id),1);
			thatstation.cargo_produce.RemoveItem(cargo_id);
			}
		if (!valid_accept && thatstation.cargo_accept.HasItem(cargo_id))
			{
			DInfo("Station "+thatstation.name+" no longer accept "+AICargo.GetCargoLabel(cargo_id),1);
			thatstation.cargo_accept.RemoveItem(cargo_id);
			}
		INSTANCE.Sleep(1);
		}
	}



