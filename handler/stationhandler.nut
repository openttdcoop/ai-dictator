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
						// 20: most left platform position
						// 21: most right platform position
						// 22: main route owner
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
	platforms		= null;	// railstation platforms AIList, item=fronttileplaformentry, value: 1=useable 0=closed
	station_tiles	= null;	// railstation tiles own by the station, value=1 entry or 0 exit

/* train station are made like that:
station_infos:
bit0 entry is working on/off
bit1 exit is working on/off
bit2 south/west escape line is working on/off
bit3 north/east escape line is working on/off
bit4 main train line fire done
bit5 alt train line fire done
*/
	
	constructor()
		{ // * are saved variables
		stationID		= null;	// *
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
		owner			= AIList();
		lastUpdate		= 0;
		moneyUpgrade	= 0;
		name			= null;
		platforms		= AIList(); // * item= platform location, value=bit0 for entry, bit1 for exit on/off
		station_tiles	= AIList();	// *
		}
}

function cStation::UpdateStationInfos()
// Update informations for that station if informations are old enough
	{
	this.UpdateCapacity();
	local now=AIDate.GetCurrentDate();
//	if ( (now - this.lastUpdate) < 7)	return false;
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
	if (AIAirport.IsAirportTile(AIStation.GetLocation(thatstation.stationID)))
		{
		
		}
	foreach (cargo, value in allcargos)
		{
		if (thatstation.cargo_produce.HasItem(cargo))
			{
			local waiting=AIStation.GetCargoWaiting(thatstation.stationID, cargo);
			thatstation.cargo_produce.SetValue(cargo, waiting);
			DInfo("CARGOS-> Station "+cStation.StationGetName(thatstation.stationID)+" produce "+AICargo.GetCargoLabel(cargo)+" with "+waiting+" units",2,"cStation::UpdateCargos");
			}
		if (thatstation.cargo_accept.HasItem(cargo))
			{
			local rating=AIStation.GetCargoRating(thatstation.stationID, cargo);
			thatstation.cargo_accept.SetValue(cargo, rating);
			DInfo("CARGOS-> Station #"+thatstation.stationID+" "+cStation.StationGetName(thatstation.stationID)+" accept "+AICargo.GetCargoLabel(cargo)+" with "+rating+" rating",2,"cStation::UpdateCargos");
			}
		INSTANCE.Sleep(1);
		}
	}

function cStation::UpdateCapacity(stationID=null)
// Update the capacity of vehicles using the station
	{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.GetStationObject(stationID);
	local vehlist=AIVehicleList_Station(thatstation.stationID);
	local allcargos=AICargoList();
	foreach (cargoID, dummy in allcargos)
		{
		local tvehlist=AIList();
		tvehlist.AddList(vehlist);
		tvehlist.Valuate(AIVehicle.GetCapacity,cargoID);
		tvehlist.RemoveValue(0);
		if (tvehlist.IsEmpty())	continue;
		local newcap=0;
		foreach (veh, cap in tvehlist)	newcap+=cap;
		allcargos.SetValue(cargoID, newcap);
		if (newcap != thatstation.vehicle_capacity.GetValue(cargoID))
			DInfo("Station "+thatstation.name+" new total capacity set to "+newcap+" for "+AICargo.GetCargoLabel(cargoID),2,"cStation::UpdateCapacity");
		INSTANCE.Sleep(1);
		}
	thatstation.vehicle_capacity.Clear()
	thatstation.vehicle_capacity.AddList(allcargos);
	}

function cStation::StationGetName(stationID=null)
// return name of a station
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.GetStationObject(stationID);
	if (thatstation==null)	return AIStation.GetName(stationID);
	if (thatstation.name==null)	thatstation.StationSetName();
	return thatstation.name;
}

function cStation::StationSetName(stationID=null)
// set name of a station
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.GetStationObject(stationID);
	if (thatstation.name==null)
		{
		thatstation.name=AIStation.GetName(this.stationID)+"(#"+this.stationID+")";
		}
}

function cStation::StationSave()
// Save the station in the database
	{
	if (this.stationID in cStation.stationdatabase)
		{ DInfo("Station #"+this.stationID+" already in database "+cStation.stationdatabase.len(),2,"cStation::StationSave"); }
	else	{
		this.StationSetName();
		DInfo("Adding station : "+this.name+" to station database",2,"cStation::StationSave");
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
			if (this.size >= this.maxsize)	return false;
			return true;
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

function cStation::IsCargoProduceAccept(cargoID, produce_query, stationID=null)
// Warper to anwer to cStation::IsCargoProduce and IsCargoAccept
// produce_query to true to answer produce, false to answer accept
	{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
				else	thatstaiton=cStation.GetStationObject(stationID);
	if (thatstation == null)	return;
	local staloc=cTileTools.FindStationTiles(AIStation.GetLocation(thatstation.stationID));
	foreach (tiles, sdummy in staloc)
		{
		local success=false;
		local value=0;
		if (produce_query)
			{
			value=AITile.GetCargoProduction(tiles, cargoID, 1, 1, thatstation.radius);
			success=(value > 0);
			}
		else	{
			value=AITile.GetCargoAcceptance(tiles, cargoID, 1, 1, thatstation.radius);
			success=(value > 7);
			}
		if (success)	return true;
		}
	return false;
	}

function cStation::IsCargoProduce(cargoID, stationID=null)
// Check if a cargo is produce at that station
	{
	return cStation.IsCargoProduceAccept(cargoID, true, stationID);
	}

function cStation::IsCargoAccept(cargoID, stationID=null)
// Check if a cargo is accept at that station
	{
	return cStation.IsCargoProduceAccept(cargoID, false, stationID);
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
			if (valid_accept || valid_produce)	break;
			local accept=AITile.GetCargoAcceptance(tiles, cargo_id, 1, 1, thatstation.radius);
			local produce=AITile.GetCargoProduction(tiles, cargo_id, 1, 1, thatstation.radius);
			if (!valid_produce && produce > 0)	valid_produce=true;
			if (!valid_accept && accept > 7)	valid_accept=true;
			}
		if (!valid_produce && thatstation.cargo_produce.HasItem(cargo_id))	{ DInfo("Station "+thatstation.name+" no longer produce "+AICargo.GetCargoLabel(cargo_id),1,"CheckCargoHandleByStation"); thatstation.cargo_produce.RemoveItem(cargo_id); }
		if (!valid_accept && thatstation.cargo_accept.HasItem(cargo_id))	{ DInfo("Station "+thatstation.name+" no longer accept "+AICargo.GetCargoLabel(cargo_id),1,"CheckCargoHandleByStation");thatstation.cargo_accept.RemoveItem(cargo_id); }
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
			foreach (tile, dummy in statprop.station_tiles)	{ cTileTools.UnBlackListTile(tile); }
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
	foreach (tile, dummy in this.locations)	this.StationClaimTile(tile, this.stationID);
	if (this.stationType != AIStation.STATION_AIRPORT)	this.radius=AIStation.GetCoverageRadius(this.stationType);
	// avoid getting the warning message for coverage of airport with that function
	switch	(this.stationType)
		{
		case	AIStation.STATION_TRAIN:
			this.specialType=AIRail.GetRailType(loc); // set rail type the station use
			this.maxsize=INSTANCE.carrier.rail_max; this.size=1;
			this.locations=AIList();
			for (local zz=0; zz < 23; zz++)	this.locations.AddItem(zz,-1); // create special cases for train usage
			for (local zz=7; zz < 11; zz++)	this.locations.SetValue(zz,0);
			this.locations.SetValue(0,1+2); // enable IN && OUT for the new station
			this.GetRailStationMiscInfo();
		break;
		case	AIStation.STATION_DOCK:		// TODO: do boat
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
	this.vehicle_count=0;
	this.StationSave();
	local dummy=this.CanUpgradeStation(); // just to set max_vehicle
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
thatstation.StationGetName();
DInfo("Station "+thatstation.StationGetName()+" depth is "+stalenght+" direction="+direction+" start="+entrypos+" end="+exitpos,1,"cStation::GetRailStationMiscInfo");
thatstation.locations.SetValue(16,entrypos);
thatstation.locations.SetValue(17,exitpos);
thatstation.locations.SetValue(18,direction);
thatstation.locations.SetValue(19,stalenght);
thatstation.DefinePlatform();
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
if ((entry & 1) == 1)	{ DInfo("Station "+thatstation.StationGetName()+" entry is open",2,"cStation::IsRailStationEntryOpen"); return true; }
DInfo("Station "+thatstation.StationGetName()+" entry is CLOSE",2,"cStation::IsRailStationEntryOpen");
return false;
}

function cStation::IsRailStationExitOpen(stationID=null)
// return true if station exit bit is set
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.locations.GetValue(0);
if ((exit & 2) == 2)	{ DInfo("Station "+thatstation.StationGetName()+" exit is open",2,"cStation::IsRailStationExitOpen"); return true; }
DInfo("Station "+thatstation.StationGetName()+" exit is CLOSE",2,"cStation::IsRailStationExitOpen");
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
DInfo("Closing the entry of station "+thatstation.StationGetName(),1,"RailStationCloseEntry");
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
DInfo("Closing the exit of station "+thatstation.StationGetName(),1,"RailStationCloseExit");
}

function cStation::RailStationSetPrimarySignalBuilt(stationID=null)
// set the flag for the main rail signals status
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.locations.GetValue(0);
entry=entry ^ 16;
thatstation.locations.SetValue(0, entry);
}

function cStation::RailStationSetSecondarySignalBuilt(stationID=null)
// set the flag for the secondary rail signals status
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.locations.GetValue(0);
entry=entry ^ 32;
thatstation.locations.SetValue(0, entry);
}

function cStation::IsRailStationPrimarySignalBuilt(stationID=null)
// return true if the primary rail signals are all built on it
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.locations.GetValue(0);
if ((exit & 16) == 16)	
	{
	DInfo("Station "+thatstation.StationGetName()+" signals are built on primary track",2,"cStation::IsRailStationPrimarySignalBuilt");
	return true;
	}
return false;
}

function cStation::IsRailStationSecondarySignalBuilt(stationID=null)
// return true if the secondary rail signals are all built on it
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.locations.GetValue(0);
if ((exit & 32) == 32)
	{
	DInfo("Station "+thatstation.StationGetName()+" signals are built on secondary track",2,"cStation::IsRailStationSecondarySignalBuilt");
	return true;
	}
return false;
}

function cStation::GetRailStationIN(getEntry, stationID=null)
// Return the tile where the station IN point is
// getEntry = true to return the entry IN, false to return exit IN
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return -1;
local entryIN=thatstation.locations.GetValue(1);
local exitIN=thatstation.locations.GetValue(3);
if (getEntry)	return entryIN;
		else	return exitIN;
}

function cStation::GetRailStationOUT(getEntry, stationID=null)
// Return the tile where the station OUT point is
// getEntry = true to return the entry OUT, false to return exit OUT
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation==null)	return -1;
local entryOUT=thatstation.locations.GetValue(2);
local exitOUT=thatstation.locations.GetValue(4);
if (getEntry)	return entryOUT;
		else	return exitOUT;
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

function cStation::IsPlatformOpen(platformID, useEntry)
// check if a platform entry or exit is usable
{
local platindex=cStation.GetPlatformIndex(platformID);
if (platindex==-1)	{ DError("Bad platform index",1,"IsPlatformOpen"); return false; }
local stationID=AIStation.GetStationID(platformID);
local thatstation=cStation.GetStationObject(stationID);
local statusbit=thatstation.platforms.GetValue(platindex);
if (useEntry)	return ((statusbit & 1) ==1);
		else	return ((statusbit & 2) ==2);
}

function cStation::DefinePlatform(stationID=null)
// look out a train station and add every platforms we found
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return -1;
local frontTile, backTile, leftTile, rightTile= null;
local direction=thatstation.GetRailStationDirection();
local staloc=thatstation.GetLocation();
if (direction == AIRail.RAILTRACK_NW_SE)
	{
	frontTile=AIMap.GetTileIndex(0,-1);
	backTile=AIMap.GetTileIndex(0,1);
	leftTile=AIMap.GetTileIndex(1,0);
	rightTile=AIMap.GetTileIndex(-1,0);
	}
else	{ // NE_SW
	frontTile=AIMap.GetTileIndex(-1,0);
	backTile=AIMap.GetTileIndex(1,0);
	leftTile=AIMap.GetTileIndex(0,-1);
	rightTile=AIMap.GetTileIndex(0,1);
	}
local isEntryClear, isExitClear=null;
local lookup=0;
local start=thatstation.GetLocation();
local end=thatstation.locations.GetValue(17);
local topLeftPlatform=start;
local topRightPlatform=start;
PutSign(start,"SS");
PutSign(end,"SE");
PutSign(start+frontTile,"cs");
PutSign(end+backTile,"ce");
// search up
while (AIRail.IsRailStationTile(lookup+start) && (AIStation.GetStationID(lookup+start)==thatstation.stationID))
	{
	topLeftPlatform=lookup+start;
	if (!thatstation.platforms.HasItem(lookup+start))	thatstation.platforms.AddItem(lookup+start,0);
	if (thatstation.platforms.HasItem(lookup+start)) // now retest, might be just added
		{
		local value=thatstation.platforms.GetValue(lookup+start);
		if (cTileTools.CanUseTile(lookup+start+frontTile,thatstation.stationID))
			if (AIRail.IsRailTile(lookup+start+frontTile))	value=value | 1;
										else	value=value & ~1;
		if (cTileTools.CanUseTile(lookup+end+backTile,thatstation.stationID))
			if (AIRail.IsRailTile(lookup+end+backTile))	value=value | 2;
										else	value=value & ~2;
		thatstation.platforms.SetValue(lookup+start,value);
		PutSign(lookup+start+frontTile,value);
		}
	lookup+=leftTile;
	}
// search down
lookup=rightTile;
while (AIRail.IsRailStationTile(lookup+start) && (AIStation.GetStationID(lookup+start)==thatstation.stationID))
	{
	topRightPlatform=lookup+start;
	if (!thatstation.platforms.HasItem(lookup+start))	thatstation.platforms.AddItem(lookup+start,0);
	if (thatstation.platforms.HasItem(lookup+start)) // now retest, might be just added
		{
		local value=thatstation.platforms.GetValue(lookup+start);
		if (cTileTools.CanUseTile(lookup+start+frontTile,thatstation.stationID))
			if (AIRail.IsRailTile(lookup+start+frontTile))	value=value | 1;
										else	value=value & ~1;
		if (cTileTools.CanUseTile(lookup+end+backTile,thatstation.stationID))
			if (AIRail.IsRailTile(lookup+end+backTile))	value=value | 2;
										else	value=value & ~2;
		thatstation.platforms.SetValue(lookup+start,value);
		PutSign(lookup+start+frontTile,value);
		}
	lookup+=rightTile;
	}
DInfo("Station "+thatstation.name+" have "+thatstation.platforms.Count()+" platforms",2,"cStation::DefinePlatforms");
thatstation.size=thatstation.platforms.Count();
thatstation.locations.SetValue(20,topLeftPlatform);
thatstation.locations.SetValue(21,topRightPlatform);
PutSign(topLeftPlatform,"NL");
PutSign(topRightPlatform,"NR");
}

function cStation::GetPlatformFrontTile(platform, useEntry)
// return the front tile of the platform
// useEntry : true to return front tile of the platform entry, false to return one for exit
{
local platindex=cStation.GetPlatformIndex(platform, useEntry);
if (platindex==-1)	return -1;
local stationID=AIStation.GetStationID(platform);
local front=cStation.GetRelativeTileForward(stationID, useEntry);
return platindex+front;
}

function cStation::GetPlatformIndex(platform, useEntry=true)
// return the platform reference (it's the station platform start location)
// useEntry: true return the real reference in our .platforms, false = return the location of the exit for that platform
// the useEntry=false query shouldn't be use as index as only the start is record, you will fail to find the platform with that index
// -> it mean don't use it when trying to find a platform in cStation.platforms list
// on error return -1
{
local stationID=AIStation.GetStationID(platform);
local thatstation=cStation.GetStationObject(stationID);
if (thatstation==null)	{ DError("Invalid platform : "+platform,2,"cStation::GetPlatformIndex"); return -1; }
if (thatstation.stationType!=AIStation.STATION_TRAIN)	{ DError("Not a rail station",1,"cStation::GetPlatformIndex"); return -1; }
local platX=AIMap.GetTileX(platform);
local platY=AIMap.GetTileY(platform);
local staX=0;
local staY=0;
if (useEntry)
	{
	staX=AIMap.GetTileX(thatstation.locations.GetValue(16)); // X=SW->NE
	staY=AIMap.GetTileY(thatstation.locations.GetValue(16)); // Y=SE->NW
	}
else	{
	staX=AIMap.GetTileX(thatstation.locations.GetValue(17));
	staY=AIMap.GetTileY(thatstation.locations.GetValue(17));
	}
if (thatstation.GetRailStationDirection()==AIRail.RAILTRACK_NE_SW)
	{ staY=platY; }
else	{ staX=platX; }// NW_SE
return AIMap.GetTileIndex(staX, staY);
}

function cStation::GetRelativeDirection(stationID, dirswitch)
// return a tile index relative to station direction and its entry/exit
// stationID: the station to get relative direction
// dirswitch: 0- left, 1-right, 2-forward, 3=backward : add 10 to get exit relative direction
// return -1 on error
{
local loc=AIStation.GetLocation(stationID);
if (!AIRail.IsRailStationTile(loc))	{ DError("Not a rail station tile",2,"cStation::GetRelativeDirection"); return -1; }
local dir=AIRail.GetRailStationDirection(loc);
local left, right, forward, backward = null;
if (dir==AIRail.RAILTRACK_NW_SE)
	{
	left=AIMap.GetTileIndex(1,0);
	right=AIMap.GetTileIndex(-1,0);
	forward=AIMap.GetTileIndex(0,-1);
	backward=AIMap.GetTileIndex(0,1);
	if (dirswitch >= 10) // SE->NW
		{
		left=AIMap.GetTileIndex(-1,0);
		right=AIMap.GetTileIndex(1,0);
		forward=AIMap.GetTileIndex(0,1);
		backward=AIMap.GetTileIndex(0,-1);
		}
	}
else	{ // NE->SW
	left=AIMap.GetTileIndex(0,-1);
	right=AIMap.GetTileIndex(0,1);
	forward=AIMap.GetTileIndex(-1,0);
	backward=AIMap.GetTileIndex(1,0);
	if (dirswitch >= 10) // SW->NE
		{
		left=AIMap.GetTileIndex(0,1);
		right=AIMap.GetTileIndex(0,-1);
		forward=AIMap.GetTileIndex(1,0);
		backward=AIMap.GetTileIndex(-1,0);
		}
	}
if (dirswitch >=10)	dirswitch-=10;
switch (dirswitch)
	{
	case 0:
		return left;
	case 1:
		return right;
	case 2:
		return forward;
	case 3:
		return backward;
	}
return -1;
}

function cStation::GetRelativeTileLeft(stationID, useEntry)
{
local value=0;
if (!useEntry) value+=10;
return cStation.GetRelativeDirection(stationID, value);
}

function cStation::GetRelativeTileRight(stationID, useEntry)
{
local value=1;
if (!useEntry) value+=10;
return cStation.GetRelativeDirection(stationID, value);
}

function cStation::GetRelativeTileForward(stationID, useEntry)
{
local value=2;
if (!useEntry) value+=10;
return cStation.GetRelativeDirection(stationID, value);
}

function cStation::GetRelativeTileBackward(stationID, useEntry)
{
local value=3;
if (!useEntry) value+=10;
return cStation.GetRelativeDirection(stationID, value);
}

function cStation::GetRelativeCrossingPoint(platform, useEntry)
// return crossing point relative to the platform, that's the point where front of station X axe meet crossing Y axe
// platform: the platform to find the relative crossing point
// useEntry: true to get crossing entry point, false for exit crossing point
{
local frontTile=cStation.GetPlatformFrontTile(platform, useEntry);
if (frontTile==-1)	return -1;
local stationID=AIStation.GetStationID(platform);
local thatstation=cStation.GetStationObject(stationID);
local crossing=0;
local direction=thatstation.GetRailStationDirection();
if (useEntry)	crossing=thatstation.locations.GetValue(5);
		else	crossing=thatstation.locations.GetValue(6);
if (crossing < 0)	{ DError("Crossing isn't define yet",2,"cBuilder::PlatformConnectors"); return -1; }
local goalTile=0;
if (direction==AIRail.RAILTRACK_NE_SW)
		goalTile=AIMap.GetTileIndex(AIMap.GetTileX(crossing),AIMap.GetTileY(frontTile));
	else	goalTile=AIMap.GetTileIndex(AIMap.GetTileX(frontTile),AIMap.GetTileY(crossing));
return goalTile;
}

function cStation::StationClaimTile(tile, stationID)
// Add a tile as own by stationID
{
cTileTools.BlackListTile(tile, stationID);
}

function cStation::RailStationClaimTile(tile, useEntry, stationID=null)
// Add a tile as own by the stationID
// useEntry: true to make it own by station entry, false to define as an exit tile
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	{ DError("Invalid stationID:"+stationID,2,"cStation::RailStationClaimTile"); return -1; }
local value=0;
if (useEntry)	value=1;
thatstation.station_tiles.AddItem(tile,value);
thatstation.StationClaimTile(tile, thatstation.stationID);
}

function cStation::RailStationDeleteEntrance(useEntry, stationID=null)
// Remove all tiles own by the station at its entry/exit
// useEntry: true to remove tiles for its entry, false for its exit
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return -1;
local removelist=AIList();
removelist.AddList(thatstation.station_tiles);
local value=0;
if (useEntry)	value=1;
removelist.KeepValue(value);
DInfo("Removing "+removelist.Count()+" tiles own by "+thatstation.name,2,"RailStationDeleteEntrance");
foreach (tile, dummy in removelist)
	{ AITile.DemolishTile(tile); thatstation.station_tiles.RemoveItem(tile); cTileTools.UnBlackListTile(tile) }
}

function cStation::StationAddTrain(taker, useEntry, stationID=null)
// Add a train to that station train counter
// stationID: the station ID
// taker: true if train is a taker, false if it's a dropper
// useEntry: true to use station entry, false for its exit
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	{ DError("Invalid stationID "+stationID,1,"cStation::StationAddTrain"); return -1; }
local ted=thatstation.locations.GetValue(7);
local txd=thatstation.locations.GetValue(8);
local tet=thatstation.locations.GetValue(9);
local txt=thatstation.locations.GetValue(10);
if (taker)
	{
	if (useEntry)	tet+=1;
			else	txt+=1;
	}
else	{
	if (useEntry)	ted+=1;
			else	txd+=1;
	}
thatstation.locations.SetValue(7, ted);
thatstation.locations.SetValue(8, txd);
thatstation.locations.SetValue(9, tet);
thatstation.locations.SetValue(10, txt);
DInfo("Station "+cStation.StationGetName(thatstation.stationID)+" add a new train: taker="+taker+" useEntry="+useEntry,2,"cStation::StationAddTrain");
}

function cStation::StationRemoveTrain(taker, useEntry, stationID=null)
// Remove a train that use a station
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	{ DError("Invalid stationID "+stationID,1,"cStation::StationRemoveTrain"); return -1; }
local ted=thatstation.locations.GetValue(7);
local txd=thatstation.locations.GetValue(8);
local tet=thatstation.locations.GetValue(9);
local txt=thatstation.locations.GetValue(10);
if (taker)
	{
	if (useEntry)	tet-=1;
			else	txt-=1;
	}
else	{
	if (useEntry)	ted-=1;
			else	txd-=1;
	}
if (ted < 0)	ted=0;
if (txd < 0)	txd=0;
if (tet < 0)	tet=0;
if (txt < 0)	txt=0;
thatstation.locations.SetValue(7, ted);
thatstation.locations.SetValue(8, txd);
thatstation.locations.SetValue(9, tet);
thatstation.locations.SetValue(10, txt);
DInfo("Station "+cStation.StationGetName(thatstation.stationID)+" remove train: taker="+taker+" useEntry="+useEntry,2,"cStation::StationAddTrain");
}

