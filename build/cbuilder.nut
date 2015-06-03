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

class cBuilder extends cClass
	{
	CriticalError=null;
	building_route= null;		// Keep here what main.route.we are working on

	constructor()
		{
		building_route= -1;
		this.ClassName="cBuilder";
		}
		function StationIsAccepting(stationid) { depcrated();}
		function StationIsProviding(stationid) { depcrated();}
		function ValidateLocation(location, direction, width, depth) { depcrated();}
        function BuildStation(routeobj, start);
        function BuildRoadByType(routeobj);
        function FindCompatibleStationExistForAllCases(routeobj, start, stationID);
        function FindCompatibleStationExists(routeobj);
		function TryBuildThatRoute(routeobj);
	}

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
		if (tile == weare)	continue; // tile is ok, it's one of our tile
		DInfo(tile+" my company "+weare,2);
		// Watchout for roadtile from company X crossing our rail
		tile=cTileTools.DemolishTile(i); // can we delete that tile ? Ignore result, we will care about it on next try
		tile=cTileTools.DemolishTile(i); // demolish it twice, this should remove the crossing roads case
		if (!cError.IsCriticalError())	continue;
								else	return false;
		}
	return true;
}

function cBuilder::BuildStation(routeobj, start)
// Build start station, reroute to the correct station builder depending on the road type to build
{
	if (!cRoute.IsValidRoute(routeobj))	return false;
	local success=false;
	switch (routeobj.VehicleType)
		{
		case AIVehicle.VT_ROAD:
		success = cBuilder.BuildRoadStation(start);
		break;
		case AIVehicle.VT_RAIL:
		success = cBuilder.BuildTrainStation(start);
		break;
		case AIVehicle.VT_WATER:
		success = cBuilder.BuildWaterStation(start);
		break;
		case RouteType.AIR:
		case RouteType.AIRMAIL:
		case RouteType.AIRNET:
		case RouteType.AIRNETMAIL:
		case RouteType.SMALLAIR:
		case RouteType.SMALLMAIL:
		case RouteType.CHOPPER:
		success = cBuilder.BuildAirStation(start);
		// we get the stationID return, but builder expect it to be in SourceStation or TargetStation to claim it
		if (success != -1)
			{
			if (start)	routeobj.SourceStation = success;
				else	routeobj.TargetStation = success;
			success = true;
			}
		else	success=false;
		break;
		}
	return success;
}

function cBuilder::BuildRoadByType(routeobj)
// build the road, reroute to correct function depending on road type
// for all except trains, src & dst = station location of start & destination station
{
	if (!cRoute.IsValidRoute(routeobj))	return false;
	local success=false;
	switch (routeobj.VehicleType)
		{
		case AIVehicle.VT_ROAD:
			DInfo("Calling road pathfinder: from " + routeobj.SourceStation.s_Name + " to " + routeobj.TargetStation.s_Name, 2);
			local fromsrc = routeobj.SourceStation.GetRoadStationEntry();
			local todst = routeobj.TargetStation.GetRoadStationEntry();
			if (!routeobj.Twoway && cBuilder.RoadRunner(fromsrc, todst, AIVehicle.VT_ROAD, routeobj.Distance))	return true;
			routeobj.Twoway = true; // mark it so roadrunner won't be run on next try
			local result = cPathfinder.GetStatus(fromsrc, todst, routeobj.SourceStation.s_ID, true, null);
			cError.ClearError();
			if (result == -2)	{ cError.RaiseError(); cPathfinder.CloseTask(fromsrc, todst); return false;}
			if (result == 2)	{ cPathfinder.CloseTask(fromsrc, todst); return true; }
			return false;
		case AIVehicle.VT_RAIL:
			success = cStationRail.CreateStationsPath(routeobj.SourceStation, routeobj.TargetStation);
			return success;
        case AIVehicle.VT_WATER:
            local src_front= cBuilder.GetDockFrontTile(routeobj.SourceStation.s_Location);
            local dst_front= cBuilder.GetDockFrontTile(routeobj.TargetStation.s_Location);
            success = cBuilder.RoadRunner(src_front, dst_front, AIVehicle.VT_WATER);
            if (!success)    { cError.RaiseError(); }
            return success;
		default:
			return true;
		break;
		}
	return success;
}

function cBuilder::FindCompatibleStationExistForAllCases(routeobj, start, stationID)
// Find if we have a station that can be re-use for building_route
// compare start(source/target) station we need vs stationID
// return true if compatible
{
	local compare = cStation.Load(stationID);
	if (!compare)	{ return false; }
	local sourcevalid = cMisc.ValidInstance(routeobj.SourceStation);
	local targetvalid = cMisc.ValidInstance(routeobj.TargetStation);
	if (sourcevalid && compare.s_ID == routeobj.SourceStation.s_ID)	return false;
	if (targetvalid && compare.s_ID == routeobj.TargetStation.s_ID)	return false;
	// bad we are comparing the same station with itself
	DInfo("We are comparing with station #" + compare.s_Name, 2);
	// find if station will accept our cargo
	local handling = true;
	if (start)
		{
		if (!compare.IsCargoProduce(routeobj.CargoID))
			{
			DInfo("Station " + compare.s_Name + " doesn't produce " + cCargo.GetCargoLabel(routeobj.CargoID), 2);
			handling = false;
			}
		}
	else	{
		if (!compare.IsCargoAccept(routeobj.CargoID))
			{
			DInfo("Station " + compare.s_Name + " doesn't accept " + cCargo.GetCargoLabel(routeobj.CargoID), 2);
			handling=false;
			}
		}
	if (!handling)
			{
			DInfo("Station " + compare.s_Name + " refuse " + cCargo.GetCargoLabel(routeobj.CargoID), 2);
			return false;
			}
	// here stations are compatibles, but still do that station is within our original station area ?
	DInfo("     Checking if " + compare.s_Name + " is within area of our industry/town", 2);
	local tilecheck = null;
	local goal = null;
	local istown = false;
	if (start)	{ istown = routeobj.SourceProcess.IsTown; goal = routeobj.SourceProcess.ID; }
		else	{ istown = routeobj.TargetProcess.IsTown; goal = routeobj.TargetProcess.ID; }
	if (istown)
			{ // check if the station is also influencing our town
			tilecheck = cTileTools.StationIsWithinTownInfluence(compare.s_ID, goal);
			if (!tilecheck)
				{
				DInfo("     Station " + compare.s_Name + " is outside " + cProcess.GetProcessName(goal, true) + " influence", 2);
				return false;
				}
			}
	else	{ // check the station is within our industry
			if (start)	tilecheck = AITileList_IndustryProducing(goal, compare.s_Radius);
				else	tilecheck = AITileList_IndustryAccepting(goal, compare.s_Radius);
			// if the station location is in that list, the station touch the industry, nice
			local touching = false;
			foreach (position, dummy in compare.s_Tiles)
				{
				if (tilecheck.HasItem(position))	{ touching = true; break; }
				}
			if (touching)	{ DInfo("     Station " + compare.s_Name + " is within range of " + cProcess.GetProcessName(goal, false), 2); }
					else	{ DInfo("     Station " + compare.s_Name + " is outside range of " + cProcess.GetProcessName(goal, false), 2); return false; }
			}
	return true;
}

function cBuilder::FindCompatibleStationExists(routeobj)
// Find if we already have a station on a place
// if compatible, we could link to use that station too
{
	// find source station compatible
	if (routeobj.StationType == null) return false;
	local sList = AIStationList(routeobj.StationType);

	DInfo("Looking for a compatible station sList=" + sList.Count(), 2);
	cBuilder.DumpRoute();
	local source_success, target_success = false;
	if (!sList.IsEmpty())
		{
		foreach (stations_check, dummy in sList)
			{
			source_success = cBuilder.FindCompatibleStationExistForAllCases(routeobj, true, stations_check);
			if (source_success)
				{
				routeobj.SourceStation = stations_check;
				DInfo("Found a compatible station for the source station",1);
				break;
				}
			}
		foreach (stations_check, dummy in sList)
			{
			target_success = cBuilder.FindCompatibleStationExistForAllCases(routeobj, false, stations_check);
			if (target_success)
				{
				routeobj.TargetStation = stations_check;
				DInfo("Found a compatible station for the target station",1);
				break;
				}
			}
		}
	local allnew = false;
	if (routeobj.StationType == AIStation.STATION_TRAIN) // the train special case
		{
		if (source_success && target_success)
			{
			local chk_src = cStation.Load(routeobj.SourceStation);
			local chk_dst = cStation.Load(routeobj.TargetStation);
			local chk_valid = false;
			foreach (owns, dummy in chk_src.s_Owner)
				if (chk_dst.s_Owner.HasItem(owns))	{ chk_valid=true; break; }
			allnew = !chk_valid;
			}
		else	allnew = true;
		}
	if (allnew)	{ routeobj.SourceStation = null; routeobj.TargetStation = null; source_success = false; target_success = false; } // make sure we create new ones

	if (!source_success)	DInfo("Failure, creating a new station for our source station.", 1);
	if (!target_success)	DInfo("Failure, creating a new station for our destination station.", 1);
}

function cBuilder::TryBuildThatRoute(routeobj)
// advance the route construction
{
	local success = false;
	DInfo("Route " + routeobj.Name, 1);
	DInfo("Status:" + routeobj.Status, 1);
	cError.ClearError();
	// not using switch/case so we can advance steps in one pass
	switch (routeobj.VehicleType)
		{
		case	RouteType.RAIL:
            if (routeobj.RailType == -1)
                    {
                    local trainspec = cCarrier.ChooseRailCouple(routeobj.CargoID, -1);
                    if (trainspec[0] == -1)	{ success = false; }
                                    else	{ success = true; }
                    if (success)    { routeobj.RailType = cEngineLib.RailTypeGetFastestType(trainspec[0]); }
                    }
            else    {
                    local trainspec = cCarrier.ChooseRailCouple(routeobj.CargoID, routeobj.RailType);
                    // must be sure one exist, as reusing a station could have change the railtype to use
                    if (trainspec[0] == -1) { success = false; }
                                    else    { success = true; }
                    }
			DInfo("Building using railtype "+cEngine.GetRailTrackName(routeobj.RailType),2);
			cTrack.SetRailType(routeobj.RailType);
		break;
		case	RouteType.ROAD:
			success = cCarrier.GetRoadVehicle(null, routeobj.CargoID);
			success = (success != -1);
		break;
		case	RouteType.WATER:
			success = cCarrier.GetWaterVehicle(null, routeobj.CargoID);
            success = (success != -1);
		break;
		case	RouteType.AIR:
		case	RouteType.AIRMAIL:
		case	RouteType.AIRNET:
		case	RouteType.AIRNETMAIL:
		case	RouteType.SMALLAIR:
		case	RouteType.SMALLMAIL:
		case	RouteType.CHOPPER:
			local modele = AircraftType.EFFICIENT;
			if (!routeobj.SourceProcess.IsTown)	modele = AircraftType.CHOPPER;
			success= cCarrier.GetAirVehicle(null, routeobj.CargoID, modele);
            success = (success != -1);
		break;
		}
	if (!success)
            {
            DWarn("There's no vehicle we could use to carry that cargo: "+cCargo.GetCargoLabel(routeobj.CargoID), 2);
            routeobj.Status = RouteStatus.DEAD;
            }
	else	{ if (routeobj.Status == 0)	routeobj.Status = 1; } // advance to next phase
	if (routeobj.Status == 1)
		{
		// for now, we just disable sharing with trains
		if (routeobj.VehicleType != RouteType.RAIL)	cBuilder.FindCompatibleStationExists(routeobj);
		if (cError.IsCriticalError())	// we could get an error when checking to upgrade station
			{
			if (cError.IsError())
					{
					cError.ClearError(); // unset it and keep going
					}
			else	{ // reason is not critical, lacking funds...
					INSTANCE.buildDelay = 2;
					return false; // let's get out, so we still have a chance to upgrade the station & find its compatibility
					}
			}
		routeobj.Status = 2;
		}
	if (routeobj.Status == 2) // change to add check against station is valid
		{
		if (routeobj.SourceStation == null)
				{
				if (routeobj.VehicleType == RouteType.RAIL)	{ cTrack.SetRailType(routeobj.RailType); }
				if (routeobj.SourceProcess.IsTown && AITown.GetRating(routeobj.SourceProcess.ID, AICompany.COMPANY_SELF) < AITown.TOWN_RATING_POOR)	{ cTileTools.SeduceTown(routeobj.SourceProcess.ID); }
				success = cBuilder.BuildStation(routeobj, true);
				if (!success && cError.IsError())	routeobj.SourceProcess.ZeroProcess();
				}
        else	{
				success=true;
				DInfo("Source station is already built, we're reusing an existing one",0);
				}
		if (success)
			{ // attach the new station object to the route, stationID of the new station is hold in SourceStation
			routeobj.SourceStation = cStation.Load(routeobj.SourceStation);
			if (!routeobj.SourceStation)	{ cError.RaiseError(); success= false; }
									else	{
											routeobj.SourceStation.OwnerClaimStation(routeobj.UID);
											if (routeobj.VehicleType == RouteType.RAIL)  { routeobj.RailType = AIRail.GetRailType(routeobj.SourceStation.s_Location); }
											}

			}
		if (!success)
                { // it's bad we cannot build our source station, that's really bad !
                if (cError.IsError())   { routeobj.Status = RouteStatus.DEAD; }
                                else	{ INSTANCE.buildDelay = 2; return false; }
                }
		else    { routeobj.Status = 3; }
		}
	if (routeobj.Status == 3)
		{
		if (routeobj.TargetStation == null)
				{
				if (routeobj.VehicleType == RouteType.RAIL)
					{
                    if (routeobj.TargetProcess.IsTown && AITown.GetRating(routeobj.TargetProcess.ID, AICompany.COMPANY_SELF) < AITown.TOWN_RATING_POOR)	cTileTools.SeduceTown(routeobj.TargetProcess.ID);
					cTrack.SetRailType(routeobj.RailType);
					}
				success = cBuilder.BuildStation(routeobj, false);
				if (!success && cError.IsError())	routeobj.TargetProcess.ZeroProcess();
				}
			else	{
				success = true;
				DInfo("Destination station is already build, we're reusing an existing one", 0);
				}
		if (success)
			{ // attach the new station object to the route, stationID of the new station is hold in TargetStation for road
			routeobj.TargetStation=cStation.Load(routeobj.TargetStation);
			if (!routeobj.TargetStation)	{ cError.RaiseError(); success = false; }
									else	routeobj.TargetStation.OwnerClaimStation(routeobj.UID);

			}
		if (!success)
			{ // we cannot do destination station
			if (cError.IsError())	routeobj.Status = RouteStatus.DEAD;
							else	{ INSTANCE.buildDelay = 2; return false; }
			}
		else	{ routeobj.Status = 4; }
		}
	if (routeobj.Status == 4) // pathfinding
		{
		success = cBuilder.BuildRoadByType(routeobj);
		if (success)
                { routeobj.Status = 5; }
        else	{
				if (cError.IsError())	{ routeobj.Status = RouteStatus.DEAD; }
                                else	{ INSTANCE.buildDelay = 1; return false; }

				} // and nothing more, stay at that phase & rebuild road when possible
		}
	if (routeobj.Status == 5)
		{ // check the route is really valid
            if (routeobj.VehicleType == AIVehicle.VT_ROAD)
                {
                success = cBuilder.CheckRoadHealth(routeobj.UID);
                }
		else	{ success = true; } // other route type for now are ok
		if (success)	{ routeobj.Status = 6; }
				else	{ routeobj.Status = RouteStatus.DEAD; }
		}
	if (routeobj.Status == 6)
		{
		local bad = false;
		if (!cMisc.ValidInstance(routeobj.SourceStation))	bad = true;
		if (!bad && !cMisc.ValidInstance(routeobj.TargetStation))	bad = true;
		if (!bad && !cMisc.ValidInstance(routeobj.SourceProcess))	bad = true;
		if (!bad && !cMisc.ValidInstance(routeobj.TargetProcess))	bad = true;
		if (!bad && !AIStation.IsValidStation(routeobj.SourceStation.s_ID))	bad = true;
		if (!bad && !AIStation.IsValidStation(routeobj.TargetStation.s_ID))	bad = true;
		if (bad)	routeobj.Status = RouteStatus.DEAD;
			else	routeobj.Status = 7;
		}
	if (routeobj.Status == 7)
		{
		routeobj.RouteDone();
		routeobj.RouteBuildGroup();
		routeobj.Route_GroupNameSave();
		DInfo("Route construction complete ! " + routeobj.Name, 0);
//		if (routeobj.
//				thatstation.s_MaxSize = thatstation.s_Size;

		print("cargoID ="+cCargo.GetCargoLabel(routeobj.CargoID));
		local srcprod=routeobj.SourceStation.IsCargoProduce(routeobj.CargoID);
		local srcacc=routeobj.SourceStation.IsCargoAccept(routeobj.CargoID);
		local dstprod=routeobj.TargetStation.IsCargoProduce(routeobj.CargoID);
		local dstacc=routeobj.TargetStation.IsCargoAccept(routeobj.CargoID);
		if (srcprod)	routeobj.SourceStation.s_CargoProduce.AddItem(routeobj.CargoID, 0);
		if (srcacc)	routeobj.SourceStation.s_CargoAccept.AddItem(routeobj.CargoID, 0);
		if (dstprod)	routeobj.TargetStation.s_CargoProduce.AddItem(routeobj.CargoID, 0);
		if (dstacc)	routeobj.TargetStation.s_CargoAccept.AddItem(routeobj.CargoID, 0);
		print("srcprod="+srcprod+" srcacc="+srcacc);
		print("dstprod="+dstprod+" dstacc="+dstacc);
		if (srcprod && srcacc && dstprod && dstacc)
			{
			DInfo("Route set as twoway", 1);
			routeobj.Twoway = true;
			}
		else	{
			DInfo("Route set as oneway", 1);
			routeobj.Twoway = false;
			}
		cRoute.RouteClaimsTiles(routeobj);
		if (INSTANCE.safeStart >0 && routeobj.VehicleType == RouteType.ROAD)	INSTANCE.safeStart--;
		cCarrier.RouteNeedVehicle(routeobj.GroupID, 2);
		INSTANCE.main.builder.building_route = -1; // Allow us to work on a new route now
		}
	if (routeobj.Status == RouteStatus.DEAD)
		{
		DInfo("TryBuildThatRoute mark " + routeobj.UID + " undoable", 1);
		routeobj.RouteIsNotDoable();
		INSTANCE.main.builder.building_route = -1;
		cError.ClearError();
		return false;
		}
	//cRoute.DutyOnRoute();
	return success;
}
