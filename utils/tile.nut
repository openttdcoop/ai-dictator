class cTileTools { }

function cTileTools::GetTilesAroundTown(town_id)
// Get tile around a town
{
local tiles = AITileList();
local townplace = AITown.GetLocation(town_id);
local distedge = AIMap.DistanceFromEdge(townplace);
local offset = null;
if (distedge < 120) {
		offset = AIMap.GetTileIndex(distedge - 1, distedge - 1);
	} else {
		offset = AIMap.GetTileIndex(120, 120);
	}
	tiles.AddRectangle(townplace - offset, townplace + offset);
	tiles.Valuate(AITile.IsWithinTownInfluence, town_id);
	tiles.KeepValue(1);
	return tiles;
}

function cTileTools::FindRoadStationTiles(tile)
// return a list of tile where we have the station we found at tile
{
//if (!AIRoad.IsRoadStationTile(tile))	return null;
local stationid=AIStation.GetStationID(tile);
//if (!AICompany.IsMine(AICompany.ResolveCompanyID(AITile.GetOwner(tile))))	return null;
local tilelist=cTileTools.GetTilesAroundPlace(tile);
tilelist.Valuate(AITile.GetDistanceManhattanToTile,tile);
tilelist.KeepBelowValue(12);
tilelist.Valuate(AIRoad.IsRoadStationTile);
tilelist.KeepValue(1);
showLogic(tilelist);
tilelist.Valuate(AIStation.GetStationID);
showLogic(tilelist);
tilelist.KeepValue(stationid);
return tilelist;
}

function cTileTools::DemolishTile(tile)
// same as AITile.DemolishTile but retry after a little wait
{
if (AITile.IsBuildable(tile)) return true;
local res=AITile.DemolishTile(tile);
if (!res)
	{
	AIController.Sleep(30);
	res=AITile.DemolishTile(tile);
	}
return res;
}

function cTileTools::GetTilesAroundPlace(place)
// Get tiles around a place
{
local tiles = AITileList();
local distedge = AIMap.DistanceFromEdge(place);
local offset = null;
if (distedge > 120) distedge=120; // limit to 120 around
offset = AIMap.GetTileIndex(distedge - 1, distedge -1);
tiles.AddRectangle(place - offset, place + offset);
return tiles;
}

function cTileTools::IsBuildableRectangleAtThisPoint(tile, width, height)
// This check if the rectangle area is buildable in any directions from that point
// Like the IsBuildableRectangle, but not limit to upper left point
// return tile point where to put the objet or -1 if nothing is buildable there
{
local returntile=-1;
local tilelist=AITileList();
local secondtile=0;
local before=0;
local after=0;
width-=1;
height-=1;
if (width < 0) width=0;
if (height < 0) height=0;
// tile is @ lowerright of the rectangle
// secondtile is @ upperleft
secondtile=tile+AIMap.GetTileIndex(0-width,0-height);
returntile=secondtile;
tilelist.AddRectangle(tile,secondtile);
tilelist.Valuate(AITile.IsBuildable);
before=tilelist.Count();
tilelist.KeepValue(1);
after=tilelist.Count();
if (after==before)	return returntile;

// tile is @ lowerleft of the rectangle
// secondtile is @ upperright
tilelist=AITileList();
secondtile=tile+AIMap.GetTileIndex(0-width,height);
returntile=tile+AIMap.GetTileIndex(0-width,0);
tilelist.AddRectangle(tile,secondtile);
tilelist.Valuate(AITile.IsBuildable);
before=tilelist.Count();
tilelist.KeepValue(1);
after=tilelist.Count();
if (after==before)	return returntile;

// tile is @ topright of the rectangle
// secondtile is @ lowerleft
tilelist=AITileList();
secondtile=tile+AIMap.GetTileIndex(width,0-height);
returntile=tile+AIMap.GetTileIndex(0,0-height);
tilelist.AddRectangle(tile,secondtile);
tilelist.Valuate(AITile.IsBuildable);
before=tilelist.Count();
tilelist.KeepValue(1);
after=tilelist.Count();

if (after==before)	return returntile;

// tile is @ topleft of the rectangle
// secondtile is @ lowerright
tilelist=AITileList();
secondtile=tile+AIMap.GetTileIndex(width,height);
returntile=tile;
tilelist.AddRectangle(tile,secondtile);
tilelist.Valuate(AITile.IsBuildable);
before=tilelist.Count();
tilelist.KeepValue(1);
after=tilelist.Count();
if (after==before)	return returntile;
return -1;
}

function cTileTools::ClearTile(tile)
{
return AITile.DemolishTile(tile);
}
/*
function cTileTools::RaiseCornersTo(level)
{
local trys=0;
local min=0;
local max=1;
do	{
	min=
	} while (!min==max || trys==100);
}*/

function cTileTools::FlattenTileAt(tileAs, tileto)
{
local srcL=AITile.GetMinHeight(tileAs);
local srcH=AITile.GetMaxHeight(tileAs);
if (!srcL==srcH) return;

local dstH=AITile.GetMaxHeight(tileto);
local dstL=AITile.GetMinHeight(tileto);
local compH=AITile.GetComplementSlope(tileto);

if (dstH > srcH)	{ KInfo("Lowering tile"); AITile.LowerTile(tileto,compH); }
if (dstH < srcH)	{ KInfo("Raising tile"); AITile.RaiseTile(tileto,compH); }

if (dstL > srcL)	{ KInfo("Lowering tile"); AITile.LowerTile(tileto,compH); }
if (dstL < srcL)	{ KInfo("Raising tile"); AITile.RaiseTile(tileto,compH); }

}

function cTileTools::FlattenTile(tilefrom, tileto)
{
return AITile.LevelTiles(tilefrom, tileto);
}

function cTileTools::CheckLandForContruction(fromTile, toTile)
// Check fromTile toTile if we need raise/lower or demolish things
{

}

