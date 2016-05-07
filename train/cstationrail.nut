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


class cStationRail extends cStation
{
	s_UseEntry		= null;	// if we use the entry of the station or its exit
	s_MainLine		= null; // location where to find main line
	s_AltLine		= null;	// location where to find alternate line
	s_Direction		= null; // direction the station use (SE, NE, NW, SW)
    s_Depth			= null; // the length/depth of the station
    s_LineState		= null; // 0 - nothing done, 1- main line done, 2- alt line done, 3- main signal done, 4- alt signal done
	s_Platforms		= null;	// AIList of platforms: item=platform location, value: 1- working, 0- non working
							// platform item -1 & -2 are topright and topleft plaform, value = location
	s_Platforms_OK	= null; // number of working platforms (less -1 & -2)

	constructor()
		{
		::cStation.constructor();
		this.ClassName="cStationRail";
		this.s_UseEntry = null;
		this.s_MainLine = -1;
		this.s_AltLine = -1;
		this.s_Direction = -1;
		this.s_Depth = -1;
		this.s_LineState = null;
		this.s_Platforms = AIList();
		this.s_Platforms_OK = 0;
		}
}

function cStationRail::DetectRailStation()
{
	this.s_SubType = AIRail.GetRailType(this.s_Location);
	local statiles = AIList();
	statiles.AddList(this.s_Tiles);
	statiles.Valuate(AIRail.GetRailType);
	statiles.RemoveValue(this.s_SubType);
	if (!statiles.IsEmpty())
		{
		DInfo("Mismatch in station railtype... "+statiles.Count()+" tracks are wrong.");
		cBanker.RaiseFundsBigTime();
		foreach (tiles, _ in statiles)	cTrack.ConvertRailType(tiles, this.s_SubType);
		}
	statiles.AddList(this.s_Tiles);
	statiles.Valuate(AIMap.GetTileX);
	statiles.KeepValue(AIMap.GetTileX(this.s_Location));
	local x = statiles.Count();
	statiles.AddList(this.s_Tiles);
	statiles.Valuate(AIMap.GetTileY);
	statiles.KeepValue(AIMap.GetTileY(this.s_Location));
	local y = statiles.Count();
	local direction = AIRail.GetRailStationDirection(this.s_Location);
	local forward, side, fixme;
	if (direction == AIRail.RAILTRACK_NW_SE)	{
												this.s_Size = y;
												this.s_Depth = x;
												forward = AIMap.GetTileIndex(0, -1);
												side = AIMap.GetTileIndex(1, 0);
												fixme = this.s_Location;
												// normal X E  loc=E
                                                // inverse E X loc=X
												}
										else	{
												this.s_Size = x;
												this.s_Depth = y;
												forward = AIMap.GetTileIndex(-1, 0);
												side = AIMap.GetTileIndex(0, -1);
												fixme = this.s_Location - side;
												// normal X E loc=X
												// revert E X loc=E
												}
    // to find out station entry/exit in use, we look for signals clues
    local sigpos = fixme + (2 * forward);
	this.s_UseEntry = null;
    local is_entry_signal = (AIRail.GetSignalType(sigpos, sigpos - forward) == AIRail.SIGNALTYPE_PBS);
    if (is_entry_signal)	this.s_MainLine = sigpos;
    sigpos += side;
    local is_exit_signal = (AIRail.GetSignalType(sigpos, sigpos + forward) == AIRail.SIGNALTYPE_PBS);
	if (is_exit_signal)	this.s_AltLine = sigpos;
	if (is_entry_signal && is_exit_signal)	this.s_UseEntry = true;
	if (this.s_UseEntry == null) // we didn't found them, so try other side of station
		{
		sigpos = fixme + side - ((1 + this.s_Depth) * forward);
		is_entry_signal = (AIRail.GetSignalType(sigpos, sigpos + forward) == AIRail.SIGNALTYPE_PBS);
		if (is_entry_signal)	this.s_MainLine = sigpos;
		sigpos -= side;
		is_exit_signal = (AIRail.GetSignalType(sigpos, sigpos - forward) == AIRail.SIGNALTYPE_PBS);
		if (is_exit_signal)	this.s_AltLine = sigpos;
		if (is_entry_signal && is_exit_signal)	this.s_UseEntry = false;
		}
	if (this.s_UseEntry != null)
		{
		statiles.Clear();
		local step;
		if (direction == AIRail.RAILTRACK_NW_SE)	{ this.s_Direction = this.s_UseEntry ? DIR_NW : DIR_SE; }
											else	{ this.s_Direction = this.s_UseEntry ? DIR_NE : DIR_SW; }
		if (this.s_UseEntry)	step = -forward;
						else	step = forward;
		local walk = this.s_MainLine;
		while (AIStation.GetStationID(walk) != this.s_ID)	{ AISign.BuildSign(walk, "*"); statiles.AddItem(walk, this.s_ID); cTileTools.BlackListTile(walk, this.s_ID); walk += step; }
		walk = this.s_AltLine;
		while (AIStation.GetStationID(walk) != this.s_ID)	{ AISign.BuildSign(walk, "o"); statiles.AddItem(walk, this.s_ID); cTileTools.BlackListTile(walk, this.s_ID); walk += step; }
		this.s_TilesOther.AddList(statiles);
		}
	DInfo("Station " + this.s_Name+" depth: " + this.s_Depth + " direction:" + cDirection.DirectionToString(this.s_Direction) + " size:" + this.s_Size + " type:" + cEngine.GetRailTrackName(this.s_SubType) + " other:" + this.s_TilesOther.Count()+" useEntry: "+this.s_UseEntry + " depot: " + cMisc.Locate(cStationRail.GetStationDepot(this.s_ID)), 1);
	cStationRail.DefinePlatform(this);
}

function cStationRail::GetPlatformFront(stationobj, platformID)
{
	local front = platformID;
	// -1 & -2 are right and left most platform
	if (front == -1 || front == -2)	front = stationobj.s_Platforms.GetValue(front);
	local forward = cDirection.GetForwardRelativeFromDirection(stationobj.s_Direction);
	if (AIStation.GetStationID(front + forward) == stationobj.s_ID)
				front += (stationobj.s_Depth * forward);
		else	front += forward;
	return front;
}

function cStationRail::ConnectPlatform(stationobj, platformID)
{
	local back = cDirection.GetBackwardRelativeFromDirection(stationobj.s_Direction);
    local target = stationobj.s_MainLine + back;
    local target_alt = stationobj.s_AltLine + back;
    local plat_front = cStationRail.GetPlatformFront(stationobj, platformID);
    local direction_to_target = cDirection.GetDirection(plat_front, target);
	local rail_side, rail_up;
	local rail_left = cTrack.GetRailTrackFromStationDirection(AIRail.RAILTRACK_NW_SW, stationobj.s_Direction);
	local rail_right= cTrack.GetRailTrackFromStationDirection(AIRail.RAILTRACK_SW_SE, stationobj.s_Direction);
	local rail_front = cTrack.GetRailTrackFromStationDirection(AIRail.RAILTRACK_NW_SE, stationobj.s_Direction);
	local rail_connector = cTrack.GetRailTrackFromStationDirection(AIRail.RAILTRACK_NE_SW, stationobj.s_Direction);
	local rail_up_left = cTrack.GetRailTrackFromStationDirection(AIRail.RAILTRACK_NE_SE, stationobj.s_Direction);
	local rail_up_right = cTrack.GetRailTrackFromStationDirection(AIRail.RAILTRACK_NW_NE, stationobj.s_Direction);
	rail_side = rail_left;
	rail_up = rail_up_left;
	if (direction_to_target == DIR_SE || direction_to_target == DIR_NE)	{ rail_side = rail_right, rail_up = rail_up_right; }
	local forward = cDirection.GetForwardRelativeFromDirection(direction_to_target);
	local left = cDirection.GetForwardRelativeFromDirection(direction_to_target);
	local all_success = true;
	if (!cTrack.BuildRailAtTile(rail_side, plat_front, true, stationobj.s_ID))	all_success = false; // the one that connect it to its neightbor
	if (!cTrack.BuildRailAtTile(rail_front, plat_front + forward, true, stationobj.s_ID)) all_success = false; // the one that allow it to be reach by neighbor
	local depot = AIRail.GetRailDepotFrontTile(cStationRail.GetStationDepot(stationobj.s_ID)); // the depot front tile
	if (plat_front + forward == target || plat_front + forward == target_alt || plat_front + forward == depot)
		{
		 // the one that allow to reach MainLine or AltLine rail
		if (!cTrack.BuildRailAtTile(rail_up, plat_front + forward, true, stationobj.s_ID))	all_success = false;
		}
	 // the one that allow that platform to goes to the depot
	if (all_success && plat_front == depot)	all_success = cTrack.BuildRailAtTile(rail_connector, plat_front, true, stationobj.s_ID);
	return all_success;
}

function cStationRail::DefinePlatform(stationobj)
// look out a train station and add every platforms we found
{
	local direction = stationobj.s_Direction;
	if (direction == -1)	{ DInfo("No direction info", 1); return; }
	local leftTile = cDirection.GetLeftRelativeFromDirection(direction);
	local lookup = 0;
	local start = stationobj.s_Location;
	local topLeftPlatform = start;
	local topRightPlatform = start;
// search up
	while (AIStation.GetStationID(lookup + start) == stationobj.s_ID)
		{
cDebug.PutSign(lookup + start,"*");
		topLeftPlatform = lookup + start;
		if (!stationobj.s_Platforms.HasItem(lookup + start))	stationobj.s_Platforms.AddItem(lookup + start,0);
		lookup += leftTile;
		}
	// search down
	lookup = 0;
	while (AIStation.GetStationID(lookup + start) == stationobj.s_ID)
		{
		cDebug.PutSign(lookup + start,"*");
		topRightPlatform = lookup + start;
		if (!stationobj.s_Platforms.HasItem(lookup + start))	stationobj.s_Platforms.AddItem(lookup + start,0);
		lookup -= leftTile;
		}
	if (stationobj.s_Platforms.HasItem(-1))	stationobj.s_Platforms.RemoveItem(-1);
	if (stationobj.s_Platforms.HasItem(-2))	stationobj.s_Platforms.RemoveItem(-2);
	stationobj.s_Platforms.AddItem(-1, topRightPlatform);
	stationobj.s_Platforms.AddItem(-2, topLeftPlatform);
	local goodCounter = 0;
	local runTarget = stationobj.s_MainLine;
	cDebug.PutSign(runTarget,"RT");
	local plat_temp = AIList();
	plat_temp.AddList(stationobj.s_Platforms);
	plat_temp.RemoveItem(-1);
	plat_temp.RemoveItem(-2);
	foreach (platidx, value in plat_temp)
		{
		if (value == 1)	{ goodCounter++; continue; }
		local check = 0;
		if (cBuilder.RoadRunner(platidx, runTarget, AIVehicle.VT_RAIL))
						{
						check = 1;
						goodCounter++;
						}
				else	{
						cStationRail.ConnectPlatform(stationobj, platidx);
						if (cBuilder.RoadRunner(platidx, runTarget, AIVehicle.VT_RAIL))	{ check = 1; goodCounter++; }
						}
		stationobj.s_Platforms.SetValue(platidx, check);
		}
	DInfo("Station platforms: " + (stationobj.s_Platforms.Count() - 2) + " working: " + goodCounter, 2);
	stationobj.s_Platforms_OK = goodCounter;
	AISign.BuildSign(stationobj.s_Platforms.GetValue(-1), "R");
	AISign.BuildSign(stationobj.s_Platforms.GetValue(-2), "L");
	cDebug.ClearSigns();
}

function cStationRail::BuildRailDepot(stationID, track_location)
{
	local track_dir = AIRail.GetRailType(track_location);
	local depot_dir = -1;
	local alt_depot_dir = -1;
	print("NW_SE: "+AIRail.RAILTRACK_NW_SE);
	if (track_dir == AIRail.RAILTRACK_NE_SW)	{ depot_dir = DIR_NW; alt_depot_dir = DIR_SE; }
                                          else	{ depot_dir = DIR_NE; alt_depot_dir = DIR_SW; }
	local forward = cDirection.GetForwardRelativeFromDirection(depot_dir);
	print("track_dir = "+track_dir+" depot_dir = " + cDirection.DirectionToString(depot_dir));
    local i = 0;
    local all_success = true;
    local create = true;
    local tile = track_location;
    if (AIRail.GetRailType(tile - forward) != AIRail.RAILTRACK_INVALID)	tile -= forward;
    local use_dir = depot_dir;
    local depot_location = -1;
    while (i < 4)
		{
		all_success = true;
		if (create)	{
					cTileTools.DemolishTile(tile - forward);
					cTerraform.TerraformLevelTiles(tile, tile - forward);
					if (!AIRail.BuildRailDepot(tile - forward, tile))   all_success = false;
																else	depot_location = tile - forward;
					}
			else	{ cTileTools.DemolishTile(tile - forward); }
		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_SW_SE, use_dir), tile, create, stationID))	all_success = false;
//		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_NW_NE, use_dir), tile + right, create, stationID))	all_success = false;
//		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_SW_SE, use_dir), tile + right + forward, create, stationID))	all_success = false;
		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_NW_SW, use_dir), tile, create, stationID))	all_success = false;
//		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_NE_SE, use_dir), tile + left, create, stationID))	all_success = false;
//		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_NW_SW, use_dir), tile + left + forward, create, stationID))	all_success = false;
		if (all_success && (i == 0 || i == 2))	return depot_location;
        i++;
        create = (i == 2);
        if (i == 2)	{
//					tile = track_location + forward;
					if (AIRail.GetRailType(tile + forward) != AIRail.RAILTRACK_INVALID)	tile += forward;
					use_dir = alt_depot_dir;
					forward = cDirection.GetForwardRelativeFromDirection(use_dir);
//					left = cDirection.GetLeftRelativeFromDirection(use_dir);
//					right = cDirection.GetRightRelativeFromDirection(use_dir);
                    }
		}
	return -1;
}

/*function cStationRail::BuildRailDepot(stationID, track_location)
{
	local track_dir = AIRail.GetRailType(track_location);
	local depot_dir = -1;
	local alt_depot_dir = -1;
    cDebug.ClearSigns();
    cDebug.PutSign(track_location, "DLOC");
//	print("track_dir = "+track_dir+" loc="+cMisc.Locate(track_location));
	local depot_dir = DIR_NE;
	local left = cDirection.GetLeftRelativeFromDirection(depot_dir);
	local forward = cDirection.GetForwardRelativeFromDirection(depot_dir);
	local p_SE = (AIRail.GetRailType(track_location - left) == track_dir) ? 1 : 0;
	local p_NW = (AIRail.GetRailType(track_location + left) == track_dir) ? 2 : 0;
    local p_SENW = p_SE + p_NW;
    local p_NE = (AIRail.GetRailType(track_location + forward) == track_dir) ? 3 : 0;
    local p_SW = (AIRail.GetRailType(track_location - forward) == track_dir) ? 4 : 0;
    local p_NESW = p_NE + p_SW;
    depot_dir = -1;
    print("p_SENW = "+p_SENW + " p_NESW="+p_NESW);
    if (p_SENW == 3 && p_NESW != 7)
				{
                if (p_NESW == 3)	{ depot_dir = DIR_NE ; alt_depot_dir = DIR_SW; }
							else	{ depot_dir = DIR_SW ; alt_depot_dir = DIR_NE; }
				}
    if (p_SENW != 3 && p_NESW == 7)
				{
				if (p_SENW == 1)	{ depot_dir = DIR_SE ; alt_depot_dir = DIR_NW; }
							else	{ depot_dir = DIR_NW ; alt_depot_dir = DIR_SE; }
				}
    if (p_SENW != 3 && p_NESW != 7)	depot_dir = -1; // we lack rails if both are not full
	if (depot_dir == -1)	{ DInfo("Invalid depot location "+cMisc.Locate(track_location), 2); return -1; }
	print("depot_dir = "+cDirection.DirectionToString(depot_dir));
	forward = cDirection.GetForwardRelativeFromDirection(depot_dir);
    left = cDirection.GetLeftRelativeFromDirection(depot_dir);
    local right = cDirection.GetRightRelativeFromDirection(depot_dir);
    local tile_list = cTileTools.GetRectangle(track_location + left, track_location + right + forward, null);
    tile_list.Valuate(AIRail.GetRailType);
    cDebug.showLogic(tile_list);
    tile_list.KeepValue(track_dir);
	if (tile_list.Count() != 6)	{ DInfo("Invalid tiles count for a depot location "+cMisc.Locate(track_location)+" count=" + tile_list.Count(), 2); return -1; }
    local i = 0;
    local all_success = true;
    local create = true;
    local tile = track_location;
    local use_dir = depot_dir;
    local depot_location = -1;
    while (i < 4)
		{
		all_success = true;
		if (create)
					{
					cTileTools.DemolishTile(tile - forward);
					cTerraform.TerraformLevelTiles(tile, tile - forward);
					if (!AIRail.BuildRailDepot(tile - forward, tile))   all_success = false;
																else	depot_location = tile - forward;
					}
			else	{ cTileTools.DemolishTile(tile - forward); }
		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_SW_SE, use_dir), tile, create, stationID))	all_success = false;
		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_NW_NE, use_dir), tile + right, create, stationID))	all_success = false;
		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_SW_SE, use_dir), tile + right + forward, create, stationID))	all_success = false;
		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_NW_SW, use_dir), tile, create, stationID))	all_success = false;
		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_NE_SE, use_dir), tile + left, create, stationID))	all_success = false;
		if (!cTrack.BuildRailAtTile(cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_NW_SW, use_dir), tile + left + forward, create, stationID))	all_success = false;
		local invalid_90 = 0;
		if (all_success)	{
							invalid_90 = cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_NW_SW, use_dir);
							if (AIRail.GetRailTracks(tile + right + forward + right) == invalid_90)	invalid_90 = -1;
							}
		if (invalid_90 != -1)
							{
							invalid_90 = cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_SW_SE, use_dir);
							if (AIRail.GetRailTracks(tile + left + forward + left) == invalid_90)	invalid_90 = -1;
							}
		if (invalid_90 == -1)	{ DInfo("Invalid depot direction, this would create 90° turn", 2); all_success = false; }
		if (all_success && (i == 0 || i == 2))	break;
        i++;
        create = (i == 2);
        if (i == 2)	{
					tile = track_location + forward;
					use_dir = alt_depot_dir;
					forward = cDirection.GetForwardRelativeFromDirection(use_dir);
					left = cDirection.GetLeftRelativeFromDirection(use_dir);
					right = cDirection.GetRightRelativeFromDirection(use_dir);
                    }
		}
	if (i == 0 || i == 2)
			{
			local sigbugger = depot_location + forward + forward;
			if (AIRail.GetSignalType(sigbugger, sigbugger + left) != AIRail.SIGNALTYPE_NONE)	AIRail.RemoveSignal(sigbugger, sigbugger + left);
			if (AIRail.GetSignalType(sigbugger, sigbugger + right) != AIRail.SIGNALTYPE_NONE)	AIRail.RemoveSignal(sigbugger, sigbugger + right);
			return depot_location;
			}
	return -1;
}  */

function cStationRail::SplitZoneCheck(tile, direction, func, value)
{
	local front = cDirection.GetForwardRelativeFromDirection(direction);
	local right = cDirection.GetRightRelativeFromDirection(direction);
	local zone = cTileTools.GetRectangle(tile - (2 * front), tile + (2 * front) - right, null);
//	local zone = cTileTools.GetRectangle(tile - (1 * front), tile + (1 * front) - right, null);
	local zoneCount = zone.Count();
	zone.Valuate(func);
	zone.KeepValue(value);
	if (zone.Count() == zoneCount)	return true;
	return false;
}

function cStationRail::LineSplitAtPoint(source, target, point, direction, stationID)
{
	local start = source[1];
	local end = target[1];
	local RT = (AIRail.IsRailTile(start) && AIRail.IsRailTile(end));
	if (!RT)	return -1;
	local seek_area = AITile();
	print("direction from split = "+cDirection.DirectionToString(direction));
	local seek_area = cTileTools.GetRectangle(point + AIMap.GetTileIndex(5,5), point - AIMap.GetTileIndex(5,5), null);
	// if we have plenty money, let's build on water
/*	if (INSTANCE.main.bank.unleash_road)	seek_area.Valuate(cStationRail.SplitZoneCheck, direction, cTileTools.IsBuildable, 1);
									else	*/seek_area.Valuate(cStationRail.SplitZoneCheck, direction, AITile.IsBuildable, 1);
	seek_area.KeepValue(1);
	cDebug.showLogic(seek_area);
	if (seek_area.IsEmpty())	{ DInfo("No area to build there", 1); return -1; }
    seek_area.Valuate(cStationRail.SplitZoneCheck, direction, AITile.GetSlope, AITile.SLOPE_FLAT);
    local need_terraform = false;
    foreach (tiles, isflat in seek_area)
		{
		if (AITile.IsWaterTile(tiles) || isflat != 1)	{ need_terraform = true; break; }
		}
	if (!INSTANCE.terraform)	seek_area.KeepValue(1);
	if (seek_area.IsEmpty() && need_terraform)	{ DInfo("We need to terraform the area and we are not able to do terraforming", 1); return -1; }
    seek_area.Valuate(AIMap.DistanceManhattan, point);
    seek_area.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    local zone;
	local front = cDirection.GetForwardRelativeFromDirection(direction);
	local right = cDirection.GetRightRelativeFromDirection(direction);
	local good_point = null;
	print("need_terraform: "+need_terraform);
    foreach (tiles, distance in seek_area)
		{
		zone = cTileTools.GetRectangle(tiles - (1 * front), tiles + (1 * front) - right, null);
		cTerraform.IsAreaClear(zone, true, false);
        if (need_terraform)	cTerraform.TerraformLevelTiles(zone, null);
        if (cTerraform.IsAreaBuildableAndFlat(zone, 0))
				{
				good_point = tiles;
				if (AIMap.DistanceManhattan(start, good_point) < 5)	continue;
				if (AIMap.DistanceManhattan(end, good_point) < 5)	continue;
				break;
				}
		}
	if (good_point == null)	{ DInfo("Unable to create a buildable area", 1); return -1; }
    local track = cTrack.GetRailTrackFromDirection(AIRail.RAILTRACK_NE_SW, direction);
//    local track_pos = [good_point, good_point + front, good_point - front, good_point - right + front, good_point - right - front, good_point - right];
    local track_pos = [good_point, good_point - right];
    local success = true;
    foreach (position in track_pos)
		{
		if (!cTrack.BuildRailAtTile(track, position, true, stationID))	{ success = false; break; }
		}
	if (success)	{ // build depot blockers
//					local dloc = good_point - front - front - right;
					local dloc = good_point - front - right;
					if (!AIRail.BuildRailDepot(dloc, dloc + front))	success = false;
															else	cStation.StationClaimTile(dloc, stationID);
//					dloc = good_point + front + front - right;
					dloc = good_point + front - right;
					if (!AIRail.BuildRailDepot(dloc, dloc - front)) success = false;
															else	cStation.StationClaimTile(dloc, stationID);
					}
	if (!success)	{
					DInfo("Failure to build some rail part", 1);
					foreach (position in track_pos)	cTrack.BuildRailAtTile(track, position, false);
					return -1;
					}
			else	{
					local res = [];
//					res.push([good_point - front - front, good_point - front]); // start point
//					res.push([good_point + front + front, good_point + front]); // new end point
//					res.push([good_point - front - front - right, good_point - front - right]); // new end point
//					res.push([good_point + front + front - right, good_point + front - right]); // start point
					res.push([good_point - front, good_point]); // start point
					res.push([good_point + front, good_point]); // new end point
					res.push([good_point - front - right, good_point - right]); // new end point
					res.push([good_point + front - right, good_point - right]); // start point
					return res;
					}
}

function cStationRail::CreateShortPoints(work_station, help_station, source, target)
{
	local mainUID = cPathfinder.GetUID(source, target);
    local start = source;
    local end = target;
    print("start "+ cMisc.Locate(start[0])+" 1="+start[1]);
	if (work_station.s_LineState == 2)
		{ // the infos we need is in the array because we are in real the destination station
        for (local i = 0; i < help_station.s_LineState.len(); i++)
				{
				cDebug.ClearSigns();
				local point = help_station.s_LineState[i];
				cTileTools.DemolishTile(point[2][0]);
				cTileTools.DemolishTile(point[3][0]);
				end = point[2];
				cPathfinder.CreateSubTask(mainUID, start, end);
				start = point[3]; // move it to next starting point
				}
		// what remains must be pathfind too
		cPathfinder.CreateSubTask(mainUID, start, target);
		help_station.s_LineState = []; // empty it so we don't redo it twice time
        return;
		}
    local mid = AIMap.GetTileIndex((AIMap.GetTileX(start[1]) + AIMap.GetTileX(end[1])) / 2, (AIMap.GetTileY(start[1]) + AIMap.GetTileY(end[1])) / 2);
	if (typeof(help_station.s_LineState) != "array")	help_station.s_LineState = [];
	local srcforward = cDirection.GetForwardRelativeFromDirection(work_station.s_Direction);
	local dstforward = cDirection.GetForwardRelativeFromDirection(help_station.s_Direction);
	local srcright = cDirection.GetRightRelativeFromDirection(work_station.s_Direction);
	local multipoint = [];
	local point;
	local distance = AIMap.DistanceManhattan(source[1], target[1]);
	print("distance = "+distance+" srcdir ="+cDirection.DirectionToString(work_station.s_Direction)+" dstdir ="+cDirection.DirectionToString(help_station.s_Direction));
	//if (distance > 60)	multipoint.push([start[0] + (12 * srcforward), work_station.s_Direction]); // a bit farer the source station
//	local t1 = abs(AIMap.GetTileX(source[0]) - AIMap.GetTileX(target[0]) * 0.1).tointeger();
//	local t2 = abs(AIMap.GetTileY(source[0]) - AIMap.GetTileY(target[0]) * 0.1).tointeger();
//	local t = AIMap.GetTileIndex(AIMap.GetTileX(source[1]) + t1, AIMap.GetTileY(source[1]) + t2);
	if (distance > 60 && distance <= 120)
						{
						local midX = (AIMap.GetTileX(source[0]) + AIMap.GetTileX(target[0])) / 2;
						local midY = (AIMap.GetTileY(source[0]) + AIMap.GetTileY(target[0])) / 2;
						multipoint.push([AIMap.GetTileIndex(midX, midY), -1]);
						}
//	if (distance > 120 && distance <= 180)
	if (distance > 120)
						{
                        local midX = (AIMap.GetTileX(target[0]) - AIMap.GetTileX(source[0]));
                        local midY = (AIMap.GetTileY(target[0]) - AIMap.GetTileY(source[0]));
                        if (midX != 0)	midX = midX / 3;
                        if (midY != 0)	midY = midY / 3;
						local p1 = AIMap.GetTileIndex(AIMap.GetTileX(source[0]) + midX, AIMap.GetTileY(source[0]) + midY);
						local p2 = AIMap.GetTileIndex(AIMap.GetTileX(target[0]) - midX, AIMap.GetTileY(target[0]) - midY);
						print("p1="+cMisc.Locate(p1)+" p2="+cMisc.Locate(p2));
						multipoint.push([p1, -1]);
						multipoint.push([p2, -1]);
						}
/*	if (distance > 180)	{
                        local midX = AIMap.GetTileX(target[0]) - AIMap.GetTileX(source[0]);
                        if (midX != 0)	midX = midX / 4;
                        local midY = AIMap.GetTileY(target[0]) - AIMap.GetTileY(source[0]);
                        if (midY != 0)	midY = midY / 4;
						multipoint.push([AIMap.GetTileIndex(AIMap.GetTileX(source[0]) + midX, AIMap.GetTileY(source[0]) + midY), -1]);
						local hX = (AIMap.GetTileX(source[0]) + AIMap.GetTileX(target[0])) / 2;
						local hY = (AIMap.GetTileY(source[0]) + AIMap.GetTileY(target[0])) / 2;
						multipoint.push([AIMap.GetTileIndex(hX, hY), -1]);
						multipoint.push([AIMap.GetTileIndex(AIMap.GetTileX(target[0]) - midX, AIMap.GetTileY(target[0]) - midY), -1]);
						print("p1 = "+cMisc.Locate(multipoint[1][0]));
						print("p2 = "+cMisc.Locate(multipoint[2][0]));
						print("p3 = "+cMisc.Locate(multipoint[3][0]));
						}*/
	//if (distance > 60)	multipoint.push([help_station.s_AltLine + (12 * dstforward), work_station.s_Direction]); // bit farer target station
	cDebug.ClearSigns();
	for (local i = 0; i < multipoint.len(); i++)
		{
		local loc = multipoint[i][0];
		local sense = multipoint[i][1];
		if (sense == -1)	sense = cDirection.GetDirection(start[0], loc);
		AISign.BuildSign(loc, loc);
		print("point "+i+" loc: " + cMisc.Locate(loc));
		local assign_station = work_station.s_ID;
		if (i == multipoint.len() -1)	assign_station = help_station.s_ID;
		point = cStationRail.LineSplitAtPoint(source, target, loc, sense, assign_station);
		if (point != -1)
			{
/*			cDebug.PutSign(point[0][0],"pS");
			cDebug.PutSign(point[0][1],"ps");
			cDebug.PutSign(point[1][0],"pE");
			cDebug.PutSign(point[1][1],"pe");
			cDebug.PutSign(point[2][0],"aS");
			cDebug.PutSign(point[2][1],"as");
			cDebug.PutSign(point[3][0],"aE");
			cDebug.PutSign(point[3][1],"ae");*/
			help_station.s_LineState.push(point);
			end = point[0];
			cPathfinder.CreateSubTask(mainUID, start, end);
			start = point[1]; // move it to next starting point
			}
		}

	local fwd = cDirection.GetForwardRelativeFromDirection(help_station.s_Direction);
	// Clean target station alternate rail entrance
	//cTileTools.DemolishTile(help_station.s_AltLine + fwd, false);
	//cTileTools.DemolishTile(help_station.s_AltLine + fwd + fwd, false);
	// what remains must be pathfind too
	cPathfinder.CreateSubTask(mainUID, start, target);
	cDebug.ClearSigns();
}

function cStationRail::RailStationGrow(stationobj)
{
	local platform_update = false;
	local can_grow = (stationobj.s_Size != stationobj.s_MaxSize);
    local new_size = 2;
    if (stationobj.s_VehicleCount + 1 > 2)
		{
		new_size = (stationobj.s_VehicleCount + 1) >> 1;
		if ((new_size % 2) != 0)	new_size++;
		}
    DWarn("Station " + stationobj.s_Name + " size: " + stationobj.s_Size + " platforms: " + stationobj.s_Platforms_OK + " cangrow:" + can_grow + " newsize: " + new_size, 1);
    DInfo("Trains: " + stationobj.s_VehicleCount + " Max: " + stationobj.s_VehicleMax, 1);
    if (stationobj.s_VehicleCount + 1 > stationobj.s_VehicleMax)	return false;
	if (can_grow && new_size > stationobj.s_Platforms_OK)
		{
		local update = false;
		local sta_dir = AIRail.GetRailStationDirection(stationobj.s_Location);
//		local next_loc = DIR_NW;
//		if (sta_dir == AIRail.RAILTRACK_NE_SW)	next_loc = DIR_NE;
		local side = cDirection.GetLeftRelativeFromDirection(stationobj.s_Direction);
		local forward = cDirection.GetForwardRelativeFromDirection(stationobj.s_Direction);
//		local left = cDirection.GetLeftRelativeFromDirection(stationobj.s_Direction);
//		local forward = cDirection.GetForwardRelativeFromDirection(stationobj.s_Direction);
		local next_to_plat = stationobj.s_Platforms.GetValue(-2); // that's most left platform
		local deadleft = (stationobj.s_Platforms.GetValue(-2) == 0);
		local deadright = (stationobj.s_Platforms.GetValue(-1) == 0);
		local zone;
		local update = !deadleft;
		if (update)	{
					zone = next_to_plat + side;
					if (stationobj.s_UseEntry)	zone -= forward * (stationobj.s_Depth - 1);
					zone = cTileTools.GetRectangle(zone, stationobj.s_MainLine - forward, null);
					cTerraform.IsAreaClear(zone, true, false);
					cTerraform.TerraformLevelTiles(zone, null);
					update = cStationRail.CreateAndBuildTrainStation(next_to_plat + side, sta_dir, 1, stationobj.s_UseEntry, [stationobj.s_ID]);
					}
		if (!update && !deadright)
					{ // if we fail we build the other side (right side)
					next_to_plat = stationobj.s_Platforms.GetValue(-1); // right platform location
					zone = next_to_plat - side;
					if (stationobj.s_UseEntry)	zone -= forward * (stationobj.s_Depth - 1);
					zone = cTileTools.GetRectangle(zone, stationobj.s_MainLine - forward, null);
					cTerraform.IsAreaClear(zone, true, false);
					cTerraform.TerraformLevelTiles(zone, null);
					update = cStationRail.CreateAndBuildTrainStation(next_to_plat - side, sta_dir, 1, stationobj.s_UseEntry, [stationobj.s_ID]);
					}
		if (update)	cStationRail.DefinePlatform(stationobj);
			else	if (cError.IsCriticalError() || (deadleft && deadright))
							{
							stationobj.s_MaxSize = stationobj.s_Size;
							DInfo("Closing station...");
							}
		cError.ClearError();
		}
	return (stationobj.s_VehicleCount + 1 <= stationobj.s_VehicleMax);
}

function cStationRail::CreateStationsPath(fromStationObj, toStationObj)
{
	local srcStation = fromStationObj;
	local dstStation = toStationObj;
	if (!AIStation.IsValidStation(fromStationObj.s_ID) || !AIStation.IsValidStation(toStationObj.s_ID))
		{
		cError.RaiseError();
		return false;
		}
	local build_mainline = !cMisc.CheckBit(srcStation.s_LineState, 1);
	local build_altline = !cMisc.CheckBit(srcStation.s_LineState, 2);
	local build_mainsignal = !cMisc.CheckBit(srcStation.s_LineState, 3);
	local build_altsignal = !cMisc.CheckBit(srcStation.s_LineState, 4);
	local src_forward = cDirection.GetForwardRelativeFromDirection(srcStation.s_Direction);
	local dst_forward = cDirection.GetForwardRelativeFromDirection(dstStation.s_Direction);
	if (build_mainline)
		{
		local srcpos = srcStation.s_MainLine;
		local srclink = srcpos + src_forward;
		local dstpos = dstStation.s_AltLine + dst_forward + dst_forward;
		local dstlink = dstpos + dst_forward;
		local source = [srclink, srcpos];
		local target = [dstlink, dstpos];
		DInfo("Calling pathfinder: srcpos="+cMisc.Locate(srcpos)+" srclink="+cMisc.Locate(srclink),2);
		DInfo("Calling pathfinder: dstpos="+cMisc.Locate(dstpos)+" dstlink="+cMisc.Locate(dstlink),2);
		local result = cPathfinder.GetStatus(source, target, srcStation.s_ID, true, srcStation.s_UseEntry);
		print("main line result: "+result);
		if (srcStation.s_LineState == null)
				{
				srcStation.s_LineState = 0; // set it to 0 to work with it
				cStationRail.CreateShortPoints(srcStation, dstStation, source, target);
				}
		switch (result)
			{
			case	-2:
				cPathfinder.CloseTask([srclink, srcpos], [dstlink, dstpos]);
				cError.RaiseError();
				return false;
			break;
			case	2:
				build_mainline = false;
				cPathfinder.CloseTask([srclink, srcpos], [dstlink, dstpos]);
				srcStation.s_LineState = cMisc.SetBit(srcStation.s_LineState, 1);
				break;
			default:
			return false;
			}
		}

	if (build_altline)
		{
		local srcpos = srcStation.s_AltLine;
		local srclink = srcpos + src_forward;
		local dstpos = dstStation.s_MainLine;
		local dstlink = dstpos + dst_forward;
		local source = [srclink, srcpos];
		local target = [dstlink, dstpos];
		local railneed = AIRail.GetRailTracks(srclink);
		DInfo("Calling pathfinder: srcpos="+cMisc.Locate(srcpos)+" srclink="+cMisc.Locate(srclink),2);
		DInfo("Calling pathfinder: dstpos="+cMisc.Locate(dstpos)+" dstlink="+cMisc.Locate(dstlink),2);
		local result = cPathfinder.GetStatus(source, target, dstStation.s_ID, false, srcStation.s_UseEntry);
		print("alt line result: "+result);
		if (railneed != AIRail.RAILTRACK_INVALID && result == 0)
			{
			cTrack.BuildRailAtTile(railneed, srcpos + src_forward + src_forward, false);
			cTrack.BuildRailAtTile(railneed, srcpos + src_forward, false);
			}

		if (typeof(dstStation.s_LineState == "array") && dstStation.s_LineState.len() > 0)
				{
				print("station dir: "+cDirection.DirectionToString(srcStation.s_Direction));
				cDebug.ClearSigns();
				cStationRail.CreateShortPoints(srcStation, dstStation, source, target);
				}

		switch (result)
			{
			case	-2:
				cPathfinder.CloseTask([srclink, srcpos], [dstlink, dstpos]);
				cError.RaiseError();
				return false;
			break;
			case	2:
				build_altline = false;
				cPathfinder.CloseTask([srclink, srcpos], [dstlink, dstpos]);
				srcStation.s_LineState = cMisc.SetBit(srcStation.s_LineState, 2);
				break;
			default:
			return false;
			}
		}
	if (!build_mainline && build_mainsignal)
		{
		if (cBuilder.SignalBuilder(srcStation.s_MainLine, dstStation.s_AltLine))
				{
				srcStation.s_LineState = cMisc.SetBit(srcStation.s_LineState, 3);
				build_mainsignal = false;
				}
		else	return false;
		}
	if (!build_altline && build_altsignal)
		{
		if (cBuilder.SignalBuilder(dstStation.s_MainLine, srcStation.s_AltLine))
				{
				srcStation.s_LineState = cMisc.SetBit(srcStation.s_LineState, 4);
				build_altsignal = false;
				}
		else	return false;
		}
	// pfff here, all connections were made, and rails built
	if (!build_mainsignal && !build_altsignal)	return true;
	return false;
}

function cStationRail::CreateAndBuildTrainStation(tilepos, direction, platnum, useEntry, newGRF)
// Create a new station, we still don't know if station will be usable
// newGRF: an array of [stationID to link with it] or [AIStation.STATION_NEW, cargoid, source industry, target industry, Is_station_at_source]
	{
	cError.ClearError();
	local link = newGRF[0];
	local c = AITile.GetTownAuthority(tilepos);
	if (AITown.IsValidTown(c) && AITown.GetRating(c, AICompany.COMPANY_SELF) < AITown.TOWN_RATING_POOR)	{ cTileTools.SeduceTown(c); }
	local money = (INSTANCE.main.carrier.train_length*AIRail.GetBuildCost(AIRail.GetCurrentRailType(), AIRail.BT_STATION)*cBanker.GetInflationRate()).tointeger();
	if (!cBanker.CanBuyThat(money))	{ DInfo("We lack money to buy the station",1); }
	cBanker.GetMoney(money);
	if (link != AIStation.STATION_NEW && AIStation.IsValidStation(link))
				{
				local rt = AIRail.GetRailType(AIStation.GetLocation(link));
				cTrack.SetRailType(rt);
				local sta_obj = cStation.Load(link);
				if (!sta_obj)	return false;
				local route_obj = cRoute.LoadRoute(sta_obj.s_Owner.Begin());
				if (!route_obj)	return false;
				newGRF.push(route_obj.CargoID);
				newGRF.push(route_obj.SourceProcess.UID);
				newGRF.push(route_obj.TargetProcess.UID);
				if (route_obj.SourceStation.s_ID == link)	newGRF.push(true);
													else	newGRF.push(false);
				}
	local cargo = newGRF[1];
	local src_istown = false;
	local dst_istown = false;
	local src_id = newGRF[2];
	local dst_id = newGRF[3];
	local src_type = AIIndustryType.INDUSTRYTYPE_UNKNOWN;
	local dst_type = AIIndustryType.INDUSTRYTYPE_UNKNOWN;
	if (src_id > 10000)
				{
				src_istown = true;
				src_id -= 10000;
				src_type = AIIndustryType.INDUSTRYTYPE_TOWN;
				}
		else	dst_type = AIIndustry.GetIndustryType(src_id);
	if (dst_id > 10000)
				{
				dst_istown = true;
				dst_id -= 10000;
				dst_type = AIIndustryType.INDUSTRYTYPE_TOWN;
				}
		else	dst_type = AIIndustry.GetIndustryType(dst_id);
	local distance = AIMap.DistanceManhattan(AIIndustry.GetLocation(src_id), AIIndustry.GetLocation(dst_id));
	if (!AIRail.BuildNewGRFRailStation(tilepos, direction, platnum, INSTANCE.main.carrier.train_length, link, cargo, src_type, dst_type, distance, newGRF[4]))
			{
			DInfo("Rail station couldn't be built, link="+link+" cost="+money,1);
			cDebug.PutSign(tilepos,"!");
			cError.IsCriticalError();
			return false;
			}
	// if we build a link station, we endup the work here.
	if (link != AIStation.STATION_NEW)	return true;
	local stationID = AIStation.GetStationID(tilepos);
	local station_obj = cStation.InitNewStation(stationID);
	//tilepos = station_obj.s_Location; // update it because we change it
	station_obj.s_UseEntry = useEntry;
	local success = true;
	local clean = AIList();
	local forward, right, station_direction;
	if (link == AIStation.STATION_NEW)
		{
        local main_line, alt_line;
        if (direction == AIRail.RAILTRACK_NE_SW)
					{
					if (useEntry)	station_direction = DIR_NE;
							else	station_direction = DIR_SW;
					forward = cDirection.GetForwardRelativeFromDirection(station_direction);
					right = cDirection.GetRightRelativeFromDirection(station_direction);
					if (useEntry)	main_line = tilepos + forward + right;
							else	main_line = tilepos + (station_obj.s_Depth * forward);
					alt_line = main_line - right;
					}
			else	{
					if (useEntry)	station_direction = DIR_NW;
							else	station_direction = DIR_SE;
					forward = cDirection.GetForwardRelativeFromDirection(station_direction);
					right = cDirection.GetRightRelativeFromDirection(station_direction);
					if (useEntry)	main_line = tilepos + forward;
							else	main_line = tilepos + right + (station_obj.s_Depth * forward);
					alt_line = main_line - right;
					}
        station_obj.s_Direction = station_direction;
		local zone = cTileTools.GetRectangle(main_line - forward, alt_line + (4 * forward) - right, null);
		cTerraform.IsAreaClear(zone, true, false);
		cTerraform.TerraformLevelTiles(zone, null);
		station_obj.s_MainLine = main_line + (1 * forward);
		station_obj.s_AltLine = alt_line + (1 * forward);
		print("main_line="+cMisc.Locate(station_obj.s_MainLine)+" alt_line="+cMisc.Locate(station_obj.s_AltLine)+" direction: " + cDirection.DirectionToString(station_direction));
		local all_tiles_main = [0, AIRail.RAILTRACK_NE_SW, forward, AIRail.RAILTRACK_NE_SW, 0, AIRail.RAILTRACK_NW_SW, 0, AIRail.RAILTRACK_NW_NE];
		local all_tiles_alt  = [0, AIRail.RAILTRACK_NE_SW, forward, AIRail.RAILTRACK_NE_SW, 2 * forward, AIRail.RAILTRACK_NE_SW, 3 * forward, AIRail.RAILTRACK_NE_SW, 0, AIRail.RAILTRACK_SW_SE, 0, AIRail.RAILTRACK_NE_SE, 0, AIRail.RAILTRACK_NW_SW, -right, AIRail.RAILTRACK_NE_SE, 0, AIRail.RAILTRACK_NW_SE];
		for (local i = 0; i < all_tiles_main.len(); i++)
			{
			local t = cTrack.GetRailTrackFromDirection(all_tiles_main[i+1], station_direction);
			local p = main_line + all_tiles_main[i];
			if (!cTrack.BuildRailAtTile(t, p, true, stationID))	success = false;
			if (!success)	{ break; }
			clean.AddItem(p, 0);
			i++;
			}
		if (success)
			for (local i = 0; i < all_tiles_alt.len(); i++)
				{
				local t = cTrack.GetRailTrackFromDirection(all_tiles_alt[i+1], station_direction);
				local p = alt_line + all_tiles_alt[i];
				if (!cTrack.BuildRailAtTile(t, p, true, stationID))	success = false;
				if (!success)	{ cError.IsCriticalError(); break; }
				clean.AddItem(p, 0);
				i++;
				}

		if (success)
			{
			local signals = [main_line + forward, main_line, alt_line + forward, alt_line+ forward + forward];
			for (local i = 0; i < signals.len(); i++)	{ if (!AIRail.BuildSignal(signals[i], signals[i+1], AIRail.SIGNALTYPE_PBS))	success = false; i++; }
			}
		if (success)
			{
			success = AIRail.BuildRailDepot(station_obj.s_AltLine - right, station_obj.s_AltLine - right - forward);
			if (success)	cStation.SetStationDepot(station_obj.s_ID, station_obj.s_AltLine - right);
			}
		}
	if (!success && cError.IsError())	{ cTrack.RailCleaner(clean, stationID); cTileTools.DemolishTile(tilepos, false); }
    return success;
	}

function cStationRail::DefineMaxTrain(stationobj)
// count number of signals on rails, that will define how many trains we can use with it
{
	local voisins = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0,-1), AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)]; // SE, NW, SW, NE
	local sigtype = AIRail.SIGNALTYPE_NORMAL;
    local maxtrain = 0;
    local tileseek = AIList();
    tileseek.AddList(stationobj.s_TilesOther);
	foreach (tile, _ in stationobj.s_TilesOther)
        {
		foreach (voisin in voisins)
			{
			if (!tileseek.HasItem(tile + voisin))	continue;
			local foundsignal = AIRail.GetSignalType(tile, tile + voisin);
        	if (AIRail.GetSignalType(tile, tile + voisin) == sigtype)	{ tileseek.RemoveItem(tile); maxtrain++; break; }
            }
        }
	stationobj.s_VehicleMax = maxtrain;
}
