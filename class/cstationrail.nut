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

class cStationRail extends cStation
{
	s_TrainSpecs = null;
	s_Platforms = null;
/*
	stationID		= null;	// id of station
	stationType		= null;	// AIStation.StationType
	specialType		= null;	// for boat = nothing
						// for trains = AIRail.RailType
						// for road = AIRoad::RoadVehicleType
						// for airport: AirportType
	size			= null;	// size of station: road = number of stations, trains=width, airport=width*height
	maxsize		= null; 	// maximum size a station could be
	locations		= null;	// locations of station tiles
						// for road, item=tile location, value = front tile location
						// for airport: nothing
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
	max_trains		= null;	// it's the number of maximum trains the station could handle
	station_tiles	= null;	// railstation tiles own by the station, value=1 entry or 0 exit

 train station are made like that:
station_infos:
bit0 entry is working on/off
bit1 exit is working on/off
bit2 south/west escape line is working on/off
bit3 north/east escape line is working on/off
bit4 main train line fire done
bit5 alt train line fire done
*/
	
	constructor()
		{
		::cStation.constructor();
		this.ClassName="cStationRail";
		this.s_TrainSpecs = AIList();
		this.s_Platforms = AIList();
		}
}

function cStationRail::GetRailStationMiscInfo(stationID=null)
// Setup misc infos about a station, we shouldn't use that function direcly as it's an helper to cStation::InitNewStation()
// stationID: the stationID to check
{
	local thatstation = false;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local stalenght=0;
	local entrypos=AIStation.GetLocation(thatstation.s_ID);
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
	cDebug.ClearSigns();
	local exitpos=null;
	cDebug.PutSign(entrypos,"Start");
	local scanner=entrypos;
	while (AIRail.IsRailStationTile(scanner))	{ stalenght++; scanner+=backTile; cDebug.PutSign(scanner,"."); INSTANCE.NeedDelay(10); }
	exitpos=scanner+frontTile;
	cDebug.PutSign(exitpos,"End");
	DInfo("Station "+thatstation.s_Name+" depth is "+stalenght+" direction="+direction+" start="+entrypos+" end="+exitpos,1);
	thatstation.s_TrainSpecs.SetValue(16,entrypos);
	thatstation.s_TrainSpecs.SetValue(17,exitpos);
	thatstation.s_TrainSpecs.SetValue(18,direction);
	thatstation.s_TrainSpecs.SetValue(19,stalenght);
	thatstation.DefinePlatform();
	cDebug.ClearSigns();
}

function cStationRail::GetRailStationFrontTile(entry, platform, stationID=null)
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
local direction=thatstation.s_TrainSpecs.GetValue(18);
local start=thatstation.s_TrainSpecs.GetValue(16);
local end=thatstation.s_TrainSpecs.GetValue(17);
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
cDebug.PutSign(frontTile,"Front="+entry);
ClearSigns();
return frontTile;
}

function cStationRail::IsRailStationEntryOpen(stationID=null)
// return true if station entry bit is set
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.s_TrainSpecs.GetValue(0);
if ((entry & 1) == 1)	{ DInfo("Station "+thatstation.StationGetName()+" entry is open",2); return true; }
DInfo("Station "+thatstation.StationGetName()+" entry is CLOSE",2);
return false;
}

function cStationRail::IsRailStationExitOpen(stationID=null)
// return true if station exit bit is set
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.s_TrainSpecs.GetValue(0);
if ((exit & 2) == 2)	{ DInfo("Station "+thatstation.StationGetName()+" exit is open",2); return true; }
DInfo("Station "+thatstation.StationGetName()+" exit is CLOSE",2);
return false;
}

function cStationRail::RailStationCloseEntry(stationID=null)
// return true if station entry bit is set
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.s_TrainSpecs.GetValue(0);
entry=entry ^ 1;
thatstation.s_TrainSpecs.SetValue(0, entry);
DInfo("Closing the entry of station "+thatstation.StationGetName(),1);
}

function cStationRail::RailStationCloseExit(stationID=null)
// Unset exit bit of the station
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.s_TrainSpecs.GetValue(0);
exit=exit ^ 2;
thatstation.s_TrainSpecs.SetValue(0, exit);
DInfo("Closing the exit of station "+thatstation.StationGetName(),1);
}

function cStationRail::RailStationSetPrimarySignalBuilt(stationID=null)
// set the flag for the main rail signals status
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.s_TrainSpecs.GetValue(0);
entry=entry ^ 16;
thatstation.s_TrainSpecs.SetValue(0, entry);
}

function cStationRail::RailStationSetSecondarySignalBuilt(stationID=null)
// set the flag for the secondary rail signals status
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local entry=thatstation.s_TrainSpecs.GetValue(0);
entry=entry ^ 32;
thatstation.s_TrainSpecs.SetValue(0, entry);
}

function cStationRail::IsRailStationPrimarySignalBuilt(stationID=null)
// return true if the primary rail signals are all built on it
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.s_TrainSpecs.GetValue(0);
if ((exit & 16) == 16)	
	{
	DInfo("Station "+thatstation.StationGetName()+" signals are built on primary track",2);
	return true;
	}
return false;
}

function cStationRail::IsRailStationSecondarySignalBuilt(stationID=null)
// return true if the secondary rail signals are all built on it
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
local exit=thatstation.s_TrainSpecs.GetValue(0);
if ((exit & 32) == 32)
	{
	DInfo("Station "+thatstation.StationGetName()+" signals are built on secondary track",2);
	return true;
	}
return false;
}

function cStationRail::GetRailStationIN(getEntry, stationID=null)
// Return the tile where the station IN point is
// getEntry = true to return the entry IN, false to return exit IN
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	return -1;
local entryIN=thatstation.s_TrainSpecs.GetValue(1);
local exitIN=thatstation.s_TrainSpecs.GetValue(3);
if (getEntry)	return entryIN;
		else	return exitIN;
}

function cStationRail::GetRailStationOUT(getEntry, stationID=null)
// Return the tile where the station OUT point is
// getEntry = true to return the entry OUT, false to return exit OUT
{
	local thatstation=false;
	if (stationID==null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local entryOUT=thatstation.s_TrainSpecs.GetValue(2);
	local exitOUT=thatstation.s_TrainSpecs.GetValue(4);
	if (getEntry)	return entryOUT;
			else	return exitOUT;
}

function cStationRail::GetRailStationDirection()	{ return this.s_TrainSpecs.GetValue(18); }
// avoid errors by returning proper index for direction of a station

function cStationRail::GetLocation(stationID=null)
// avoid errors, return station location
{
	local thatstation=false;
	if (stationID==null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	if (thatstation.s_Type==AIStation.STATION_TRAIN)	return thatstation.s_TrainSpecs.GetValue(16);
	return AIStation.GetLocation(thatstation.s_ID);
}

function cStationRail::IsPlatformOpen(platformID, useEntry)
// check if a platform entry or exit is usable
{
local platindex=cStation.GetPlatformIndex(platformID);
if (platindex==-1)	{ DError("Bad platform index",1); return false; }
local stationID=AIStation.GetStationID(platformID);
local thatstation=cStation.GetStationObject(stationID);
local statusbit=thatstation.s_Platforms.GetValue(platindex);
if (useEntry)	return ((statusbit & 1) ==1);
		else	return ((statusbit & 2) ==2);
}

function cStationRail::DefinePlatform(stationID=null)
// look out a train station and add every platforms we found
{
	local thatstation=false;
	if (stationID==null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
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
	local end=thatstation.s_TrainSpecs.GetValue(17);
	local topLeftPlatform=start;
	local topRightPlatform=start;
	local usable=false;
/*cDebug.PutSign(start,"SS");
cDebug.PutSign(end,"SE");
cDebug.PutSign(start+frontTile,"cs");
cDebug.PutSign(end+backTile,"ce");*/
// search up
	while (AIRail.IsRailStationTile(lookup+start) && (AIStation.GetStationID(lookup+start)==thatstation.s_ID))
		{
		topLeftPlatform=lookup+start;
		if (!thatstation.s_Platforms.HasItem(lookup+start))	thatstation.s_Platforms.AddItem(lookup+start,0);
		if (thatstation.s_Platforms.HasItem(lookup+start)) // now retest, might be just added
			{
			local value=thatstation.s_Platforms.GetValue(lookup+start);
			usable=AIRail.IsRailTile(lookup+start+frontTile);
			if (usable)	usable=cTileTools.CanUseTile(lookup+start+frontTile, thatstation.s_ID);
			if (usable)
				{
				local rtrack=AIRail.GetRailTracks(lookup+start+frontTile);
				usable=((rtrack & direction) == direction);
				}
			if (usable)	value=value | 1;
				else	value=value & ~1;
	
			usable=AIRail.IsRailTile(lookup+end+backTile);
			if (usable)	usable=cTileTools.CanUseTile(lookup+end+backTile, thatstation.s_ID);
			if (usable)
				{
				local rtrack=AIRail.GetRailTracks(lookup+end+backTile);
				usable=((rtrack & direction) == direction);
				}
			if (usable)	value=value | 2;
				else	value=value & ~2;
			thatstation.s_Platforms.SetValue(lookup+start,value);
			//cDebug.PutSign(lookup+start+frontTile,value);
			}
		lookup+=leftTile;
		}
	// search down
	lookup=rightTile;
	while (AIRail.IsRailStationTile(lookup+start) && (AIStation.GetStationID(lookup+start)==thatstation.s_ID))
		{
		topRightPlatform=lookup+start;
		if (!thatstation.s_Platforms.HasItem(lookup+start))	thatstation.s_Platforms.AddItem(lookup+start,0);
		if (thatstation.s_Platforms.HasItem(lookup+start)) // now retest, might be just added
			{
			local value=thatstation.s_Platforms.GetValue(lookup+start);
			usable=AIRail.IsRailTile(lookup+start+frontTile);
			if (usable)	usable=cTileTools.CanUseTile(lookup+start+frontTile, thatstation.s_ID);
			if (usable)
				{
				local rtrack=AIRail.GetRailTracks(lookup+start+frontTile);
				usable=((rtrack & direction) == direction);
				}
			if (usable)	value=value | 1;
				else	value=value & ~1;
	
			usable=AIRail.IsRailTile(lookup+end+backTile);
			if (usable)	usable=cTileTools.CanUseTile(lookup+end+backTile, thatstation.s_ID);
			if (usable)
				{
				local rtrack=AIRail.GetRailTracks(lookup+end+backTile);
				usable=((rtrack & direction) == direction);
				}
			if (usable)	value=value | 2;
				else	value=value & ~2;
	
			thatstation.s_Platforms.SetValue(lookup+start,value);
			//cDebug.PutSign(lookup+start+frontTile,value);
			}
		lookup+=rightTile;
		}
	local goodPlatforms=AIList();
	goodPlatforms.AddList(thatstation.s_Platforms);
	if (thatstation.s_Owner.Count() == 0)
		goodPlatforms.RemoveValue(0);	// no one own it yet, we just validate a platform if its rail in front is built
	else	{
	//	local mainOwner=cRoute.GetRouteObject(thatstation.owner.Begin());
	//	if (mainOwner == null)	{ DError("Cannot get station owner route "+thatstation.owner.Begin(),1,"cStation.DefinePlatform"); return false; }
		local runTarget=cStation.RailStationGetRunnerTarget(thatstation.s_ID);
		cDebug.PutSign(runTarget,"Checker");
		foreach (platidx, openclose in goodPlatforms)
			{
			local value=0;
			if (runTarget == -1)	break;
			if ((openclose & 1) == 1 && cBuilder.RoadRunner(platidx, runTarget, AIVehicle.VT_RAIL))	value=value | 1;
																	else	value=value & ~1;
			if ((openclose & 2) == 2 && cBuilder.RoadRunner(platidx, runTarget, AIVehicle.VT_RAIL))	value=value | 2;
																	else	value=value & ~2;
			thatstation.s_Platforms.SetValue(platidx, value);
			if (value == 0)	goodPlatforms.RemoveItem(platidx); // not so true if we connect both side of a station, but good for now
			}	
		}
	DInfo("Station "+thatstation.s_Name+" have "+thatstation.s_Platforms.Count()+" platforms, "+goodPlatforms.Count()+" platforms are ok",2);
	thatstation.s_Size=thatstation.s_Platforms.Count();
//	thatstation.max_trains=goodPlatforms.Count();
	thatstation.s_TrainSpecs.SetValue(20,topLeftPlatform);
	thatstation.s_TrainSpecs.SetValue(21,topRightPlatform);
	//cDebug.PutSign(topLeftPlatform,"NL");
	//cDebug.PutSign(topRightPlatform,"NR");
}

function cStationRail::RailStationGetRunnerTarget(runnerID)
// return the tile location where we could use RoadRunner for checks
// this is the rail entry or exit from the main or secondary track, depending what the station can handle
// -1 on error
{
local thatstation=cStation.GetStationObject(runnerID);
if (thatstation == null || thatstation.owner.Count()==0)	return -1;
local mainOwner=cRoute.GetRouteObject(thatstation.owner.Begin());
if (mainOwner == null)	return -1;
local primary=(mainOwner.source_stationID == runnerID);
if (primary)
	{
	if (mainOwner.source_RailEntry)	return thatstation.s_TrainSpecs.GetValue(4);
						else	return thatstation.s_TrainSpecs.GetValue(3);
	}
else	{
	if (mainOwner.target_RailEntry)	return thatstation.s_TrainSpecs.GetValue(2);
						else	return thatstation.s_TrainSpecs.GetValue(1);
	}
return -1;
}

function cStationRail::GetPlatformFrontTile(platform, useEntry)
// return the front tile of the platform
// useEntry : true to return front tile of the platform entry, false to return one for exit
{
local platindex=cStation.GetPlatformIndex(platform, useEntry);
if (platindex==-1)	return -1;
local stationID=AIStation.GetStationID(platform);
local front=cStation.GetRelativeTileForward(stationID, useEntry);
return platindex+front;
}

function cStationRail::GetPlatformIndex(platform, useEntry=true)
// return the platform reference (it's the station platform start location)
// useEntry: true return the real reference in our .s_Platforms, false = return the location of the exit for that platform
// the useEntry=false query shouldn't be use as index as only the start is record, you will fail to find the platform with that index
// -> it mean don't use it when trying to find a platform in cStation.s_Platforms list
// on error return -1
{
local stationID=AIStation.GetStationID(platform);
local thatstation=cStation.GetStationObject(stationID);
if (thatstation==null)	{ DError("Invalid platform : "+platform,2); return -1; }
if (thatstation.stationType!=AIStation.STATION_TRAIN)	{ DError("Not a rail station",1); return -1; }
local platX=AIMap.GetTileX(platform);
local platY=AIMap.GetTileY(platform);
local staX=0;
local staY=0;
if (useEntry)
	{
	staX=AIMap.GetTileX(thatstation.s_TrainSpecs.GetValue(16)); // X=SW->NE
	staY=AIMap.GetTileY(thatstation.s_TrainSpecs.GetValue(16)); // Y=SE->NW
	}
else	{
	staX=AIMap.GetTileX(thatstation.s_TrainSpecs.GetValue(17));
	staY=AIMap.GetTileY(thatstation.s_TrainSpecs.GetValue(17));
	}
if (thatstation.GetRailStationDirection()==AIRail.RAILTRACK_NE_SW)
	{ staY=platY; }
else	{ staX=platX; }// NW_SE
return AIMap.GetTileIndex(staX, staY);
}

function cStationRail::GetRelativeDirection(stationID, dirswitch)
// return a tile index relative to station direction and its entry/exit
// stationID: the station to get relative direction
// dirswitch: 0- left, 1-right, 2-forward, 3=backward : add 10 to get exit relative direction
// return -1 on error
{
local loc=AIStation.GetLocation(stationID);
if (!AIRail.IsRailStationTile(loc))	{ DError("Not a rail station tile",2); return -1; }
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

function cStationRail::GetRelativeTileLeft(stationID, useEntry)
{
local value=0;
if (!useEntry) value+=10;
return cStation.GetRelativeDirection(stationID, value);
}

function cStationRail::GetRelativeTileRight(stationID, useEntry)
{
local value=1;
if (!useEntry) value+=10;
return cStation.GetRelativeDirection(stationID, value);
}

function cStationRail::GetRelativeTileForward(stationID, useEntry)
{
local value=2;
if (!useEntry) value+=10;
return cStation.GetRelativeDirection(stationID, value);
}

function cStationRail::GetRelativeTileBackward(stationID, useEntry)
{
local value=3;
if (!useEntry) value+=10;
return cStation.GetRelativeDirection(stationID, value);
}

function cStationRail::GetRelativeCrossingPoint(platform, useEntry)
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
if (useEntry)	crossing=thatstation.s_TrainSpecs.GetValue(5);
		else	crossing=thatstation.s_TrainSpecs.GetValue(6);
if (crossing < 0)	{ DError("Crossing isn't define yet",2); return -1; }
local goalTile=0;
if (direction==AIRail.RAILTRACK_NE_SW)
		goalTile=AIMap.GetTileIndex(AIMap.GetTileX(crossing),AIMap.GetTileY(frontTile));
	else	goalTile=AIMap.GetTileIndex(AIMap.GetTileX(frontTile),AIMap.GetTileY(crossing));
return goalTile;
}

function cStationRail::RailStationClaimTile(tile, useEntry, stationID=null)
// Add a tile as own by the stationID
// useEntry: true to make it own by station entry, false to define as an exit tile
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	{ DError("Invalid stationID:"+stationID,2); return -1; }
local value=0;
if (useEntry)	value=1;
thatstation.station_tiles.AddItem(tile,value);
thatstation.StationClaimTile(tile, thatstation.stationID);
}

function cStationRail::RailStationDeleteEntrance(useEntry, stationID=null)
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
DInfo("Removing "+removelist.Count()+" tiles own by "+thatstation.name,2);
foreach (tile, dummy in removelist)
	{ AITile.DemolishTile(tile); thatstation.station_tiles.RemoveItem(tile); cTileTools.UnBlackListTile(tile) }
}

function cStationRail::StationAddTrain(taker, useEntry, stationID=null)
// Add a train to that station train counter
// stationID: the station ID
// taker: true if train is a taker, false if it's a dropper
// useEntry: true to use station entry, false for its exit
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	{ DError("Invalid stationID "+stationID,1); return -1; }
local ted=thatstation.s_TrainSpecs.GetValue(7);
local txd=thatstation.s_TrainSpecs.GetValue(8);
local tet=thatstation.s_TrainSpecs.GetValue(9);
local txt=thatstation.s_TrainSpecs.GetValue(10);
if (taker)
	{
	if (useEntry)	tet+=1;
			else	txt+=1;
	}
else	{
	if (useEntry)	ted+=1;
			else	txd+=1;
	}
thatstation.s_TrainSpecs.SetValue(7, ted);
thatstation.s_TrainSpecs.SetValue(8, txd);
thatstation.s_TrainSpecs.SetValue(9, tet);
thatstation.s_TrainSpecs.SetValue(10, txt);
DInfo("Station "+cStation.StationGetName(thatstation.stationID)+" add a new train: taker="+taker+" useEntry="+useEntry,2);
}

function cStationRail::StationRemoveTrain(taker, useEntry, stationID=null)
// Remove a train that use a station
{
local thatstation=null;
if (stationID==null)	thatstation=this;
		else		thatstation=cStation.GetStationObject(stationID);
if (thatstation == null)	{ DError("Invalid stationID "+stationID,1); return -1; }
local ted=thatstation.s_TrainSpecs.GetValue(7);
local txd=thatstation.s_TrainSpecs.GetValue(8);
local tet=thatstation.s_TrainSpecs.GetValue(9);
local txt=thatstation.s_TrainSpecs.GetValue(10);
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
thatstation.s_TrainSpecs.SetValue(7, ted);
thatstation.s_TrainSpecs.SetValue(8, txd);
thatstation.s_TrainSpecs.SetValue(9, tet);
thatstation.s_TrainSpecs.SetValue(10, txt);
DInfo("Station "+cStation.StationGetName(thatstation.stationID)+" remove train: taker="+taker+" useEntry="+useEntry,2);
}
