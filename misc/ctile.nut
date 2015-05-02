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

class cTileTools
{
static	TilesBlackList = AIList(); // item=tile, value=stationID that own the tile
}

function cTileTools::TileIsOur(tile)
// return true if we own that tile
{
	return (AICompany.IsMine(AITile.GetOwner(tile)));
}

function cTileTools::IsTilesBlackList(tile)
{
	return cTileTools.TilesBlackList.HasItem(tile);
}

function cTileTools::GetTileStationOwner(tile)
// return station that own the tile
// or -1
{
	if (cTileTools.TilesBlackList.HasItem(tile))	{ return cTileTools.TilesBlackList.GetValue(tile); }
	return -1;
}

function cTileTools::CanUseTile(tile, owner)
// Answer if we can use that tile
{
	local coulduse=true;
	local ot=cTileTools.GetTileStationOwner(tile);
	if (ot == owner)	return true;
	if (ot == -1)	return true;
	return false;
}

function cTileTools::BlackListTile(tile, stationID = -255)
{
// we store the stationID for a blacklisted tile or a negative value that tell us why it was blacklist
// -255 not usable at all, we can't use it
// -100 don't use that tile when building a station, it's a valid tile, but a bad spot
	if (AIMap.IsValidTile(tile))
		{
		if (stationID == -255)	{ cTileTools.TilesBlackList.AddItem(tile, -255); return; }
		if (stationID == -100)	{ cTileTools.TilesBlackList.AddItem(tile, -100); return; }
		local owner = cTileTools.GetTileStationOwner(tile);
		if (owner == -1)	{ cTileTools.TilesBlackList.AddItem(tile, stationID); return; }
		// allow tile to be claim if not own by a station
		if (owner < 0)	{ cTileTools.TilesBlackList.SetValue(tile, stationID); }
		// allow temporary claims tiles (0 - 100000+stationID) to be reclaim by a real stationID
		}
}

function cTileTools::UnBlackListTile(tile)
{
	if (cTileTools.IsTilesBlackList(tile))	{ cTileTools.TilesBlackList.RemoveItem(tile); }
}

function cTileTools::IsRiverTile(tile)
// pfff, finally a solve to detect river
{
	if (!AITile.IsWaterTile(tile))	return false;
	if (AITile.IsCoastTile(tile))	return false; // just assume a river cost tile is a water tile
	if (AIMarine.IsDockTile(tile))	return false;
	if (AIMarine.IsWaterDepotTile(tile))	return false;
	if (AIMarine.IsBuoyTile(tile))	return false;
	if (AIMarine.IsCanalTile(tile))	return false;
	if (AIMarine.IsLockTile(tile))	return false;
	if (AITile.GetMinHeight(tile) > 0)	return true; // no need to check its maxheight, coasttile already answer it
	return false;
}

function cTileTools::PurgeBlackListTiles(alist, creation=false)
// remove all tiles that are blacklist from an AIList and return it
// if creation is false, don't remove tiles that cannot be use for station creation
{
	alist.Valuate(cTileTools.GetTileStationOwner);
	alist.RemoveAboveValue(0); // remove own tiles
	alist.RemoveValue(-255); // remove bad tiles
	if (creation)	{ alist.RemoveValue(-100); } // remove bad spot for station
	return alist;
}

function cTileTools::GetTilesAroundTown(town_id)
// Get tile around a town
{
	local tiles = AITileList();
	local townplace = AITown.GetLocation(town_id);
	tiles=cTileTools.GetTilesAroundPlace(townplace,200);
	tiles.Valuate(AITile.IsWithinTownInfluence, town_id);
	tiles.KeepValue(1);
	return tiles;
}

function cTileTools::FindStationTiles(tile)
// return a list of tiles where we have the station we found at tile
{
	local stationid=AIStation.GetStationID(tile);
	if (!AIStation.IsValidStation(stationid))	return AIList();
	local tilelist=cTileTools.GetTilesAroundPlace(tile,16);
	tilelist.Valuate(AIStation.GetStationID);
	tilelist.KeepValue(stationid);
	return tilelist;
}

function cTileTools::StationIsWithinTownInfluence(stationid, townid)
// A tweak for AIStation.IsWithinTownInfluence in openttd < 1.1.2
{
	local stationtile=cTileTools.FindStationTiles(AIStation.GetLocation(stationid));
	foreach (tile, dummy in stationtile)	{ if (AITile.IsWithinTownInfluence(tile, townid) || AITile.GetTownAuthority(tile) == townid) return true; }
	return false;
}

function cTileTools::DemolishTile(tile)
// same as AITile.DemolishTile but retry after a little wait, protect rails, tunnel and bridge
{
	if (AITile.IsStationTile(tile))	return false; // must check if we have a real way to destroy station if need
	if (AIRail.IsRailDepotTile(tile))	{ return cTrack.StationKillRailDepot(tile); }
	if (AIRoad.IsRoadDepotTile(tile) || AIMarine.IsWaterDepotTile(tile))	{ return cTrack.DestroyDepot(tile); }
	if (AIRail.IsRailTile(tile))	return false;
	if (AIBridge.IsBridgeTile(tile) && cBridge.IsRailBridge(tile))	return false;
	if (AITunnel.IsTunnelTile(tile))	return false;
	local res = cError.ForceAction(AITile.DemolishTile, tile);
	return res;
}

function cTileTools::GetTilesAroundPlace(place,maxsize)
// Get tiles around a place
{
	local tiles = AITileList();
	local mapSizeX = AIMap.GetMapSizeX();
	local mapSizeY = AIMap.GetMapSizeY();
	local ox = AIMap.GetTileX(place);
	local oy = AIMap.GetTileY(place);
	local tx = ox;
	local ty = oy;
	if (ox - maxsize < 1)	ox = 1;
				else	ox = ox - maxsize;
	if (tx + maxsize >= mapSizeX-2)	tx = mapSizeX-2;
						else	tx = tx + maxsize;
	if (oy - maxsize < 1)	oy = 1;
				else	oy = oy - maxsize;
	if (ty + maxsize >= mapSizeY-2)	ty = mapSizeY-2;
						else	ty = ty + maxsize;
	local o = AIMap.GetTileIndex(ox, oy);
	local t = AIMap.GetTileIndex(tx, ty);
	tiles.AddRectangle(o, t);
	return tiles;
}

function cTileTools::IsBuildable(tile)
// function to check a water tile is buildable, handle non water with AITIle.IsBuildable()
{
	if (AIMarine.IsDockTile(tile))	return false;
	if (AIMarine.IsWaterDepotTile(tile))	return false;
	if (AIMarine.IsBuoyTile(tile))	return false;
	if (AIMarine.IsCanalTile(tile))	return false;
	if (AIMarine.IsLockTile(tile))	return false;
	if (!AITile.IsWaterTile(tile))	{ return AITile.IsBuildable(tile); }
	if (cTileTools.IsRiverTile(tile))	return true; // even without terraform, we could demolish the tile.
	return INSTANCE.terraform; // if no terraform is allow, water tile cannot be use
}

function cTileTools::TownBriber(townID)
// Bribe a town upto getting the neededRating
{
	if (AITown.IsActionAvailable(townID, AITown.TOWN_ACTION_BRIBE))
		{
		DInfo("Offering money to "+AITown.GetName(townID),1);
		return AITown.PerformTownAction(townID, AITown.TOWN_ACTION_BRIBE);
		}
	else	return false;
}

function cTileTools::PlantsTreeAtTown(townID, makeplace=false)
// Plants tree near townID to improve rating
// Return true if we found any free tiles to work on
{
	local towntiles = cTileTools.GetTilesAroundPlace(AITown.GetLocation(townID), 200);
	towntiles.Valuate(AITile.IsBuildable)
	towntiles.KeepValue(1);
	towntiles.Valuate(AITile.GetTownAuthority);
	towntiles.KeepValue(townID);
	towntiles.Valuate(AITile.HasTreeOnTile);
	if (makeplace)
		{
		towntiles.KeepValue(1);
		foreach (tiles, _ in towntiles)	if (!AITile.DemolishTile(tiles))	return false;
		return true;
		}
	towntiles.KeepValue(0);
	foreach (tiles, _ in towntiles)	AITile.PlantTree(tiles);
	return (!towntiles.IsEmpty());
}

function cTileTools::SeduceTown(townID)
// Try seduce a town
// needRating : rating we must reach
// return true if we reach needRating level with that town
{
	local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
	local curRating = AITown.GetRating(townID, weare);
	local town_name=AITown.GetName(townID);
	DInfo("Town: "+town_name+" rating: "+curRating,2);
	if (curRating == AITown.TOWN_RATING_NONE)	curRating = AITown.TOWN_RATING_GOOD;
	// plants tree to improve our rating to a town that doesn't know us yet
	if (curRating >= AITown.TOWN_RATING_POOR)
			{

			DInfo("Could get costy for no result to continue seducing "+town_name+", giving up.",1);
			return true;
			}
	local 	keeploop=true;
	if (curRating == AITown.TOWN_RATING_APPALLING)	cTileTools.PlantsTreeAtTown(townID, true);
	// clear any trees place to rebuild them later
	DInfo(	"Trying bribing "+town_name+" as much as we can",1);
	do	{
		keeploop=(AITown.GetRating(townID, weare) < AITown.TOWN_RATING_POOR);
		if (keeploop)	keeploop=cTileTools.TownBriber(townID);
		if (!keeploop)	DInfo("Result ="+keeploop,2);
		::AIController.Sleep(10);
		} while (keeploop);
	// bad bribe will put us at POOR on failure, goog to keep bribing until we fail then
	if (!cTileTools.PlantsTreeAtTown(townID))	DInfo("Cannot seduce "+town_name+" anymore with tree.",1);
	return (AITown.GetRating(townID, weare) >= AITown.TOWN_RATING_POOR);
}

function cTileTools::IsRemovable(tile)
// return true/false if the tile could be remove
{
	local test=false;
	if (cTileTools.IsBuildable(tile))	return true;
	local testmode=AITestMode();
	test=cTileTools.DemolishTile(tile);
	testmode=null;
	return test;
}

function cTileTools::IsAreaRemovable(area)
// return true/false is all tiles could be remove in area AIList
{
	local worklist=AIList();
	worklist.AddList(area); // protect area list values
	cTileTools.YexoValuate(worklist, cTileTools.IsRemovable);
	worklist.RemoveValue(1);
	return (worklist.IsEmpty());
}

function cTileTools::ClearArea(area)
// Clean out an area to allow building on it
{
	foreach (tile, _ in area)	cTileTools.DemolishTile(tile);
}

function cTileTools::IsAreaBuildable(area)
// return true if owner can destroy to build the area
{
	if (!cTileTools.IsAreaRemovable(area))	return false;
	local owncheck=AIList();
	owncheck.AddList(area);
	owncheck.Valuate(AITile.IsBuildable);
	owncheck.KeepValue(0); // keep only non useable tiles
	if (owncheck.Count() > 5)	return false;
	return true;
}

// This function comes from AdmiralAI, version 22, written by Yexo
// taken from SuperLib, this will becomes the most re-use function :D
function cTileTools::YexoCallFunction(func, args)
{
	switch (args.len()) {
		case 0: return func();
		case 1: return func(args[0]);
		case 2: return func(args[0], args[1]);
		case 3: return func(args[0], args[1], args[2]);
		case 4: return func(args[0], args[1], args[2], args[3]);
		case 5: return func(args[0], args[1], args[2], args[3], args[4]);
		case 6: return func(args[0], args[1], args[2], args[3], args[4], args[5]);
		case 7: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
		case 8: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
		default: throw "Too many arguments to CallFunction";
	}
}

// This function comes from AdmiralAI, version 22, written by Yexo
// taken from SuperLib, this will becomes the most re-use function :D
function cTileTools::YexoValuate(list, valuator, ...)
{
	assert(typeof(list) == "instance");
	assert(typeof(valuator) == "function");

	local args = [null];

	for(local c = 0; c < vargc; c++) {
		args.append(vargv[c]);
	}

	foreach(item, _ in list) {
		args[0] = item;
		local value = cTileTools.YexoCallFunction(valuator, args);
		if (typeof(value) == "bool") {
			value = value ? 1 : 0;
		} else if (typeof(value) != "integer") {
			throw("Invalid return type from valuator");
		}
		list.SetValue(item, value);
	}
}

function cTileTools::GetPosRelativeFromDirection(dirswitch, direction)
// Get the relative tile from "dirswitch" relative to "direction"
// dirswitch: 0- left, 1-right, 2-forward, 3=backward
{
	local left, right, forward, backward = null;
	switch (direction)
		{
		case DIR_NE:
			left=AIMap.GetTileIndex(0,-1);
			right=AIMap.GetTileIndex(0,1);
			forward=AIMap.GetTileIndex(-1,0);
			backward=AIMap.GetTileIndex(1,0);
		break;
		case DIR_SE:
			left=AIMap.GetTileIndex(-1,0);
			right=AIMap.GetTileIndex(1,0);
			forward=AIMap.GetTileIndex(0,1);
			backward=AIMap.GetTileIndex(0,-1);
		break;
		case DIR_SW:
			left=AIMap.GetTileIndex(0,1);
			right=AIMap.GetTileIndex(0,-1);
			forward=AIMap.GetTileIndex(1,0);
			backward=AIMap.GetTileIndex(-1,0);
		break;
		case DIR_NW:
			left=AIMap.GetTileIndex(1,0);
			right=AIMap.GetTileIndex(-1,0);
			forward=AIMap.GetTileIndex(0,-1);
			backward=AIMap.GetTileIndex(0,1);
		break;
		}
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

function cTileTools::GetLeftRelativeFromDirection(direction)
	{
	return cTileTools.GetPosRelativeFromDirection(0,direction);
	}

function cTileTools::GetRightRelativeFromDirection(direction)
	{
	return cTileTools.GetPosRelativeFromDirection(1,direction);
	}

function cTileTools::GetForwardRelativeFromDirection(direction)
	{
	return cTileTools.GetPosRelativeFromDirection(2,direction);
	}

function cTileTools::GetBackwardRelativeFromDirection(direction)
	{
	return cTileTools.GetPosRelativeFromDirection(3,direction);
	}

function cTileTools::GetDistanceChebyshevToTile(tilefrom, tileto)
    {
    local x1 = AIMap.GetTileX(tilefrom);
    local x2 = AIMap.GetTileX(tileto);
    local y1 = AIMap.GetTileY(tilefrom);
    local y2 = AIMap.GetTileY(tileto);
    return max(abs(x2 - x1), abs(y2 - y1));
    }
