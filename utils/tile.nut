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

class cTileTools { }

function cTileTools::GetTilesAroundTown(town_id)
// Get tile around a town
{
local tiles = AITileList();
local townplace = AITown.GetLocation(town_id);
tiles=cTileTools.GetTilesAroundPlace(townplace);
tiles.Valuate(AITile.IsWithinTownInfluence, town_id);
tiles.KeepValue(1);
return tiles;
}

function cTileTools::FindStationTiles(tile)
// return a list of tiles where we have the station we found at tile
{
local stationid=AIStation.GetStationID(tile);
if (!AIStation.IsValidStation(stationid))	return AIList();
local tilelist=cTileTools.GetTilesAroundPlace(tile);
tilelist.Valuate(AITile.GetDistanceManhattanToTile,tile);
tilelist.KeepBelowValue(12);
tilelist.Valuate(AIStation.GetStationID);
tilelist.KeepValue(stationid);
return tilelist;
}

function cTileTools::IsWithinTownInfluence(stationid, townid)
// A correction to AIStation.IsWithinTownInfluence bug
{
local stationtile=cTileTools.FindStationTiles(AIStation.GetLocation(stationid));
local within=false;
foreach (tile, dummy in stationtile)	{ if (AITile.IsWithinTownInfluence(tile, townid)) within=true; }
return within;
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

function cTileTools::ShapeTile(tile, wantedHeight)
{
//
local srcL=AITile.GetMinHeight(tile);
local srcH=AITile.GetMaxHeight(tile);
local slope=AITile.GetSlope(tile);
local compSlope=AITile.GetComplementSlope(tile);
compSlope=AITile.SLOPE_ELEVATED-slope;
if (srcL == wantedHeight && srcH == wantedHeight)
	{
	//DInfo("Tile at level");
	PutSign(tile,"=");	
	return true;
	}
DInfo("Tile: "+tile+" Slope: "+slope+" compSlope: "+compSlope+" target: "+wantedHeight+" srcL: "+srcL+" srcH: "+srcH);
local error=null;
if (srcL > wantedHeight || srcH > wantedHeight)
	{
	PutSign(tile,"v");
	AITile.LowerTile(tile, slope);
	error=AIError.GetLastError();
	DInfo("Lowering tile "+AIError.GetLastErrorString());
	if (error == AIError.ERR_NONE)	return true;
						else	return false;
	}
if (srcL < wantedHeight || srcH < wantedHeight)
	{
	PutSign(tile,"^");
	//local invSlope=AITile.SLOPE_ELEVATED-slope;
	AITile.RaiseTile(tile, compSlope);
	error=AIError.GetLastError();	
	DInfo("Raising tile "+AIError.GetLastErrorString());
	if (error == AIError.ERR_NONE)	return true;
						else	return false;
	}
// we fail to lower slope if we try lower one that is bellow first
}

function cTileTools::TerraformTile(tile, wantedHeight, Check=false)
{
local srcL=null;
local srcH=null;
local success=false;
do
	{
	srcL=AITile.GetMinHeight(tile);
	srcH=AITile.GetMaxHeight(tile);
	success=cTileTools.ShapeTile(tile, wantedHeight);
	if (!success)	INSTANCE.NeedDelay(50);
	} while (success && srcL != wantedHeight && srcH != wantedHeight);
if (!success)	DInfo("Fail");
return success;
}
	
function cTileTools::FlattenTile(tilefrom, tileto)
{
return AITile.LevelTiles(tilefrom, tileto);
}

function cTileTools::MostItemInList(list, item)
// add item to list if not exist and set counter to 1, else increase counter
// return the list
{
if (!list.HasItem(item))	{ list.AddItem(item,1); DInfo("new item : "+item); }
				else	{ local c=list.GetValue(item); c++; list.SetValue(item,c); DInfo("Item "+item+" now at "+c); }
DInfo("deb: "+list.GetValue(item));
return list;
}

function cTileTools::CheckLandForContruction(fromTile, toTile)
// Check fromTile toTile if we need raise/lower or demolish things
{
local maxH=AITileList();
local minH=AITileList();
fromTile=30594;
toTile=33402;
maxH.AddRectangle(fromTile,toTile);
minH.AddList(maxH);
maxH.Valuate(AITile.GetMaxHeight);
minH.Valuate(AITile.GetMinHeight);
local cellHCount=AIList();
local cellLCount=AIList();
local shouldsuccess=true;
foreach (tile, max in maxH)
	{
	//PutSign(tile,"*");
/*	if (!cellHCount.HasItem(max))
			{
			cellHCount.AddItem(max,1);
			}
		else	{
			local c=cellHCount.GetValue(max);
			c++; cellHCount.SetValue(max,c);
			}
	DInfo("new: "+max+" newval:"+cellHCount.GetValue(max));*/
	cellHCount=cTileTools.MostItemInList(cellHCount,maxH.GetValue(tile)); // could use "max" var instead, but clearer as-is
	cellLCount=cTileTools.MostItemInList(cellLCount,minH.GetValue(tile));
	}
DInfo("CellHCount size"+cellHCount.Count());
DInfo("CellLCount size"+cellLCount.Count());
foreach (item, value in cellHCount)
	{
	DInfo("High -> "+item+" / "+value);
	}
foreach (item, value in cellLCount)
	{
	DInfo("Low -> "+item+" / "+value);
	}
foreach (tile, max in maxH)
	{
	//PutSign(tile,AITile.GetMinHeight(tile)+"/"+max);
	}

cellHCount.Sort(AIList.SORT_BY_VALUE,false);
cellLCount.Sort(AIList.SORT_BY_VALUE,false);
local HeightIsLow=true;
local currentHeight=-1;
local h_firstitem=1000;
local l_firstitem=1000;
do	{
	h_firstitem=cellHCount.Begin();
	l_firstitem=cellLCount.Begin();
	DInfo("Checking h:"+cellHCount.GetValue(h_firstitem)+" vs l:"+cellLCount.GetValue(l_firstitem));
	if (cellHCount.GetValue(h_firstitem) < cellLCount.GetValue(l_firstitem))
			{
			DInfo("Pick low level");
			HeightIsLow=true;
			currentHeight=l_firstitem;
			cellLCount.RemoveItem(l_firstitem);
			}
	else		{
			HeightIsLow=false;
			currentHeight=h_firstitem;
			DInfo("Pick high level");
			cellHCount.RemoveItem(h_firstitem);
			}
	DInfo("currentHeight="+currentHeight+" low?"+HeightIsLow);
	INSTANCE.NeedDelay(50);
	// Now we have determine what low or high height we need to reach by priority (most tiles first, with a pref to lower height)
	local doable=true;
	if (currentHeight == 0) // not serious to build at that level
		{
		DInfo("Water level detect!");
		doable=false;
		continue;
		}
	local tTile=AITileList();
	tTile.AddList(maxH);
	tTile.Sort(AIList.SORT_BY_VALUE,HeightIsLow);
	foreach (tile, max in tTile)
		{
		if (!cTileTools.TerraformTile(tile, currentHeight)) 
			{
			doable=false;
			break;
			}
		//INSTANCE.NeedDelay(10);
		}

	if (doable)
		{ DInfo("It' doable!"); break; }
	DInfo("conditions: "+h_firstitem+" / "+l_firstitem);
	} while (h_firstitem > 0 || l_firstitem > 0); // loop until both lists are empty

//DInfo("Stopwatch");
foreach (tile, dummyvalue in maxH)
	{
	}
return maxH;
}

