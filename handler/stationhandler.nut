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
						// for road, item=tile location, value = front tile location
						// for airport: tiles locations (nothing yet use until we add support for any airport type)
						// for train:
						// 0: station_infos
						// 1: entry_in tile where we should find the entry that lead to the station
						// 2: entry_out
						// 3: exit_in
						// 4: exit_out
						// 5: entry_crossing
						// 6: exit_crossing
						// 7: number of train dropper using entry
						// 8: number of train dropper using exit
						// 9: number of train taker using entry
						// 10: number of train taker using exit
						// 11: entry_in_link tile to pathfind to enter the station by IN point
						// 12: entry_out_link
						// 13: exit_in_link
						// 14: exit_out_link
						// 15: depot for exit, entry depot is "cstation.depot"
						// 16: startpoint : when created, tile where the start of station is == AIStation.GetLocation
						// 17: endpoint : when created, tile where the end of station is
						// 18: direction: when created, the direction of the station return by AIRail.GetRailStationDirection
						// 19: depth: when created, the lenght (depth) the station is, for its width, "cstation.size" keep that info
	depot			= null;	// depot position and id are the same
	cargo_produce	= null;	// cargos ID produce at station, value = amount waiting
	cargo_accept	= null;	// cargos ID accept at station, value = cargo rating
	radius		= null;	// radius of the station
	vehicle_count	= null;	// vehicle using that station
	vehicle_max		= null;	// max vehicle that station could handle
	vehicle_capacity	= null;	// total capacity of all vehicle using the station, item=cargoID, value=capacity
	owner			= null;	// list routes that own that station
	lastUpdate		= null;	// record last date we update infos for the station
	moneyUpgrade	= null;	// money we need for upgrading the station
	name			= null;	// station name
	platform_entry	= null;	// railstation platforms AIList, item=fronttileplaformentry, value: 1=useable 0=closed
	platform_exit	= null;	// railstation platforms AIList, item=fronttileplaformexit, value: 1=useable 0=closed
// station size = (tte)+(tde / 2)+(ttx)+(tdx/2)
// station size >=3 + connect all front & back tiles
// station size =2
/* train station are made like that:
station_infos:
bit0 entry is working on/off
bit1 exit is working on/off
bit2 south/west escape line is working on/off
bit3 north/east escape line is working on/off
bit4 use semaphore on/off (unuse as i don't know how to get semaphore from api yet)

train_entry_in = tile location of rails we should connect a rail route to use that station entry to go in
train_entry_out= tile location... to use that station entry to get out of the station
train_exit_in  = tile location of rails we should connect a rail route to use that station entry to go in
train_exit_out = tile location... to use that station exit to get out of the station
crossing       = tile location where rails cross each other to connect parrallel lines, distance from station may vary but always >1 tiles and < XxEe


 - = rail, S = station, E=entry in, e=entry out, X=exit in, x=exit out, L&l=escape lines, F=a fire
\/ crossing point, where the rail cross each other
/\ crossing point can be +2 +5 from S
	       /-FLLLLLLLLLLF-\
	-E-F-\/--F-SSSSSSSS-F--\/-F-X--
	-e-F-/\--F-SSSSSSSS-F--/\-F-x--
	       \-FllllllllllF-/
*/
	
	constructor()
		{
		stationID		= null;	// * = info is save
		stationType		= null;	// *
		specialType		= null;	// *
		size			= 1;    	// *
		maxsize		= 1;    	// *
		locations		= AIList(); // *
		depot			= -1;		// *
		cargo_produce	= AIList();
		cargo_accept	= AIList();
		radius		= 0;		// *
		vehicle_count	= 0;	
		vehicle_max		= 0;
		vehicle_capacity	= AIList();
		owner			= AIList();	// * save but unuse, reclaims when loading
		lastUpdate		= 0;
		moneyUpgrade	= 0;
		name			= null;
		platform_entry	= AIList();
		platform_exit	= AIList();
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
			DInfo("CARGOS-> Station #"+thatstation.stationID+" "+AIStation.GetName(thatstation.stationID)+" produce "+AICargo.GetCargoLabel(cargo)+" with "+waiting+" units",2,"cStation::UpdateCargos");
			}
		if (thatstation.cargo_accept.HasItem(cargo))
			{
			local rating=AIStation.GetCargoRating(thatstation.stationID, cargo);
			thatstation.cargo_accept.SetValue(cargo, rating);
			DInfo("CARGOS-> Station #"+thatstation.stationID+" "+AIStation.GetName(thatstation.stationID)+" accept "+AICargo.GetCargoLabel(cargo)+" with "+rating+" rating",2,"cStation::UpdateCargos");
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
		{ DInfo("Station #"+this.stationID+" already in database "+cStation.stationdatabase.len(),2,"cStation::StationSave"); }
	else	{
		DInfo("Adding station : "+this.stationID+" to station database",2,"cStation::StationSave");
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
				{ DInfo("NEW AIRPORT AVAIABLE ! "+newairport,2,"cStation::CanUpgradeStation"); }
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
	local staloc=cTileTools.FindStationTiles(AIStation.GetLocation(thatstation.stationID));
	foreach (cargo_id, cdummy in cargolist)
		{
		foreach (tiles, sdummy in staloc)
			{
			if (thatstation.cargo_accept.HasItem(cargo_id) || thatstation.cargo_produce.HasItem(cargo_id))	break;
			local valid=true;
			switch (thatstation.stationType)
				{
				case AIStation.STATION_BUS_STOP:
					if (cargo_id != cCargo.GetPassengerCargo())	valid=false;
					break;
				case AIStation.STATION_TRUCK_STOP:
					if (cargo_id == cCargo.GetPassengerCargo())	valid=false;
					break;
				case AIStation.STATION_AIRPORT:
					if (cargo_id != cCargo.GetPassengerCargo() && cargo_id != cCargo.GetMailCargo()) valid=false;
					break;
				case AIStation.STATION_TRAIN:
					break;
				case AIStation.STATION_DOCK:
					break;
				}
			if (!valid)	break;
			local accept=AITile.GetCargoAcceptance(tiles, cargo_id, 1, 1, thatstation.radius);
			local produce=AITile.GetCargoProduction(tiles, cargo_id, 1, 1, thatstation.radius);
			if (accept > 7 && valid)	thatstation.cargo_accept.AddItem(cargo_id, accept);
			if (produce > 0 && valid)	thatstation.cargo_produce.AddItem(cargo_id, produce);
			INSTANCE.Sleep(1);
			}
		INSTANCE.Sleep(1);
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
			DInfo("Removing station #"+stationid+" from station database",1,"cStation::DeleteStation");
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
		DInfo("Route #"+uid+" claims station #"+this.stationID+". "+this.owner.Count()+" routes are sharing it",1,"cStation::ClaimOwner");
		this.UpdateStationInfos()
		}
	}

function cStation::OwnerReleaseStation(uid)
// Route unclaims the ownership for that station, ask to destroy the station if no more owner own it
	{
	if (this.owner.HasItem(uid))
		{
		this.owner.RemoveItem(uid);
		DInfo("Route #"+uid+" release station #"+this.stationID+". "+this.owner.Count()+" routes are sharing it",1,"cStation::OwnerReleaseStation");
		this.UpdateStationInfos();
		if (this.owner.IsEmpty())
			{
			INSTANCE.builder.DeleteStation(uid, this.stationID);
			}
		}
	}

function cStation::IsDepot(tile)
// return true if we have a depot at tile
	{
	if (tile == null)	return false;
	local isDepot=(AIMarine.IsWaterDepotTile(tile) || AIRoad.IsRoadDepotTile(tile) || AIRail.IsRailDepotTile(tile) || AIAirport.IsHangarTile(tile));
	return isDepot;
	}

function cStation::CheckAirportLimits()
// Set limits for airports
	{
	if (!AIStation.IsValidStation(this.stationID))
		{
		DWarn("Invalid airport station ID",1,"CheckAirportLimits");
		return; // it happen if the airport is moved and now invalid
		}
	locations=cTileTools.FindStationTiles(AIStation.GetLocation(this.stationID));
	this.specialType=AIAirport.GetAirportType(this.locations.Begin());
	if (this.specialType == 255)
		{
		DWarn("Invalid airport type at "+this.locations.Begin(),1,"CheckAirportLimits");
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
	if (this.stationID == null)	{ DWarn("Bad station id : null",1,"InitNewStation"); return; }
	this.stationType = cStation.FindStationType(this.stationID);
	local loc=AIStation.GetLocation(this.stationID);
	this.locations=cTileTools.FindStationTiles(loc);
	if (this.stationType != AIStation.STATION_AIRPORT)	this.radius=AIStation.GetCoverageRadius(this.stationType);
	// avoid getting the warning message for coverage of airport with that function
	switch	(this.stationType)
		{
		case	AIStation.STATION_TRAIN:
			this.specialType=AIRail.GetRailType(loc); // set rail type the station use
			this.maxsize=INSTANCE.carrier.rail_max; this.size=1;
			this.locations=AIList();
			for (local zz=0; zz < 20; zz++)	this.locations.AddItem(zz,-1); // create special cases for train usage
			for (local zz=7; zz < 11; zz++)	this.locations.SetValue(zz,0);
			this.locations.SetValue(0,1+2); // enable IN && OUT for the new station
			this.GetRailStationMiscInfo();
			this.maxsize=1; // TODO: remove the upgrade blocker
		break;
		case	AIStation.STATION_DOCK:		// TODO: do it
			this.maxsize=1; this.size=1;
		break;
		case	AIStation.STATION_BUS_STOP:
		case	AIStation.STATION_TRUCK_STOP:
			this.maxsize=INSTANCE.carrier.road_max;
			this.size=locations.Count();
			if (AIRoad.HasRoadType(locations.Begin(), AIRoad.ROADTYPE_ROAD))
				this.specialType=AIRoad.ROADTYPE_ROAD;	// set road type the station use
			else	this.specialType=AIRoad.ROADTYPE_TRAM;
			foreach(loc, dummy in this.locations)	this.locations.SetValue(loc, AIRoad.GetRoadStationFrontTile(loc));
		break;
		case	AIStation.STATION_AIRPORT:
			this.maxsize=1000; // airport size is limited by airport avaiability
			this.size=this.locations.Count();
			this.specialType=AIAirport.GetAirportType(this.locations.Begin());
			this.radius=AIAirport.GetAirportCoverageRadius(this.specialType);
			this.depot=AIAirport.GetHangarOfAirport(loc);
			DInfo("Airport size: "+this.locations.Count(),2,"InitNewStation");
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

function cStation::GetRailStationMiscInfo(stationID=null)
// Setup misc infos about a station, we shouldn't use that function direcly as it's an helper to cStation::InitNewStation()
// stationID: the stationID to check
{
local thatstation=null;
if (stationID == null)	thatstation=this;
			else	thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return -1;
local stalenght=0;
local entrypos=AIStation.GetLocation(thatstation.stationID);
local direction, frontTile, backTile=null;
direction=AIRail.GetRailStationDirection(entrypos);
if (direction == AIRail.RAILTRACK_NW_SE)
	{
	frontTile=AIMap.GetTileIndex(0,-1);
	backTile=AIMap.GetTileIndex(0,1);
	}
else	{ // NE_SW
	frontTile=AIMap.GetTileIndex(-1,0);
	backTile=AIMap.GetTileIndex(1,0);
	}
ClearSignsALL();
local exitpos=null;
PutSign(entrypos,"Start");
local scanner=entrypos;
while (AIRail.IsRailStationTile(scanner))	{ stalenght++; scanner+=backTile; PutSign(scanner,"."); INSTANCE.NeedDelay(10); }
exitpos=scanner+frontTile;
PutSign(exitpos,"End");
DInfo("Rail station depth is "+stalenght+" direction="+direction+" start="+entrypos+" end="+exitpos,1,"cStation::GetRailStationMiscInfo");
thatstation.locations.SetValue(16,entrypos);
thatstation.locations.SetValue(17,exitpos);
thatstation.locations.SetValue(18,direction);
thatstation.locations.SetValue(19,stalenght);
ClearSignsALL();
}

function cStation::GetRailStationFrontTile(entry, platform, stationID=null)
// like AIRail.GetRailDepotFrontTile but with a rail station
// entry: true to return front tile of the station entry, else front tile of station exit (end of station)
// platform: the platform location to find entry/exit front tile
// stationID: the rail stationID
// return -1 on error
{
local thatstation=null;
if (stationID == null)	thatstation=this;
			else	thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return -1;
local direction=thatstation.locations.GetValue(18);
local start=thatstation.locations.GetValue(16);
local end=thatstation.locations.GetValue(17);
local frontTile=null;
if (direction==AIRail.RAILTRACK_NE_SW)
		{
		start=AIMap.GetTileIndex(AIMap.GetTileX(start),AIMap.GetTileY(platform))+AIMap.GetTileIndex(-1,0);
		end=AIMap.GetTileIndex(AIMap.GetTileX(end),AIMap.GetTileY(platform))+AIMap.GetTileIndex(1,0);
		}
	else	{
		start=AIMap.GetTileIndex(AIMap.GetTileX(platform),AIMap.GetTileY(start))+AIMap.GetTileIndex(0,-1);
		end=AIMap.GetTileIndex(AIMap.GetTileX(platform),AIMap.GetTileY(end))+AIMap.GetTileIndex(0,1);
		}
if (entry)	frontTile=start;
	else	frontTile=end;
PutSign(frontTile,"Front="+entry);
ClearSignsALL();
return frontTile;
}

function cStation::IsRailStationEntryOpen(stationID=null)
// return true if station entry bit is set
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.locations.GetValue(0);
if ((entry & 1) == 1)	{ DInfo("station "+stationID+" entry is open",2,"cStation::IsRailStationEntryOpen"); return true; }
DInfo("station "+stationID+" entry is CLOSE",2,"cStation::IsRailStationEntryOpen");
return false;
}

function cStation::IsRailStationExitOpen(stationID=null)
// return true if station exit bit is set
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.locations.GetValue(0);
if ((exit & 2) == 2)	{ DInfo("station "+stationID+" exit is open",2,"cStation::IsRailStationExitOpen"); return true; }
DInfo("station "+stationID+" exit is CLOSE",2,"cStation::IsRailStationExitOpen");
return false;
}

function cStation::RailStationCloseEntry(stationID=null)
// return true if station entry bit is set
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.locations.GetValue(0);
entry=entry ^ 1;
thatstation.locations.SetValue(0, entry);
DInfo("Closing the entry of station "+thatstation.GetName(),1,"RailStationCloseEntry");
}

function cStation::RailStationCloseExit(stationID=null)
// Unset exit bit of the station
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.locations.GetValue(0);
exit=exit ^ 2;
thatstation.locations.SetValue(0, exit);
DInfo("Closing the exit of station "+thatstation.GetName(),1,"RailStationCloseExit");
}

function cStation::GetRailStationIN(getEntry, stationID=null)
// Return the tile where the station IN point is
// getEntry = true to return the entry IN, false to return exit IN
// If the IN point doesn't exist, return the virtual position where the station IN would be (default=fronttile of station)
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return -1;
return thatstation.GetRailStationFrontTile(getEntry,thatstation.GetLocation());
}

function cStation::GetRailStationOUT(getEntry, stationID=null)
// Return the tile where the station OUT point is
// getEntry = true to return the entry OUT, false to return exit OUT
// If the OUT point doesn't exist, return the virtual position where the station OUT would be (default= left fronttile of station)
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation.GetRailStationDirection()==AIRail.RAILTRACK_NE_SW)
	return (thatstation.GetRailStationIN(getEntry)+AIMap.GetTileIndex(0,-1));
else	return (thatstation.GetRailStationIN(getEntry)+AIMap.GetTileIndex(-1,0));
}

function cStation::GetRailStationDirection()	{ return this.locations.GetValue(18); }
// avoid errors by returning proper index for direction of a station

function cStation::GetLocation(stationID=null)
// avoid errors, return station location
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return -1;
if (thatstation.stationType==AIStation.STATION_TRAIN)	return thatstation.locations.GetValue(16);
return AIStation.GetLocation(thatstation.stationID);
}

function cStation::GetName(stationID=null)
// return name of the station
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return "BAD STATIONID";
if (thatstation.name == null)	thatstation.name=AIStation.GetName(thatstation.stationID);
return thatstation.name;
}

function cStation::PlatformGetNumberOpen(useEntry, stationID=null)
// return the number of platforms that station have with useable entries (they are working & connected)
{
local counter=0;
local whatPlatform=null;
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return "BAD STATIONID";
if (useEntry)	whatPlatform=thatstation.platform_entry;
		else	whatPlatform=thatstation.platform_exit;
foreach (platform, status in whatPlatform)	if (status==1)	counter++;
return counter;
}

function cStation::PlatformIsOpen(useEntry, platform)
// return the status of a platform
{
local thatstation=null;
local stationID=AIStation.GetStationID(platform);
local whatPlatform=null;
thatstation=cStation.GetStationObject(stationID);
if (useEntry)	whatPlatform=thatstation.platform_entry;
		else	whatPlatform=thatstation.platform_exit;
return (whatPlatform.GetValue(platform)==1);
}

function cStation::GetRailDepot(stationID=null)
// Return a valid rail depot for that stationID
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return "BAD STATIONID";
if (cStation.IsDepot(thatstation.depot))	return thatstation.depot;
if (cStation.IsDepot(thatstation.locations.GetValue(15)))	return thatstation.locations.GetValue(15);
return -1;
}
