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

class MyRoadPF extends RoadPathFinder {
	_cost_level_crossing = null;
}
function MyRoadPF::_Cost(path, new_tile, new_direction, self)
{
	local cost = ::RoadPathFinder._Cost(path, new_tile, new_direction, self);
	if (AITile.HasTransportType(new_tile, AITile.TRANSPORT_RAIL)) cost += self._cost_level_crossing;
	return cost;
}

function MyRoadPF::_GetTunnelsBridges(last_node, cur_node, bridge_dir)
{
	local slope = AITile.GetSlope(cur_node);
	if (slope == AITile.SLOPE_FLAT && AITile.IsBuildable(cur_node + (cur_node - last_node))) return [];
	local tiles = [];
	for (local i = 2; i < this._max_bridge_length; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = cur_node + i * (cur_node - last_node);
		if (!bridge_list.IsEmpty() && AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), cur_node, target)) {
			tiles.push([target, bridge_dir]);
		}
	}

	if (slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SE && slope != AITile.SLOPE_NE) return tiles;
	local other_tunnel_end = AITunnel.GetOtherTunnelEnd(cur_node);
	if (!AIMap.IsValidTile(other_tunnel_end)) return tiles;

	local tunnel_length = AIMap.DistanceManhattan(cur_node, other_tunnel_end);
	local prev_tile = cur_node + (cur_node - other_tunnel_end) / tunnel_length;
	if (AITunnel.GetOtherTunnelEnd(other_tunnel_end) == cur_node && tunnel_length >= 2 &&
			prev_tile == last_node && tunnel_length < _max_tunnel_length && AITunnel.BuildTunnel(AIVehicle.VT_ROAD, cur_node)) {
		tiles.push([other_tunnel_end, bridge_dir]);
	}
	return tiles;
}

class MyRailPF extends RailPathFinder {
	_cost_level_crossing = null;
}
function MyRailPF::_Cost(path, new_tile, new_direction, self)
{
	local cost = ::RailPathFinder._Cost(path, new_tile, new_direction, self);
	if (AITile.HasTransportType(new_tile, AITile.TRANSPORT_ROAD)) cost += self._cost_level_crossing;
	return cost;
}

function cBuilder::CanBuildRoadStation(tile, direction)
{
if (!AITile.IsBuildable(tile)) return false;
local offsta = null;
local offdep = null;
local middle = null;
local middleout = null;
switch (direction)
	{
	case DIR_NE:
		offdep = AIMap.GetTileIndex(0,-1);  
		offsta = AIMap.GetTileIndex(-1,0);
		middle = AITile.CORNER_W;
		middleout = AITile.CORNER_N;
	break;
	case DIR_NW:
		offdep = AIMap.GetTileIndex(1,0);
		offsta = AIMap.GetTileIndex(0,-1);
		middle = AITile.CORNER_S;
		middleout = AITile.CORNER_W;
	break;
	case DIR_SE:
		offdep = AIMap.GetTileIndex(-1,0);
		offsta = AIMap.GetTileIndex(0,1);
		middle = AITile.CORNER_N;
		middleout = AITile.CORNER_E;
	break;
	case DIR_SW:
		offdep = AIMap.GetTileIndex(0,1);
		offsta = AIMap.GetTileIndex(1,0);
		middle = AITile.CORNER_E;
		middleout = AITile.CORNER_S;
	break;
	}
statile = tile; deptile = tile + offdep;
stafront = tile + offsta; depfront = tile + offsta + offdep;
if (!AITile.IsBuildable(deptile)) {return false;}
if (!AITile.IsBuildable(stafront) && !AIRoad.IsRoadTile(stafront)) {return false;}
if (!AITile.IsBuildable(depfront) && !AIRoad.IsRoadTile(depfront)) {return false;}
local height = AITile.GetMaxHeight(statile);
local tiles = AITileList();
tiles.AddTile(statile);
tiles.AddTile(stafront);
tiles.AddTile(deptile);
tiles.AddTile(depfront);
if (!AIGameSettings.GetValue("construction.build_on_slopes"))
	{
	foreach (idx, dummy in tiles)
		{
		if (AITile.GetSlope(idx) != AITile.SLOPE_FLAT) return false;
		}
	} 
else	{
	if ((AITile.GetCornerHeight(stafront, middle) != height) && (AITile.GetCornerHeight(stafront, middleout) != height)) return false;
	}
	foreach (idx, dummy in tiles)
		{
		if (AITile.GetMaxHeight(idx) != height) return false;
		if (AITile.IsSteepSlope(AITile.GetSlope(idx))) return false;
		}
local test = AITestMode();
if (!AIRoad.BuildRoad(stafront, statile))
	{
	if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) return false;
	}
if (!AIRoad.BuildRoad(depfront, deptile))
	{
	if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) return false;
	}
if (!AIRoad.BuildRoad(stafront, depfront))
	{
	if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) return false;
	}
if (!AIRoad.BuildRoadStation(statile, stafront, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_NEW)) return false;
if (!AIRoad.BuildRoadDepot(deptile, depfront)) return false;
test = null;
return true;
}

function cBuilder::BuildAndStickToRoad(tile, stationtype)
/**
* Find a road near tile and build a road depot or station connected to that road
*
* @param tile tile where to put the structure
* @param stationtype if AIRoad.ROADVEHTYPE_BUS+100000 build a depot, else build a station of stationtype type
* @return -1 on error, tile position on success, CriticalError is set 
*/
{
local directions=[AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)]; 

// ok we know we are close to a road, let's find where the road is
local direction=-1;
local tooclose=false;

foreach (voisin in directions)
	{
	if (AIRoad.IsRoadTile(tile+voisin)) { direction=tile+voisin; break; }
	}
if (direction == -1)	{ DWarn("Can't find a road to stick our structure ???",2); return -1; }

if (stationtype != (AIRoad.ROADVEHTYPE_BUS+100000)) // not a depot = truck or bus station need
	{
	foreach (voisin in directions) // find if the place isn't too close from another station
		{
		tooclose=AITile.IsStationTile(tile+voisin);
		if (!tooclose)	tooclose=AITile.IsStationTile(tile+voisin+voisin);
		if (tooclose)
			{
			DError("Road station would be too close from another station",2);
			root.builder.CriticalError=true; // force a critical error
			return -1;
			}
		}
	}
// now build the structure, function is in stationbuilder.nut
return root.builder.BuildRoadStationOrDepotAtTile(tile, direction, stationtype, true);
}

function cBuilder::BuildRoadDepotAtTile(tile)
// Try to build a road depot at tile and nearer
{
local reusedepot=cTileTools.GetTilesAroundPlace(tile);
reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
reusedepot.Sort(AIList.SORT_BY_VALUE, true);
reusedepot.RemoveAboveValue(10);
reusedepot.Valuate(AITile.IsWaterTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AITile.IsStationTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AIRail.IsRailTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AIRail.IsRailDepotTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AIRoad.IsRoadDepotTile);
reusedepot.KeepValue(0);
reusedepot.Valuate(AITile.GetSlope);
reusedepot.KeepValue(AITile.SLOPE_FLAT); // only flat tile filtering
reusedepot.Valuate(AIRoad.GetNeighbourRoadCount); // now only keep places stick to a road
reusedepot.KeepAboveValue(0);
reusedepot.Valuate(AIRoad.IsRoadTile);
reusedepot.KeepValue(0);
reusedepot=root.builder.FilterBlacklistTiles(reusedepot);
reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
reusedepot.Sort(AIList.SORT_BY_VALUE, true);
local newpos=-1;
foreach (tile, dummy in reusedepot)
	{
	newpos=root.builder.BuildAndStickToRoad(tile, AIRoad.ROADVEHTYPE_BUS+100000);
	if (newpos != -1)	return newpos;
	}
return -1;
}

function cBuilder::BuildRoadStation(road_index,start)
/**
* Build a road station for a route
*
* @param road_index index of the road to build the station
* @param start true to build at source, false at destination
* @return true or false
*/
{
root.bank.RaiseFundsBigTime();
AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
root.builder.currentRoadType=AIRoad.GetCurrentRoadType();
local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
local dir, tilelist, checklist, otherplace, istown, isneartown=null;
local road = root.chemin.RListGetItem(road_index);
if (start)	{
		dir = root.builder.GetDirection(road.ROUTE.src_place, road.ROUTE.dst_place);
		if (road.ROUTE.src_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(road.ROUTE.src_id);
			checklist= cTileTools.GetTilesAroundTown(road.ROUTE.src_id);
			isneartown=true; istown=true;
			}
		else	{
			tilelist = AITileList_IndustryProducing(road.ROUTE.src_id, rad);
			checklist = AITileList_IndustryProducing(road.ROUTE.src_id, rad);
			isneartown=true; // fake it's a town, it produce, it might be within a town (like a bank)
			istown=false;	 
			}
		otherplace=road.ROUTE.dst_place;
		}
	else	{
		dir = root.builder.GetDirection(road.ROUTE.dst_place, road.ROUTE.src_place);
		if (road.ROUTE.dst_istown)
			{
			tilelist = cTileTools.GetTilesAroundTown(road.ROUTE.dst_id);
			checklist= cTileTools.GetTilesAroundTown(road.ROUTE.dst_id);
			tilelist.Valuate(AITile.GetCargoAcceptance, road.ROUTE.cargo_id, 1, 1, rad);
			tilelist.KeepAboveValue(8);
			checklist.Valuate(AITile.GetCargoAcceptance, road.ROUTE.cargo_id, 1, 1, rad);
			checklist.KeepAboveValue(8);
			isneartown=true; istown=true;
			}
		else	{
			tilelist = AITileList_IndustryAccepting(road.ROUTE.dst_id, rad);
			checklist = AITileList_IndustryAccepting(road.ROUTE.dst_id, rad);
			isneartown=true; istown=false;
			}
		otherplace=road.ROUTE.src_place;
		}
// let's see if we can stick to a road
tilelist.Sort(AIList.SORT_BY_VALUE, false); // highest values first
checklist.Valuate(AIRoad.IsRoadTile);
checklist.KeepValue(1);
root.builder.FilterBlacklistTiles(checklist);
if (checklist.IsEmpty())
	{
	DInfo("Cannot stick our station to a road, building classic",2);
	isneartown=false;
	}
else	{
	DInfo("Sticking station & depot to the road",2);
	}
checklist.AddList(tilelist); // re-put tiles in it in case we fail building later
local stationtype = null;
if (AICargo.GetTownEffect(road.ROUTE.cargo_id) == AICargo.TE_PASSENGERS)
		{ stationtype = AIRoad.ROADVEHTYPE_BUS; }
	else 	{ stationtype = AIRoad.ROADVEHTYPE_TRUCK; }

if (isneartown)	{ // first, removing most of the unbuildable cases
		tilelist.Valuate(AITile.IsWaterTile);
		tilelist.KeepValue(0);
		tilelist.Valuate(AITile.IsStationTile);
		tilelist.KeepValue(0);
		tilelist.Valuate(AIRail.IsRailTile);
		tilelist.KeepValue(0);
		tilelist.Valuate(AIRail.IsRailDepotTile);
		tilelist.KeepValue(0);
		tilelist.Valuate(AIRoad.IsRoadDepotTile);
		tilelist.KeepValue(0);
		tilelist.Valuate(AITile.GetSlope);
		tilelist.KeepValue(AITile.SLOPE_FLAT); // only flat tile filtering
		tilelist.Valuate(AIRoad.GetNeighbourRoadCount); // now only keep places stick to a road
		tilelist.KeepAboveValue(0);
		tilelist.Valuate(AIRoad.IsRoadTile);
		tilelist.KeepValue(0);
		if (!istown && !start)	// not a town, and start = only industry as destination
			{
			tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
			tilelist.Sort(AIList.SORT_BY_VALUE,true); // little distance first
			}
		else	{ // town or (industry at start)
			if (!istown) tilelist.Valuate(AITile.GetCargoProduction, road.ROUTE.cargo_id, 1, 1, rad);
				else tilelist.Valuate(AITile.GetCargoAcceptance, road.ROUTE.cargo_id, 1, 1, rad);
			tilelist.Sort(AIList.SORT_BY_VALUE, false);
			}
		//showLogic(tilelist);
		}
	else	{
		if (!istown)
			{
			tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
			}
		tilelist.Sort(AIList.SORT_BY_VALUE,true);
		}
DInfo("Tilelist set to "+tilelist.Count(),2);
local success = false;
local depotbuild=false;
local stationbuild=false;
local newStation=cStation();

deptile=-1; statile=-1;
if (isneartown)
	{
	foreach (tile, dummy in tilelist)
		{
		statile=root.builder.BuildAndStickToRoad(tile, stationtype);
		if (statile >= 0)
			{ stationbuild = true; break; }
		}
	foreach (tile, dummy in tilelist)
		{
		if (tile == statile) continue; // don't build on the same place as our new station
		deptile=root.builder.BuildAndStickToRoad(tile, AIRoad.ROADVEHTYPE_BUS+100000); // depot
		if (deptile >= 0)
			{ depotbuild = true; break; }
		}
	success=(depotbuild && stationbuild);
	if (success) // we have depot + station tile, pathfind to them
		{ root.builder.BuildRoadROAD(AIRoad.GetRoadDepotFrontTile(deptile), AIRoad.GetRoadStationFrontTile(statile));	}
	}
if ((statile==-1 || deptile==-1) && !istown && isneartown)
	{ // We fail to build the station, but it's because we force build station close to roads and there is no roads
	if (statile>0)	cTileTools.DemolishTile(statile);
	if (deptile>0)	cTileTools.DemolishTile(deptile);
	isneartown=false;
	tilelist.AddList(checklist); // restore the list of original tiles
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.KeepAboveValue(0);
	tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
	tilelist.Sort(AIList.SORT_BY_VALUE, true);
	}
if (!isneartown)
	{
	//showLogic(tilelist);
	foreach (tile, dummy in tilelist)
		{
		if (cBuilder.CanBuildRoadStation(tile, dir))
			{
			success = true;
			break;
			}
		else	continue;
		}
	}
if (!success) 
	{
	DInfo("Can't find a good place to build the road station !",1);
	root.builder.CriticalError=true;
	return false;
	}
// if we are here all should be fine, we could build now
if (!isneartown)
	{
	AIRoad.BuildRoad(stafront, statile);
	AIRoad.BuildRoad(depfront, deptile);
	AIRoad.BuildRoad(stafront, depfront);
	if (!AIRoad.BuildRoadStation(statile, stafront, stationtype, AIStation.STATION_NEW))
		{
		AILog.Error("Station could not be built: " + AIError.GetLastErrorString());
		return false;
		}
	if (!AIRoad.BuildRoadDepot(deptile, depfront))
		{
		AILog.Error("Depot could not be built: " + AIError.GetLastErrorString());
		cTileTools.DemolishTile(statile);
		return false;
		}
	}
newStation.STATION.station_id=AIStation.GetStationID(statile);
newStation.STATION.type=1; // single station
if (stationtype == AIRoad.ROADVEHTYPE_TRUCK)	newStation.STATION.railtype=11;
	else					newStation.STATION.railtype=10;
newStation.STATION.e_depot=deptile;
newStation.STATION.e_loc=AIRoad.GetRoadStationFrontTile(statile);
newStation.STATION.direction=root.builder.GetDirection(statile,AIRoad.GetRoadStationFrontTile(statile));
root.chemin.GListAddItem(newStation); // create the station
local lastStation=root.chemin.GListGetSize()-1;
if (start)
	{
	road.ROUTE.src_station = lastStation;
	road.ROUTE.src_entry = true;
	}
 else	{
	road.ROUTE.dst_station = lastStation;
	road.ROUTE.dst_entry = true;
	}
root.chemin.RListUpdateItem(road_index,road);
return true;
}

function cBuilder::PathfindRoadROAD(head1, head2)
// just pathfind the road, but still don't build it
{
local pathfinder = MyRoadPF();
pathfinder._cost_level_crossing = 1000;
pathfinder._cost_coast = 100;
pathfinder._cost_slope = 100;
pathfinder._cost_bridge_per_tile = 100;
pathfinder._cost_tunnel_per_tile = 80;
pathfinder._max_bridge_length = 20;
pathfinder.InitializePath([head1], [head2]);
local savemoney=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
root.bank.SaveMoney(); // thinking long time, don't waste money
DInfo("Road Pathfinding...",1);
local path = false;
local counter=0;
while (path == false && counter < 150)
	{
	path = pathfinder.FindPath(100);
	counter++;
	AIController.Sleep(1);
	}
// restore our money
root.bank.RaiseFundsTo(savemoney);
if (path != null && path != false)
	{
	DInfo("Path found. (" + counter + ")",1);
	return path;
	}
else	{
	ClearSignsALL();
	DInfo("Pathfinding failed.",1);
	root.builder.CriticalError=true;
	return false;
	}
}

function cBuilder::BuildRoadFrontTile(tile, targettile)
{
if (!AIRoad.IsRoadTile(targettile))	cTileTools.DemolishTile(targettile);
AIRoad.BuildRoad(tile, targettile);
return AIRoad.AreRoadTilesConnected(tile, targettile);
}

function cBuilder::CheckRoadHealth(idx)
// we check a route for trouble & try to solve them
// return true if no problems were found
{
local good=true;
local road=root.chemin.RListGetItem(idx);
if (road == -1) return false;
local space="        ";
local correction=false;
local temp=null;
if (road.ROUTE.kind != AIVehicle.VT_ROAD)	return false; // only check road type
local source_station_obj=root.chemin.GListGetItem(road.ROUTE.src_station);
if (source_station_obj == -1) return false;
local target_station_obj=root.chemin.GListGetItem(road.ROUTE.dst_station);
if (target_station_obj == -1) return false;
local src_stationid=source_station_obj.STATION.station_id;
local tgt_stationid=target_station_obj.STATION.station_id;
local src_stationloc=AIStation.GetLocation(src_stationid);
local tgt_stationloc=AIStation.GetLocation(tgt_stationid);
local src_depotid=source_station_obj.STATION.e_depot;
local tgt_depotid=target_station_obj.STATION.e_depot;
local src_station_front=AIRoad.GetRoadStationFrontTile(src_stationloc);
local tgt_station_front=AIRoad.GetRoadStationFrontTile(tgt_stationloc);
local src_entry_loc=0;
local tgt_entry_loc=0;
local facing=0;
local tempfront=0;
local msg="";
local station_tile=null;
local source_tilestation=AIList();
local target_tilestation=AIList();
local randlist
DInfo("Checking route health of #"+idx+" "+road.ROUTE.src_name+"-"+road.ROUTE.dst_name+":"+road.ROUTE.cargo_name,1);
root.NeedDelay(50);
// check stations for trouble
// source station
temp=src_stationid;
correction=false;
local error_repair="Fixed !";
local error_error="Fail to fix it";
if (!AIStation.IsValidStation(temp))	{ DInfo(space+" Source Station is invalid !",1); good=false; }
	else	DInfo(space+"Source station "+AIStation.GetName(temp)+"("+temp+") is valid",1);
if (good)
	{
	station_tile=cTileTools.FindRoadStationTiles(AIStation.GetLocation(temp));
	source_tilestation.AddList(station_tile);
	DInfo(space+space+"Station size : "+station_tile.Count(),1);
	foreach (tile, dummy in station_tile)
		{
		PutSign(tile, "S");
		msg=space+space+"Entry "+tile+" is ";
		tempfront=AIRoad.GetRoadStationFrontTile(tile);
		if (!AIRoad.AreRoadTilesConnected(tile, tempfront))
			{
			msg+="NOT usable. ";
			correction=root.builder.BuildRoadFrontTile(tile, tempfront);
			if (correction)	msg+=error_repair;
				else	{ msg+=error_error; good=false; }
			}
		else	{ msg+="usable"; }
		DInfo(msg,1);
		}
	}
// the depot

msg=space+"Source Depot "+src_depotid+" is ";
if (!AIRoad.IsRoadDepotTile(src_depotid))
	{
	msg+="invalid. ";
	if (src_depotid=root.builder.BuildRoadDepotAtTile(AIStation.GetLocation(src_stationid), AIRoad.ROADVEHTYPE_BUS+100000))	msg+=error_repair;
		else	{ msg+=error_error; good=false; }
	}
else	msg+="valid";
DInfo(msg,1);
local depotfront=AIRoad.GetRoadDepotFrontTile(src_depotid);
if (good)
	{
	msg=space+space+"Depot entry is ";
	if (!AIRoad.AreRoadTilesConnected(src_depotid, depotfront))
		{
		msg+="not usable. ";
		correction=root.builder.BuildRoadFrontTile(src_depotid, depotfront);
		if (correction)	msg+=error_repair;
			else	{ msg+=error_error; good=false; }
		}
	else	msg+="usable";
	DInfo(msg,1);
	}
ClearSignsALL();
// target station
temp=tgt_stationid;
correction=false;
if (temp == src_stationid)	temp=-1;
if (!AIStation.IsValidStation(temp))	{ DInfo(space+" Target Station is invalid ! "+temp+"("+src_stationid+")",1); good=false; }
	else	DInfo(space+"Target station "+AIStation.GetName(temp)+"("+temp+") is valid",1);
if (good)
	{
	local station_tile=cTileTools.FindRoadStationTiles(AIStation.GetLocation(temp));
	target_tilestation.AddList(station_tile);
	DInfo(space+space+"Station size : "+station_tile.Count(),1);
	foreach (tile, dummy in station_tile)
		{
		PutSign(tile, "S");
		msg=space+space+"Entry "+tile+" is ";
		tempfront=AIRoad.GetRoadStationFrontTile(tile);
		if (!AIRoad.AreRoadTilesConnected(tile, tempfront))
			{
			msg+="NOT usable. ";
			correction=root.builder.BuildRoadFrontTile(tile, tempfront);
			if (correction)	msg+=error_repair;
				else	{ msg+=error_error; good=false; }
			}
		else	{ msg+="usable"; }
		}
	}
// the depot
msg=space+"Target Depot "+tgt_depotid+" is ";
if (!AIRoad.IsRoadDepotTile(tgt_depotid))
	{
	msg+="invalid. ";
	if (tgt_depotid=root.builder.BuildRoadDepotAtTile(AIStation.GetLocation(tgt_stationid), AIRoad.ROADVEHTYPE_BUS+100000))	msg+=error_repair;
		else	{ msg+=error_error; good=false; }
	}
else	msg+="valid";
DInfo(msg,1);
depotfront=AIRoad.GetRoadDepotFrontTile(tgt_depotid);
if (good)
	{
	msg=space+space+"Depot entry is ";
	if (!AIRoad.AreRoadTilesConnected(tgt_depotid, depotfront))
		{
		msg+="not usable. ";
		correction=root.builder.BuildRoadFrontTile(tgt_depotid, depotfront);
		if (correction)	{ msg+=error_repair; }
			else	{ msg+=error_error; good=false; }
		}
	else	msg+="usable.";
	DInfo(msg,1);
	}
// check the road itself
if (good)
	{
	source_station_obj.STATION.e_depot=src_depotid;
	target_station_obj.STATION.e_depot=tgt_depotid;
	root.chemin.GListUpdateItem(road.ROUTE.src_station, source_station_obj);
	root.chemin.GListUpdateItem(road.ROUTE.dst_station, target_station_obj);
	local src_depot_front=AIRoad.GetRoadDepotFrontTile(src_depotid);
	local tgt_depot_front=AIRoad.GetRoadDepotFrontTile(tgt_depotid);
	src_entry_loc=AIRoad.GetRoadStationFrontTile(AIStation.GetLocation(source_station_obj.STATION.station_id));
	tgt_entry_loc=AIRoad.GetRoadStationFrontTile(AIStation.GetLocation(target_station_obj.STATION.station_id));
	local entry_loc=0;
	foreach (tile, dummy in source_tilestation)
		{
		entry_loc=AIRoad.GetRoadStationFrontTile(tile);
		msg=space+"Connnection from source station -> Entry "+tile+" to its depot : ";
		if (!root.builder.RoadRunner(entry_loc, src_depot_front, AIVehicle.VT_ROAD))
			{
			msg+="Damage & ";
			root.builder.BuildRoadROAD(entry_loc, src_depot_front);
			if (!root.builder.RoadRunner(entry_loc, src_depot_front, AIVehicle.VT_ROAD))
				{ msg+=error_error; good=false; }
			else	{ msg+=error_repair; }
			DInfo(msg,1);
			}
		else	{ DInfo(msg+"Working",1); }
		ClearSignsALL();
		}
	foreach (tile, dummy in target_tilestation)
		{
		entry_loc=AIRoad.GetRoadStationFrontTile(tile);
		msg=space+"Connnection from destination station -> Entry "+tile+" to its depot : ";
		if (!root.builder.RoadRunner(entry_loc, tgt_depot_front, AIVehicle.VT_ROAD))
			{
			msg+="Damage & ";
			root.builder.BuildRoadROAD(entry_loc, tgt_depot_front);
			if (!root.builder.RoadRunner(entry_loc, tgt_depot_front, AIVehicle.VT_ROAD))
				{ msg+=error_error; good=false; }
			else	{ msg+=error_repair; }
			DInfo(msg,1);
			}
		else	{ DInfo(msg+"Working",1); }
		ClearSignsALL();
		}
	msg=space+"Connection from source station to target station : "
	if (!root.builder.RoadRunner(src_entry_loc, tgt_entry_loc, AIVehicle.VT_ROAD))
		{
		msg+="Damage & ";
		root.builder.BuildRoadROAD(src_entry_loc, tgt_entry_loc);
		if (!root.builder.RoadRunner(src_entry_loc, tgt_entry_loc, AIVehicle.VT_ROAD))
			{ msg+=error_error; good=false; }
		else	{ msg+=error_repair; }
		DInfo(msg,1);
		}
	else	{ DInfo(msg+"Working",1); }
	}
root.chemin.RListDumpOne(idx);
root.NeedDelay(50);
ClearSignsALL();
return good;
}

function cBuilder::ConstructRoadROAD(path)
// this construct (build) the road we get from path
{
root.bank.RaiseFundsBigTime();
DInfo("Building road structure",0);
local prev = null;
local waserror = false;
local counter=0;
holes=[];
while (path != null)
	{
	local par = path.GetParent();
	if (par != null)
		{
		if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1)
			{
			if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile()))
				{
				local error = AIError.GetLastError();
				if (error != AIError.ERR_ALREADY_BUILT)
					{
					if (error == AIError.ERR_VEHICLE_IN_THE_WAY)
						{
						DInfo("A vehicle was in the way while I was building the road. Retrying...",1);
						counter = 0;
						AIController.Sleep(75);
						while (!AIRoad.BuildRoad(path.GetTile(), par.GetTile()) && counter < 3)
							{
							counter++;
							AIController.Sleep(75);
							}
						if (counter > 2)
							{
							DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),1);
							cBuilder.ReportHole(path.GetTile(), par.GetTile(), waserror);
							waserror = true;
							}
						 else	{
							if (waserror)
								{
								waserror = false;
								holes.push([holestart, holeend]);
								}
							}
						}
					else	{
						DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),1);
						cBuilder.ReportHole(path.GetTile(), par.GetTile(), waserror);
						waserror = true;
						}
					}
			 	else	{
					if (waserror)
						{
						waserror = false;
						holes.push([holestart, holeend]);
						}
					}
				}
		 	else 	{
				if (waserror)
					{
					waserror = false;
					holes.push([holestart, holeend]);
					}
				}
			}
	 	else	{
			if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile()))
				{
				if (AIRoad.IsRoadTile(path.GetTile())) cTileTools.DemolishTile(path.GetTile());
				if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile())
					{
					if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile()))
						{
						DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),1);
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH)
							{
							DInfo("That tunnel would be too expensive. Construction aborted.",1);
							return false;
							}
						cBuilder.ReportHole(prev.GetTile(), par.GetTile(), waserror);
						waserror = true;
						}
					else	{
						if (waserror)
							{
							waserror = false;
							holes.push([holestart, holeend]);
							}
						}
					}
			 	else	{
					local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
					bridgelist.Valuate(AIBridge.GetMaxSpeed);
					if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridgelist.Begin(), path.GetTile(), par.GetTile()))
						{
						DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),1);
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH)
							{
							DInfo("That bridge would be too expensive. Construction aborted.",1);
							return false;
							}
						cBuilder.ReportHole(prev.GetTile(), par.GetTile(), waserror);
						waserror = true;
						}
					 else	{
						if (waserror)
							{
							waserror = false;
							holes.push([holestart, holeend]);
							}
						}
					}
				}
			}
		}
	prev = path;
	path = par;
	}
if (waserror)
	{
	waserror = false;
	holes.push([holestart, holeend]);
	}
if (holes.len() > 0)
	{ DInfo("Road construction fail...",1); return false; }
return true;
}


function cBuilder::BuildRoadROAD(head1, head2)
// pathfind+building the road
// we return true or false if it fail
{
local path= false;
path = root.builder.PathfindRoadROAD(head1, head2);
if (path != null && path != false)
	{
	return root.builder.ConstructRoadROAD(path);
	}
else	{ return false;	}
}

