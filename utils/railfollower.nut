/* -*- Mode: C++; tab-width: 6 -*- */ 
/*
 * This file is part of AdmiralAI.
 *
 * AdmiralAI is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * AdmiralAI is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with AdmiralAI.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2008-2010 Thijs Marinussen
 */

/** @file railfollower.nut A custom rail track finder. */

/**
 * A Rail pathfinder for existing rails.
 * Original file from AdmiralAI modified to met my needs
 */
class RailFollower extends RailPathFinder
{
static	RailList = AIList();		// list of rails, item=tile index, value=owner route or -1 if none own it
}

function RailFollower::_Neighbours(path, cur_node, self)
{
	/* self._max_cost is the maximum path cost, if we go over it, the path isn't valid. */
	if (path.GetCost() >= self._max_cost) return [];

	local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
	local tiles = [];
	if (AITile.HasTransportType(cur_node, AITile.TRANSPORT_RAIL)) {
		/* Only use track we own. */
		if (!AICompany.IsMine(AITile.GetOwner(cur_node))) return [];

		/* If the existing track type is incompatible this tile is unusable. */
		//if (!AIRail.TrainHasPowerOnRail(AIRail.GetRailType(cur_node), self._new_type)) return [];

		if (AIRail.GetSignalType(path.GetParent().GetTile(), path.GetTile()) == AIRail.SIGNALTYPE_PBS) return [];
		if (AITile.IsStationTile(cur_node)) return [];

		/* Check if the current tile is part of a bridge or tunnel. */
		if (AIBridge.IsBridgeTile(cur_node) || AITunnel.IsTunnelTile(cur_node)) {
			if ((AIBridge.IsBridgeTile(cur_node) && AIBridge.GetOtherBridgeEnd(cur_node) == path.GetParent().GetTile()) ||
			  (AITunnel.IsTunnelTile(cur_node) && AITunnel.GetOtherTunnelEnd(cur_node) == path.GetParent().GetTile())) {
				local other_end = path.GetParent().GetTile();
				local next_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
				tiles.push([next_tile, self._GetDirection(null, cur_node, next_tile, true)]);
			} else if (AIBridge.IsBridgeTile(cur_node)) {
				local other_end = AIBridge.GetOtherBridgeEnd(cur_node);;
				local prev_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
				if (prev_tile == path.GetParent().GetTile()) tiles.push([AIBridge.GetOtherBridgeEnd(cur_node), self._GetDirection(null, path.GetParent().GetTile(), cur_node, true)]);
			} else {
				local other_end = AITunnel.GetOtherTunnelEnd(cur_node);
				local prev_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
				if (prev_tile == path.GetParent().GetTile()) tiles.push([AITunnel.GetOtherTunnelEnd(cur_node), self._GetDirection(null, path.GetParent().GetTile(), cur_node, true)]);
			}
		} else {
			foreach (offset in offsets) {
				local next_tile = cur_node + offset;
				/* Don't turn back */
				if (next_tile == path.GetParent().GetTile()) continue;
				/* Disallow 90 degree turns */
				if (path.GetParent().GetParent() != null &&
					next_tile - cur_node == path.GetParent().GetParent().GetTile() - path.GetParent().GetTile()) continue;
				if (AIRail.AreTilesConnected(path.GetParent().GetTile(), cur_node, next_tile)) {
					tiles.push([next_tile, self._GetDirection(path.GetParent().GetTile(), cur_node, next_tile, false)]);
				}
			}
		}
	}
	return tiles;
}

function RailFollower::SetRailOwner(railsource, routeUID)
// Set a rail own by a route
{
	if (RailFollower.RailList.HasItem(railsource))	RailFollower.RailList.SetValue(railsource, routeUID);
								else	RailFollower.RailList.AddItem(railsource, routeUID);
}

function RailFollower::RailRunner(source, walkedtiles=null)
// Follow rail from rail source to find a rail station attach to it
{
local found = -1;
if (walkedtiles == null)	{ walkedtiles=AIList(); }
				else	{ if (!walkedtiles.IsEmpty())	found=walkedtiles.GetValue(walkedtiles.Begin()); }
local valid=false;
local direction=null;
//if (RailFollower.RailList.HasItem(source) && RailFollower.RailList.GetValue(source) != -1)	return -1;
if (AIRail.IsRailStationTile(source))
	{
	local staID=AIStation.GetStationID(source);
print("rail station ! "+AIStation.GetName(staID));
	local staobj=cStation.GetStationObject(staID);
	if (staobj != null && !staobj.owner.IsEmpty())
		{
		local r_own=staobj.owner.Begin();
//		print("station "+r_own);
		foreach (tiles, owner in walkedtiles)	{ RailFollower.SetRailOwner(tiles, r_own); walkedtiles.SetValue(tiles, r_own); }
		}
	}
local directions=[AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)];
foreach (voisin in directions)
	{
	direction=source+voisin;
	if (cBridge.IsBridgeTile(source) || AITunnel.IsTunnelTile(source))
		{
		local endat=null;
		endat=cBridge.IsBridgeTile(source) ? AIBridge.GetOtherBridgeEnd(source) : AITunnel.GetOtherTunnelEnd(source);
		// i will jump at bridge/tunnel exit, check tiles around it to see if we are connect to someone (guessTile)
		// if we are connect to someone, i reset "source" to be "someone" and continue
		local guessTile=null;	
		foreach (where in directions)
			{
			if (cBuilder.AreRailTilesConnected(endat, endat+where))	{ guessTile=endat+where; }
			}
		if (guessTile != null)
			{
			source=guessTile;
			direction=source+voisin;
			}
		}
	valid=cBuilder.AreRailTilesConnected(source, direction);
	if (walkedtiles.HasItem(direction))	{ valid=false; }
	if (valid) { walkedtiles.AddItem(direction,found); found=RailFollower.RailRunner(direction, walkedtiles); }
	if (valid)	RailFollower.SetRailOwner(direction, found);
	//if (INSTANCE.debug) DInfo("Valid="+valid+" dir="+direction,2);
//	if (found == -1 && valid)	found=RailFollower.RailRunner(direction, walkedtiles);
	if (valid && INSTANCE.debug)	PutSign(direction,"X");
	//if (found != -1) return found;
	}
return found;
}

function RailFollower::FindRailOwner(tilelist)
// find route owning rails
{
local clearList=AIList();
clearList.AddList(RailFollower.RailList);
clearList.RemoveValue(-1); // Remove rail with no owner
tilelist.RemoveList(clearList); // So we in removed all rails we know the owner
tilelist.Valuate(AIRail.IsRailTile);
tilelist.KeepValue(1); // keep only rails
if (tilelist.IsEmpty())	{ DInfo("All rails are known or no rails.",1,"RailFollower.FindRailOwner"); return; }
local runnercount=0;
local tiletocheck=tilelist.Count();
ClearSigns();
//foreach (tiles, dummy in tilelist)	PutSign(tiles, ".");
print("tile to check : "+tiletocheck);
foreach (tiles, dummy in tilelist)
	{
	ClearSigns();
	//foreach (tiles, owner in RailFollower.RailList)	PutSign(tiles, "+");
	//if (RailFollower.RailList.HasItem(tiles) && RailFollower.RailList.GetValue(tiles) != -1)	{ print("known tile"); continue; }
	//PutSign(tiles,"o");
//foreach (tiles, owner in RailFollower.RailList)	print("dumping RailList ="+tiles+" own="+owner);

	print("following tiles="+tiles+" res="+RailFollower.RailRunner(tiles)+" runnercount="+runnercount+" RailList.Count="+RailFollower.RailList.Count()+" tilelist.Count="+tilelist.Count()); runnercount++;
	tilelist.RemoveList(RailFollower.RailList);
	}
print("SUMUP tile to check : "+tiletocheck+" runnercount="+runnercount);
ClearSigns();
print("Cleaning dead line...");
local deadrails=AIList();
deadrails.AddList(RailFollower.RailList);
deadrails.KeepValue(-1);
print("dead rails : "+deadrails.Count());
cBuilder.RailCleaner(deadrails);
print("SUMUP");
ClearSigns();
}
