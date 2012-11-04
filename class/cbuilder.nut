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

class cBuilder extends cClass
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
	building_route= null;		// Keep here what main.route.we are working on
	
	constructor()
		{
		building_route= -1;
		this.ClassName="cBuilder";
		}
	}

function cBuilder::SetRailType(rtype=null)
// set current railtype
{
	if (rtype == null)
		{
		local railtypes = AIRailTypeList();
		if (railtypes.IsEmpty())	{ DWarn("There's no railtype available !",1); return false; }
		rtype=railtypes.Begin();
		}
	if (!AIRail.IsRailTypeAvailable(rtype))	{ DWarn("Railtype "+rtype+" is not available !",1); return false; }
	AIRail.SetCurrentRailType(rtype);
}


/*
function cBuilder::StationIsAccepting(stationid)
// add that station to the station_drop list
{
if (!INSTANCE.main.builder.station_drop.HasItem(stationid))	INSTANCE.main.builder.station_take.AddItem(stationid, 1);
}

function cBuilder::StationIsProviding(stationid)
// add that station to the station_take list
{
if (!INSTANCE.main.builder.station_take.HasItem(stationid))	INSTANCE.main.builder.station_take.AddItem(stationid, 1);
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
	if (!INSTANCE.main.builder.IsCriticalError()) continue;
		else	{ return false; }
	}
ClearSigns();
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
// Build start station, remain.route.to the correct station main.builder.depending on the road type to build
{
local success=false;
switch (INSTANCE.main.route.main.route.type)
	{
	case AIVehicle.VT_ROAD:
	success=INSTANCE.main.builder.BuildRoadStation(start);
	break;
	case AIVehicle.VT_RAIL:
	success=INSTANCE.main.builder.BuildTrainStation(start);
	break;
	case AIVehicle.VT_WATER:
	break;
	case RouteType.AIR:
	case RouteType.AIRMAIL:
	case RouteType.AIRNET:
	case RouteType.AIRNETMAIL:
	case RouteType.SMALLAIR:
	case RouteType.SMALLMAIL:
	case RouteType.CHOPPER:
	success=INSTANCE.main.builder.BuildAirStation(start);
	if (success!=-1)	success=true;
			else	success=false;
	break;
	}
return success;
}

function cBuilder::BuildRoadByType()
// build the road, remain.route.to correct function depending on road type
// for all except trains, src & dst = station location of start & destination station
{
local success=false;
switch (INSTANCE.main.route.main.route.type)
	{
	case AIVehicle.VT_ROAD:
	local fromsrc=INSTANCE.main.route.source.GetRoadStationEntry();
	local todst=INSTANCE.main.route.target.GetRoadStationEntry();
	DInfo("Calling road pathfinder: from src="+fromsrc+" to dst="+todst,2,"BuildRoadByType");
	if (!INSTANCE.main.builder.RoadRunner(fromsrc, todst, AIVehicle.VT_ROAD))	return INSTANCE.main.builder.BuildRoadROAD(fromsrc,todst);
												else	return true;
	case AIVehicle.VT_RAIL:
	success=INSTANCE.main.builder.CreateStationsConnection(INSTANCE.main.route.source_stationID, INSTANCE.main.route.target_stationID);
	return success;
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
	INSTANCE.main.builder.DeleteStation(-1, stationID);
	DInfo("Removing station "+cStation.StationGetName(stationID)+" that is unused.",1,"FindCompatibleStationExistForAllCases");
	return false;
	}
if (compare.stationID == INSTANCE.main.route.source_stationID)	return false;
if (compare.stationID == INSTANCE.main.route.target_stationID)	return false;
//if (compare.stationType == AIStation.STATION_TRAIN)	return false; // mark all rail stations incompatible to sharing
DInfo("We are comparing with station #"+stationID+" "+cStation.StationGetName(stationID),2);
// find if station will accept our cargo
local handling=true;
if (start)
	{
	if (!compare.IsCargoProduce(INSTANCE.main.route.cargoID))
		{
		DInfo("That station "+cStation.StationGetName(compare.stationID)+" doesn't produce "+AICargo.GetCargoLabel(INSTANCE.main.route.cargoID),2,"cBuilder::FindCompatibleStationExistsForAllCases");
		handling=false;
		}
	}
else	{
	if (!compare.IsCargoAccept(INSTANCE.main.route.cargoID))
		{
		DInfo("That station "+cStation.StationGetName(compare.stationID)+" doesn't accept "+AICargo.GetCargoLabel(INSTANCE.main.route.cargoID),2,"cBuilder::FindCompatibleStationExistsForAllCases");
		handling=false;
		}
	}
if (!handling)	{
		DInfo("Station "+cStation.StationGetName(compare.stationID)+" refuse "+AICargo.GetCargoLabel(INSTANCE.main.route.cargoID),2,"cBuilder::FindCompatibleStationExistsForAllCases");
		return false;
		}
// here station are compatible, but still do that station is within our original station area ?
DInfo("Checking if station is within area of our industry/town",2,"cBuilder::FindCompatibleStationExistsForAllCases");
local tilecheck = null;
local goal=null;
local startistown=false;
if (start)	{ startistown=INSTANCE.main.route.source_istown; goal=INSTANCE.main.route.sourceID; }
	else	{ startistown=INSTANCE.main.route.target_istown; goal=INSTANCE.main.route.targetID; }
if (startistown)
	{ // check if the station is also influencing our town
	tilecheck=cTileTools.IsWithinTownInfluence(compare.stationID,goal);
	if (!tilecheck)	
		{
		DInfo("Station is outside "+AITown.GetName(goal)+" influence",2,"cBuilder::FindCompatibleStationExistsForAllCases");
		return false;
		}
	}
else	{ // check the station is within our industry
	if (start)	tilecheck=AITileList_IndustryProducing(goal, compare.radius);
		else	tilecheck=AITileList_IndustryAccepting(goal, compare.radius);
	// if the station location is in that list, the station touch the industry, nice
	local touching = false;
	local stationtiles=cTileTools.FindStationTiles(AIStation.GetLocation(compare.stationID));
	foreach (position, dummy in stationtiles)
		{	if (tilecheck.HasItem(position))	touching = true; }
	if (touching)
		{ DInfo("Station is within our industry radius",2,"cBuilder::FindCompatibleStationExistsForAllCases"); }
	else	{
		DInfo("Station is outside "+AIIndustry.GetName(goal)+" radius",2,"cBuilder::FindCompatibleStationExistsForAllCases");
		return false;
		}
	}
return true;
}

function cBuilder::FindCompatibleStationExists()
// Find if we already have a station on a place
// if compatible, we could link to use that station too
{
// find source station compatible
if (INSTANCE.main.route.station_type==null) return false;
local sList=AIStationList(INSTANCE.main.route.station_type);
DInfo("Looking for a compatible station sList="+sList.Count(),2,"cBuilder::FindCompatibleStationExists");
DInfo("statyppe="+INSTANCE.main.route.station_type+" BUS="+AIStation.STATION_BUS_STOP+" TRUCK="+AIStation.STATION_TRUCK_STOP,1,"cBuilder::FindCompatibleStationExists");
INSTANCE.main.builder.DumpRoute();
local source_success=false;
local target_success=false;
if (!sList.IsEmpty())
	{
	foreach (stations_check, dummy in sList)
		{
		source_success=INSTANCE.main.builder.FindCompatibleStationExistForAllCases(true, stations_check);
		if (source_success)
			{
			INSTANCE.main.route.source_stationID=stations_check;
			DInfo("Found a compatible station for the source station",1,"cBuilder::FindCompatibleStationExists");
			break;
			}
		}
	foreach (stations_check, dummy in sList)
		{
		target_success=INSTANCE.main.builder.FindCompatibleStationExistForAllCases(false, stations_check);
		if (target_success)
			{
			INSTANCE.main.route.target_stationID=stations_check;
			DInfo("Found a compatible station for the target station",1,"cBuilder::FindCompatibleStationExists");
			break;
			}
		}
	}
local allnew=false;
if (INSTANCE.main.route.station_type == AIStation.STATION_TRAIN) // the train special case
	{
	if (source_success && target_success)
		{
		local chk_src=cStation.GetStationObject(INSTANCE.main.route.source_stationID);
		local chk_dst=cStation.GetStationObject(INSTANCE.main.route.target_stationID);
		local chk_valid=false;
		foreach (owns, dummy in chk_src.owner)
			if (chk_dst.owner.HasItem(owns))	chk_valid=true;
		allnew=!chk_valid;
		}
	else	allnew=true;
	}
if (allnew)	{ INSTANCE.main.route.source_stationID=null; INSTANCE.main.route.target_stationID=null; source_success=false; target_success=false; } // make sure we create new ones

if (!source_success)	DInfo("Failure, creating a new station for our source station.",1,"cBuilder::FindCompatibleStationExists");
if (!target_success)	DInfo("Failure, creating a new station for our destination station.",1,"cBuilder::FindCompatibleStationExists");
}

function cBuilder::TryBuildThatRoute()
// advance the main.route.construction
{
local success=false;
local buildWithRailType=null;
DInfo("Route #"+INSTANCE.main.builder.building_main.route." Status:"+INSTANCE.main.route.status,1,"TryBuildThatRoute");
// not using switch/case so we can advance steps in one pass
switch (INSTANCE.main.route.main.route.type)
	{
	case	RouteType.RAIL:
		local trainspec=INSTANCE.main.vehicle.ChooseRailCouple(INSTANCE.main.route.cargoID);
		if (trainspec.IsEmpty())	success=null;
						else	success=true;
		if (success)	buildWithRailType=cCarrier.GetRailTypeNeedForEngine(trainspec.Begin());
		if (success==-1)	success=null;
		if (INSTANCE.main.route.source_stationID != null && INSTANCE.main.route.rail_type == null && AIStation.IsValidStation(INSTANCE.main.route.source_stationID))
			{ // make sure we set rails as the first station and not like the ones detect from the train
			INSTANCE.main.route.rail_type=AIRail.GetRailType(AIStation.GetLocation(INSTANCE.main.route.source_stationID));
			buildWithRailType=INSTANCE.main.route.rail_type;
			}
		DInfo("Building using "+buildWithRailType+" rail type",2,"TryBuildThatRoute");
	break;
	case	RouteType.ROAD:
		success=INSTANCE.main.vehicle.ChooseRoadVeh(INSTANCE.main.route.cargoID);
	break;
	case	RouteType.WATER:
		success=null;
	break;
	case	RouteType.AIR:
	case	RouteType.AIRMAIL:
	case	RouteType.AIRNET:
	case	RouteType.AIRNETMAIL:
	case	RouteType.SMALLAIR:
	case	RouteType.SMALLMAIL:
	case	RouteType.CHOPPER:
		local modele=AircraftType.EFFICIENT;
		if (!INSTANCE.main.route.source_istown)	modele=AircraftType.CHOPPER;
		success=INSTANCE.main.vehicle.ChooseAircraft(INSTANCE.main.route.cargoID, INSTANCE.main.route.distance, modele);
	break;
	}
if (!success)
	{
	DWarn("There's no vehicle we could use to carry that cargo: "+AICargo.GetCargoLabel(INSTANCE.main.route.cargoID),2,"TryBuildThatRoute");
	INSTANCE.main.route.RouteIsNotDoable();
	INSTANCE.main.builder.building_main.route.-1;
	return false;
	}
else	{ if (INSTANCE.main.route.status==0)	INSTANCE.main.route.status=1; } // advance to next phase

if (INSTANCE.main.route.status==1)
	{
	INSTANCE.main.builder.FindCompatibleStationExists();
	if (INSTANCE.main.builder.IsCriticalError())	// we could get an error when checking to upgrade station
		{
		if (INSTANCE.main.builder.CriticalError)
			{
			INSTANCE.main.builder.CriticalError = false; // unset it and keep going
			}
		else	{ // reason is not critical, lacking funds...
			INSTANCE.builddelay=true;
			return false; // let's get out, so we still have a chance to upgrade the station & find its compatibility
			}
		}
	INSTANCE.main.route.status=2;
	}
if (INSTANCE.main.route.status==2) // change to add check against station is valid
	{
	if (INSTANCE.main.route.source_stationID==null)
			{
			if (INSTANCE.main.route.main.route.type == RouteType.RAIL)	INSTANCE.main.builder.SetRailType(buildWithRailType);
			success=INSTANCE.main.builder.BuildStation(true);
			}
		else	{
			success=true;
			DInfo("Source station is already build, we're reusing an existing one",0,"TryBuildThatRoute");
			}
	if (!success)
		{ // it's bad we cannot build our source station, that's really bad !
		if (INSTANCE.main.builder.CriticalError)
			{
			INSTANCE.main.builder.CriticalError=false;
			INSTANCE.main.route.RouteIsNotDoable();
			INSTANCE.main.builder.building_main.route.-1;
			return false;
			}
		else	{ INSTANCE.builddelay=true; return false; }
		}
	else { INSTANCE.main.route.status=3; }
	}
if (INSTANCE.main.route.status==3)	
	{
	if (INSTANCE.main.route.target_stationID==null)
			{
			if (INSTANCE.main.route.main.route.type == RouteType.RAIL)
				{
				buildWithRailType=AIRail.GetRailType(AIStation.GetLocation(INSTANCE.main.route.source_stationID));
				INSTANCE.main.builder.SetRailType(buildWithRailType);
				}
			success=INSTANCE.main.builder.BuildStation(false);
			}
		else	{
			success=true;
			DInfo("Destination station is already build, we're reusing an existing one",0,"TryBuildThatRoute");
			}
	if (!success)
		{ // we cannot do destination station
		if (INSTANCE.main.builder.CriticalError)
			{
			INSTANCE.main.builder.CriticalError=false;
			INSTANCE.main.route.RouteIsNotDoable();
			INSTANCE.main.builder.building_main.route.-1;
			return false;
			}
		else	{ INSTANCE.builddelay=true; return false; }
		}
	else	{ INSTANCE.main.route.status=4 }
	}
if (INSTANCE.main.route.status==4) // pathfinding
	{
	INSTANCE.main.route.RouteCheckEntry();
	success=INSTANCE.main.builder.BuildRoadByType();
	if (success)	{ INSTANCE.main.route.status=5; }
		else	{
			if (INSTANCE.main.builder.CriticalError)
				{
				INSTANCE.main.builder.CriticalError=false;
				INSTANCE.main.route.RouteIsNotDoable();
				INSTANCE.main.builder.building_main.route.-1;
				return false;
				}
		else	{ return false; }
			} // and nothing more, stay at that phase & rebuild road when possible
	}
if (INSTANCE.main.route.status==5)
	{ // check the main.route.is really valid
	if (INSTANCE.main.route.main.route.type == AIVehicle.VT_ROAD)
		{
		INSTANCE.main.route.RouteCheckEntry();
		success=INSTANCE.main.builder.CheckRoadHealth(INSTANCE.main.route.UID);
		}
	else	{ success=true; } // other main.route.type for now are ok
	if (success)	{ INSTANCE.main.route.status=6; }
			else	{ INSTANCE.main.route.RouteIsNotDoable(); INSTANCE.main.builder.building_main.route.-1; return false; }
	}	
if (INSTANCE.main.route.status==6)
	{
	INSTANCE.main.route.RouteDone();
	DInfo("Route contruction complete ! "+cRoute.RouteGetName(INSTANCE.main.route.UID),0,"TryBuildThatRoute");
	local srcprod=INSTANCE.main.route.source.IsCargoProduce(INSTANCE.main.route.cargoID);
	local srcacc=INSTANCE.main.route.source.IsCargoAccept(INSTANCE.main.route.cargoID);
	local dstprod=INSTANCE.main.route.target.IsCargoProduce(INSTANCE.main.route.cargoID);
	local dstacc=INSTANCE.main.route.target.IsCargoAccept(INSTANCE.main.route.cargoID);
	if (srcprod && srcacc && dstprod && dstacc)
		{
		DInfo("Route set as twoway",0,"TryBuildThatRoute");
		INSTANCE.main.route.twoway=true;
		}
	else	{
		DInfo("Route set as oneway",0,"TryBuildThatRoute");
		INSTANCE.main.route.twoway=false;
		}
	INSTANCE.builddelay=false;
	INSTANCE.main.builder.building_main.route.-1; // Allow us to work on a new main.route.now
	if (INSTANCE.safeStart >0 && INSTANCE.main.route.main.route.type == RouteType.ROAD)	INSTANCE.safeStart--;
	//if (INSTANCE.main.route.main.route.type==RouteType.RAIL)	INSTANCE.main.route.DutyOnRailsRoute(INSTANCE.main.route.UID);
	//							else	INSTANCE.main.route.DutyOnRoute();
	}
return success;
}
*/
