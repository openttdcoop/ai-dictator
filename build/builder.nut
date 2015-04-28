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
		if (!cError.IsCriticalError()) continue;
			else	{ return false; }
		}
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

function cBuilder::DirectionToString(dir1)
// true if direction oppose each other
{
	if (dir1 == DIR_SE)	return "DIR_SE("+DIR_SE+")";
	if (dir1 == DIR_NW)	return "DIR_NW("+DIR_NW+")";
	if (dir1 == DIR_NE)	return "DIR_NE("+DIR_NE+")";
	if (dir1 == DIR_SW)	return "DIR_SW("+DIR_SW+")";
	return "(invalid direction:"+dir1+")";
}

function cBuilder::BuildStation(start)
// Build start station, reroute to the correct station builder depending on the road type to build
{
	local success=false;
	switch (INSTANCE.main.route.VehicleType)
		{
		case AIVehicle.VT_ROAD:
		success=INSTANCE.main.builder.BuildRoadStation(start);
		break;
		case AIVehicle.VT_RAIL:
		success=INSTANCE.main.builder.BuildTrainStation(start);
		break;
		case AIVehicle.VT_WATER:
		success=INSTANCE.main.builder.BuildWaterStation(start);
		break;
		case RouteType.AIR:
		case RouteType.AIRMAIL:
		case RouteType.AIRNET:
		case RouteType.AIRNETMAIL:
		case RouteType.SMALLAIR:
		case RouteType.SMALLMAIL:
		case RouteType.CHOPPER:
		success=INSTANCE.main.builder.BuildAirStation(start);
		// we get the stationID return, but builder expect it to be in SourceStation or TargetStation to claim it
		if (success != -1)
			{
			if (start)	INSTANCE.main.route.SourceStation = success;
				else	INSTANCE.main.route.TargetStation = success;
			success = true;
			}
		else	success=false;
		break;
		}
	return success;
}

function cBuilder::BuildRoadByType()
// build the road, reroute to correct function depending on road type
// for all except trains, src & dst = station location of start & destination station
{
	local success=false;
	switch (INSTANCE.main.route.VehicleType)
		{
		case AIVehicle.VT_ROAD:
			DInfo("Calling road pathfinder: from "+INSTANCE.main.route.SourceStation.s_Name+" to "+INSTANCE.main.route.TargetStation.s_Name,2);
			local fromsrc=INSTANCE.main.route.SourceStation.GetRoadStationEntry();
			local todst=INSTANCE.main.route.TargetStation.GetRoadStationEntry();
			if (!INSTANCE.main.route.Twoway && INSTANCE.main.builder.RoadRunner(fromsrc, todst, AIVehicle.VT_ROAD, INSTANCE.main.route.Distance))	return true;
			INSTANCE.main.route.Twoway = true; // mark it so roadrunner won't be run on next try
			local result = cPathfinder.GetStatus(fromsrc, todst, INSTANCE.main.route.SourceStation.s_ID);
			cError.ClearError();
			if (result == -1)	{ cError.RaiseError(); cPathfinder.CloseTask(fromsrc, todst); return false;}
			if (result == 2)	{ cPathfinder.CloseTask(fromsrc, todst); return true; }
			return false;
		case AIVehicle.VT_RAIL:
			success=INSTANCE.main.builder.CreateStationsConnection(INSTANCE.main.route.SourceStation.s_ID, INSTANCE.main.route.TargetStation.s_ID);
			print("create station connection return : "+success);
			return success;
        case AIVehicle.VT_WATER:
            local src_front= cBuilder.GetDockFrontTile(INSTANCE.main.route.SourceStation.s_Location);
            local dst_front= cBuilder.GetDockFrontTile(INSTANCE.main.route.TargetStation.s_Location);
            success = cBuilder.RoadRunner(src_front, dst_front, AIVehicle.VT_WATER);
            if (!success)    { cError.RaiseError(); }
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
	local compare=cStation.Load(stationID);
	if (!compare)	{ return false; }
	local sourcevalid = cMisc.ValidInstance(INSTANCE.main.route.SourceStation);
	local targetvalid = cMisc.ValidInstance(INSTANCE.main.route.TargetStation);
	if (sourcevalid && compare.s_ID == INSTANCE.main.route.SourceStation.s_ID)	return false;
	if (targetvalid && compare.s_ID == INSTANCE.main.route.TargetStation.s_ID)	return false;
	// bad we are comparing the same station with itself
	DInfo("We are comparing with station #"+compare.s_Name,2);
	// find if station will accept our cargo
	local handling=true;
	if (start)
		{
		if (!compare.IsCargoProduce(INSTANCE.main.route.CargoID))
			{
			DInfo("Station "+compare.s_Name+" doesn't produce "+cCargo.GetCargoLabel(INSTANCE.main.route.CargoID),2);
			handling=false;
			}
		}
	else	{
		if (!compare.IsCargoAccept(INSTANCE.main.route.CargoID))
			{
			DInfo("Station "+compare.s_Name+" doesn't accept "+cCargo.GetCargoLabel(INSTANCE.main.route.CargoID),2);
			handling=false;
			}
		}
	if (!handling)
			{
			DInfo("Station "+compare.s_Name+" refuse "+cCargo.GetCargoLabel(INSTANCE.main.route.CargoID),2);
			return false;
			}
	// here stations are compatibles, but still do that station is within our original station area ?
	DInfo("     Checking if "+compare.s_Name+" is within area of our industry/town",2);
	local tilecheck = null;
	local goal=null;
	local istown=false;
	if (start)	{ istown=INSTANCE.main.route.SourceProcess.IsTown; goal=INSTANCE.main.route.SourceProcess.ID; }
		else	{ istown=INSTANCE.main.route.TargetProcess.IsTown; goal=INSTANCE.main.route.TargetProcess.ID; }
	if (istown)
		{ // check if the station is also influencing our town
		tilecheck=cTileTools.StationIsWithinTownInfluence(compare.s_ID, goal);
		if (!tilecheck)
			{
			DInfo("     Station "+compare.s_Name+" is outside "+cProcess.GetProcessName(goal, true)+" influence",2);
			return false;
			}
		}
	else	{ // check the station is within our industry
		if (start)	tilecheck=AITileList_IndustryProducing(goal, compare.s_Radius);
			else	tilecheck=AITileList_IndustryAccepting(goal, compare.s_Radius);
		// if the station location is in that list, the station touch the industry, nice
		local touching = false;
		foreach (position, dummy in compare.s_Tiles)
			{
			if (tilecheck.HasItem(position))	{ touching = true; break; }
			}
		if (touching)
			{ DInfo("     Station "+compare.s_Name+" is within range of "+cProcess.GetProcessName(goal, false),2); }
		else	{
			{ DInfo("     Station "+compare.s_Name+" is outside range of "+cProcess.GetProcessName(goal, false),2); }
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
	if (INSTANCE.main.route.StationType == null) return false;
	local sList=AIStationList(INSTANCE.main.route.StationType);

	DInfo("Looking for a compatible station sList="+sList.Count(),2);
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
				INSTANCE.main.route.SourceStation = stations_check;
				DInfo("Found a compatible station for the source station",1);
				break;
				}
			}
		foreach (stations_check, dummy in sList)
			{
			target_success=INSTANCE.main.builder.FindCompatibleStationExistForAllCases(false, stations_check);
			if (target_success)
				{
				INSTANCE.main.route.TargetStation = stations_check;
				DInfo("Found a compatible station for the target station",1);
				break;
				}
			}
		}
	local allnew=false;
	if (INSTANCE.main.route.StationType == AIStation.STATION_TRAIN) // the train special case
		{
		if (source_success && target_success)
			{
			local chk_src=cStation.Load(INSTANCE.main.route.SourceStation);
			local chk_dst=cStation.Load(INSTANCE.main.route.TargetStation);
			local chk_valid=false;
			foreach (owns, dummy in chk_src.s_Owner)
				if (chk_dst.s_Owner.HasItem(owns))	{ chk_valid=true; break; }
			allnew=!chk_valid;
			}
		else	allnew=true;
		}
	if (allnew)	{ INSTANCE.main.route.SourceStation=null; INSTANCE.main.route.TargetStation=null; source_success=false; target_success=false; } // make sure we create new ones

	if (!source_success)	DInfo("Failure, creating a new station for our source station.",1);
	if (!target_success)	DInfo("Failure, creating a new station for our destination station.",1);
}

function cBuilder::TryBuildThatRoute()
// advance the route construction
{
	local success=false;
	DInfo("Route "+INSTANCE.main.route.Name,1);
	DInfo("Status:"+INSTANCE.main.route.Status,1);
	// not using switch/case so we can advance steps in one pass
	switch (INSTANCE.main.route.VehicleType)
		{
		case	RouteType.RAIL:
            if (INSTANCE.main.route.RailType == -1)
                    {
                    local trainspec = cCarrier.ChooseRailCouple(INSTANCE.main.route.CargoID, -1);
                    if (trainspec[0] == -1)	{ success = false; }
                                    else	{ success = true; }
                    if (success)    { INSTANCE.main.route.RailType = cEngineLib.RailTypeGetFastestType(trainspec[0]); }
                    }
            else    {
                    local trainspec = cCarrier.ChooseRailCouple(INSTANCE.main.route.CargoID, INSTANCE.main.route.RailType);
                    // must be sure one exist, as reusing a station could have change the railtype to use
                    if (trainspec[0] == -1) { success = false; }
                                    else    { success = true; }
                    }
			DInfo("Building using railtype "+cEngine.GetRailTrackName(INSTANCE.main.route.RailType),2);
			cTrack.SetRailType(INSTANCE.main.route.RailType);
		break;
		case	RouteType.ROAD:
			success = cCarrier.GetRoadVehicle(null, INSTANCE.main.route.CargoID);
			success = (success != -1);
		break;
		case	RouteType.WATER:
			success = cCarrier.GetWaterVehicle(null, INSTANCE.main.route.CargoID);
            success = (success != -1);
		break;
		case	RouteType.AIR:
		case	RouteType.AIRMAIL:
		case	RouteType.AIRNET:
		case	RouteType.AIRNETMAIL:
		case	RouteType.SMALLAIR:
		case	RouteType.SMALLMAIL:
		case	RouteType.CHOPPER:
			local modele=AircraftType.EFFICIENT;
			if (!INSTANCE.main.route.SourceProcess.IsTown)	modele=AircraftType.CHOPPER;
			success= cCarrier.GetAirVehicle(null, INSTANCE.main.route.CargoID, modele);
            success = (success != -1);
		break;
		}
	if (!success)
            {
            DWarn("There's no vehicle we could use to carry that cargo: "+cCargo.GetCargoLabel(INSTANCE.main.route.CargoID),2);
            INSTANCE.main.route.Status = RouteStatus.DEAD;
            }
	else	{ if (INSTANCE.main.route.Status==0)	INSTANCE.main.route.Status=1; } // advance to next phase
	if (INSTANCE.main.route.Status==1)
		{
		INSTANCE.main.builder.FindCompatibleStationExists();
		if (cError.IsCriticalError())	// we could get an error when checking to upgrade station
			{
			if (cError.IsError())
				{
				cError.ClearError(); // unset it and keep going
				}
			else	{ // reason is not critical, lacking funds...
				INSTANCE.buildDelay=2;
				return false; // let's get out, so we still have a chance to upgrade the station & find its compatibility
				}
			}
		INSTANCE.main.route.Status=2;
		}
	if (INSTANCE.main.route.Status==2) // change to add check against station is valid
		{
		if (INSTANCE.main.route.SourceStation == null)
				{
				if (INSTANCE.main.route.VehicleType == RouteType.RAIL)	{ cTrack.SetRailType(INSTANCE.main.route.RailType); }
				if (INSTANCE.main.route.SourceProcess.IsTown && AITown.GetRating(INSTANCE.main.route.SourceProcess.ID, AICompany.COMPANY_SELF) < AITown.TOWN_RATING_POOR)	{ cTileTools.SeduceTown(INSTANCE.main.route.SourceProcess.ID); }
				success = INSTANCE.main.builder.BuildStation(true);
				if (!success && cError.IsError())	INSTANCE.main.route.SourceProcess.ZeroProcess();
				}
        else	{
				success=true;
				DInfo("Source station is already built, we're reusing an existing one",0);
				}
		if (success)
			{ // attach the new station object to the route, stationID of the new station is hold in SourceStation
			INSTANCE.main.route.SourceStation = cStation.Load(INSTANCE.main.route.SourceStation);
			if (!INSTANCE.main.route.SourceStation)	{ cError.RaiseError(); success= false; }
                                            else	{
                                                    INSTANCE.main.route.SourceStation.OwnerClaimStation(INSTANCE.main.route.UID);
                                                    if (INSTANCE.main.route.VehicleType == RouteType.RAIL)  { INSTANCE.main.route.RailType = AIRail.GetRailType(INSTANCE.main.route.SourceStation.s_Location); }
                                                    }

			}
		if (!success)
                { // it's bad we cannot build our source station, that's really bad !
                if (cError.IsError())   { INSTANCE.main.route.Status = RouteStatus.DEAD; }
                                else	{ INSTANCE.buildDelay=2; return false; }
                }
		else    { INSTANCE.main.route.Status=3; }
		}
	if (INSTANCE.main.route.Status==3)
		{
		if (INSTANCE.main.route.TargetStation == null)
				{
				if (INSTANCE.main.route.VehicleType == RouteType.RAIL)
					{
                    if (INSTANCE.main.route.TargetProcess.IsTown && AITown.GetRating(INSTANCE.main.route.TargetProcess.ID, AICompany.COMPANY_SELF) < AITown.TOWN_RATING_POOR)	cTileTools.SeduceTown(INSTANCE.main.route.TargetProcess.ID);
					cTrack.SetRailType(INSTANCE.main.route.RailType);
					}
				success=INSTANCE.main.builder.BuildStation(false);
				if (!success && cError.IsError())	INSTANCE.main.route.TargetProcess.ZeroProcess();
				}
			else	{
				success=true;
				DInfo("Destination station is already build, we're reusing an existing one",0);
				}
		if (success)
			{ // attach the new station object to the route, stationID of the new station is hold in TargetStation for road
			INSTANCE.main.route.TargetStation=cStation.Load(INSTANCE.main.route.TargetStation);
			if (!INSTANCE.main.route.TargetStation)	{ cError.RaiseError(); success= false; }
											else	INSTANCE.main.route.TargetStation.OwnerClaimStation(INSTANCE.main.route.UID);

			}
		if (!success)
			{ // we cannot do destination station
			if (cError.IsError())	INSTANCE.main.route.Status = RouteStatus.DEAD;
							else	{ INSTANCE.buildDelay=2; return false; }
			}
		else	{ INSTANCE.main.route.Status=4 }
		}
	if (INSTANCE.main.route.Status==4) // pathfinding
		{
		success=INSTANCE.main.builder.BuildRoadByType();
		if (success)
                { INSTANCE.main.route.Status=5; }
        else	{
        print("trybuildthatroute: pathfind fail");
				if (cError.IsError())	{ INSTANCE.main.route.Status = RouteStatus.DEAD; }
                                else	{ INSTANCE.buildDelay = 1; return false; }

				} // and nothing more, stay at that phase & rebuild road when possible
		}
	if (INSTANCE.main.route.Status==5)
		{ // check the route is really valid
            if (INSTANCE.main.route.VehicleType == AIVehicle.VT_ROAD)
                {
                success=INSTANCE.main.builder.CheckRoadHealth(INSTANCE.main.route.UID);
                }
		else	{ success=true; } // other route type for now are ok
		if (success)	{ INSTANCE.main.route.Status=6; }
				else	{ INSTANCE.main.route.Status=RouteStatus.DEAD; }
		}
	if (INSTANCE.main.route.Status==6)
		{
		local bad = false;
		if (!cMisc.ValidInstance(INSTANCE.main.route.SourceStation))	bad=true;
		if (!bad && !cMisc.ValidInstance(INSTANCE.main.route.TargetStation))	bad=true;
		if (!bad && !cMisc.ValidInstance(INSTANCE.main.route.SourceProcess))	bad=true;
		if (!bad && !cMisc.ValidInstance(INSTANCE.main.route.TargetProcess))	bad=true;
		if (!bad && !AIStation.IsValidStation(INSTANCE.main.route.SourceStation.s_ID))	bad=true;
		if (!bad && !AIStation.IsValidStation(INSTANCE.main.route.TargetStation.s_ID))	bad=true;
		if (bad)	INSTANCE.main.route.Status=RouteStatus.DEAD;
			else	INSTANCE.main.route.Status=7;
		}
	if (INSTANCE.main.route.Status==7)
		{
		INSTANCE.main.route.RouteDone();
		INSTANCE.main.route.RouteBuildGroup();
		INSTANCE.main.route.Route_GroupNameSave();
		DInfo("Route construction complete ! "+INSTANCE.main.route.Name,0);
		print("cargoID ="+cCargo.GetCargoLabel(INSTANCE.main.route.CargoID));
		local srcprod=INSTANCE.main.route.SourceStation.IsCargoProduce(INSTANCE.main.route.CargoID);
		local srcacc=INSTANCE.main.route.SourceStation.IsCargoAccept(INSTANCE.main.route.CargoID);
		local dstprod=INSTANCE.main.route.TargetStation.IsCargoProduce(INSTANCE.main.route.CargoID);
		local dstacc=INSTANCE.main.route.TargetStation.IsCargoAccept(INSTANCE.main.route.CargoID);
		if (srcprod)	INSTANCE.main.route.SourceStation.s_CargoProduce.AddItem(INSTANCE.main.route.CargoID,0);
		if (srcacc)	INSTANCE.main.route.SourceStation.s_CargoAccept.AddItem(INSTANCE.main.route.CargoID,0);
		if (dstprod)	INSTANCE.main.route.TargetStation.s_CargoProduce.AddItem(INSTANCE.main.route.CargoID,0);
		if (dstacc)	INSTANCE.main.route.TargetStation.s_CargoAccept.AddItem(INSTANCE.main.route.CargoID,0);
		print("srcprod="+srcprod+" srcacc="+srcacc);
		print("dstprod="+dstprod+" dstacc="+dstacc);
		if (srcprod && srcacc && dstprod && dstacc)
			{
			DInfo("Route set as twoway",1);
			INSTANCE.main.route.Twoway=true;
			}
		else	{
			DInfo("Route set as oneway",1);
			INSTANCE.main.route.Twoway=false;
			}
		INSTANCE.main.route.RouteClaimsTiles();
		INSTANCE.main.builder.building_route=-1; // Allow us to work on a new route now
		if (INSTANCE.safeStart >0 && INSTANCE.main.route.VehicleType == RouteType.ROAD)	INSTANCE.safeStart--;
		INSTANCE.main.route.DutyOnRoute();
		}
	if (INSTANCE.main.route.Status == RouteStatus.DEAD)
		{
		DInfo("TryBuildThatRoute mark "+INSTANCE.main.route.UID+" undoable",1);
		INSTANCE.main.route.RouteIsNotDoable();
		INSTANCE.main.builder.building_route=-1;
		return false;
		}
	return success;
}
