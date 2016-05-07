/* -*- Mode: C++; tab-width: 6 -*- */
/**
 *    This file is part of DictatorAI
 *    (c) krinn@chez.com
 *
 *    It's free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 2 of the License, or
 *    any later version.
 *
 *    You should have received a copy of the GNU General Public License
 *    with it.  If not, see <http://www.gnu.org/licenses/>.
 *
**/

class MyRailPF extends RailPathFinder
	{
		_cost_level_crossing = null;
	}

MyRailPF.Cost._set <- function(idx, val)
	{
	if (this._main._running) { throw ("You are not allowed to change parameters of a running pathfinder."); }
	switch (idx)
			{
			case "max_cost":          this._main._max_cost = val; break;
			case "tile":              this._main._cost_tile = val; break;
			case "diagonal_tile":     this._main._cost_diagonal_tile = val; break;
			case "turn":              this._main._cost_turn = val; break;
			case "slope":             this._main._cost_slope = val; break;
			case "bridge_per_tile":   this._main._cost_bridge_per_tile = val; break;
			case "tunnel_per_tile":   this._main._cost_tunnel_per_tile = val; break;
			case "coast":             this._main._cost_coast = val; break;
			case "max_bridge_length": this._main._max_bridge_length = val; break;
			case "max_tunnel_length": this._main._max_tunnel_length = val; break;
			default: throw ("the index '" + idx + "' does not exist");
			}
	return val;
	}

MyRailPF.Cost._get <- function(idx)
	{
	switch (idx)
			{
			case "max_cost":          return this._main._max_cost;
			case "tile":              return this._main._cost_tile;
			case "diagonal_tile":     return this._main._cost_diagonal_tile;
			case "turn":              return this._main._cost_turn;
			case "slope":             return this._main._cost_slope;
			case "bridge_per_tile":   return this._main._cost_bridge_per_tile;
			case "tunnel_per_tile":   return this._main._cost_tunnel_per_tile;
			case "coast":             return this._main._cost_coast;
			case "max_bridge_length": return this._main._max_bridge_length;
			case "max_tunnel_length": return this._main._max_tunnel_length;
			default: throw ("the index '" + idx + "' does not exist");
			}
	}

function MyRailPF::_Estimate(cur_tile, cur_direction, goal_tiles, self)
	{
		local min_cost = self._max_cost;
		foreach (tile in goal_tiles)
			{
			local dx = abs(AIMap.GetTileX(cur_tile) - AIMap.GetTileX(tile[0]));
			local dy = abs(AIMap.GetTileY(cur_tile) - AIMap.GetTileY(tile[0]));
			min_cost = min(min_cost, (max(dx, dy) * self._cost_tile * 2)); // Chebychev with diagonals move.
            }
		return min_cost;
	}

function MyRailPF::_CheckForceBridge(cur_node, last_node, length)
{
	local k= AIExecMode();
	for (local i = 0; i < length; i++)
		{
		local target = cur_node + i * (cur_node - last_node);
		if (!AITile.IsBuildable(target))	return true;
		}
	return false;
}

function MyRailPF::_GetTunnelsBridges(last_node, cur_node, bridge_dir)
{
// 1 NE
// 2 SW
// 8 SE
// 4 NW
	local slope = AITile.GetSlope(cur_node);
	local buildable = AITile.IsBuildable(cur_node + (cur_node - last_node));
	if (slope == AITile.SLOPE_FLAT && buildable) return [];
	//if (slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SE && slope != AITile.SLOPE_NE && slope != AITile.SLOPE_FLAT) return [];
	local tiles = [];
	local good_s_slope = AIList();
	local good_e_slope = AIList();
	good_s_slope.AddItem(AITile.SLOPE_FLAT, 0);
	good_e_slope.AddItem(AITile.SLOPE_FLAT, 0);
	switch (bridge_dir)
		{
		case	1: // NE
			good_s_slope.AddItem(AITile.SLOPE_SW, 0);
			good_s_slope.AddItem(AITile.SLOPE_S, 0);
			good_s_slope.AddItem(AITile.SLOPE_W, 0);
			good_e_slope.AddItem(AITile.SLOPE_NE, 0);
			good_e_slope.AddItem(AITile.SLOPE_N, 0);
			good_e_slope.AddItem(AITile.SLOPE_E, 0);
			break;
		case	2: // SW
			good_s_slope.AddItem(AITile.SLOPE_NE, 0);
			good_s_slope.AddItem(AITile.SLOPE_N, 0);
			good_s_slope.AddItem(AITile.SLOPE_E, 0);
			good_e_slope.AddItem(AITile.SLOPE_SW, 0);
			good_e_slope.AddItem(AITile.SLOPE_S, 0);
			good_e_slope.AddItem(AITile.SLOPE_W, 0);
			break;
		case	4: // NW
			good_s_slope.AddItem(AITile.SLOPE_SE, 0);
			good_s_slope.AddItem(AITile.SLOPE_S, 0);
			good_s_slope.AddItem(AITile.SLOPE_E, 0);
			good_e_slope.AddItem(AITile.SLOPE_NW, 0);
			good_e_slope.AddItem(AITile.SLOPE_N, 0);
			good_e_slope.AddItem(AITile.SLOPE_W, 0);
			break;
		case	8: // SE
			good_s_slope.AddItem(AITile.SLOPE_NW, 0);
			good_s_slope.AddItem(AITile.SLOPE_N, 0);
			good_s_slope.AddItem(AITile.SLOPE_W, 0);
			good_e_slope.AddItem(AITile.SLOPE_SE, 0);
			good_e_slope.AddItem(AITile.SLOPE_S, 0);
			good_e_slope.AddItem(AITile.SLOPE_E, 0);
			break;
		default: return [];
		}
	if (!good_s_slope.HasItem(slope))	return [];
	local bridges = AIList();
	for (local i = 2; i < this._max_bridge_length; i++)
		{
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = cur_node + i * (cur_node - last_node);
		// only allow some slope type as target
		local t_slope = AITile.GetSlope(target);
		if (!good_e_slope.HasItem(t_slope))	continue;

		if (!bridge_list.IsEmpty() && AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridge_list.Begin(), cur_node, target))
			{
			local diff_height = 0;
			if (abs(AITile.GetMinHeight(cur_node) - AITile.GetMinHeight(target)) != 0)	diff_height = 1;
			if (diff_height == 0 && abs(AITile.GetMaxHeight(cur_node) - AITile.GetMaxHeight(target)) != 0)	diff_height = 1;
			//local diff_height = abs(AITile.GetMinHeight(cur_node) - AITile.GetMinHeight(target));
			if (MyRailPF._CheckForceBridge(cur_node, last_node, i))
					{
					// if we have no gain from height but have no bridge or a not vital bridge is set, we store this one
					if (diff_height == 0)
						{
						if (bridges.IsEmpty() || bridges.GetValue(bridges.Begin()) == 0)
							{
							bridges.Clear();
							bridges.AddItem(target, 1);
							continue;
							}
						if (slope == AITile.SLOPE_FLAT)	continue; // if no diff and one is FLAT, then both are flat and it's not nice
						}
					// if we have a gain from height difference or because one side is not flat, it's a better one
					bridges.AddItem(target, 1);
					break;
					}
				else	{ // we're not force to build one
					if (AITile.GetSlope(target) == AITile.SLOPE_FLAT || slope == AITile.SLOPE_FLAT)	continue; // we don't need it, and we have 0 gain from height ; useless
					if (bridges.IsEmpty())	{ bridges.AddItem(target, 0); continue; }
					if (bridges.GetValue(bridges.Begin()) != 0)	continue;
					bridges.AddItem(target, 0);
					break; // end searching, as soon as
					}
			}
		}
	if (!bridges.IsEmpty())
			foreach (bt, bf in bridges)
			{
			tiles.push([bt, bridge_dir]);
			}
//	if (!bridges.IsEmpty())	tiles.push([bridges.Begin(), bridge_dir]);

	if (slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SE && slope != AITile.SLOPE_NE) return tiles;
	local other_tunnel_end = AITunnel.GetOtherTunnelEnd(cur_node);
	if (!AIMap.IsValidTile(other_tunnel_end)) return tiles;

	local tunnel_length = AIMap.DistanceManhattan(cur_node, other_tunnel_end);
	local prev_tile = cur_node + (cur_node - other_tunnel_end) / tunnel_length;
	if (AITunnel.GetOtherTunnelEnd(other_tunnel_end) == cur_node && tunnel_length >= 2 &&
			prev_tile == last_node && tunnel_length < _max_tunnel_length && AITunnel.BuildTunnel(AIVehicle.VT_RAIL, cur_node)) {
		tiles.push([other_tunnel_end, bridge_dir]);
	}
	return tiles;
}
