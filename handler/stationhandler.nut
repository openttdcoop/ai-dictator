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
						// for airport, 1st value = 0- big planes, 1- small planes, 2- chopper, 3=townID attach to it
	depot			= null;	// depot position and id are the same
	cargo_produce	= null;	// cargos ID produce at station, value = amount waiting
	cargo_accept	= null;	// cargos ID accept at station, value = cargo rating
	radius		= null;	// radius of the station
	vehicle_count	= null;	// vehicle using that station
	vehicle_max		= null;	// max vehicle that station could handle
	vehicle_capacity	= null;	// total capacity of all vehicle using the station, item=cargoID, value=capacity
	owner			= null;	// list routes that own that station
	lastUpdate		= null;	// record last date we update infos for the station
	
	constructor()
		{
		stationID		= null;
		stationType		= null;
		specialType		= null;
		size			= 1;
		maxsize		= 1;
		locations		= AIList();
		depot			= null;
		cargo_produce	= AIList();
		cargo_accept	= AIList();
		radius		= 0;
		vehicle_count	= 0;	
		vehicle_max		= 0;
		vehicle_capacity	= AIList();
		owner			= AIList();
		lastUpdate		= 0;
		}
}

function cStation::UpdateStationInfos()
// Update informations for that station if informations are old enough
	{
	local now=AIDate.GetCurrentDate();
	if ( (now - this.lastUpdate) < 7)	return false;
	this.UpdateCapacity();
	this.lastUpdate=now;
	this.UpdateCargos();
	}

function cStation::UpdateCargos(stationID=null)
// Update Cargos waiting & rating at station
	{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.GetStationObject(stationID);
	local allcargos=AIList();
	allcargos.AddList(thatstation.cargo_produce);
	allcargos.AddList(thatstation.cargo_accept);
	foreach (cargo, value in allcargos)
		{
		INSTANCE.Sleep(1);
		if (thatstation.cargo_produce.HasItem(cargo))
			{
			local waiting=AIStation.GetCargoWaiting(thatstation.stationID, cargo);
			thatstation.cargo_produce.SetValue(cargo, waiting);
			DInfo("CARGOS-> Station #"+thatstation.stationID+" "+AIStation.GetName(thatstation.stationID)+" produce "+AICargo.GetCargoLabel(cargo)+" with "+waiting+" units",2);
			}
		if (thatstation.cargo_accept.HasItem(cargo))
			{
			local rating=AIStation.GetCargoRating(thatstation.stationID, cargo);
			thatstation.cargo_accept.SetValue(cargo, rating);
			DInfo("CARGOS-> Station #"+thatstation.stationID+" "+AIStation.GetName(thatstation.stationID)+" accept "+AICargo.GetCargoLabel(cargo)+" with "+rating+" rating",2);
			}
		}
	}

function cStation::UpdateCapacity()
// Update the capacity of vehicles using the station
	{
	local temp=AIVehicleList_Station(this.stationID);
	if (temp.IsEmpty())	return;
	local allveh=AIList();	// keep compatibility with 1.0.4, 1.0.5
	allveh.AddList(temp);
	temp=AICargoList();
	local allcargos=AIList();
	allcargos.AddList(temp);
	foreach (cargoID, dummy in allcargos)	allcargos.SetValue(cargoID, 0);
	foreach (veh, vehdummy in allveh)
		{
		local vehcapacity=0;
		local vehtype=AIVehicle.GetVehicleType(veh);
		if (vehtype == AIVehicle.VT_AIR)
			{  // for aircrafts we only check passenger capacity, because mail capacity would make it fail else
			local cargoID=cCargo.GetPassengerCargo();
			vehcapacity=AIVehicle.GetCapacity(veh, cargoID);
			local stacapacity=allcargos.GetValue(cargoID);
			if (vehcapacity > 0)	allcargos.SetValue(cargoID, stacapacity+vehcapacity);
			INSTANCE.Sleep(1);
			}
		else	{
			foreach (cargoID, fullcapacity in allcargos)
				{
				vehcapacity=AIVehicle.GetCapacity(veh, cargoID);
				if (vehcapacity > 0)
					{
					allcargos.SetValue(cargoID, fullcapacity+vehcapacity);
					break;
					}
				INSTANCE.Sleep(1);
				}
			}
		}
	this.vehicle_capacity.Clear();
	this.vehicle_capacity.AddList(allcargos);
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
			if (newairport > this.specialType)
				{ DInfo("NEW AIRPORT AVAIABLE ! "+newairport,2); }
			if (this.locations.Count()==1)	return false; // plaforms have 1 size only
			if (newairport > this.specialType)	return true;
								else	return false;
		break;
		default: // bus or truck
			this.vehicle_max=this.size*INSTANCE.carrier.road_upgrade;
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

function cStation::IsCargoProduce(cargoID, stationID=null)
// Check if a cargo is produce at that station
	{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.GetStationObject(stationID);
	if (thatstation == null)	return;
	return thatstation.cargo_produce.HasItem(cargoID);
	}

function cStation::IsCargoAccept(cargoID, stationID=null)
// Check if a cargo is accept at that station
	{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.GetStationObject(stationID);
	if (thatstation == null)	return;
	return thatstation.cargo_accept.HasItem(cargoID);
	}

function cStation::CheckCargoHandleByStation(stationID=null)
// Check what cargo is accept or produce at station
	{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.GetStationObject(stationID);
	if (thatstation == null)	return;
	thatstation.cargo_produce.Clear();
	thatstation.cargo_accept.Clear();
	local cargolist=AICargoList();
	foreach (tiles, dummy in thatstation.locations)
		{
		INSTANCE.Sleep(1);
		foreach (cargo_id, dummy in cargolist)
			{
			local valid=true;
			if (thatstation.stationType == AIStation.STATION_BUS_STOP && cargo_id != cCargo.GetPassengerCargo())	valid=false;
			if (thatstation.stationType == AIStation.STATION_TRUCK_STOP && cargo_id == cCargo.GetPassengerCargo())	valid=false;
			if (thatstation.stationType == AIStation.STATION_AIRPORT && cargo_id != cCargo.GetPassengerCargo() && cargo_id != cCargo.GetMailCargo())	valid=false;
			if (thatstation.cargo_accept.HasItem(cargo_id) && thatstation.cargo_produce.HasItem(cargo_id))	valid=false;
			if (!valid)	continue;
			local accept=AITile.GetCargoAcceptance(tiles, cargo_id, 1, 1, thatstation.radius);
			local produce=AITile.GetCargoProduction(tiles, cargo_id, 1, 1, thatstation.radius);
			local valid=true;
			if (accept > 7 && valid)	thatstation.cargo_accept.AddItem(cargo_id, accept);
			if (produce > 0 && valid)	thatstation.cargo_produce.AddItem(cargo_id, produce);
			}
		}
	//thatstation.UpdateCargos();
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
// Route claims ownership for that station
	{
	if (!this.owner.HasItem(uid))
		{
		this.owner.AddItem(uid,1);
		DInfo("STATIONS -> Route #"+uid+" claims station #"+this.stationID+". "+this.owner.Count()+" routes are sharing it",1);
		this.UpdateStationInfos()
		}
	}

function cStation::OwnerReleaseStation(uid)
// Route unclaims the ownership for that station, ask to destroy the station if no more owner own it
	{
	if (this.owner.HasItem(uid))
		{
		this.owner.RemoveItem(uid);
		DInfo("STATIONS -> Route #"+uid+" release station #"+this.stationID+". "+this.owner.Count()+" routes are sharing it",1);
		this.UpdateStationInfos();
		if (this.owner.IsEmpty())
			{
			INSTANCE.builder.DeleteStation(uid, this.stationID);
			}
		}
	}

function cStation::CheckAirportLimits()
// Set limits for airports
	{
	if (!AIStation.IsValidStation(this.stationID))
		{
		DWarn("Invalid airport station ID",1);
		return; // it happen if the airport is moved and now invalid
		}
	locations=cTileTools.FindStationTiles(AIStation.GetLocation(this.stationID));
	this.specialType=AIAirport.GetAirportType(this.locations.Begin());
	if (this.specialType == 255)
		{
		DWarn("Invalid airport type at "+this.locations.Begin(),1);
		PutSign(this.locations.Begin(),"INVALID AIRPORT TYPE !");
		INSTANCE.NeedDelay(100);
		return;
		}
	this.radius=AIAirport.GetAirportCoverageRadius(this.specialType);
	local planetype=0;	// big planes
	if (this.specialType == AIAirport.AT_SMALL)	planetype=1; // small planes
	this.locations.SetValue(this.locations.Begin(), planetype);
	this.depot=AIAirport.GetHangarOfAirport(this.locations.Begin());
	local virtualized=cStation.IsStationVirtual(this.stationID);
	// get out of airnetwork if the network is too poor
	local rawlimit=INSTANCE.carrier.AirportTypeLimit[this.specialType];
	DInfo("rawlimit="+rawlimit+" type="+this.specialType,1);
	this.vehicle_max=rawlimit;
	if (virtualized)	this.vehicle_max=INSTANCE.carrier.airnet_max * cCarrier.VirtualAirRoute.len();
	if (this.vehicle_max > rawlimit)	this.vehicle_max=rawlimit;
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
			DInfo("Airport size: "+this.locations.Count(),2);
		break;
		}
	// for everyone, the cargos
	this.vehicle_count=0;
	this.StationSave();
	local dummy=this.CanUpgradeStation(); // just to set max_vehicle
	this.CheckCargoHandleByStation();
	this.UpdateStationInfos();
	}

function cStation::IsStationVirtual(stationID)
// return true if the station is part of the airnetwork
	{
	return (cCarrier.VirtualAirRoute.len() > 1 && cStation.VirtualAirports.HasItem(stationID));
	}
