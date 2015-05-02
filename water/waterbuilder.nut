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

function cBuilder::BuildWaterDepotAtTile(tile, destination)
// Try to build a water depot at tile and nearer
{
    local reusedepot = cTileTools.GetTilesAroundPlace(tile, 15);
    reusedepot.Valuate(AIMarine.IsWaterDepotTile);
    foreach (position, value in reusedepot)
        {  // try reusing one, making sure we can reach it
        if (value == 0) { continue; }
        if (tile == position) { continue; } // avoid runner failure
        local reuse = cBuilder.RoadRunner(tile, position, AIVehicle.VT_WATER);
        if (reuse)  { return position; }
        }
    reusedepot.KeepValue(0);
    reusedepot.Valuate(AITile.IsWaterTile);
    reusedepot.KeepValue(1);
    reusedepot.Valuate(AITile.IsStationTile);
    reusedepot.KeepValue(0);
    reusedepot.Valuate(AIMarine.IsBuoyTile);
    reusedepot.KeepValue(0);
    reusedepot.Valuate(AIMarine.IsDockTile);
    reusedepot.KeepValue(0);
    reusedepot.Valuate(AITile.GetDistanceManhattanToTile, tile);
    reusedepot.RemoveBelowValue(3);
    reusedepot.KeepBelowValue(16);
	reusedepot.Valuate(AITile.GetDistanceSquareToTile, destination);
    reusedepot.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    local newpos=-1;
    foreach (tile, dummy in reusedepot)
        {
        local dir = cBuilder.GetDirection(tile, destination);
        local front = cDirection.GetForwardRelativeFromDirection(dir);
        if (!AITile.IsWaterTile(tile+front) || !(AITile.IsWaterTile(tile+front+front))) { continue; } // boats will stay stuck in it else
        newpos = AIMarine.BuildWaterDepot(tile, tile+front);
        if (newpos)	{ return tile; }
        }
    return -1;
}

function cBuilder::BuildWaterStation(start)
// Build a water station for a route
// @param start true to build at source, false at destination
// @return true or false
{
	INSTANCE.main.bank.RaiseFundsBigTime();
	local stationtype = null;
	local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	local dir, otherplace =null;
	local tilelist = AIList();
	if (start)
            {
            dir = INSTANCE.main.builder.GetDirection(INSTANCE.main.route.SourceProcess.Location, INSTANCE.main.route.TargetProcess.Location);
            tilelist = cTileTools.GetTilesAroundPlace(INSTANCE.main.route.SourceProcess.Location, 3 * radius); // 3x for town, 2x industry in cProcess
            print("working on "+INSTANCE.main.route.SourceProcess.Name);
            if (INSTANCE.main.route.SourceProcess.IsTown)
                    {
                    tilelist.Valuate(AITile.IsCoastTile);
                    tilelist.KeepValue(1);
                    tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.CargoID, 1, 1, radius);
                    tilelist.KeepAboveValue(7); // prefer test acceptance to make sure we won't carry over passengers none wants
                    tilelist.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.CargoID, 1, 1, radius);
                    tilelist.KeepAboveValue(0); // prefer test acceptance to make sure we won't carry over passengers none wants
                    }
            else	{
                    if (AIIndustry.HasDock(INSTANCE.main.route.SourceProcess.ID))
                                {
                                INSTANCE.main.route.SourceStation = AIStation.GetStationID(INSTANCE.main.route.SourceProcess.StationLocation);
                                local newStation = INSTANCE.main.route.CreateNewStation(true);
                                if (newStation == null) { return false; }
                                newStation.s_SubType = -2;
                                newStation.s_Depot = cBuilder.BuildWaterDepotAtTile(INSTANCE.main.route.SourceProcess.StationLocation, INSTANCE.main.route.TargetProcess.Location);
                                return true;
                                }
                        else    {
                                tilelist.Valuate(AITile.IsCoastTile);
                                tilelist.KeepValue(1);
                                tilelist.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.CargoID, 1, 1, radius);
                                tilelist.KeepAboveValue(0);
                                }
                    }
            otherplace=INSTANCE.main.route.TargetProcess.Location;
            }
	else	{
            dir = INSTANCE.main.builder.GetDirection(INSTANCE.main.route.TargetProcess.Location, INSTANCE.main.route.TargetProcess.Location);
            tilelist = cTileTools.GetTilesAroundPlace(INSTANCE.main.route.TargetProcess.Location, 3 * radius); // 3x for town, 2x industry in cProcess
                        print("working on "+INSTANCE.main.route.TargetProcess.Name);
                        if (tilelist.IsEmpty()) { print("odd no tiles"); }
            if (INSTANCE.main.route.TargetProcess.IsTown)
                    {
                    tilelist.Valuate(AITile.IsCoastTile);
                    tilelist.KeepValue(1);
                    tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.CargoID, 1, 1, radius);
                    tilelist.KeepAboveValue(7);
                    tilelist.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.CargoID, 1, 1, radius);
                    tilelist.KeepAboveValue(0);
                    }
            else	{
                    if (AIIndustry.HasDock(INSTANCE.main.route.TargetProcess.ID))
                                {
                                INSTANCE.main.route.TargetStation = AIStation.GetStationID(INSTANCE.main.route.TargetProcess.StationLocation);
                                local newStation = INSTANCE.main.route.CreateNewStation(false);
                                if (newStation == null) { return false; }
                                newStation.s_SubType = -2;
                                newStation.s_Depot = cBuilder.BuildWaterDepotAtTile(INSTANCE.main.route.TargetProcess.StationLocation, INSTANCE.main.route.SourceProcess.Location);
                                return true;
                                }
                        else    {
                                tilelist.Valuate(AITile.IsCoastTile);
                                tilelist.KeepValue(1);
                                tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.CargoID, 1, 1, radius);
                                tilelist.KeepAboveValue(7);
                                }
                    }
            otherplace=INSTANCE.main.route.SourceProcess.Location;
            }
	local sta_tile = -1;
    if (tilelist.IsEmpty()) { sta_tile = -100; print("no tiles") ;}
    local testedList = AIList();
    testedList.AddList(tilelist);
    testedList.Valuate(cBuilder.CanBuildDockAtTile, false);   // first check without terraforming
    testedList.KeepValue(1);
    if (testedList.IsEmpty())
            {
            print("no tiles without terraforming");
            if (!INSTANCE.terraform)    { sta_tile = -100; }
                                else    { testedList.AddList(tilelist); sta_tile = -2; }
            }
	cDebug.showLogic(tilelist);

    if (sta_tile != -100)
            {
            //testedList.Valuate(AITile.GetDistanceSquareToTile, otherplace);
            testedList.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
            foreach (tile, _ in tilelist)
                {
                local success = false;
                cDebug.PutSign(tile, ".");
                if (sta_tile == -2)
                        {
                        success = cBuilder.CanBuildDockAtTile(tile, true);
                        if (!success)   { continue; } // bad tile (no water in front) / lack money / cannot terraform it...
                        }
                success = AIMarine.BuildDock(tile, AIStation.STATION_NEW);
                if (success)    { sta_tile = tile; break; }
                }
            if (sta_tile < 0)   { sta_tile = -100; }
            }
    if (sta_tile == -100)
        {
		DError("Can't find a good place to build the dock !",1);
		cError.RaiseError();
		return false;
        }
    if (start)  { INSTANCE.main.route.SourceStation = AIStation.GetStationID(sta_tile); }
        else    { INSTANCE.main.route.TargetStation = AIStation.GetStationID(sta_tile); }
    local newstation = INSTANCE.main.route.CreateNewStation(start);
    // now the depot
    newstation.s_Depot = cBuilder.BuildWaterDepotAtTile(sta_tile, otherplace);
    return true;
}

function cBuilder::CanBuildDockAtTile(tile, allow_terraforming)
/**
* Check if we can build a dock at tile, you should pass a coast tile so.
* @param tile The tile to check
* @param allow_terraforming if enable it will terraform the tile to gave a usuable tile
* @return True if the tile is usuable
**/
{
    local slope = AITile.GetSlope(tile);
    local fronttile = AIList();
    fronttile.AddItem(AITile.SLOPE_NW, AIMap.GetTileIndex(0, 1));
    fronttile.AddItem(AITile.SLOPE_SW, AIMap.GetTileIndex(-1, 0));
    fronttile.AddItem(AITile.SLOPE_NE, AIMap.GetTileIndex(1, 0));
    fronttile.AddItem(AITile.SLOPE_SE, AIMap.GetTileIndex(0, -1));
    if (fronttile.HasItem(slope) && AITile.IsWaterTile(tile + fronttile.GetValue(slope)))    { return true; }
    if (!allow_terraforming)    { return false; }
    local n_slope;
    foreach (slopeneed, _ in fronttile)
        {
        n_slope = slope ^ slopeneed;
        local t_slope = slope + n_slope;
        if (!fronttile.HasItem(t_slope))    { continue; }
        if (!AITile.IsWaterTile(tile +fronttile.GetValue(t_slope)))    { continue; }
        cDebug.PutSign(tile, "!");
        local test = AITestMode();
        local result = AITile.RaiseTile(tile, n_slope); // better not waste money
        print("simulate result "+result);
        test = null;
        if (result)    { result = AITile.RaiseTile(tile, n_slope); }
        return result;
        }
    return false;
}

function cBuilder::GetDockFrontTile(tile)
/**
* Get the front part of a dock
* @param tile The tile location of a dock
* @param -1 on error, else the dock front tile or the station tile if not a dock
**/

{
    local sta_id = AIStation.GetStationID(tile);
    if (!AIStation.IsValidStation(sta_id))  return -1;
    if (AITile.IsWaterTile(tile))   return tile;
    local tiles = cTileTools.GetTilesAroundPlace(tile, 4);
    tiles.Valuate(AIStation.GetStationID);
    tiles.KeepValue(sta_id);
    if (tiles.Count() > 1)  { tiles.RemoveItem(tile); }
    return tiles.Begin();
}

function cBuilder::RepairWaterRoute(idx)
{
    local road = cRoute.Load(idx);
    if (!road)  { return false; }
    cBanker.RaiseFundsBigTime();
    if (!AIMarine.IsWaterDepotTile(road.SourceStation.s_Depot))
        {
        road.SourceStation.s_Depot = cBuilder.BuildWaterDepotAtTile(road.SourceStation.s_Location, road.TargetStation.s_Location);
        }
    if (!AIMarine.IsWaterDepotTile(road.TargetStation.s_Depot))
        {
        road.TargetStation.s_Depot = cBuilder.BuildWaterDepotAtTile(road.TargetStation.s_Location, road.SourceStation.s_Location);
        }
    if (!AIMarine.IsWaterDepotTile(road.SourceStation.s_Depot) && !AIMarine.IsWaterDepotTile(road.TargetStation.s_Depot))
        {
        DInfo("RepairWaterRoute mark #"+idx+" undoable",1);
        road.RouteIsNotDoable();
        }
}
