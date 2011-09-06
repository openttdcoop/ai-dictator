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
static	terraformCost = AIList();
static	TilesBlackList = AIList(); // item=tile, value=stationID that own the tile
}

function cTileTools::IsTilesBlackList(tile)
{
return cTileTools.TilesBlackList.HasItem(tile);
}

function cTileTools::GetTileOwner(tile)
// return station that own the tile
{
if (cTileTools.TilesBlackList.HasItem(tile))	return cTileTools.TilesBlackList.GetValue(tile);
return -1;
}

function cTileTools::CanUseTile(tile, owner)
// Answer if we can use that tile
{
local ot=cTileTools.GetTileOwner(tile);
if (ot == owner)	return true;
if (ot == -1)	return true;
if (ot == -100)	return true;
return false;
}

function cTileTools::CanUseTileForStationCreation(tile)
{
local owner=cTileTools.GetTileOwner(tile);
return (owner == -1);
}

function cTileTools::BlackListTile(tile, stationID=-255)
{
// we store the stationID for a blacklisted tile or a negative value that tell us why it was blacklist
// -255 not usable at all, we can't use it
// -100 don't use that tile when building a station, it's a valid tile, but a bad spot
if (AIMap.IsValidTile(tile))
	{
	local owner=cTileTools.GetTileOwner(tile);
	cTileTools.TilesBlackList.AddItem(tile, -1);
	if (stationID!=-100 && owner == -1)	cTileTools.TilesBlackList.SetValue(tile, stationID);
	if (stationID == -255)	cTileTools.TilesBlackList.SetValue(tile, -255);
	if (stationID == -100)	cTileTools.TilesBlackList.SetValue(tile, -100);
	}
}

function cTileTools::BlackListTileSpot(tile)
// blacklist that tile for possible station spot creation
{
cTileTools.BlackListTile(tile, -100);
}

function cTileTools::UnBlackListTile(tile)
{
if (cTileTools.IsTilesBlackList(tile))	cTileTools.TilesBlackList.RemoveItem(tile);
}

function cTileTools::PurgeBlackListTiles(alist, creation=false)
// remove all tiles that are blacklist from an AIList and return it
// if creation is false, don't remove tiles that cannot be use for station creation
{
local purgelist=AIList();
purgelist.AddList(alist);
purgelist.Valuate(cTileTools.GetTileOwner);
purgelist.RemoveValue(-1); // keep only ones that are not own by anyone
if (!creation)	purgelist.RemoveValue(-100); // but not own because of bad spot
foreach (tile, dummy in purgelist)	{ alist.RemoveItem(tile); INSTANCE.Sleep(1); }
return alist;
}

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
if (cTileTools.IsBuildable(tile)) return true;
if (AIRail.IsRailTile(tile))	return false;
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
if (distedge > 200) distedge=200; // limit to 120 around
offset = AIMap.GetTileIndex(distedge - 1, distedge -1);
tiles.AddRectangle(place - offset, place + offset);
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
if (!AITile.IsWaterTile(tile))	return AITile.IsBuildable(tile);
					else	return INSTANCE.terraform; // if no terraform is allow, water tile cannot be use
return true;
}

function cTileTools::IsAreaFlat(startTile, width, height)
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

function cTileTools::IsBuildableRectangleFlat(tile, width, height)
// a wrapper to AITile.IsBuildableRectangle that also answer to "Are all tiles flat"
{
local check=AITile.IsBuildableRectangle(tile, width, height);
if (!check)	return false;
return cTileTools.IsAreaFlat(tile, width, height);
}

function cTileTools::IsBuildableRectangle(tile, width, height, ignoreList=AIList())
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
DInfo("Width: "+width+" height: "+height,1,"IsBuildableRectangle");
width-=1;
height-=1;
if (width < 0) width=0;
if (height < 0) height=0;
// tile is @ topleft of the rectangle
// secondtile is @ lowerright
tilelist=AITileList();
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
//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	PutSign(tile,"1");
after=tilelist.Count();
if (after==before)	return returntile;
// tile is @ topright of the rectangle
// secondtile is @ lowerleft
tilelist=AITileList();
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
//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	PutSign(tile,"2");
after=tilelist.Count();
if (after==before)	return returntile;
// tile is @ lowerleft of the rectangle
// secondtile is @ upperright
tilelist=AITileList();
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
//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	PutSign(tile,"3");
after=tilelist.Count();
if (after==before)	return returntile;
// tile is @ lowerright of the rectangle
// secondtile is @ upperleft
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
//if (INSTANCE.debug)	foreach (tile, dummy in tilelist)	PutSign(tile,"4");
if (after==before)	return returntile;

return -1;
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
	DInfo("AI terraforming is disable, failure",1,"ShapeTile");
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
		DInfo("Tile: "+tile+" Removing SteepSlope",2,"ShapeTile");
		AITile.RaiseTile(tile,compSlope);
		error=AIError.GetLastError();
		if (error != AIError.ERR_NONE)	generror=true;
		slope=AITile.GetSlope(tile);
		compSlope=AITile.GetComplementSlope(slope);
		srcL=AITile.GetMinHeight(tile);
		srcH=AITile.GetMaxHeight(tile);
		if (evaluateOnly)	return false;
		}
	DInfo("Tile: "+tile+" Slope: "+slope+" compSlope: "+compSlope+" target: "+wantedHeight+" srcL: "+srcL+" srcH: "+srcH+" real slope: "+AITile.GetSlope(tile),2,"ShapeTile");
	//PutSign(tile,"!");
	INSTANCE.Sleep(1);
	if ((srcH < wantedHeight || srcL < wantedHeight) && !generror)
		{
		if (AITile.GetSlope(tile) == AITile.SLOPE_ELEVATED)
					AITile.RaiseTile(tile, AITile.SLOPE_FLAT);			
				else	AITile.RaiseTile(tile, compSlope);
		error=AIError.GetLastError();	
		DInfo("Raising tile "+AIError.GetLastErrorString()+" minHeight: "+AITile.GetMinHeight(tile)+" maxheight: "+AITile.GetMaxHeight(tile)+" new slope:"+AITile.GetSlope(tile),2,"ShapeTile");
		if (error != AIError.ERR_NONE)	generror=true;
		}
	if ((srcL > wantedHeight || srcH > wantedHeight) && !generror)
		{
		if (AITile.GetSlope(tile) == AITile.SLOPE_FLAT)
					{ AITile.LowerTile(tile, AITile.SLOPE_ELEVATED);}
				else	{ AITile.LowerTile(tile, slope); }
		error=AIError.GetLastError();	
		DInfo("Lowering tile "+AIError.GetLastErrorString()+" minHeight: "+AITile.GetMinHeight(tile)+" maxheight: "+AITile.GetMaxHeight(tile)+" new slope:"+AITile.GetSlope(tile),2,"ShapeTile");
		if (error != AIError.ERR_NONE)	generror=true;
		}
	} while (!generror && srcH != wantedHeight && srcL != wantedHeight && !evaluateOnly);
return generror;
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
// return -1 on failure, on success the tile where to drop a construction (upper left tile)
{
PutSign(tile,"?");
local newTile=cTileTools.IsBuildableRectangle(tile, width, height, ignoreList);
if (newTile == -1)	return newTile; // area not clear give up, the terraforming will fail too
//function cTileTools::IsBuildableRectangleFlat(tile, width, height)
if (cTileTools.IsBuildableRectangleFlat(newTile, width, height))	return newTile;
local tileTo=newTile+AIMap.GetTileIndex(width-1,height-1);
INSTANCE.bank.RaiseFundsBigTime();
print("before terrraform : "+cTileTools.IsBuildableRectangleFlat(newTile, width, height));
cTileTools.TerraformLevelTiles(newTile, tileTo);
print("after terrraform : "+cTileTools.IsBuildableRectangleFlat(newTile, width, height));
INSTANCE.NeedDelay(200);
if (cTileTools.IsBuildableRectangleFlat(newTile, width, height))		return newTile;
											else	return -1;
}

function cTileTools::TerraformLevelTiles(tileFrom, tileTo)
// terraform from tileFrom to tileTo
// return true if success
{
local tlist=AITileList();
tlist.AddRectangle(tileFrom, tileTo);
if (tlist.IsEmpty())	DInfo("No tiles to work with !",1,"TerraformLevelTiles");
//if (INSTANCE.debug)	foreach (tile, dummy in tlist)	PutSign(tile,"T");
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
foreach (solution, prize in bestOrder)	DInfo("solve: "+solution+" prize: "+prize,2,"TerraformLevelTiles");
if (!Solve.IsEmpty())
	{
	foreach (solution, prize in bestOrder)
		{
		local direction=Solve.GetValue(solution);
		if (!cBanker.CanBuyThat(prize))
			{
			DInfo("Stopping action. We won't have enought money to succeed",1,"TerraformLevelTiles");
			cTileTools.terraformCost.Clear();
			cTileTools.terraformCost.AddItem(0,prize);
			break;
			}
		cBanker.RaiseFundsBigTime();
		if (direction < 0)	money=cTileTools.TerraformDoAction(tlist, solution, true, false);
					else	money=cTileTools.TerraformDoAction(tlist, solution, false, false);	
		if (money != -1)
			{
			DInfo("Success, we spent "+money+" credits for the operation",1,"TerraformLevelTiles");
			return true;
			}
		}
	}
DInfo("Fail",1,"TerraformLevelTiles");
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
DInfo("predict failure : "+error+" Money need="+moneyNeed,2,"TerraformDoAction");
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
DInfo("spent "+moneySpend+" money",2,"TerraformDoAction");
if (!error)
	{
	DInfo("flatten successfuly land at level : "+wantedHeight,1,"TerraformDoAction");
	return moneySpend;
	}
DInfo("fail flatten land at level : "+wantedHeight,1,"TerraformDoAction");
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
	DInfo("doesn't find any tiles to work on!",1,"TerraformHeightSolver");
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
cellHCount.Sort(AIList.SORT_BY_VALUE,false);
cellLCount.Sort(AIList.SORT_BY_VALUE,false);
local HeightIsLow=true;
local currentHeight=-1;
local h_firstitem=1000;
local l_firstitem=1000;
local Solve=AIList();
local terratrys=0;
DInfo("Start near "+AITown.GetName(AITile.GetClosestTown(tlist.Begin())),1,"cTileTools::TerraformSolver");
do	{
	h_firstitem=cellHCount.Begin();
	l_firstitem=cellLCount.Begin();
	//DInfo("Checking h:"+cellHCount.GetValue(h_firstitem)+" vs l:"+cellLCount.GetValue(l_firstitem));
	if (cellHCount.GetValue(h_firstitem) < cellLCount.GetValue(l_firstitem))
			{
			DInfo("Trying lowering tiles level to "+currentHeight,2,"cTileTools::TerraformSolver");
			HeightIsLow=true;
			currentHeight=l_firstitem;
			cellLCount.RemoveItem(l_firstitem);
			}
	else		{
			HeightIsLow=false;
			currentHeight=h_firstitem;
			cellHCount.RemoveItem(h_firstitem);
			DInfo("Trying raising tiles level to "+currentHeight,2,"cTileTools::TerraformSolver");
			}
	// Now we have determine what low or high height we need to reach by priority (most tiles first, with a pref to lower height)
	terratrys++;
	if (currentHeight == 0) // not serious to build at that level
		{
		DInfo("Water level detect !",1,"cTileTools::TerraformSolver");
		Solve.AddItem(0,0);
		continue;
		}
	local money=0;
	local error=false;
	money=cTileTools.TerraformDoAction(maxH, currentHeight, HeightIsLow, true);
	if (money != -1)
			{
			DInfo("Solve found, "+money+" credits need to reach level "+currentHeight,1,"cTileTools::TerraformSolver");
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
DInfo("Solver has search "+terratrys+" time",1,"cTileTools::TerraformSolver");
return Solve;
}

function cTileTools::SeduceTown(townID, needRating)
// Fill a tile with trees
// needRating : rating we must reach
// return true if we reach needRating level with that town
{
local towntiles=cTileTools.GetTilesAroundPlace(AITown.GetLocation(townID));
local curRating=AITown.GetRating(townID, AICompany.COMPANY_SELF);
towntiles.Valuate(AITile.IsWithinTownInfluence,townID);
towntiles.KeepValue(1);
towntiles.Valuate(AITile.IsBuildable);
towntiles.KeepValue(1);
local savetiles=AIList();
savetiles.AddList(towntiles);
local good=true;
local money=AIAccounting();
//towntiles.Valuate(AITile.GetDistanceManhattanToTile,AITown.GetLocation(townID));
//towntiles.Sort(AIList.SORT_BY_VALUE, true);
savetiles.Valuate(AITile.HasTreeOnTile);
savetiles.KeepValue(0);
local town_name=AITown.GetName(townID);
//foreach (tile, dummy in towntiles)	PutSign(tile,"R");
// 1 -> 2 = 293 trees
// 2 -> 3 = 417 trees
DInfo("Town: "+town_name+" rating: "+curRating+" free tiles="+savetiles.Count(),2,"cTileTools::SeduceTown");
//if (curRating < AITown.TOWN_RATING_VERY_POOR && savetiles.Count()< 45)
// 1 -> 4 rate = 
local needclean=0;
if (savetiles.Count() < 95)	needclean=95-savetiles.Count();
if (curRating == 1 && needclean > 0)
	{ // we need clean some area to get space for our trees
	local treeon=AIList();
	treeon.AddList(towntiles);
	treeon.Valuate(AITile.HasTreeOnTile);
	treeon.KeepValue(1);
	treeon.KeepTop(needclean);
	savetiles.AddList(treeon); // this way we add tiles that have trees on it, but keep tiles without tiles too
	savetiles.KeepTop(95);
	foreach (tile, dummy in savetiles) AITile.DemolishTile(tile); // if we lack money to remove the tree we will fail anyway
	}
local totalTree=0;
local totalspent=0;
local tiledone=0;
foreach (tile, dummy in towntiles)
	{
	if (curRating >= needRating || curRating == AITown.TOWN_RATING_GOOD)	break;
	tiledone++;
	do	{
		good=AITile.PlantTree(tile);
		if (good)	{ totalTree++; totalspent+=AITile.GetBuildCost(AITile.BT_BUILD_TREES); }
		INSTANCE.bank.RaiseFundsTo(12000);
		DInfo(town_name+" "+AIError.GetLastErrorString()+" newrate: "+AITown.GetRating(townID, AICompany.COMPANY_SELF)+" baseprice: "+AITile.GetBuildCost(AITile.BT_BUILD_TREES)+" totaltrees: "+totalTree+" money="+totalspent,2,"cTileTools::SeduceTown");
		//AIController.Sleep(1);
		} while (good && (AICompany.GetBankBalance(AICompany.COMPANY_SELF)>10000));
	AIController.Sleep(2);
	curRating=AITown.GetRating(townID, AICompany.COMPANY_SELF);	
	}
local endop="Success !";
if (!good && curRating < needRating)	endop="Failure.";
DInfo(endop+" "+town_name+" Rate now:"+curRating+" Target Rate:"+needRating+" Funds: "+AICompany.GetBankBalance(AICompany.COMPANY_SELF)+" Spend: "+money.GetCosts()+" size: "+towntiles.Count(),1,"cTileTools::SeduceTown");
print("trees: "+totalTree+" tiledone="+tiledone);
return (curRating >= needRating);
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

function cTileTools::IsAreaBuildable(area, owner)
// return true if owner might build in the area
{
local owncheck=AIList();
owncheck.AddList(area);
owncheck.Valuate(cTileTools.CanUseTile, owner);
owncheck.KeepValue(0); // keep only non useable tiles
if (!owncheck.IsEmpty())	return false;
return cTileTools.IsAreaRemovable(area);
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

