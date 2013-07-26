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

function RailFollower::FindRouteRails(source, target, stationID)
{
	local solve = cBuilder.RoadRunnerHelper(source, target, AIVehicle.VT_RAIL);
	cDebug.ClearSigns();
	cDebug.showLogic(solve);
	return solve;
}

function RailFollower::FindRailOwner()
// find route owning rails
{
	cRoute.RouteDamage.Valuate(AIRail.IsRailTile);
	cRoute.RouteDamage.KeepValue(1);
	foreach (tile, value in cRoute.RouteDamage)	cRoute.RouteDamage.SetValue(tile, -1);
	local rail_routes = AIGroupList();
	rail_routes.Valuate(AIGroup.GetVehicleType);
	rail_routes.KeepValue(AIVehicle.VT_RAIL);
	local uid_list = [];
	foreach (grp, value in rail_routes)	if (cRoute.GroupIndexer.HasItem(grp))	uid_list.push(cRoute.GroupIndexer.GetValue(grp));
	foreach (uid in uid_list)
		{
		local road = cRoute.Load(uid);
		if (!road)	continue;
		// first re-assign trains state to each station (taker, droppper, using entry/exit)
		local train_list = AIVehicleList_Group(road.GroupID);	
		foreach (trains, _ in train_list)
			{
			road.SourceStation.StationAddTrain(true, road.Source_RailEntry);
			road.TargetStation.StationAddTrain(false, road.Target_RailEntry);
			}
		DInfo("Finding rails for route "+road.Name);
		if (!road.Primary_RailLink)	{ DInfo("CheckRouteStationStatus mark "+road.UID+" undoable",1); road.RouteIsNotDoable(); continue; }
		local stationID = road.SourceStation.s_ID;
		local start, end = null;
		if (road.Source_RailEntry)	start = road.SourceStation.s_EntrySide[TrainSide.IN_LINK];
						else	start = road.SourceStation.s_ExitSide[TrainSide.IN_LINK];
		if (road.Target_RailEntry)	end = road.TargetStation.s_EntrySide[TrainSide.OUT_LINK];
						else	end = road.TargetStation.s_ExitSide[TrainSide.OUT_LINK];
		local bad = false;
		local station_tiles = RailFollower.FindRouteRails(start, end, road.SourceStation.s_ID);
		local more_tiles;
		bad = (station_tiles.IsEmpty());
		if (!bad)	{
				more_tiles = RailFollower.FindRouteRails(road.SourceStation.s_Location, end, road.SourceStation.s_ID);
				bad = (more_tiles.IsEmpty());
				}
		station_tiles.AddList(more_tiles);
		if (!bad)	{
				more_tiles = RailFollower.FindRouteRails(road.TargetStation.s_Location, start, road.TargetStation.s_ID);
				bad = (more_tiles.IsEmpty());
				}
		station_tiles.AddList(more_tiles);
		foreach (tiles, _ in station_tiles)	{
								cStationRail.RailStationClaimTile(tiles, road.Source_RailEntry, road.SourceStation.s_ID);
								cRoute.RouteDamage.RemoveItem(tiles);
								}
		if (bad)	{
				DInfo("CheckRouteStationStatus mark "+road.UID+" undoable",1);
				road.RouteIsNotDoable();
				}
		}
	DInfo("Unknown rails remaining : "+cRoute.RouteDamage.Count());
	cRoute.RouteDamage.Clear();
}
