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
// statile = 100;
// deptile = 100
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
{
if (AITile.IsStationTile(tile)) return -1; // protect station

// ok we know we are close to a road, let's find where the road is
local direction=tile+AIMap.GetTileIndex(0,1);
if (!AIRoad.IsRoadTile(direction))
	{
	direction=tile+AIMap.GetTileIndex(0,-1);
	if (!AIRoad.IsRoadTile(direction))
		{
		direction=tile+AIMap.GetTileIndex(1,0);
		if (!AIRoad.IsRoadTile(direction))
			{
			direction=tile+AIMap.GetTileIndex(-1,0);
			if (!AIRoad.IsRoadTile(direction))	{ DInfo("Can't find the road ???",2); return -1; }
			}
		}
	}
if (!cTileTools.DemolishTile(tile))
	{ DInfo("Can't remove that tile : "+AIError.GetLastErrorString(),2); return -1; }
// sometimes, the road isn't fully connect to us, try build it, and don't care failure
AIRoad.BuildRoad(direction,tile);
if (stationtype == (AIRoad.ROADVEHTYPE_BUS+100000)) // depot, i add 100000 to know it's a depot i need
	{
	if (!AIRoad.BuildRoadDepot(tile,direction))
		{ DInfo("Can't built the depot : "+AIError.GetLastErrorString(),2); return -1; }
	else	{
		if (AIRoad.AreRoadTilesConnected(tile,direction))	return tile;
			else	{
				DInfo("Something is bad with the depot",2);
				cTileTools.DemolishTile(tile);
				root.builder.BlacklistTile(tile);
				return -1;
				}
		}
	}
// if we are still here, we have done others cases already
local directions=[AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)];
foreach (voisin in directions)
	{
	if (AITile.IsStationTile(tile+voisin))	return -1; // prevent build a station close to another one (us or anyone)
	}
if (!AIRoad.BuildRoadStation(tile, direction, stationtype, AIStation.STATION_NEW))
	{ DInfo("Can't built the station : "+AIError.GetLastErrorString(),2); return -1; }
	else	{
		if (AIRoad.AreRoadTilesConnected(tile,direction))	return tile;
		else	{
			DInfo("Something is bad with that station",2);
			cTileTools.DemolishTile(tile); 
			root.builder.BlacklistTile(tile);
			return -1;
			}
		}
return -1;
}

function cBuilder::BuildRoadStation(start)
{
root.bank.RaiseFundsBigTime();
AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
root.builder.currentRoadType=AIRoad.GetCurrentRoadType();
local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
local dir, tilelist, checklist, otherplace, istown, isneartown=null;
local road = root.chemin.RListGetItem(root.chemin.nowRoute);
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
root.builder.RemoveBlacklistTiles(checklist);
if (checklist.IsEmpty())
	{
	DInfo("Cannot stick our station to a road, building classic",1);
	isneartown=false;
	}
else	{
	DInfo("Sticking station & depot to the road",1);
	}

/*local gotRoad=false;
foreach (i, dummy in checklist)
	{
	DInfo("checklist "+i+" dummy="+dummy);
	if (dummy == 1)	{ gotRoad=true; break; }
	}
if (!gotRoad)
	{	// no road there, we need one
	AIRoad.BuildRoad(direction,tile);
	}*/

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
			DInfo("Town or industry start, valuate as biggest first",2);
			}
		//showLogic(tilelist);
		}
	else	{
		//tilelist.Valuate(AITile.IsBuildable); 
		//tilelist.KeepAboveValue(0); 
		if (!istown)
			{
			tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
			}
		tilelist.Sort(AIList.SORT_BY_VALUE,true);
		}
DInfo("Tilelist set to "+tilelist.Count(),2);
//tilelist.Sort(AIList.SORT_BY_VALUE, !isneartown);
local success = false;
local depotbuild=false;
local stationbuild=false;
local newStation=cStation();

/*if (!istown && isneartown)
	{
	tilelist = AITileList_IndustryAccepting(road.ROUTE.dst_id, rad);
	tilelist.Sort(AIList.SORT_BY_VALUE, false);
	tilelist.Valuate(AITile.IsBuildable); // test
	tilelist.KeepAboveValue(0); //test
	tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
	}*/
if (isneartown)
	{
	foreach (tile, dummy in tilelist)
		{
		statile=cBuilder.BuildAndStickToRoad(tile, stationtype);
		if (statile >= 0)
			{ stationbuild = true; break; }
		}
	foreach (tile, dummy in tilelist)
		{
		if (tile == statile) continue; // don't build on the same place as our new station
		deptile=cBuilder.BuildAndStickToRoad(tile, AIRoad.ROADVEHTYPE_BUS+100000); // depot
		if (deptile >= 0)
			{ depotbuild = true; break; }
		}
	success=(depotbuild && stationbuild);
	if (success) // we have depot + station tile, pathfind to them
		{ root.builder.BuildRoadROAD(AIRoad.GetRoadDepotFrontTile(deptile), AIRoad.GetRoadStationFrontTile(statile));	}
	}

if (statile==-1 && !istown && isneartown)
	{ // We fail to build the station, but it's because we force build station close to roads and there is no roads
	isneartown=false;
	tilelist = AITileList_IndustryAccepting(road.ROUTE.dst_id, rad);
	tilelist.Sort(AIList.SORT_BY_VALUE, false);
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.KeepAboveValue(0);
	tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
	tilelist.Sort(AIList.SORT_BY_VALUE, true);
	}
if (!isneartown)
	{
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
root.chemin.RListUpdateItem(root.chemin.nowRoute,road);
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

function cBuilder::RoadStationFindFrontTile(tile, direction)
// return station front tile for station at tile
{
switch (direction)
	{
	case DIR_NE:
		return tile + AIMap.GetTileIndex(-1,0);
	break;
	case DIR_NW:
		return tile + AIMap.GetTileIndex(0,-1);
	break;
	case DIR_SE:
		return tile + AIMap.GetTileIndex(0,1);
	break;
	case DIR_SW:
		return tile + AIMap.GetTileIndex(1,0);
	break;
	}
}

function cBuilder::CheckRoadHealth(idx)
// we check a route for trouble & try to solve them
{
local good=true;
local road=root.chemin.RListGetItem(idx);
local space="        ";
local correction=false;
local temp=null;
if (!road.ROUTE.isServed)	good=false;
if (road.ROUTE.kind != AIVehicle.VT_ROAD)	return false; // only check road type
local source_station_obj=root.chemin.GListGetItem(road.ROUTE.src_station);
local target_station_obj=root.chemin.GListGetItem(road.ROUTE.dst_station);
local src_stationid=source_station_obj.STATION.station_id;
local tgt_stationid=target_station_obj.STATION.station_id;
local src_stationloc=AIStation.GetLocation(src_stationid);
local tgt_stationloc=AIStation.GetLocation(tgt_stationid);
local src_depotid=source_station_obj.STATION.e_depot;
local tgt_depotid=target_station_obj.STATION.e_depot;
local src_station_front=AIRoad.GetRoadStationFrontTile(src_stationloc);
local tgt_station_front=AIRoad.GetRoadStationFrontTile(tgt_stationloc);
local facing=0;
local tempfront=0;
local msg="";
DInfo("Checking route health of #"+idx+" "+road.ROUTE.src_name+"-"+road.ROUTE.dst_name+":"+road.ROUTE.cargo_name,1);
// check station troubles
// source station
temp=src_stationid;
correction=false;
local error_repair="Fixed !";
local error_error="Fail to fix it";
if (!AIStation.IsValidStation(temp))	{ DInfo(space+" Source Station is invalid !",1); good=false; }
	else	DInfo(space+"Source station "+AIStation.GetName(temp)+"("+temp+") is valid",1);
local station_tile=cTileTools.FindRoadStationTiles(AIStation.GetLocation(temp));
DInfo(space+space+"Station size : "+station_tile.Count(),1);
facing=source_station_obj.STATION.direction;
DInfo(space+space+"Station is facing : "+facing,1);
foreach (tile, dummy in station_tile)
	{
	PutSign(tile, "S");
	msg=space+space+"Entry "+tile+" is ";
	tempfront=root.builder.RoadStationFindFrontTile(tile, facing);
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

// the depot
temp=src_depotid;
local depotfront=AIRoad.GetRoadDepotFrontTile(temp);
msg=space+"Source Depot "+src_depotid+" is ";
if (!AIRoad.IsRoadDepotTile(src_depotid))
	{
	msg+="invalid. ";
	if (root.builder.RoadBuildDepot(idx, true))	msg+=error_repair;
		else	{ msg+=error_error; good=false; }
	}
else	msg+="valid";
DInfo(msg,1);

msg=space+space+"Depot entry is ";
if (!AIRoad.AreRoadTilesConnected(temp, depotfront))
	{
	msg+="not usable. ";
	correction=root.builder.BuildRoadFrontTile(temp, depotfront);
	if (correction)	msg+=error_repair;
		else	{ msg+=error_error; good=false; }
	}
else	msg+="usable";
DInfo(msg,1);


// target station
temp=tgt_stationid;
correction=false;
if (!AIStation.IsValidStation(temp))	{ DInfo(space+" Source Station is invalid !",1); good=false; }
	else	DInfo(space+"Target station "+AIStation.GetName(temp)+"("+temp+") is valid",1);
local station_tile=cTileTools.FindRoadStationTiles(AIStation.GetLocation(temp));
DInfo(space+space+"Station size : "+station_tile.Count(),1);
facing=target_station_obj.STATION.direction;
DInfo(space+space+"Station is facing : "+facing,1);
foreach (tile, dummy in station_tile)
	{
	msg=space+space+"Entry "+tile+" is ";
	tempfront=root.builder.RoadStationFindFrontTile(tile, facing);
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
// the depot
temp=tgt_depotid;
depotfront=AIRoad.GetRoadDepotFrontTile(temp);
msg=space+"Target Depot "+src_depotid+" is ";
if (!AIRoad.IsRoadDepotTile(src_depotid))
	{
	msg+="invalid. ";
	if (root.builder.RoadBuildDepot(idx, true))	msg+=error_repair;
		else	{ msg+=error_error; good=false; }
	}
else	msg+="valid";
DInfo(msg,1);
msg=space+space+"Depot entry is ";
if (!AIRoad.AreRoadTilesConnected(temp, depotfront))
	{
	msg+="not usable. ";
	correction=root.builder.BuildRoadFrontTile(temp, depotfront);
	if (correction)	{ msg+=error_repair; }
		else	{ msg+=error_error; good=false; }
	}
else	msg+="usable.";
DInfo(msg,1);

// check the road itself
source_station_obj=root.chemin.GListGetItem(road.ROUTE.src_station);
target_station_obj=root.chemin.GListGetItem(road.ROUTE.dst_station);
// reload stations, might have change because of corrections we have made to them
local src_depot_front=AIRoad.GetRoadDepotFrontTile(source_station_obj.STATION.e_depot);
local tgt_depot_front=AIRoad.GetRoadDepotFrontTile(target_station_obj.STATION.e_depot);
msg=space+"Connection from source station to its depot : "
if (!root.builder.RoadRunner(src_station_front, src_depot_front, AIVehicle.VT_ROAD))
	{
	msg+="Damage & ";
	root.builder.BuildRoadROAD(src_station_front, src_depot_front);
	if (!root.builder.RoadRunner(src_station_front, src_depot_front, AIVehicle.VT_ROAD))
		{ msg+=error_error; good=false; }
	else	{ msg+=error_repair; }
	DInfo(msg,1);
	}
	else	{ DInfo(msg+"Working",1); }
ClearSignsALL();
msg=space+"Connection from target station to its depot : "
if (!root.builder.RoadRunner(tgt_station_front, tgt_depot_front, AIVehicle.VT_ROAD))
	{
	msg+="Damage & ";
	root.builder.BuildRoadROAD(tgt_station_front, tgt_depot_front);
	if (!root.builder.RoadRunner(tgt_station_front, tgt_depot_front, AIVehicle.VT_ROAD))
		{ msg+=error_error; good=false; }
	else	{ msg+=error_repair; }
	DInfo(msg,1);
	}
	else	{ DInfo(msg+"Working",1); }
ClearSignsALL();
msg=space+"Connection from source station to target station : "
if (!root.builder.RoadRunner(src_station_front, tgt_station_front, AIVehicle.VT_ROAD))
	{
	msg+="Damage & ";
	root.builder.BuildRoadROAD(src_station_front, tgt_station_front);
	if (!root.builder.RoadRunner(src_station_front, tgt_station_front, AIVehicle.VT_ROAD))
		{ msg+=error_error; good=false; }
	else	{ msg+=error_repair; }
	DInfo(msg,1);
	}
	else	{ DInfo(msg+"Working",1); }
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

