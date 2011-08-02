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
// A tweak for AIStation.IsWithinTownInfluence in openttd < 1.1.2
{
local stationtile=cTileTools.FindStationTiles(AIStation.GetLocation(stationid));
foreach (tile, dummy in stationtile)	{ if (AITile.IsWithinTownInfluence(tile, townid)) return true; }
return false;
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

function cTileTools::IsBuildableRectangleAtThisPoint(tile, width, height, ignoreList=AIList())
// This check if the rectangle area is buildable in any directions from that point
// Like the IsBuildableRectangle, but not limit to upper left point
// tile : tile to search a solve for
// width & height : dimensions
// ignoreList: AIList() with tiles we should ignore (report them as if they were IsBuildable even something is there)
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
foreach (itile, idummy in ignoreList)
	{
	if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
	}
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
foreach (itile, idummy in ignoreList)
	{
	if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
	}
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
foreach (itile, idummy in ignoreList)
	{
	if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
	}
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
foreach (itile, idummy in ignoreList)
	{
	if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
	}
tilelist.KeepValue(1);
after=tilelist.Count();
if (after==before)	return returntile;
return -1;
}

function cTileTools::ClearTile(tile)
{
return AITile.DemolishTile(tile);
}

function cTileTools::ShapeTile(tile, wantedHeight, evaluateOnly)
// Flatten the tile at wanted height level
// tile: tile to shape
// wantedHeight: height to flatten land to
// evaluateOnly: ignore steep slope : that's to not fail when we evaluate the success
{
local srcL=AITile.GetMinHeight(tile);
local srcH=AITile.GetMaxHeight(tile);
local slope=AITile.GetSlope(tile);
local error=null;
local generror=false;
local tsign=null;
local compSlope=AITile.GetComplementSlope(slope);
if (srcL == wantedHeight && srcH == wantedHeight)	return generror;
if (!INSTANCE.terraform)
	{
	DInfo("ShapeTile-> AI terraforming is disable, failure",2);
	return true;
	}
do	{
	srcL=AITile.GetMinHeight(tile);
	srcH=AITile.GetMaxHeight(tile);
	slope=AITile.GetSlope(tile);
	compSlope=AITile.GetComplementSlope(slope);
	if ((slope & AITile.SLOPE_STEEP) == AITile.SLOPE_STEEP)
		{
		slope-=AITile.SLOPE_STEEP;
		compSlope=AITile.GetComplementSlope(slope);
		DInfo("ShapeTile-> Tile: "+tile+" Removing SteepSlope",2);
		AITile.RaiseTile(tile,compSlope);
		error=AIError.GetLastError();
		if (error != AIError.ERR_NONE)	generror=true;
		slope=AITile.GetSlope(tile);
		compSlope=AITile.GetComplementSlope(slope);
		srcL=AITile.GetMinHeight(tile);
		srcH=AITile.GetMaxHeight(tile);
		if (evaluateOnly)	return false;
		}
	DInfo("ShapeTile-> Tile: "+tile+" Slope: "+slope+" compSlope: "+compSlope+" target: "+wantedHeight+" srcL: "+srcL+" srcH: "+srcH+" real slope: "+AITile.GetSlope(tile),2);
	PutSign(tile,"!");
	INSTANCE.Sleep(1);
	if ((srcH < wantedHeight || srcL < wantedHeight) && !generror)
		{
		if (AITile.GetSlope(tile) == AITile.SLOPE_ELEVATED)
					AITile.RaiseTile(tile, AITile.SLOPE_FLAT);			
				else	AITile.RaiseTile(tile, compSlope);
		error=AIError.GetLastError();	
		DInfo("ShapeTile-> Raising tile "+AIError.GetLastErrorString()+" minHeight: "+AITile.GetMinHeight(tile)+" maxheight: "+AITile.GetMaxHeight(tile)+" new slope:"+AITile.GetSlope(tile),2);
		if (error != AIError.ERR_NONE)	generror=true;
		}
	if ((srcL > wantedHeight || srcH > wantedHeight) && !generror)
		{
		if (AITile.GetSlope(tile) == AITile.SLOPE_FLAT)
					{ AITile.LowerTile(tile, AITile.SLOPE_ELEVATED);}
				else	{ AITile.LowerTile(tile, slope); }
		error=AIError.GetLastError();	
		DInfo("ShapeTile-> Lowering tile "+AIError.GetLastErrorString()+" minHeight: "+AITile.GetMinHeight(tile)+" maxheight: "+AITile.GetMaxHeight(tile)+" new slope:"+AITile.GetSlope(tile),2);
		if (error != AIError.ERR_NONE)	generror=true;
		}
	} while (!generror && srcH != wantedHeight && srcL != wantedHeight && !evaluateOnly);
return generror;
}

function cTileTools::FlattenTile(tilefrom, tileto)
// flatten tiles from tilefrom to tileto, use first tile as reference for the height to reach
{
local tlist=AITileList();
tlist.AddRectangle(tilefrom, tileto);
return AITile.LevelTiles(tilefrom, tileto);
}

function cTileTools::MostItemInList(list, item)
// add item to list if not exist and set counter to 1, else increase counter
// return the list
{
if (!list.HasItem(item))	{ list.AddItem(item,1); }
				else	{ local c=list.GetValue(item); c++; list.SetValue(item,c); }
return list;
}

function cTileTools::CheckLandForConstruction(tile, width, height, ignoreList=AIList())
// Check the tiles area for construction, look if tiles are clear, and flatten the land if need
// return -1 on failure, the tile where to drop a construction (upper left tile)
{
PutSign(tile,"HERE");
local newTile=cTileTools.IsBuildableRectangleAtThisPoint(tile, width, height, ignoreList);
if (newTile == -1)	return newTile; // area not clear give up, the terraforming will fail too
local tileTo=newTile+AIMap.GetTileIndex(width,height);
if (cTileTools.TerraformLevelTiles(newTile, tileTo))
		return newTile;
	else	return -1;
}

function cTileTools::TerraformLevelTiles(tileFrom, tileTo)
// terraform from tileFrom to tileTo
// return true if success
{
local tlist=AITileList();
tlist.AddRectangle(tileFrom, tileTo);
local Solve=cTileTools.TerraformHeightSolver(tlist);
Solve.RemoveValue(0); // discard failures
local bestOrder=AIList();
bestOrder.AddList(Solve);
foreach (level, prize in bestOrder)
	{
	local c=abs(prize);
	bestOrder.SetValue(level,prize);
	}
bestOrder.Sort(AIList.SORT_BY_VALUE, true);
local money=-1;
foreach (solution, prize in bestOrder)	DInfo("sol: "+solution+" prize: "+prize);
if (!Solve.IsEmpty())
	{
	foreach (solution, prize in bestOrder)
		{
		local direction=Solve.GetValue(solution);
		if (!cBanker.CanBuyThat(prize))
			{
			DInfo("TerraformLevelTiles-> Stopping action. We won't have enought money to succed",1);
			continue;
			}
		cBanker.RaiseFundsBigTime();
		if (direction < 0)	money=cTileTools.TerraformDoAction(tlist, solution, true, false);
					else	money=cTileTools.TerraformDoAction(tlist, solution, false, false);	
		if (money != -1)
			{
			DInfo("TerraformLevelTiles-> Success, we spent "+money+" credits for the operation",1);
			return true;
			}
		}
	}
DInfo("TerraformLevelTiles-> Fail",2);
return false;
}

function cTileTools::TerraformDoAction(tlist, wantedHeight, UpOrDown, evaluate=false)
// Try flatten tiles in tlist to the wanted height level
// tlist : tiles to check
// wantedHeight : the level to flatten tiles to
// UpOrDown: true to level down, false to level up the tiles
// evaluate : true to only check if we can do it, else we will execute the terraforming
// return :	-1 in both case if this will fail
//		when evaluate & success return estimated costs need to do the operation
//		when !evaluate & success return costs taken to do the operation
{
local moneySpend=0;
local moneyNeed=0;
local tTile=AITileList();
tTile.AddList(tlist);
tTile.Sort(AIList.SORT_BY_VALUE,UpOrDown);
local costs=AIAccounting();
local testrun=AITestMode();
local error=false;
foreach (tile, max in tTile)
	{
	error=cTileTools.ShapeTile(tile, wantedHeight, true);
	if (error)	break;
	}
testrun=null;
moneyNeed=costs.GetCosts();	
DInfo("TerraformDoAction-> predict failure : "+error+" Money need="+moneyNeed,2);
if (error)	moneyNeed=-1;
if (evaluate)	return moneyNeed;
costs.ResetCosts();
if (!error)
	{
	foreach (tile, max in tTile)
		{
		error=cTileTools.ShapeTile(tile, wantedHeight, false);
		if (error) break;
		}
	}
moneySpend=costs.GetCosts();
DInfo("TerraformDoAction-> spent "+moneySpend+" money",2);
if (!error)
	{
	DInfo("TerraformDoAction-> flatten successfuly land at level : "+wantedHeight,1);
	return moneySpend;
	}
DInfo("TerraformDoAction-> fail flatten land at level : "+wantedHeight,1);
return -1;
}

function cTileTools::TerraformHeightSolver(tlist)
// Look at tiles in tlist and try to find the height that cost us the less to flatten them all at same height
// tlist: the tile list to check
// return : tilelist table with item=height
//		value = 0 when failure
//		value > 0 should success if raising tiles, it's also money we need to do it
//		value < 0 should success if lowering tiles, it's also the negative value of money need to do it
// so best solve is lowest value (by abs value) && value != 0
{
if (tlist.IsEmpty())	
	{
	DInfo("TerraformSolver-> doesn't find any tiles to work on!",1);
	return AIList();
	}
local maxH=tlist;
local minH=AITileList();
local moneySpend=0;
local moneyNeed=0;
minH.AddList(maxH);
maxH.Valuate(AITile.GetMaxHeight);
minH.Valuate(AITile.GetMinHeight);
local cellHCount=AIList();
local cellLCount=AIList();
foreach (tile, max in maxH)
	{
	// this loop count each tile lower height and higher height on each tiles
	cellHCount=cTileTools.MostItemInList(cellHCount,maxH.GetValue(tile)); // could use "max" var instead, but clearer as-is
	cellLCount=cTileTools.MostItemInList(cellLCount,minH.GetValue(tile));
	}
//DInfo("CellHCount size"+cellHCount.Count());
//DInfo("CellLCount size"+cellLCount.Count());
cellHCount.Sort(AIList.SORT_BY_VALUE,false);
cellLCount.Sort(AIList.SORT_BY_VALUE,false);
local HeightIsLow=true;
local currentHeight=-1;
local h_firstitem=1000;
local l_firstitem=1000;
local Solve=AIList();
local terratrys=0;
DInfo("TerrraformSolver-> Start near "+AITown.GetName(AITile.GetClosestTown(tlist.Begin())),1);
do	{
	h_firstitem=cellHCount.Begin();
	l_firstitem=cellLCount.Begin();
	//DInfo("Checking h:"+cellHCount.GetValue(h_firstitem)+" vs l:"+cellLCount.GetValue(l_firstitem));
	if (cellHCount.GetValue(h_firstitem) < cellLCount.GetValue(l_firstitem))
			{
			DInfo("TerraformSolver-> trying lowering tiles level to "+currentHeight,2);
			HeightIsLow=true;
			currentHeight=l_firstitem;
			cellLCount.RemoveItem(l_firstitem);
			}
	else		{
			HeightIsLow=false;
			currentHeight=h_firstitem;
			cellHCount.RemoveItem(h_firstitem);
			DInfo("TerraformSolver-> trying raising tiles level to "+currentHeight,2);
			}
	// Now we have determine what low or high height we need to reach by priority (most tiles first, with a pref to lower height)
	terratrys++;
	if (currentHeight == 0) // not serious to build at that level
		{
		DInfo("TerraformSolver-> Water level detect !",1);
		Solve.AddItem(0,0);
		continue;
		}
	local money=0;
	local error=false;
	money=cTileTools.TerraformDoAction(maxH, currentHeight, HeightIsLow, true);
	if (money != -1)
			{
			DInfo("TerraformSolver-> found a solve, "+money+" credits need to reach level "+currentHeight,1);
			if (money == 0)	money=1; // in case no money is need, we still ask 1 credit, else we will mistake as a failure
			if (HeightIsLow)	money=0-money; // force negative to lower tile
			}
		else	money=0; // 0 == failure
	if (Solve.HasItem(currentHeight))
			{
			if (Solve.GetValue(currentHeight) < money)	Solve.SetValue(currentHeight,money); // add it if solve cost less
			}
		else	Solve.AddItem(currentHeight,money);
	} while (h_firstitem > 0 || l_firstitem > 0); // loop until both lists are empty
DInfo("TerraformSolver has search "+terratrys+" time",1);
return Solve;
}

function cTileTools::SeduceTown(townID, needRating)
// Fill a tile with trees
// needRating : rating we must reach
// return true if we reach needRating level with that town
{
local towntiles=cTileTools.GetTilesAroundTown(townID);
local curRating=AITown.GetRating(townID, AICompany.COMPANY_SELF);
towntiles.Valuate(AITile.IsBuildable);
towntiles.KeepValue(1);
local good=true;
local money=AIAccounting();
DInfo("Town: "+AITown.GetName(townID)+" rating: "+AITown.GetRating(townID, AICompany.COMPANY_SELF),0);
foreach (tile, dummy in towntiles)
	{
	if (curRating > needRating)	break;
	do	{
		good=AITile.PlantTree(tile);
		INSTANCE.bank.RaiseFundsTo(12000);
		DInfo("Plants tree -> +"good+" "+AIError.GetLastErrorString()+" newrate: "+AITown.GetRating(townID, AICompany.COMPANY_SELF));
		} while (good && AICompany.GetBankBalance(AICompany.COMPANY_SELF)>10000);
	curRating=AITown.GetRating(townID, AICompany.COMPANY_SELF);	
	}
local endop="Success !";
if (!good || curRating < needRating)	endop="Failure.";
DInfo("SeduceTown-> "+endop+" Rate now:"+curRating+" Funds: "+AICompany.GetBankBalance(AICompany.COMPANY_SELF)+" Spend: "+money.GetCosts()+" size: "+towntiles.Count(),1);
return (curRating > needRating);
}
