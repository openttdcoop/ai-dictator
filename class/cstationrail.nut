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
	s_EntrySide		= null;	// List holding entry related infos
						// 0: entry_in tile where we should find the entry that lead to the station
						// 1: entry_out
						// 2: entry_crossing
						// 3: entry_in_link tile to pathfind to enter the station by IN point
						// 4: entry_out_link
						// 5: entry_depot
	s_ExitSide		= null;	// List holding exit related infos
						// 0: exit_in tile where we should find the entry that lead to the station
						// 1: exit_out
						// 2: exit_crossing
						// 3: exit_in_link tile to pathfind to enter the station by IN point
						// 4: exit_out_link
						// 5: exit_depot
	s_Train		= null;	// Special list holding train infos
						// 0: STATIONBIT, see bellow
						// 1: number of train dropper using entry
						// 2: number of train dropper using exit
						// 3: number of train taker using entry
						// 4: number of train taker using exit
						// 5: startpoint : when created, tile where the start of station is == AIStation.GetLocation
						// 6: endpoint : when created, tile where the end of station is
						// 7: direction: when created, the direction of the station return by AIRail.GetRailStationDirection
						// 8: depth: when created, the lenght (depth) the station is, for its width, "cstation.size" keep that info
						// 9: most left platform position
						// 10: most right platform position
						// 11: main route owner
						// 12: it's the number of all working platforms

/*	STATIONBIT
	bit0 entry is built 1 / not working 0
	bit1 exit is built 1 / not working 0
	bit2 as source station entry is use 1, exit is use 0
	bit3 as target station entry is use 1, exit is use 0
	bit4 main train line fire done yes 1/0 no
	bit5 alt train line fire done yes 1/0 no
*/
	s_Platforms		= null;	// AIList of platforms: item=platform location
						// value= bit0 on/off entry status
						// value= bit1 on/off exit status
						// value= bit2 on/off healthy connect

	constructor()
		{
		::cStation.constructor();
		this.ClassName="cStationRail";
		this.s_Train = array(15,-1);
		this.s_Platforms = AIList();
		this.s_EntrySide = array(6,-1);
		this.s_ExitSide = array(6,-1);
		this.s_Train[TrainType.STATIONBIT]=3; // enable IN & OUT of station
		this.s_Train[TrainType.TET]=0;
		this.s_Train[TrainType.TED]=0;
		this.s_Train[TrainType.TXT]=0;
		this.s_Train[TrainType.TXD]=0;
		this.s_Train[TrainType.GOODPLATFORM]=1;
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
	local stalength=0;
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
	DInfo("Detecting station depth",1);
	cDebug.PutSign(entrypos,"Start");
	local scanner=entrypos;
	while (AIRail.IsRailStationTile(scanner))	{ stalength++; scanner+=backTile; cDebug.PutSign(scanner,"."); INSTANCE.NeedDelay(10); }
	exitpos=scanner+frontTile;
	cDebug.PutSign(exitpos,"End");
	DInfo("Station "+thatstation.s_Name+" depth is "+stalength+" direction="+direction+" start="+entrypos+" end="+exitpos,1);
	thatstation.s_Train[TrainType.START_POINT]= entrypos;
	thatstation.s_Train[TrainType.END_POINT]= exitpos;
	thatstation.s_Train[TrainType.DIRECTION]= direction;
	thatstation.s_Train[TrainType.DEPTH]= stalength;
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
	local thatstation = false;
	if (stationID == null)	thatstation=this;
				else	thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local direction=thatstation.s_Train[TrainType.DIRECTION];
	local start=thatstation.s_Train[TrainType.START_POINT];
	local end=thatstation.s_Train[TrainType.END_POINT];
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
	cDebug.ClearSigns();
	return frontTile;
}

function cStationRail::IsRailStationEntryOpen(stationID=null)
// return true if station entry bit is set
{
	local thatstation=false;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local entry=thatstation.s_Train[TrainType.STATIONBIT];
	if (cMisc.CheckBit(entry,0))	{ DInfo("Station "+thatstation.s_Name+" entry is open",2); return true; }
	DInfo("Station "+thatstation.s_Name+" entry is CLOSE",2);
	return false;
}

function cStationRail::IsRailStationExitOpen(stationID=null)
// return true if station exit bit is set
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local exit=thatstation.s_Train[TrainType.STATIONBIT];
	if (cMisc.CheckBit(exit,1))	{ DInfo("Station "+thatstation.s_Name+" exit is open",2); return true; }
	DInfo("Station "+thatstation.s_Name+" exit is CLOSE",2);
	return false;
}

function cStationRail::RailStationCloseEntry(stationID=null)
// Unset entry bit of the station
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local entry=thatstation.s_Train[TrainType.STATIONBIT];
	entry=cMisc.ClearBit(entry, 0); //entry=entry ^ 1;
	thatstation.s_Train[TrainType.STATIONBIT]= entry;
	DInfo("Closing the entry of station "+thatstation.s_Name,1);
}

function cStationRail::RailStationCloseExit(stationID=null)
// Unset exit bit of the station
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local exit=thatstation.s_Train[TrainType.STATIONBIT];
	exit=cMisc.ClearBit(exit, 1); //exit=exit ^ 2;
	thatstation.s_Train[TrainType.STATIONBIT]= exit;
	DInfo("Closing the exit of station "+thatstation.s_Name,1);
}

function cStationRail::RailStationSetPrimarySignalBuilt(stationID=null)
// set the flag for the main rail signals status
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local entry=thatstation.s_Train[TrainType.STATIONBIT];
	entry=cMisc.SetBit(entry, 4);
	thatstation.s_Train[TrainType.STATIONBIT]= entry;
}

function cStationRail::RailStationSetSecondarySignalBuilt(stationID=null)
// set the flag for the secondary rail signals status
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local entry=thatstation.s_Train[TrainType.STATIONBIT];
	entry=cMisc.SetBit(entry, 5);
	thatstation.s_Train[TrainType.STATIONBIT]= entry;
}

function cStationRail::IsRailStationPrimarySignalBuilt(stationID=null)
// return true if the primary rail signals are all built on it
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local exit=thatstation.s_Train[TrainType.STATIONBIT];
	if (cMisc.CheckBit(exit, 4))
		{
		DInfo("Station "+thatstation.s_Name+" signals are built on primary track",2);
		return true;
		}
	return false;
}

function cStationRail::SetPlatformWorking(platformID, status, stationID = null)
// Set or unset the working state of a platform
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return false;
	if (!thatstation.s_Platforms.HasItem(platformID))	return false;
	local platf = thatstation.s_Platforms.GetValue(platformID);
	if (status)	platf = cMisc.SetBit(platf, 2);
		else	platf = cMisc.ClearBit(platf, 2);
	thatstation.s_Platforms.SetValue(platformID, platf);
}

function cStationRail::IsPlatformWorking(platformID, stationID = null)
// return true if the platform is working (connect to the rails route)
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return false;
	if (!thatstation.s_Platforms.HasItem(platformID))	return false;
	local platvalue = thatstation.s_Platforms.GetValue(platformID);
	if (cMisc.CheckBit(platvalue, 2))	return true;
	return false;
}

function cStationRail::IsRailStationSecondarySignalBuilt(stationID=null)
// return true if the secondary rail signals are all built on it
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local exit=thatstation.s_Train[TrainType.STATIONBIT];
	if (cMisc.CheckBit(exit, 5))
		{
		DInfo("Station "+thatstation.s_Name+" signals are built on secondary track",2);
		return true;
		}
	return false;
}

function cStationRail::GetRailStationIN(getEntry, stationID=null)
// Return the tile where the station IN point is
// getEntry = true to return the entry IN, false to return exit IN
{
	local thatstation=null;
	if (stationID == null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local entryIN=thatstation.s_EntrySide[TrainSide.IN];
	local exitIN=thatstation.s_ExitSide[TrainSide.IN];
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
	local entryOUT=thatstation.s_EntrySide[TrainSide.OUT];
	local exitOUT=thatstation.s_ExitSide[TrainSide.OUT];
	if (getEntry)	return entryOUT;
			else	return exitOUT;
}

function cStationRail::GetRailStationDirection()	{ return this.s_Train[TrainType.DIRECTION]; }
// avoid errors by returning proper index for direction of a station

function cStationRail::IsPlatformOpen(platformID, useEntry)
// check if a platform entry or exit is usable
{
	local platindex=cStationRail.GetPlatformIndex(platformID);
	if (platindex == -1)	{ DError("Bad platform index",1); return false; }
	local stationID=AIStation.GetStationID(platformID);
	if (stationID == null)	return -1;
	local thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local statusbit=thatstation.s_Platforms.GetValue(platindex);
	if (useEntry)	return (cMisc.CheckBit(statusbit, 0));
			else	return (cMisc.CheckBit(statusbit, 1));
}

function cStationRail::DefinePlatform(stationID=null)
// look out a train station and add every platforms we found
{
	local thatstation=false;
	if (stationID == null)	thatstation=this;
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
	local lookup=0;
	local start=staloc;
	local end=thatstation.s_Train[TrainType.END_POINT];
	local topLeftPlatform=start;
	local topRightPlatform=start;
// search up
	while (AIRail.IsRailStationTile(lookup+start) && (AIStation.GetStationID(lookup+start)==thatstation.s_ID))
		{
cDebug.PutSign(lookup+start,"*");
		topLeftPlatform=lookup+start;
		if (!thatstation.s_Platforms.HasItem(lookup+start))	thatstation.s_Platforms.AddItem(lookup+start,0);
		lookup+=leftTile;
		}
	// search down
	lookup=rightTile;
	while (AIRail.IsRailStationTile(lookup+start) && (AIStation.GetStationID(lookup+start)==thatstation.s_ID))
		{
cDebug.PutSign(lookup+start,"*");
		topRightPlatform=lookup+start;
		if (!thatstation.s_Platforms.HasItem(lookup+start))	thatstation.s_Platforms.AddItem(lookup+start,0);
		lookup+=rightTile;
		}
	local goodCounter=0;
	/*if (thatstation.s_Owner.Count() == 0)	thatstation.s_Platforms.SetValue(thatstation.s_Platforms.Begin(), 7);
	// no one own it yet, we just validate a platform if its rail in front is built
	else	{*/
		local runTarget=cStationRail.RailStationGetRunnerTarget(thatstation.s_ID);
		cDebug.PutSign(runTarget,"Checker "+runTarget);
		foreach (platidx, value in thatstation.s_Platforms)
			{
			if (runTarget == -1)	break;
	print("platform="+ platidx+" result ="+cBuilder.RoadRunner(platidx, runTarget, AIVehicle.VT_RAIL)+" value="+value);
			if (!cMisc.CheckBit(value,0) && cBuilder.RoadRunner(platidx, runTarget, AIVehicle.VT_RAIL))	value=cMisc.SetBit(value,0);
			if (!cMisc.CheckBit(value,1) && cBuilder.RoadRunner(platidx, runTarget, AIVehicle.VT_RAIL))	value=cMisc.SetBit(value,1);
			thatstation.s_Platforms.SetValue(platidx, value);
			if (cMisc.CheckBit(value,0) || cMisc.CheckBit(value, 1))	{ goodCounter++; thatstation.SetPlatformWorking(platidx, true); }
			}	
//		}
	DInfo("Station "+thatstation.s_Name+" have "+thatstation.s_Platforms.Count()+" platforms, "+goodCounter+" platforms are ok",2);
	thatstation.s_Train[TrainType.GOODPLATFORM]=goodCounter;
	thatstation.s_Size=thatstation.s_Platforms.Count();
	thatstation.s_Train[TrainType.PLATFORM_LEFT]=topLeftPlatform;
	thatstation.s_Train[TrainType.PLATFORM_RIGHT]=topRightPlatform;
	if (thatstation.s_Platforms.Count() > 1 && !thatstation.IsPlatformWorking(topLeftPlatform) && !thatstation.IsPlatformWorking(topRightPlatform))
		{
		DInfo("Closing station "+thatstation.s_Name+" as it cannot grow anymore",1);
		thatstation.s_MaxSize = thatstation.s_Size;
		}
}

function cStationRail::RailStationGetRunnerTarget(runnerID)
// return the tile location where we could use RoadRunner for checks
// this is the rail entry or exit from the main or secondary track, depending what the station can handle
// -1 on error
{
	local thatstation=cStation.Load(runnerID);
	if (!thatstation || thatstation.s_Owner.Count()==0)	return -1;
	local mainOwner=cRoute.Load(thatstation.s_Owner.Begin());
	if (!mainOwner)	return -1;
	local primary=(mainOwner.SourceStation.s_ID == runnerID);
	if (primary)
		{
		if (mainOwner.Source_RailEntry)	return thatstation.s_EntrySide[TrainSide.IN];
							else	return thatstation.s_ExitSide[TrainSide.IN];
		}
	else	{
		if (mainOwner.Target_RailEntry)	return thatstation.s_EntrySide[TrainSide.OUT];
							else	return thatstation.s_ExitSide[TrainSide.OUT];
		}
	return -1;
}

function cStationRail::GetPlatformFrontTile(platform, useEntry)
// return the front tile of the platform
// useEntry : true to return front tile of the platform entry, false to return one for exit
{
	local platindex=cStationRail.GetPlatformIndex(platform, useEntry);
	if (platindex==-1)	return -1;
	local stationID=AIStation.GetStationID(platform);
	local front=cStationRail.GetRelativeTileForward(stationID, useEntry);
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
	local thatstation=cStation.Load(stationID);
	if (!thatstation)	{ DError("Invalid platform : "+platform,2); return -1; }
	if (thatstation.s_Type != AIStation.STATION_TRAIN)	{ DError("Not a rail station",1); return -1; }
	local platX=AIMap.GetTileX(platform);
	local platY=AIMap.GetTileY(platform);
	local staX=0;
	local staY=0;
	if (useEntry)
		{
		staX=AIMap.GetTileX(thatstation.s_Train[TrainType.START_POINT]); // X=SW->NE
		staY=AIMap.GetTileY(thatstation.s_Train[TrainType.START_POINT]); // Y=SE->NW
		}
	else	{
		staX=AIMap.GetTileX(thatstation.s_Train[TrainType.END_POINT]);
		staY=AIMap.GetTileY(thatstation.s_Train[TrainType.END_POINT]);
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
	return cStationRail.GetRelativeDirection(stationID, value);
}

function cStationRail::GetRelativeTileRight(stationID, useEntry)
{
	local value=1;
	if (!useEntry) value+=10;
	return cStationRail.GetRelativeDirection(stationID, value);
}

function cStationRail::GetRelativeTileForward(stationID, useEntry)
{
	local value=2;
	if (!useEntry) value+=10;
	return cStationRail.GetRelativeDirection(stationID, value);
}

function cStationRail::GetRelativeTileBackward(stationID, useEntry)
{
	local value=3;
	if (!useEntry) value+=10;
	return cStationRail.GetRelativeDirection(stationID, value);
}

function cStationRail::GetRelativeCrossingPoint(platform, useEntry)
// return crossing point relative to the platform, that's the point where front of station X axe meet crossing Y axe
// platform: the platform to find the relative crossing point
// useEntry: true to get crossing entry point, false for exit crossing point
{
	local frontTile=cStationRail.GetPlatformFrontTile(platform, useEntry);
	if (frontTile==-1)	return -1;
	local stationID=AIStation.GetStationID(platform);
	local thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local crossing=0;
	local direction=thatstation.GetRailStationDirection();
	if (useEntry)	crossing=thatstation.s_EntrySide[TrainSide.CROSSING];
			else	crossing=thatstation.s_ExitSide[TrainSide.CROSSING];
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
	local thatstation= false;
	if (stationID==null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	{ DError("Invalid stationID:"+stationID,2); return -1; }
	local value=0;
	if (useEntry)	value=1;
	if (AITile.IsStationTile(tile))	thatstation.s_Tiles.AddItem(tile, value);
						else	thatstation.s_TilesOther.AddItem(tile, value);
	thatstation.StationClaimTile(tile, thatstation.s_ID);
}

function cStationRail::RailStationDeleteEntrance(useEntry, stationID=null)
// Remove all tiles own by the station at its entry/exit
// useEntry: true to remove tiles for its entry, false for its exit
{
	local thatstation=false;
	if (stationID==null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	return -1;
	local removelist=AIList();
	removelist.AddList(thatstation.s_Tiles);
	local value=0;
	if (useEntry)	value=1;
	removelist.KeepValue(value);
	DInfo("Removing "+removelist.Count()+" tiles own by "+thatstation.s_Name,2);
	foreach (tile, dummy in removelist)
		{ AITile.DemolishTile(tile); thatstation.s_Tiles.RemoveItem(tile); cTileTools.UnBlackListTile(tile) }
}

function cStationRail::StationAddTrain(taker, useEntry, stationID=null)
// Add a train to that station train counter
// stationID: the station ID
// taker: true if train is a taker, false if it's a dropper
// useEntry: true to use station entry, false for its exit
{
	local thatstation=false;
	if (stationID==null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	{ DError("Invalid stationID "+stationID,1); return -1; }
	local ted=thatstation.s_Train[TrainType.TED];
	local txd=thatstation.s_Train[TrainType.TXD];
	local tet=thatstation.s_Train[TrainType.TET];
	local txt=thatstation.s_Train[TrainType.TXT];
	if (taker)
		{
		if (useEntry)	tet++;
				else	txt++;
		}
	else	{
		if (useEntry)	ted++;
				else	txd++;
		}
	thatstation.s_Train[TrainType.TED]= ted;
	thatstation.s_Train[TrainType.TXD]= txd;
	thatstation.s_Train[TrainType.TET]= tet;
	thatstation.s_Train[TrainType.TXT]= txt;
	DInfo("Station "+cStation.GetStationName(thatstation.s_ID)+" add a new train: taker="+taker+" useEntry="+useEntry,2);
}

function cStationRail::StationRemoveTrain(taker, useEntry, stationID=null)
// Remove a train that use a station
{
	local thatstation=false;
	if (stationID==null)	thatstation=this;
			else		thatstation=cStation.Load(stationID);
	if (!thatstation)	{ DError("Invalid stationID "+stationID,1); return -1; }
	local ted=thatstation.s_Train[TrainType.TED];
	local txd=thatstation.s_Train[TrainType.TXD];
	local tet=thatstation.s_Train[TrainType.TET];
	local txt=thatstation.s_Train[TrainType.TXT];
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
	thatstation.s_Train[TrainType.TED]= ted;
	thatstation.s_Train[TrainType.TXD]= txd;
	thatstation.s_Train[TrainType.TET]= tet;
	thatstation.s_Train[TrainType.TXT]= txt;
	DInfo("Station "+cStation.GetStationName(thatstation.s_ID)+" remove train: taker="+taker+" useEntry="+useEntry,2);
}

function cStationRail::RailStationPhaseUpdate()
// Update platform and build missing parts
// thatstation is a cStationRail instance
{
	local needUpdate=false;
	if (this instanceof cStationRail)
		{
		this.DefinePlatform();
		foreach (platform, status in this.s_Platforms)
			{
		//	if (cMisc.CheckBit(status,2))	continue; // if set platform is good, so don't rerun that on this one
			if (this.s_EntrySide[TrainSide.CROSSING] >= 0)	{ needUpdate = true; cBuilder.PlatformConnectors(platform, true); }
			if (this.s_ExitSide[TrainSide.CROSSING] >= 0)	{ needUpdate = true; cBuilder.PlatformConnectors(platform, false); }
			}
		}
	else return;
	if (needUpdate)	this.DefinePlatform();
}


