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

class cBuilder
	{
static	DIR_NE = 2; 
static	DIR_NW = 0; 
static	DIR_SE = 1; 
static	DIR_SW = 3; 
	currentRoadType=null;
	
	statile=null;
	stafront = null;
	deptile=null;
	depfront=null;
	statop=null;
	stabottom=null;
	stationdir=null;
	frontfront=null;
	CriticalError=null;
	holestart=null;
	holeend=null;
	holes=null;
	savedepot = null; 		// the tile of the last depot we have build
	building_route = null;		// Keep here what route we are working on
	
	constructor()
		{
		CriticalError=false;
		building_route = -1;
		}
	}

function cBuilder::StationIsAccepting(stationid)
// add that station to the station_drop list
{
if (!INSTANCE.builder.station_drop.HasItem(stationid))	INSTANCE.builder.station_take.AddItem(stationid, 1);
}

function cBuilder::StationIsProviding(stationid)
// add that station to the station_take list
{
if (!INSTANCE.builder.station_take.HasItem(stationid))	INSTANCE.builder.station_take.AddItem(stationid, 1);
}

function cBuilder::IsCriticalError()
// Check the last error to see if the error is a critical error or temp failure
// we return false when no error or true when error
// we set CriticalError to true for a critcal error or false for a temp failure
{
if (INSTANCE.builder.CriticalError) return true; // tell everyone we fail until the flag is remove
local lasterror=AIError.GetLastError();
local errcat=AIError.GetErrorCategory();
DInfo("Error check: "+AIError.GetLastErrorString()+" Cat: "+errcat,2);
switch (lasterror)
	{
	case AIError.ERR_NOT_ENOUGH_CASH:
		INSTANCE.builder.CriticalError=false;
		INSTANCE.bank.RaiseFundsBigTime();
		return true;
	break;
	case AIError.ERR_NONE:
		INSTANCE.builder.CriticalError=false;
		return false;
	break;
	case AIError.ERR_VEHICLE_IN_THE_WAY:
		INSTANCE.builder.CriticalError=false;
		return true;
	break;
	case AIError.ERR_LOCAL_AUTHORITY_REFUSES:
		INSTANCE.builder.CriticalError=false;
		return true;
	break;
	case AIError.ERR_ALREADY_BUILT:
		INSTANCE.builder.CriticalError=false;
		return false; // let's fake we success in that case
	break;
	default:
		INSTANCE.builder.CriticalError=true;
		return true; // critical set
	}
}

function cBuilder::ValidateLocation(location, direction, width, depth)
// check a rectangle of 5 length x size width for construction
// true if we are good to go, false on error
{
local tiletester=AITileList();
local checker=null;
switch (direction)
	{
	case AIRail.RAILTRACK_NE_SW:
// gauche/droite
		checker = AIMap.GetTileIndex(depth,width);
	break;
	case AIRail.RAILTRACK_NW_SE:
// haut/bas
		checker = AIMap.GetTileIndex(width,depth);
	break;
	}
tiletester.AddRectangle(location, location+checker);
local tile=null;
local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
// we will demolish anything that can prevent us from building, except if that thing is own by us
// this way we clean the path but still keep our previous tracks on, in case anything goes wrong
// we will still have a valid station
foreach (i, dummy in tiletester)
	{
	tile=AITile.GetOwner(i);
	// TODO: i suppose our HQ can make next test fail, so todo is add a check & move the hq
	// HQ is 2 tiles squarre
	// TODO: check also tile is own by us, but at least a train related stuff, else we may destroy
	// a road/air... station and so invaliding ourself a working route
	if (tile == weare)	continue; // tile is ok, it's one of our tile
	DInfo(tile+" my company "+weare,2);
	// Watchout for roadtile from company X crossing our rail
	tile=cTileTools.DemolishTile(i); // can we delete that tile ? Ignore result, we will care about it on next try
	tile=cTileTools.DemolishTile(i); // demolish it twice, this should remove the crossing roads case
	if (!INSTANCE.builder.IsCriticalError()) continue;
		else	{ return false; }
	}
ClearSignsALL();
return true;
}

function cBuilder::GetDirection(tilefrom, tileto)
// SimpleAI code
{
	local distx = AIMap.GetTileX(tileto) - AIMap.GetTileX(tilefrom);
	local disty = AIMap.GetTileY(tileto) - AIMap.GetTileY(tilefrom);
	local ret = 0;
	if (abs(distx) > abs(disty)) {
		ret = 2;
		disty = distx;
	}
	if (disty > 0) {ret = ret + 1}
	return ret;	
}

function cBuilder::BuildStation(start)
// Build start station, reroute to the correct station builder depending on the road type to build
{
local success=false;
switch (INSTANCE.route.route_type)
	{
	case AIVehicle.VT_ROAD:
	success=INSTANCE.builder.BuildRoadStation(start);
	break;
	case AIVehicle.VT_RAIL:
	success=INSTANCE.builder.BuildTrainStation(start);
	break;
	case AIVehicle.VT_WATER:
	break;
	case AIVehicle.VT_AIR:
	case RouteType.AIRNET:
	case RouteType.CHOPPER:
	success=INSTANCE.builder.BuildAirStation(start);
	break;
	}
return success;
}

function cBuilder::BuildRoadByType()
// build the road, reroute to correct function depending on road type
// for all except trains, src & dst = station location of start & destination station
{
local success=false;
switch (INSTANCE.route.route_type)
	{
	case AIVehicle.VT_ROAD:
	DInfo("source instance "+INSTANCE.route.source,1);
	local fromsrc=INSTANCE.route.source.GetRoadStationEntry();
	local todst=INSTANCE.route.target.GetRoadStationEntry();
	DInfo("Calling road pathfinder: from src="+fromsrc+" to dst="+todst,2);
	return INSTANCE.builder.BuildRoadROAD(fromsrc,todst);
	break;

	case AIVehicle.VT_RAIL:
	success=INSTANCE.builder.CreateStationsConnection(road.ROUTE.src_station, road.ROUTE.dst_station);
	local sentry=false; local dentry=false;
	if (success)	{
			local sSt=INSTANCE.chemin.GListGetItem(road.ROUTE.src_station);
			local dSt=INSTANCE.chemin.GListGetItem(road.ROUTE.dst_station);
			local srcpos=sSt.STATION.query;
			local dstpos=dSt.STATION.query;
			local srclink=0; local dstlink=0;
			if (sSt.STATION.e_loc == srcpos)	{ srclink=sSt.STATION.e_link; sentry=true; }
						else		{ srclink=sSt.STATION.s_link; sentry=false; }
			if (dSt.STATION.e_loc == dstpos)	{ dstlink=dSt.STATION.e_link; dentry=true; }
						else		{ dstlink=dSt.STATION.s_link; dentry=false; }
			DInfo("Calling rail pathfinder: src="+srcpos+" dst="+dstpos,2);
			PutSign(srcpos,"Source"+srcpos); PutSign(dstpos,"Target"+dstpos);
			//PutSign(srclink,"Distance: "+srclink); PutSign(dstlink,"LinkTarget"+dstlink);
			success=INSTANCE.builder.BuildRoadRAIL([srclink,srcpos],[dstlink,dstpos]);
			}
	if (!success)	{ return false; } // leave critical status for caller
	// if we are here we success
	road.ROUTE.src_entry=sentry;
	road.ROUTE.dst_entry=dentry;
	INSTANCE.chemin.RListUpdateItem(idx,road);
	break;
	default:
		return true;
	break;
	}
return success;
}

function cBuilder::FindCompatibleStationExistForAllCases(start, stationID)
// Find if we have a station that can be re-use for building_route
// compare start(source/target) station we need vs stationID
// return true if compatible
{
local compare=cStation.GetStationObject(stationID);
if (compare == null)	// might happen, we found a dead station
	{
	INSTANCE.builder.DeleteStation(-1, stationID);
	return false;
	}
DInfo("We are comparing with station #"+stationID+" "+AIStation.GetName(stationID),2);
// find if station will accept our cargo
local handling=true;
if (start)
	{
	if (!compare.cargo_produce.HasItem(INSTANCE.route.cargoID))
		{
		DInfo("That station "+AIStation.GetName(compare.stationID)+" doesn't produce "+AICargo.GetCargoLabel(INSTANCE.route.cargoID),2);
		handling=false;
		}
	}
else	{
	if (!compare.cargo_accept.HasItem(INSTANCE.route.cargoID))
		{
		DInfo("That station "+AIStation.GetName(compare.stationID)+" doesn't accept "+AICargo.GetCargoLabel(INSTANCE.route.cargoID),2);
		handling=false;
		}
	}
if (!handling)	{
		DInfo("Station "+AIStation.GetName(compare.stationID)+" refuse "+AICargo.GetCargoLabel(INSTANCE.route.cargoID),2);
		return false;
		}
// here station are compatible, but still do that station is within our original station area ?
DInfo("Checking if station is within area of our industry/town",2);
local tilecheck = null;
local goal=null;
local startistown=false;
if (start)	{ startistown=INSTANCE.route.source_istown; goal=INSTANCE.route.sourceID; }
	else	{ startistown=INSTANCE.route.target_istown; goal=INSTANCE.route.targetID; }
if (startistown)
	{ // check if the station is also influencing our town
	tilecheck=cTileTools.IsWithinTownInfluence(compare.stationID,goal);
	// for airports, the IsWithinTownInfluence always fail
	//if (!tilecheck && INSTANCE.route.station_type == AIStation.STATION_AIRPORT)
		//if (AIAirport.
//	if (!tilecheck && AIStation.HasStationType(INSTANCE.route.station_type) == AIStation.STATION_AIRPORT)
	if (!tilecheck)	
		{
		DInfo("Station is outside "+AITown.GetName(goal)+" influence",2);
		return false;
		}
	}
else	{ // check the station is within our industry
	if (start)	tilecheck=AITileList_IndustryProducing(goal, compare.radius);
		else	tilecheck=AITileList_IndustryAccepting(goal, compare.radius);
	// if the station location is in that list, the station touch the industry, nice
	local touching = false;
	foreach (position, dummy in compare.locations)
		{	if (tilecheck.HasItem(position))	touching = true; }
	if (touching)
		{ DInfo("Station is within our industry radius",2); }
	else	{ DInfo("Station is outside "+AIIndustry.GetName(goal)+" radius",2);
		return false;
		}
	}

DInfo("Checking if station can accept more vehicles",1);
// TODO: fix that fast !!! We are giving stationID to a function that need routeID
/*
if (!INSTANCE.carrier.CanAddNewVehicle(compare.stationID,start))
	{
	DInfo("Station cannot get more vehicle, even compatible, we need a new one",1);
	return false;
	}*/
return true;
}

function cBuilder::FindCompatibleStationExists()
// Find if we already have a station on a place
// if compatible, we could link to use that station too
{
// find source station compatible
local sList=AIStationList(INSTANCE.route.station_type);
DInfo("Looking for a compatible station sList="+sList.Count(),2);
DInfo("statyppe="+INSTANCE.route.station_type+" BUS="+AIStation.STATION_BUS_STOP+" TRUCK="+AIStation.STATION_TRUCK_STOP,1);
INSTANCE.builder.DumpRoute();
local source_success=false;
local target_success=false;
if (!sList.IsEmpty())
	{
	foreach (stations_check, dummy in sList)
		{
		source_success=INSTANCE.builder.FindCompatibleStationExistForAllCases(true, stations_check);
		if (source_success)
			{
			INSTANCE.route.source_stationID=stations_check;
			DInfo("Found a compatible station for the source station",1);
			break;
			}
		}
	foreach (stations_check, dummy in sList)
		{
		target_success=INSTANCE.builder.FindCompatibleStationExistForAllCases(false, stations_check);
		if (target_success)
			{
			INSTANCE.route.target_stationID=stations_check;
			DInfo("Found a compatible station for the target station",1);
			break;
			}
		}
	}
INSTANCE.NeedDelay(100);
if (!source_success)	DInfo("Failure, creating a new station for our source station.",1);
if (!target_success)	DInfo("Failure, creating a new station for our destination station.",1);
}

function cBuilder::TryBuildThatRoute()
// advance the route construction
{
local success=false;
DInfo("Route #"+INSTANCE.builder.building_route+" Status:"+INSTANCE.route.status,1);
if (INSTANCE.route.status==0) // not using switch/case so we can advance steps in one pass
	{
	switch (INSTANCE.route.route_type)
		{
		case	RouteType.RAIL:
			success=null;
		break;
		case	RouteType.ROAD:
			success=INSTANCE.carrier.ChooseRoadVeh(INSTANCE.route.cargoID);
		break;
		case	RouteType.WATER:
			success=null;
		break;
		case	RouteType.AIR:
			local modele=AircraftType.EFFICIENT;
			if (!INSTANCE.route.source_istown)	modele=AircraftType.CHOPPER;
			INSTANCE.carrier.ChooseAircraft(INSTANCE.route.cargoID, modele);
		break;
		}
	if (success == null)
		{
		DWarn("There's no vehicle for that transport type we could use to carry that cargo: "+AICargo.GetCargoLabel(INSTANCE.route.cargoID),2);
		INSTANCE.route.RouteIsNotDoable();
		return false;
		}
	else	{ INSTANCE.route.status=1; } // advance to next phase
	}
if (INSTANCE.route.status==1)
	{
	INSTANCE.builder.FindCompatibleStationExists();
	if (INSTANCE.builder.IsCriticalError())	// we could get an error when checking to upgrade station
		{
		if (INSTANCE.builder.CriticalError)
			{
			INSTANCE.builder.CriticalError = false; // unset it and keep going
			}
		else	{ // reason is not critical, lacking funds...
			INSTANCE.builddelay=true;;
			return false; // let's get out, so we still have a chance to upgrade the station & find its compatibility
			}
		}
	INSTANCE.route.status=2;
	}

if (INSTANCE.route.status==2)
	{
	if (INSTANCE.route.source_stationID==null)	{ success=INSTANCE.builder.BuildStation(true); }
		else	{
			success=true;
			DInfo("Source station is already build, we're reusing an existing one",0);
			INSTANCE.route.RouteUpdate();
			}
	if (!success)
		{ // it's bad we cannot build our source station, that's really bad !
		if (INSTANCE.builder.CriticalError)
			{
			INSTANCE.builder.CriticalError=false;
			INSTANCE.route.RouteIsNotDoable();
			return false;
			}
		else	{ INSTANCE.builddelay=true; return false; }
		}
	else { INSTANCE.route.status=3; }
	}

if (INSTANCE.route.status==3)	
	{
	if (INSTANCE.route.target_stationID==null)	{ success=INSTANCE.builder.BuildStation(false); }
		else	{
			success=true;
			DInfo("Destination station is already build, we're reusing an existing one",0);
			INSTANCE.route.RouteUpdate();
			}
	if (!success)
		{ // we cannot do destination station
		if (INSTANCE.builder.CriticalError)
			{
			INSTANCE.builder.CriticalError=false;
			INSTANCE.route.RouteIsNotDoable();
			return false;
			}
		else	{ INSTANCE.builddelay=true; return false; }
		}
	else	{ INSTANCE.route.status=4 }
	}
if (INSTANCE.route.status==4)
	{
	success=INSTANCE.builder.BuildRoadByType();
	if (success)	{ INSTANCE.route.status=5; }
		else	{
			if (INSTANCE.builder.CriticalError)
				{
				INSTANCE.builder.CriticalError=false;
				INSTANCE.route.RouteIsNotDoable();
				return false;
				}
		else	{ INSTANCE.builddelay=true; return false; }
			} // and nothing more, stay at that phase & rebuild road when possible
	}
if (INSTANCE.route.status==5)
	{ // check the route is really valid
	if (INSTANCE.route.route_type == AIVehicle.VT_ROAD)
		{
		success=INSTANCE.builder.CheckRoadHealth(INSTANCE.route.UID);
		}
	else	{ success=true; } // other route type for now are ok
	if (success)	{ INSTANCE.route.status=6; }
			else	{ INSTANCE.route.RouteIsNotDoable(); return false; }
	}	
if (INSTANCE.route.status==6)
	{
	INSTANCE.route.RouteDone();
	DInfo("Route contruction complete ! "+INSTANCE.route.name,0);
	INSTANCE.builddelay=true;
	INSTANCE.builder.building_route=-1; // Allow us to work on a new route now
	}
return success;
}

