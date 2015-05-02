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
}

function cTerraform::IsAreaFlat(startTile, width, height)
// from nocab terraform.nut as Terraform::IsFlat
// http://www.tt-forums.net/viewtopic.php?f=65&t=43259&sid=9335e2ce38b4bd5e3d4df99cf23d30d7
{
	local mapSizeX = AIMap.GetMapSizeX();
	local goalHeight = AITile.GetMinHeight(startTile);

	// Check if the terrain isn't already flat.
	for (local i = 0; i < width; i++)
		for (local j = 0; j < height; j++)
			if (AITile.GetMinHeight(startTile + i + j * mapSizeX) != goalHeight ||
				AITile.GetSlope(startTile + i + j * mapSizeX) != AITile.SLOPE_FLAT)
				return false;
	return true;
}

function cTerraform::IsBuildableRectangleFlat(tile, width, height, ignoreList=AIList())
// a wrapper to AITile.IsBuildableRectangle that also answer to "Are all tiles flat"
{
	local check=AITile.IsBuildableRectangle(tile, width, height);
	if (!check)	return false;
	return cTileTools.IsAreaFlat(tile, width, height);
}

function cTerraform::IsBuildableRectangle(tile, width, height, ignoreList=AIList())
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
	//DInfo("Width: "+width+" height: "+height,1,"IsBuildableRectangle");
	width-=1;
	height-=1;
	if (width < 0) width=0;
	if (height < 0) height=0;
	// tile is @ topleft of the rectangle
	// secondtile is @ lowerright
	tilelist.Clear();
	secondtile=tile+AIMap.GetTileIndex(width,height);
	returntile=tile;
	tilelist.AddRectangle(tile,secondtile);
	tilelist.Valuate(cTileTools.IsBuildable);
	before=tilelist.Count();
	foreach (itile, idummy in ignoreList)
		{
		if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
		}
	tilelist.KeepValue(1);
	after=tilelist.Count();
	if (after==before)
		{
		//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	cDebug.PutSign(tile,"1");
		//cDebug.PutSign(returntile,"X");
		return returntile;
		}
	// tile is @ topright of the rectangle
	// secondtile is @ lowerleft
	tilelist.Clear();
	secondtile=tile+AIMap.GetTileIndex(width,0-height);
	returntile=tile+AIMap.GetTileIndex(0,0-height);
	tilelist.AddRectangle(tile,secondtile);
	tilelist.Valuate(cTileTools.IsBuildable);
	before=tilelist.Count();
	foreach (itile, idummy in ignoreList)
		{
		if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
		}
	tilelist.KeepValue(1);
	after=tilelist.Count();
	if (after==before)
		{
		//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	cDebug.PutSign(tile,"2");
		//cDebug.PutSign(returntile,"X");
		return returntile;
		}
	// tile is @ lowerleft of the rectangle
	// secondtile is @ upperright
	tilelist.Clear();
	secondtile=tile+AIMap.GetTileIndex(0-width,height);
	returntile=tile+AIMap.GetTileIndex(0-width,0);
	tilelist.AddRectangle(tile,secondtile);
	tilelist.Valuate(cTileTools.IsBuildable);
	before=tilelist.Count();
	foreach (itile, idummy in ignoreList)
		{
		if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
		}
	tilelist.KeepValue(1);
	after=tilelist.Count();
	if (after==before)
		{
		//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	cDebug.PutSign(tile,"3");
		//cDebug.PutSign(returntile,"X");
		return returntile;
		}
	// tile is @ lowerright of the rectangle
	// secondtile is @ upperleft
	tilelist.Clear();
	secondtile=tile+AIMap.GetTileIndex(0-width,0-height);
	returntile=secondtile;
	tilelist.AddRectangle(tile,secondtile);
	tilelist.Valuate(cTileTools.IsBuildable);
	before=tilelist.Count();
	foreach (itile, idummy in ignoreList)
		{
		if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
		}
	tilelist.KeepValue(1);
	after=tilelist.Count();
	if (after==before)
		{
		//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	cDebug.PutSign(tile,"4");
		//cDebug.PutSign(returntile,"X");
		return returntile;
		}
	return -1;
}

function cTerraform::IsFlatBuildableAreaExist(tile, width, height, ignoreList=AIList())
// This check if the rectangle area is buildable and flat in any directions from that point
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
	//DInfo("Width: "+width+" height: "+height,1,"IsBuildableRectangle");
	width-=1;
	height-=1;
	if (width < 0) width=0;
	if (height < 0) height=0;
	// tile is @ topleft of the rectangle
	// secondtile is @ lowerright
	tilelist.Clear();
	secondtile=tile+AIMap.GetTileIndex(width,height);
	returntile=tile;
	tilelist.AddRectangle(tile,secondtile);
	tilelist.Valuate(cTileTools.IsBuildable);
	before=tilelist.Count();
	foreach (itile, idummy in ignoreList)
		{
		if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
		}
	tilelist.KeepValue(1);
		//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	cDebug.PutSign(tile,"1");
	after=tilelist.Count();
	if (after==before && cTileTools.IsAreaFlat(returntile, width+1, height+1))	return returntile;
	// tile is @ topright of the rectangle
	// secondtile is @ lowerleft
	tilelist.Clear();
	secondtile=tile+AIMap.GetTileIndex(width,0-height);
	returntile=tile+AIMap.GetTileIndex(0,0-height);
	tilelist.AddRectangle(tile,secondtile);
	tilelist.Valuate(cTileTools.IsBuildable);
	before=tilelist.Count();
	foreach (itile, idummy in ignoreList)
		{
		if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
		}
	tilelist.KeepValue(1);
	//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	cDebug.PutSign(tile,"2");
	after=tilelist.Count();
	if (after==before && cTileTools.IsAreaFlat(returntile, width+1, height+1))	return returntile;
	// tile is @ lowerleft of the rectangle
	// secondtile is @ upperright
	tilelist.Clear();
	secondtile=tile+AIMap.GetTileIndex(0-width,height);
	returntile=tile+AIMap.GetTileIndex(0-width,0);
	tilelist.AddRectangle(tile,secondtile);
	tilelist.Valuate(cTileTools.IsBuildable);
	before=tilelist.Count();
	foreach (itile, idummy in ignoreList)
		{
		if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
		}
	tilelist.KeepValue(1);
	//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	cDebug.PutSign(tile,"3");
	after=tilelist.Count();
	if (after==before && cTileTools.IsAreaFlat(returntile, width+1, height+1))	return returntile;
	// tile is @ lowerright of the rectangle
	// secondtile is @ upperleft
	tilelist.Clear();
	secondtile=tile+AIMap.GetTileIndex(0-width,0-height);
	returntile=secondtile;
	tilelist.AddRectangle(tile,secondtile);
	tilelist.Valuate(cTileTools.IsBuildable);
	before=tilelist.Count();
	foreach (itile, idummy in ignoreList)
		{
		if (tilelist.HasItem(itile))	tilelist.SetValue(itile,1);
		}
	tilelist.KeepValue(1);
	after=tilelist.Count();
	//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	cDebug.PutSign(tile,"4");
	if (after==before && cTileTools.IsAreaFlat(returntile, width+1, height+1))	return returntile;
	return -1;
}

function cTerrafrom::ShapeTile(tile, wantedHeight, evaluateOnly)
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

function cTerraform::CheckLandForConstruction(tile, width, height, ignoreList=AIList())
// Check the tiles area for construction, look if tiles are clear, and flatten the land if need
// return -1 on failure, on success the tile where to drop a construction (upper left tile)
{
	cDebug.PutSign(tile,"?");
	local newTile=cTileTools.IsBuildableRectangle(tile, width, height, ignoreList);
	if (newTile == -1)	return newTile; // area not clear give up, the terraforming will fail too
	if (cTileTools.IsBuildableRectangleFlat(newTile, width, height))	return newTile;
	local tileTo=newTile+AIMap.GetTileIndex(width-1,height-1);
	INSTANCE.main.bank.RaiseFundsBigTime();
	cTileTools.TerraformLevelTiles(newTile, tileTo);
	INSTANCE.NeedDelay(20);
	if (cTileTools.IsBuildableRectangleFlat(newTile, width, height))		return newTile;
	return -1;
}

function cTerraform::TerraformLevelTiles(tileFrom, tileTo)
// terraform from tileFrom to tileTo
// return true if success
{
	local tlist=AITileList();
	if (AITile.IsWaterTile(tileFrom))	{ print("raising fromtile "+AITile.RaiseTile(tileFrom, AITile.SLOPE_N + AITile.SLOPE_S)); }
	tlist.AddRectangle(tileFrom, tileTo);
	if (tlist.IsEmpty())	DInfo("No tiles to work with !",4);
	local Solve=cTileTools.TerraformHeightSolver(tlist);
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
				DInfo("Stopping action. We won't have enought money to succeed",4);
				cTileTools.terraformCost.AddItem(999999,prize);
				break;
				}
			cBanker.RaiseFundsBigTime();
			if (direction < 0)	money=cTileTools.TerraformDoAction(tlist, solution, true, false);
						else	money=cTileTools.TerraformDoAction(tlist, solution, false, false);
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
	foreach (tile, max in tTile)
		{
		error=cTileTools.ShapeTile(tile, wantedHeight, true);
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
		foreach (tile, max in tTile)
			{
			error=cTileTools.ShapeTile(tile, wantedHeight, false);
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
// return : tilelist table with item=height
//		value = 0 when failure
//		value > 0 should success if raising tiles, it's also money we need to do it
//		value < 0 should success if lowering tiles, it's also the negative value of money need to do it
// so best solve is lowest value (by abs value) && value != 0
{
	if (tlist.IsEmpty())
		{
		DInfo("doesn't find any tiles to work on!",4);
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
		cellHCount = cMisc.MostItemInList(cellHCount,maxH.GetValue(tile)); // could use "max" var instead, but clearer as-is
		cellLCount = cMisc.MostItemInList(cellLCount,minH.GetValue(tile));
		}
	cellHCount.Sort(AIList.SORT_BY_VALUE,false);
	cellLCount.Sort(AIList.SORT_BY_VALUE,false);
	local HeightIsLow=true;
	local currentHeight=-1;
	local h_firstitem=1000;
	local l_firstitem=1000;
	local Solve=AIList();
	local terratrys=0;
	DInfo("Terraform: "+cMisc.Locate(tlist.Begin()),3);
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
		else		{
				HeightIsLow=false;
				currentHeight=h_firstitem;
				cellHCount.RemoveItem(h_firstitem);
				DInfo("Trying raising tiles level to "+currentHeight,4);
				}
		// Now we have determine what low or high height we need to reach by priority (most tiles first, with a pref to lower height)
		terratrys++;
		if (currentHeight == 0) // not serious to build at that level
			{
			DInfo("Water level detect !",4);
			Solve.AddItem(0,0);
			continue;
			}
		local money=0;
		local error=false;
		money=cTileTools.TerraformDoAction(maxH, currentHeight, HeightIsLow, true);
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
