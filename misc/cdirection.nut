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

class cDirection extends cClass
{
		constructor()
			{
			this.ClassName	= "cDirection";
			}
}

function cDirection::DirectionToString(dir1)
// return a string with direction
{
	if (dir1 == DIR_SE)	return "DIR_SE("+DIR_SE+")";
	if (dir1 == DIR_NW)	return "DIR_NW("+DIR_NW+")";
	if (dir1 == DIR_NE)	return "DIR_NE("+DIR_NE+")";
	if (dir1 == DIR_SW)	return "DIR_SW("+DIR_SW+")";
	return "(invalid direction:"+dir1+")";
}

function cDirection::GetDirection(tilefrom, tileto)
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

function cDirection::GetPosRelativeFromDirection(dirswitch, direction)
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
		default:	return -1;
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

function cDirection::GetLeftRelativeFromDirection(direction)
	{
	return cDirection.GetPosRelativeFromDirection(0,direction);
	}

function cDirection::GetRightRelativeFromDirection(direction)
	{
	return cDirection.GetPosRelativeFromDirection(1,direction);
	}

function cDirection::GetForwardRelativeFromDirection(direction)
	{
	return cDirection.GetPosRelativeFromDirection(2,direction);
	}

function cDirection::GetBackwardRelativeFromDirection(direction)
	{
	return cDirection.GetPosRelativeFromDirection(3,direction);
	}

function cDirection::GetDistanceChebyshevToTile(tilefrom, tileto)
    {
    local x1 = AIMap.GetTileX(tilefrom);
    local x2 = AIMap.GetTileX(tileto);
    local y1 = AIMap.GetTileY(tilefrom);
    local y2 = AIMap.GetTileY(tileto);
    return max(abs(x2 - x1), abs(y2 - y1));
    }

function cDirection::GoingInTown(tile, direction)
// return true if we are going inside a town, making a nightmare to build there (and rating hell)
{
	local t = AITile.GetClosestTown(tile);
    local forward = cDirection.GetForwardRelativeFromDirection(direction);
	local end = tile + (4 * forward);
	local sdist = AITown.GetDistanceManhattanToTile(t, tile);
	local edist = AITown.GetDistanceManhattanToTile(t, end);
	if (sdist < 20 && sdist > edist) // we are going in this town
				{
				print("going near "+AITown.GetName(t));
				local w = cTileTools.GetTilesAroundTown(t);
				w.Valuate(AITile.GetCargoProduction, cCargo.GetPassengerCargo(), 1, 1, 1);
				foreach (tiles, prod in w)	if (prod > 0 || AIRoad.IsRoadTile(tiles))	w.SetValue(tiles, -1);
				w.KeepValue(-1); // this should keep roads & houses
				local c = AIList();
				for (local i = 0; i < 4; i++)	c.AddItem(tile + (i * forward), 0);
				c.RemoveList(w);
				if (c.Count() < 2)	{ DInfo("We are going in "+AITown.GetName(t)+" count="+c.Count(), 2); return true; }
				}
	return false;
}

function cDirection::GetDirectionFromStationDirection(tilefrom, tileto, station_direction)
// get the direction we will go toward depending on the station direction
{
	local aim_dir = cDirection.GetDirection(tilefrom, tileto);
	//print("tilefrom: X="+AIMap.GetTileX(tilefrom)+" y="+AIMap.GetTileY(tilefrom));
	//print("tileto: X="+AIMap.GetTileX(tileto)+" y="+AIMap.GetTileY(tileto));
	if (station_direction == AIRail.RAILTRACK_NE_SW)
			{
			if (aim_dir == DIR_NE || aim_dir == DIR_SW)	return aim_dir;
            if (AIMap.GetTileX(tilefrom) > AIMap.GetTileX(tileto))	return DIR_NE;
															else	return DIR_SW;
			}
	else	{
			if (aim_dir == DIR_NW || aim_dir == DIR_SE)	return aim_dir;
            if (AIMap.GetTileY(tilefrom) > AIMap.GetTileY(tileto))	return DIR_NW;
															else	return DIR_SE;
			}
}
