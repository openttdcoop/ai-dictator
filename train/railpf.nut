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
		/* As estimate we multiply the lowest possible cost for a single tile with
		*  with the minimum number of tiles we need to traverse. */
		foreach (tile in goal_tiles) {
			local dx = abs(AIMap.GetTileX(cur_tile) - AIMap.GetTileX(tile[0]));
			local dy = abs(AIMap.GetTileY(cur_tile) - AIMap.GetTileY(tile[0]));
			min_cost = min(min_cost, min(dx, dy) * self._cost_diagonal_tile * 2 + (max(dx, dy) - min(dx, dy)) * self._cost_tile);
		}
		return min_cost * 1.1;
	}
