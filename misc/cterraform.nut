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

class cTerraform
{
static	terraformCost = AIList();
		constructor()
			{
			this.ClassName	= "cTerraform";
			}
}

function cTerraform::IsAreaFlat(area, ignore_list = AIList())
// Check the tile list in area if all tiles are flat
{
	local n = AIList();
	n.AddList(area);
	n.RemoveList(ignore_list);
	n.Valuate(AITile.GetSlope);
	n.RemoveValue(AITile.SLOPE_FLAT);
	return (n.IsEmpty());
}

function cTerraform::IsAreaBuildable(area, max_remove, ignore_list = AIList())
// return true if area is buildable or if we need to remove max_remove to make the area buildable
{
	local owncheck = AIList();
	owncheck.AddList(area);
	owncheck.RemoveList(ignore_list);
	owncheck.Valuate(cTileTools.IsBuildable);
	owncheck.KeepValue(0);
	if (owncheck.Count() > max_remove)	return false;
	return true;
}

function cTerraform::IsAreaBuildableAndFlat(area, max_remove, ignore_list = AIList())
// return true if area is flat and buildable or if we need to remove max_remove to make the area flat and buildable
{
	if (!cTerraform.IsAreaFlat(area, ignore_list))	{ return false; }
	return cTerraform.IsAreaBuildable(area, max_remove, ignore_list);
}

function cTerraform::IsAreaClear(area, safe_clear, get_cost_only, ignore_list = AIList())
// Clean out an area to allow building on it
// safe_clear : if true we get some protection from cTileTools.DemolishTile
// only_cost : if true, we won't clear the area, but return only the costs to do it
// return the costs to clear or taken to handle the area, -1 if something cannot be clear
{
	local cost = 0;
	foreach (tile, _ in area)
			{
			if (ignore_list.HasItem(tile))	continue;
			local tile_cost = cTileTools.IsTileClear(tile, safe_clear, get_cost_only);
			if (tile_cost == -1)	return -1;
			cost += tile_cost;
			}
	DInfo("Money to clear area: "+cost,3);
	return cost;
}

function cTerraform::CheckAreaForConstruction(area, safe, max_remove, allow_terraform, ignore_list = AIList())
/** @brief Check area to see if we will be able to build on it, answering costs need to do it
 *
 * @param area The area tile list to check
 * @param safe Given parameter to safe keep us with cTileTools.DemolishTile
 * @param max_remove maximum destruction we will allow else, we consider it not doable
 * @param allow_terraform true if we are able to terraform the area (might still not be able because of AI settings)
 * @param ignore_list an ailist with tiles we should ignore (or force to be seen buildable)
 * @return The costs need to do it, -1 if it's not doable.
 *
 */
{
	local area_work = AIList();
	area_work.AddList(area);
	if (area_work.IsEmpty())	return -1;
	if (!cTerraform.IsAreaBuildable(area_work, max_remove, ignore_list))	return -1;
	// check if we will really be able to clear everything, <safe> might disallow that
	local cost_clear = cTerraform.IsAreaClear(area_work, safe, true, ignore_list);
	if (cost_clear == -1)	return -1;
	if (!allow_terraform || !INSTANCE.terraform)	return cost_clear;
	area_work.RemoveList(ignore_list);
	local terra_solve = cTerraform.TerraformHeightSolver(area_work);
	terra_solve.RemoveValue(0);
	if (terra_solve.IsEmpty())	return cost_clear;
	terra_solve.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
	cost_clear += abs(terra_solve.GetValue(terra_solve.Begin()));
    return cost_clear;
}

function cTerraform::CheckRectangleForConstruction(tile, width, height, safe, max_remove, allow_terraform, ignore_list = AIList())
// Rectangle functions are wrapper that use GetRectangle to build the area and then just call the Area functions
{
	local t = cTileTools.GetRectangle(tile, width, height);
	return cTerraform.CheckAreaForConstruction(t, safe, max_remove, allow_terraform, ignore_list);
}

function cTerraform::IsRectangleFlat(tile, width, height)
// Check a rectangle is flat
{
	local t = cTileTools.GetRectangle(tile, width, height);
	return cTerraform.IsAreaFlat(t);
}

function cTerraform::IsRectangleBuildable(tile, width, height, max_remove, ignore_list = AIList())
// return true if the rectangle is buildable
{
	local t = cTileTools.GetRectangle(tile, width, height);
	return cTerraform.IsAreaBuildable(t, max_remove, ignore_list);
}

function cTerraform::IsRectangleBuildableAndFlat(tile, width, height, max_remove, ignore_list = AIList())
// return true if the rectangle is buildable and flat
{
	local n = cTileTools.GetRectangle(tile, width, height);
	return cTerraform.IsAreaBuildableAndFlat(n, max_remove, ignore_list);
}

function cTerraform::ShapeTile(tile, wantedHeight, evaluateOnly)
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
		DInfo("AI terraforming is disable, failure",1);
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
			//DInfo("Tile: "+tile+" Removing SteepSlope",2);
			AITile.RaiseTile(tile,compSlope);
			error=AIError.GetLastError();
			if (error != AIError.ERR_NONE)	generror=true;
			slope=AITile.GetSlope(tile);
			compSlope=AITile.GetComplementSlope(slope);
			srcL=AITile.GetMinHeight(tile);
			srcH=AITile.GetMaxHeight(tile);
			if (evaluateOnly)	return false;
			}
		//DInfo("Tile: "+tile+" Slope: "+slope+" compSlope: "+compSlope+" target: "+wantedHeight+" srcL: "+srcL+" srcH: "+srcH+" real slope: "+AITile.GetSlope(tile),2,"ShapeTile");
		cDebug.PutSign(tile,"!");
		if ((srcH < wantedHeight || srcL < wantedHeight) && !generror)
			{
			if (AITile.GetSlope(tile) == AITile.SLOPE_ELEVATED)
						AITile.RaiseTile(tile, AITile.SLOPE_FLAT);
					else	AITile.RaiseTile(tile, compSlope);
			error=AIError.GetLastError();
			//DInfo("Raising tile "+AIError.GetLastErrorString()+" minHeight: "+AITile.GetMinHeight(tile)+" maxheight: "+AITile.GetMaxHeight(tile)+" new slope:"+AITile.GetSlope(tile),2,"ShapeTile");
			if (error != AIError.ERR_NONE)	generror=true;
			}
		if ((srcL > wantedHeight || srcH > wantedHeight) && !generror)
			{
			if (AITile.GetSlope(tile) == AITile.SLOPE_FLAT)
						{ AITile.LowerTile(tile, AITile.SLOPE_ELEVATED);}
					else	{ AITile.LowerTile(tile, slope); }
			error=AIError.GetLastError();
			//DInfo("Lowering tile "+AIError.GetLastErrorString()+" minHeight: "+AITile.GetMinHeight(tile)+" maxheight: "+AITile.GetMaxHeight(tile)+" new slope:"+AITile.GetSlope(tile),2,"ShapeTile");
			if (error != AIError.ERR_NONE)	generror=true;
			}
		} while (!generror && srcH != wantedHeight && srcL != wantedHeight && !evaluateOnly);
	return generror;
}

function cTerraform::TerraformLevelTiles(tileFrom, tileTo)
// terraform from tileFrom to tileTo ; if tileFrom is an array, we terraform the array list in tileFrom
// return true if success
{
	local tlist = AITileList();
	if (cMisc.IsAIList(tileFrom))	tlist.AddList(tileFrom);
                            else	tlist.AddRectangle(tileFrom, tileTo);
	if (tlist.IsEmpty())	{ DInfo("No tiles to work with !",4); return false; }
    foreach (tile, _ in tlist) // raising water level tiles
    	if (AITile.IsWaterTile(tile))
				{
				if (cTileTools.IsRiverTile(tile))	AITile.DemolishTile(tile);
											else	AITile.RaiseTile(tile, AITile.SLOPE_N + AITile.SLOPE_S + AITile.SLOPE_W);
				}
	local Solve = cTerraform.TerraformHeightSolver(tlist);
	Solve.RemoveValue(0); // discard failures
	local bestOrder=AIList();
	bestOrder.AddList(Solve);
	foreach (level, prize in Solve)
		{
		local c=abs(prize);
		bestOrder.SetValue(level,prize);
		}
	bestOrder.Sort(AIList.SORT_BY_VALUE, true);
	local money = -1;
	foreach (solution, prize in bestOrder)	DInfo("solve: "+solution+" prize: "+prize,4);
	if (!Solve.IsEmpty())
		{
		foreach (solution, prize in bestOrder)
			{
			local direction=Solve.GetValue(solution);
			if (!cBanker.CanBuyThat(prize))
				{
				DInfo("Stopping action. We won't have enough money to succeed",4);
				cTerraform.terraformCost.AddItem(999999,prize);
				break;
				}
			cBanker.RaiseFundsBigTime();
			if (direction < 0)	money = cTerraform.TerraformDoAction(tlist, solution, true, false);
						else	money = cTerraform.TerraformDoAction(tlist, solution, false, false);
			if (money != -1)
				{
				DInfo("Success, we spent "+money+" credits for the operation",4);
				return true;
				}
			}
		}
	DInfo("Fail",3);
	return false;
}

function cTerraform::TerraformDoAction(tlist, wantedHeight, UpOrDown, evaluate=false)
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
	if (!evaluate)	cDebug.showLogic(tTile);
	local costs=AIAccounting();
	local testrun=AITestMode();
	local error=false;
	foreach (tile, _ in tTile)
		{
		error=cTerraform.ShapeTile(tile, wantedHeight, true);
		if (error)	break;
		}
	testrun=null;
	moneyNeed=costs.GetCosts();
	DInfo("predict failure : "+error+" Money need="+moneyNeed,4);
	if (error)	moneyNeed=-1;
	if (evaluate)	return moneyNeed;
	costs.ResetCosts();
	if (!error)
		{
		foreach (tile, _ in tTile)
			{
			error=cTerraform.ShapeTile(tile, wantedHeight, false);
			if (error) break;
			}
		}
	moneySpend=costs.GetCosts();
	DInfo("spent "+moneySpend+" money",3);
	if (!error)
		{
		DInfo("flatten successfuly land at level : "+wantedHeight,4);
		return moneySpend;
		}
	DInfo("fail flatten land at level : "+wantedHeight,4);
	return -1;
}

function cTerraform::TerraformHeightSolver(tlist)
// Look at tiles in tlist and try to find the height that cost us the less to flatten them all at same height
// tlist: the tile list to check
// return : tilelist table with item=height level
//		value = 0 when failure
//		value > 0 should success if raising tiles, it's also money we need to do it
//		value < 0 should success if lowering tiles, it's also the negative value of money need to do it
// so best solve is lowest value (by abs value) && value != 0
{
	if (tlist.IsEmpty())
		{
		DInfo("TerraformHeightSolver doesn't find any tiles to work on!",4);
		return AIList();
		}
	local maxH = AIList();
	maxH.AddList(tlist);
	local minH = AITileList();
	local moneySpend=0;
	local moneyNeed=0;
	minH.AddList(maxH);
	maxH.Valuate(AITile.GetMaxHeight);
	minH.Valuate(AITile.GetMinHeight);
	local cellHCount=AIList();
	local cellLCount=AIList();
	foreach (tile, _ in maxH)
		{
		// this loop count each tile lower height and higher height on each tiles
		cellHCount = cMisc.MostItemInList(cellHCount,max(1, maxH.GetValue(tile))); // max(1, value) so we never try water level height
		cellLCount = cMisc.MostItemInList(cellLCount,max(1, minH.GetValue(tile)));
		}
	cellHCount.Sort(AIList.SORT_BY_VALUE,false);
	cellLCount.Sort(AIList.SORT_BY_VALUE,false);
	local HeightIsLow=true;
	local currentHeight=-1;
	local h_firstitem=1000;
	local l_firstitem=1000;
	local Solve=AIList();
	local terratrys=0;
	do	{
		h_firstitem=cellHCount.Begin();
		l_firstitem=cellLCount.Begin();
		if (cellHCount.GetValue(h_firstitem) < cellLCount.GetValue(l_firstitem))
				{
				HeightIsLow=true;
				currentHeight=l_firstitem;
				cellLCount.RemoveItem(l_firstitem);
				DInfo("Trying lowering tiles level to "+currentHeight,4);
				}
		else	{
				HeightIsLow=false;
				currentHeight=h_firstitem;
				cellHCount.RemoveItem(h_firstitem);
				DInfo("Trying raising tiles level to "+currentHeight,4);
				}
		// Now we have determine what low or high height we need to reach by priority (most tiles first, with a pref to lower height)
		terratrys++;
		local money=0;
		local error=false;
		money = cTerraform.TerraformDoAction(maxH, currentHeight, HeightIsLow, true);
		if (money != -1)
				{
				DInfo("Solve found, "+money+" credits need to reach level "+currentHeight,4);
				if (money == 0)	money=1; // in case no money is need, we still ask 1 credit, else we will mistake as a failure
				if (HeightIsLow)	money=0-money; // force negative to lower tile
				}
			else	money=0; // 0 == failure
		if (Solve.HasItem(currentHeight) && money!=0)
				{
				if (abs(Solve.GetValue(currentHeight)) > abs(money))	Solve.SetValue(currentHeight,money); // add it if solve cost less
				}
			else	Solve.AddItem(currentHeight,money);
		} while (cellHCount.Count() > 0 && cellLCount.Count() > 0); // loop until both lists are empty
	DInfo("Solver has search "+terratrys+" time",4);
	return Solve;
}
