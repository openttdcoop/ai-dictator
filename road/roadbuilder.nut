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

class MyRoadPF extends RoadPathFinder
	{
	_cost_level_crossing = null;
	}

function MyRoadPF::_Cost(self, path, new_tile, new_direction)
{
	local cost = ::RoadPathFinder._Cost(self, path, new_tile, new_direction);
//print("whois null ? "+new_tile+" 
	if (AITile.HasTransportType(new_tile, AITile.TRANSPORT_RAIL)) cost += self._cost_level_crossing;
	return cost;
}

function MyRoadPF::_Estimate(self, cur_tile, cur_direction, goal_tiles)
{
	return 1.4*::RoadPathFinder._Estimate(self, cur_tile, cur_direction, goal_tiles);
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

function cBuilder::BuildAndStickToRoad(tile, stationtype, stalink=-1)
// Find a road near tile and build a road depot or station connected to that road
//
// @param tile tile where to put the structure
// @param stationtype if AIRoad.ROADVEHTYPE_BUS+100000 build a depot, else build a station of stationtype type
// @return -1 on error, tile position on success, CriticalError is set 
//
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

if (stationtype != (AIRoad.ROADVEHTYPE_BUS+100000) && stalink == -1) // not a depot = truck or bus station need
	{
	foreach (voisin in directions) // find if the place isn't too close from another station
		{
		tooclose=AITile.IsStationTile(tile+voisin);
		if (!tooclose)	tooclose=AITile.IsStationTile(tile+voisin+voisin);
		if (tooclose)
			{
			DWarn("Road station would be too close from another station",2);
			INSTANCE.main.builder.CriticalError=true; // force a critical error
			return -1;
			}
		}
	}
// now build the structure, function is in stationbuilder.nut
return INSTANCE.main.builder.BuildRoadStationOrDepotAtTile(tile, direction, stationtype, stalink);
}

function cBuilder::BuildRoadDepotAtTile(tile)
// Try to build a road depot at tile and nearer
{
local reusedepot=cTileTools.GetTilesAroundPlace(tile,24);
reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
reusedepot.Sort(AIList.SORT_BY_VALUE, true);
reusedepot.RemoveAboveValue(8);
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
reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
reusedepot.Sort(AIList.SORT_BY_VALUE, true);
local newpos=-1;
foreach (tile, dummy in reusedepot)
	{
	newpos=INSTANCE.main.builder.BuildAndStickToRoad(tile, AIRoad.ROADVEHTYPE_BUS+100000);
	if (newpos != -1)	return newpos;
	}
return -1;
}

function cBuilder::BuildRoadStation(start)
// Build a road station for a route
// @param start true to build at source, false at destination
// @return true or false
{
	INSTANCE.main.bank.RaiseFundsBigTime();
	local stationtype = null;
	local rad=null;
	if (AICargo.GetTownEffect(INSTANCE.main.route.CargoID) == AICargo.TE_PASSENGERS)
		{
		rad= AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
		stationtype = AIRoad.ROADVEHTYPE_BUS;
		}
	else	{
		rad= AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		stationtype = AIRoad.ROADVEHTYPE_TRUCK;
		}
	local dir, tilelist, checklist, otherplace, istown, isneartown=null;
	if (start)
		{
		dir = INSTANCE.main.builder.GetDirection(INSTANCE.main.route.SourceProcess.Location, INSTANCE.main.route.TargetProcess.Location);
		if (INSTANCE.main.route.SourceProcess.IsTown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.main.route.SourceProcess.ID);
			checklist= cTileTools.GetTilesAroundTown(INSTANCE.main.route.SourceProcess.ID);
			isneartown=true; istown=true;
			if (!cTileTools.TownRatingNice(INSTANCE.main.route.SourceProcess.ID))
				{
				DInfo("Our rating with "+AITown.GetName(INSTANCE.main.route.SourceProcess.ID)+" is too poor",1);
				return false;
				}
			}
		else	{
			tilelist = AITileList_IndustryProducing(INSTANCE.main.route.SourceProcess.ID, rad);
			checklist = AITileList_IndustryProducing(INSTANCE.main.route.SourceProcess.ID, rad);
			isneartown=true; // fake it's a town, it produce, it might be within a town (like a bank)
			istown=false;	 
			}
		otherplace=INSTANCE.main.route.TargetProcess.Location;
		}
	else	{
		dir = INSTANCE.main.builder.GetDirection(INSTANCE.main.route.TargetProcess.Location, INSTANCE.main.route.SourceProcess.Location);
		if (INSTANCE.main.route.TargetProcess.IsTown)
			{
			tilelist = cTileTools.GetTilesAroundTown(INSTANCE.main.route.TargetProcess.ID);
			checklist= cTileTools.GetTilesAroundTown(INSTANCE.main.route.TargetProcess.ID);
			isneartown=true; istown=true;
			if (!cTileTools.TownRatingNice(INSTANCE.main.route.TargetProcess.ID))
				{
				DInfo("Our rating with "+AITown.GetName(INSTANCE.main.route.TargetProcess.ID)+" is too poor",1);
				return false;
				}
			}
		else	{
			tilelist = AITileList_IndustryAccepting(INSTANCE.main.route.TargetProcess.ID, rad);
			checklist = AITileList_IndustryAccepting(INSTANCE.main.route.TargetProcess.ID, rad);
			isneartown=true; istown=false;
			}
		otherplace=INSTANCE.main.route.SourceProcess.Location;
		}
	// let's see if we can stick to a road
	tilelist.Sort(AIList.SORT_BY_VALUE, false); // highest values first
	checklist.Valuate(AIRoad.IsRoadTile);
	checklist.KeepValue(1);
	if (checklist.IsEmpty())
		{
		DInfo("Cannot stick our station to a road, building classic",2);
		isneartown=false;
		}
	else	{
		DInfo("Sticking station & depot to the road",2);
		}
	checklist.AddList(tilelist); // re-put tiles in it in case we fail building later

	if (isneartown)
		{ // first, removing most of the unbuildable cases
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
		if (!istown && !start)	// not a town, and not start = only industry as destination
			{
			tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
			tilelist.Sort(AIList.SORT_BY_VALUE,true); // little distance first
			}
		else	{ // town or (industry at start)
			if (!istown)
	 				tilelist.Valuate(AITile.GetCargoProduction, INSTANCE.main.route.CargoID, 1, 1, rad);
				else	{
					tilelist.Valuate(AITile.GetCargoAcceptance, INSTANCE.main.route.CargoID, 1, 1, rad);
					tilelist.KeepAboveValue(7);
					}
			tilelist.Sort(AIList.SORT_BY_VALUE, false);
			}
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
	deptile=-1; statile=-1;
	if (isneartown)
		{
		foreach (tile, dummy in tilelist)
			{
			statile=INSTANCE.main.builder.BuildAndStickToRoad(tile, stationtype);
			if (statile >= 0)
				{ stationbuild = true; break; }
			}
		if (stationbuild)
			{ // try build depot closer to our station
			tilelist.Valuate(AITile.GetDistanceManhattanToTile,statile);
			tilelist.Sort(AIList.SORT_BY_VALUE, true);
			}
		foreach (tile, dummy in tilelist)
			{
			if (tile == statile) continue; // don't build on the same place as our new station
			deptile=INSTANCE.main.builder.BuildAndStickToRoad(tile, AIRoad.ROADVEHTYPE_BUS+100000); // depot
			if (deptile >= 0)
				{ depotbuild = true; break; }
			}
		success=(depotbuild && stationbuild);
		if (success) // we have depot + station tile, pathfind to them
			{ INSTANCE.main.builder.BuildRoadROAD(AIRoad.GetRoadDepotFrontTile(deptile), AIRoad.GetRoadStationFrontTile(statile));	}
		}
	if ((statile==-1 || deptile==-1) && !istown && isneartown)
		{ // We fail to build the station, but it's because we force build station close to roads and there is no roads
		if (statile>0)	cTileTools.DemolishTile(statile);
		if (deptile>0)	cTileTools.DemolishTile(deptile);
		isneartown=false;
		tilelist.AddList(checklist); // restore the list of original tiles
		tilelist.Valuate(AITile.IsBuildable);
		tilelist.KeepValue(1);
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
		INSTANCE.main.builder.CriticalError=true;
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
			DError("Station could not be built",1);
			return false;
			}
		if (!AIRoad.BuildRoadDepot(deptile, depfront))
			{
			DError("Depot could not be built",1);
			cTileTools.DemolishTile(statile);
			return false;
			}
		}
	if (start)	INSTANCE.main.route.SourceStation=AIStation.GetStationID(statile);
		else	INSTANCE.main.route.TargetStation=AIStation.GetStationID(statile);
	local newStation = INSTANCE.main.route.CreateNewStation(start);
	if (newStation == null)	return false;
	newStation.s_Depot = deptile; // attach a depot to that station
	local stadir = INSTANCE.main.builder.GetDirection(statile, AIRoad.GetRoadStationFrontTile(statile));
	local tileFrom= statile + cTileTools.GetRightRelativeFromDirection(stadir);
	local tileTo= statile + cTileTools.GetLeftRelativeFromDirection(stadir);
	cTileTools.TerraformLevelTiles(tileFrom, tileTo); // try levels mainstation and its neighbourg
	tileTo=statile+cTileTools.GetLeftRelativeFromDirection(stadir)+cTileTools.GetForwardRelativeFromDirection(stadir)+cTileTools.GetForwardRelativeFromDirection(stadir);
	cTileTools.TerraformLevelTiles(tileFrom, tileTo); // try levels all tiles a station could use to grow
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
local pfInfo=null;
INSTANCE.main.bank.SaveMoney(); // thinking long time, don't waste money
pfInfo=AISign.BuildSign(head1,"Pathfinding...");
DInfo("Road Pathfinding...",1);
local path = false;
local counter=0;
while (path == false && counter < 250)
	{
	path = pathfinder.FindPath(250);
	counter++;
	AISign.SetName(pfInfo,"Pathfinding... "+counter);
	AIController.Sleep(1);
	}
// restore our money
INSTANCE.main.bank.RaiseFundsBy(savemoney);
AISign.RemoveSign(pfInfo);
if (path != null && path != false)
	{
	DInfo("Path found. (" + counter + ")",0);
	return path;
	}
else	{
	cDebug.ClearSigns();
	DInfo("Pathfinding failed.",1);
	INSTANCE.main.builder.CriticalError=true;
	return false;
	}
}

function cBuilder::BuildRoadFrontTile(tile, targettile)
{
if (!AIRoad.IsRoadTile(targettile))
	{
	cTileTools.DemolishTile(targettile);
	AIRoad.BuildRoad(tile, targettile);
	}
return AIRoad.AreRoadTilesConnected(tile, targettile);
}

function cBuilder::CheckRoadHealth(routeUID)
// we check a route for trouble & try to solve them
// return true if no problems were found
{
	local repair=cRoute.Load(routeUID);
	if (!repair)	{ DInfo("Cannot load that route for a repair, switching to current route.",1); repair=INSTANCE.main.route; }
	if (typeof(repair.SourceStation) != "instance" || typeof(repair.TargetStation) != "instance")
				{ DInfo("Cannot repair that route as stations aren't setup.",1); return false; }
	if (repair.VehicleType != AIVehicle.VT_ROAD)	return false; // only check road type
	local good=true;
	local space="        ";
	local correction=false;
	local temp=null;
	local minGood=false;
	DInfo("Checking route health of "+repair.Name,1);
	// check stations for trouble
	// source station
	correction=false;
	local msg="";
	local error_repair="Fixed !";
	local error_error="Fail to fix it";
	temp=repair.SourceStation;
	if (!AIStation.IsValidStation(temp.s_ID))	{ DInfo(space+" Source Station is invalid !",1); good=false; }
							else	DInfo(space+"Source station "+temp.s_Name+" is valid",1);
	if (good)
		{
		DInfo(space+space+"Station size : "+temp.s_Tiles.Count(),1);
		foreach (tile, front in temp.s_Tiles)
			{
			cDebug.PutSign(tile, "S");
			msg=space+space+"Entry "+tile+" is ";
			if (!AIRoad.AreRoadTilesConnected(tile, front))
				{
				msg+="NOT usable. ";
				correction=INSTANCE.main.builder.BuildRoadFrontTile(tile, front);
				if (correction)	msg+=error_repair;
					else	{ msg+=error_error; good=false; }
				}
			else	{ msg+="usable"; }
			DInfo(msg,1);
			}
		}
	cDebug.ClearSigns();
	// target station
	correction=false;
	temp=repair.TargetStation;
	if (!AIStation.IsValidStation(temp.s_ID))	{ DInfo(space+" Destination Station is invalid !",1); good=false; }
							else	DInfo(space+"Destination station "+temp.s_Name+" is valid",1);
	if (good)
		{
		DInfo(space+space+"Station size : "+temp.s_Tiles.Count(),1);
		foreach (tile, front in temp.s_Tiles)
			{
			cDebug.PutSign(tile, "S");
			msg=space+space+"Entry "+tile+" is ";
			if (!AIRoad.AreRoadTilesConnected(tile, front))
				{
				msg+="NOT usable. ";
				correction=INSTANCE.main.builder.BuildRoadFrontTile(tile, front);
				if (correction)	msg+=error_repair;
					else	{ msg+=error_error; good=false; }
				}
			else	{ msg+="usable"; }
			DInfo(msg,1);
			}
		}
	cDebug.ClearSigns();
	// check the road itself from source to destination
	msg=space+"Connection from source station to target station : "
	foreach (stile, sfront in repair.SourceStation.s_Tiles)
		{
		foreach (dtile, dfront in repair.TargetStation.s_Tiles)
			{
			msg=space+"Connnection from "+repair.SourceStation.s_Name+" Entry #"+stile+" to "+repair.TargetStation.s_Name+" Entry #"+dtile+" : ";
			if (!INSTANCE.main.builder.RoadRunner(sfront, dfront, AIVehicle.VT_ROAD))
				{
				msg+="Damage & ";
				INSTANCE.main.builder.BuildRoadROAD(sfront, dfront);
				if (!INSTANCE.main.builder.RoadRunner(sfront, dfront, AIVehicle.VT_ROAD))
					{ msg+=error_error; good=false; }
				else	{ msg+=error_repair; minGood=true; break; }
				DInfo(msg,1);
				}
			else	{ DInfo(msg+"Working",1); minGood=true; break; }
			}
		if (minGood)	break;
		cDebug.ClearSigns();
		}

	// the source depot
	msg=space+"Source Depot "+repair.SourceStation.s_Depot+" is ";
	if (!AIRoad.IsRoadDepotTile(repair.SourceStation.s_Depot))
		{
		msg+="invalid. ";
		repair.SourceStation.s_Depot = INSTANCE.main.builder.BuildRoadDepotAtTile(repair.SourceStation.GetRoadStationEntry());
		if (AIRoad.IsRoadDepotTile(repair.SourceStation.s_Depot))	msg+=error_repair;
											else	{ msg+=error_error; good=false; }
		}
	else	msg+="valid";
	DInfo(msg,1);
	local depotfront=AIRoad.GetRoadDepotFrontTile(repair.SourceStation.s_Depot);
	if (good)
		{
		msg=space+space+"Depot entry is ";
		if (!AIRoad.AreRoadTilesConnected(repair.SourceStation.s_Depot, depotfront))
			{
			msg+="not usable. ";
			correction=INSTANCE.main.builder.BuildRoadFrontTile(repair.SourceStation.s_Depot, depotfront);
			if (correction)	msg+=error_repair;
					else	{ msg+=error_error; good=false; }
			}
		else	msg+="usable";
		DInfo(msg,1);
		}

	// the destination depot
	msg=space+"Destination Depot "+repair.TargetStation.s_Depot+" is ";
	if (!AIRoad.IsRoadDepotTile(repair.TargetStation.s_Depot))
		{
		msg+="invalid. ";
		repair.TargetStation.s_Depot = INSTANCE.main.builder.BuildRoadDepotAtTile(repair.TargetStation.GetRoadStationEntry());
		if (AIRoad.IsRoadDepotTile(repair.TargetStation.s_Depot))	msg+=error_repair;
											else	{ msg+=error_error; good=false; }
		}
	else	msg+="valid";
	DInfo(msg,1);
	local depotfront=AIRoad.GetRoadDepotFrontTile(repair.TargetStation.s_Depot);
	if (good)
		{
		msg=space+space+"Depot entry is ";
		if (!AIRoad.AreRoadTilesConnected(repair.TargetStation.s_Depot, depotfront))
			{
			msg+="not usable. ";
			correction=INSTANCE.main.builder.BuildRoadFrontTile(repair.TargetStation.s_Depot, depotfront);
			if (correction)	msg+=error_repair;
					else	{ msg+=error_error; good=false; }
			}
		else	msg+="usable";
		DInfo(msg,1);
		}

	if (good)
		{
		local src_depot_front=AIRoad.GetRoadDepotFrontTile(repair.SourceStation.s_Depot);
		local tgt_depot_front=AIRoad.GetRoadDepotFrontTile(repair.TargetStation.s_Depot);
		foreach (tile, front in repair.SourceStation.s_Tiles)
			{
			msg=space+"Connnection from source station -> Entry "+tile+" to its depot : ";
			if (!INSTANCE.main.builder.RoadRunner(front, src_depot_front, AIVehicle.VT_ROAD))
				{
				msg+="Damage & ";
				INSTANCE.main.builder.BuildRoadROAD(front, src_depot_front);
				if (!INSTANCE.main.builder.RoadRunner(front, src_depot_front, AIVehicle.VT_ROAD))
					{ msg+=error_error; good=false;  cTileTools.DemolishTile(repair.source.depot); }
				else	{ msg+=error_repair; }
				DInfo(msg,1);
				}
			else	{ DInfo(msg+"Working",1); }
			cDebug.ClearSigns();
			}
		foreach (tile, front in repair.TargetStation.s_Tiles)
			{
			msg=space+"Connnection from destination station -> Entry "+tile+" to its depot : ";
			if (!INSTANCE.main.builder.RoadRunner(front, tgt_depot_front, AIVehicle.VT_ROAD))
				{
				msg+="Damage & ";
				INSTANCE.main.builder.BuildRoadROAD(front, tgt_depot_front);
				if (!INSTANCE.main.builder.RoadRunner(front, tgt_depot_front, AIVehicle.VT_ROAD))
					{ msg+=error_error; good=false; cTileTools.DemolishTile(repair.target.depot); }
				else	{ msg+=error_repair; }
				DInfo(msg,1);
				}
			else	{ DInfo(msg+"Working",1); }
			cDebug.ClearSigns();
			}
		}
	cDebug.ClearSigns();
	return minGood;
}

function cBuilder::ConstructRoadROAD(path)
// this construct (build) the road we get from path
{
INSTANCE.main.bank.RaiseFundsBigTime();
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
			local parpar=par.GetParent();
			if (parpar != null)
				{
				// check for small up/down hills correction
				local targetTile=path.GetTile();
				local parTile=par.GetTile();
				local equal= (AITile.GetMinHeight(parTile) == AITile.GetMinHeight(targetTile));
				if (equal && AITile.GetSlope(parTile) != AITile.SLOPE_FLAT && AITile.GetSlope(targetTile) != AITile.SLOPE_FLAT)
					{
					DInfo("Smoothing land to build road",1);
					cTileTools.TerraformLevelTiles(targetTile, parpar.GetTile());
					}
				}

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
			if (!cBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile()))
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
					local bridgeID = cBridge.GetCheapBridgeID(AIVehicle.VT_ROAD, AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
//					local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
//					bridgelist.Valuate(AIBridge.GetPrice,AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1 );
//					bridgelist.Sort(AIList.SORT_BY_VALUE,true);
					if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridgeID, path.GetTile(), par.GetTile()))
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
// Pathfind and building the road.
// AllowDelay to false to get immediate road construction and block script until its end.
// AllowDelay to true to use cPathfinder class that makes all pathfinding advance, but let the script continue others tasks.
// we return true or false if it fail
{
local path= false;
path = INSTANCE.main.builder.PathfindRoadROAD(head1, head2);
if (path != null && path != false)
	{
	return INSTANCE.main.builder.ConstructRoadROAD(path);
	}
else	{ return false;	}
}

function cBuilder::RoadFindCompatibleDepot(tile)
// Try to find an existing road depot near tile and reuse it
//
// @param tile the tile to search the depot
// @return -1 on failure, depot location on success
{
local reusedepot=cTileTools.GetTilesAroundPlace(tile,24);
reusedepot.Valuate(AIRoad.IsRoadDepotTile);
reusedepot.KeepValue(1);
reusedepot.Valuate(AITile.GetOwner);
local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
reusedepot.KeepValue(weare);
reusedepot.Valuate(AITile.GetDistanceManhattanToTile,tile);
reusedepot.Sort(AIList.SORT_BY_VALUE, true);
reusedepot.RemoveAboveValue(10);

local newdeploc=-1;
if (!reusedepot.IsEmpty())
	{
	newdeploc=reusedepot.Begin();
	}
return newdeploc;
}

function cBuilder::RoadStationNeedUpgrade(roadidx,start)
// Upgrade a road station.
// @param roadidx index of the route to upgrade
// @param start true to upgrade source station, false for destination station
// @return true or false
{
//local new_location=[AIMap.GetTileIndex(0,-1), AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(-1,0), AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,-1), AIMap.GetTileIndex(-1,1), AIMap.GetTileIndex(1,-1), AIMap.GetTileIndex(1,1)];
// left, right, behind middle, front middle, behind left, behind right, front left, front right
//local new_facing=[AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0), AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0,-1)];
// 0 will be same as original station, north, south, east, west
	local road=cRoute.Load(roadidx);
	if (!road)	return false;
	if (road.Status != 100)	return false;
	cBanker.RaiseFundsBigTime();
	local work=null;
	if (start)	work=road.SourceStation;
		else	work=road.TargetStation;
	DInfo("Upgrading road station "+work.s_Name,0);
	work.s_DateLastUpgrade = AIDate.GetCurrentDate(); // setup the date in case of failure
	local depot_id=work.s_Depot;
	DInfo("Road depot is at "+depot_id,2);
	// first lookout where is the station, where is its entry, where is the depot, where is the depot entry
	local sta_pos=work.s_Location;
	local sta_front=AIRoad.GetRoadStationFrontTile(sta_pos);
	local dep_pos=depot_id;
	local dep_front=AIRoad.GetRoadDepotFrontTile(depot_id);
	local depotdead=false;
	local statype= AIRoad.ROADVEHTYPE_BUS;
	if (work.s_Type == AIStation.STATION_TRUCK_STOP)	statype=AIRoad.ROADVEHTYPE_TRUCK;
	local deptype=AIRoad.ROADVEHTYPE_BUS+100000; // we add 100000
	local new_sta_pos=-1;
	local new_dep_pos=-1;
	local success=false;
	local upgradepos=[];
	local facing=INSTANCE.main.builder.GetDirection(sta_pos, sta_front);
	local p_left = cTileTools.GetPosRelativeFromDirection(0, facing);
	local p_right = cTileTools.GetPosRelativeFromDirection(1, facing);
	local p_forward = cTileTools.GetPosRelativeFromDirection(2, facing);
	local p_backward = cTileTools.GetPosRelativeFromDirection(3, facing);
	cDebug.PutSign(sta_pos+p_left,"L");
	cDebug.PutSign(sta_pos+p_right,"R");
	cDebug.PutSign(sta_pos+p_backward,"B");
	cDebug.PutSign(sta_pos+p_forward+p_forward,"F");
	DInfo("Size :"+work.s_Size,2);
	INSTANCE.NeedDelay(100);
	// 1st tile of station, 2nd tile to face
	upgradepos.push(sta_pos+p_left);				// left of station, same facing
	upgradepos.push(sta_pos+p_left+p_forward);

	upgradepos.push(sta_pos+p_right);				// right of station, same facing
	upgradepos.push(sta_pos+p_right+p_forward);

	upgradepos.push(sta_pos+p_left); 				// left of station, facing left
	upgradepos.push(sta_pos+p_left+p_left);

	upgradepos.push(sta_pos+p_right);				// right of station, facing right
	upgradepos.push(sta_pos+p_right+p_right);

	upgradepos.push(sta_pos+p_forward+p_forward);		// front station, facing opposite
	upgradepos.push(sta_pos+p_forward);

	upgradepos.push(sta_pos+p_forward+p_forward+p_left);	// front station, left, facing opposite
	upgradepos.push(sta_pos+p_forward+p_left);

	upgradepos.push(sta_pos+p_forward+p_forward+p_right);	// front station, right, facing opposite
	upgradepos.push(sta_pos+p_forward+p_right);

	upgradepos.push(sta_pos+p_forward+p_forward+p_right);	// front right of station, facing right
	upgradepos.push(sta_pos+p_forward+p_forward+p_right+p_right);

	upgradepos.push(sta_pos+p_forward+p_forward+p_left);	// front left of station, facing left
	upgradepos.push(sta_pos+p_forward+p_forward+p_left+p_left);

	upgradepos.push(sta_pos+p_backward);				// behind station, facing opposite
	upgradepos.push(sta_pos+p_backward+p_backward);

	upgradepos.push(sta_pos+p_backward+p_left);		// behind station, left, facing opposite
	upgradepos.push(sta_pos+p_backward+p_left+p_backward);

	upgradepos.push(sta_pos+p_backward+p_right);		// behind station, right, facing opposite
	upgradepos.push(sta_pos+p_backward+p_right+p_backward);

	upgradepos.push(sta_pos+p_backward+p_left);		// behind station, left, facing left
	upgradepos.push(sta_pos+p_backward+p_left+p_left);

	upgradepos.push(sta_pos+p_backward+p_right);		// behind station, right, facing right
	upgradepos.push(sta_pos+p_backward+p_right+p_right);

	local allfail=true;
	for (local i=0; i < upgradepos.len()-1; i++)
		{
		local tile=upgradepos[i];
		local direction=upgradepos[i+1];
		print("we are doing i="+i);
		if (AIRoad.IsRoadStationTile(tile) || AIRoad.IsRoadStationTile(direction))	{ i++; continue; } // don't build on a station
		if (tile == dep_pos || direction == dep_pos)	{ depotdead = cBuilder.DestroyDepot(dep_pos); }
		// kill our depot if it is about to bug us building
		if (AIRoad.IsRoadTile(tile))	{ i++; continue; } // don't build on a road if we could avoid it
cDebug.PutSign(tile, "S");
cDebug.PutSign(direction, "o");

		new_sta_pos=INSTANCE.main.builder.BuildRoadStationOrDepotAtTile(tile, direction, statype, work.s_ID);
		if (!INSTANCE.main.builder.CriticalError)	allfail=false; // if we have only critical errors we're doom
		INSTANCE.main.builder.CriticalError=false; // discard it
		if (new_sta_pos != -1)	break;
		AIController.Sleep(1);
		INSTANCE.NeedDelay(50);
cDebug.ClearSigns();
		i++;
		}
	DInfo("2nd try don't care roads",2);
	// same as upper but destructive
	if (new_sta_pos == -1)
		{
		for (local i=0; i < upgradepos.len()-1; i++)
			{
			local tile=upgradepos[i];
			local direction=upgradepos[i+1];
		print("we are doing i="+i);
			if (AIRoad.IsRoadStationTile(tile) || AIRoad.IsRoadStationTile(direction))	{ i++; continue; } // don't build on a station
cDebug.PutSign(tile, "S");
cDebug.PutSign(direction, "o");

			if (tile == dep_pos || direction == dep_pos)	{ depotdead = cBuilder.DestroyDepot(dep_pos); }
			// kill our depot if it is about to bug us building
			if (!cTileTools.DemolishTile(tile))	{ DInfo("Cannot clean the place for the new station at "+tile,1); }
			new_sta_pos=INSTANCE.main.builder.BuildRoadStationOrDepotAtTile(tile, direction, statype, work.s_ID);
			if (!INSTANCE.main.builder.CriticalError)	allfail=false; // if we have only critical errors we're doom
			INSTANCE.main.builder.CriticalError=false; // discard it
			if (new_sta_pos != -1)	break;
			AIController.Sleep(1);
			INSTANCE.NeedDelay(50);
cDebug.ClearSigns();
			i++;
			}
		}
	if (new_sta_pos == dep_front && !depotdead)
		{
		depotdead=true; // the depot entry is now block by the station
		cBuilder.DestroyDepot(dep_pos);
		}
	if (depotdead)	
		{
		DWarn("Road depot was destroy while upgrading",1);
		new_dep_pos=INSTANCE.main.builder.BuildRoadDepotAtTile(new_sta_pos);
		work.s_Depot=new_dep_pos;
		INSTANCE.main.builder.CriticalError=false;
		// Should be more than enough
		}
	if (new_sta_pos > -1)
		{
		DInfo("Station "+work.s_Name+" has been upgrade",0);
		work.s_Tiles = cTileTools.FindStationTiles(work.s_Location);
		work.s_Tiles.Valuate(AIRoad.GetRoadStationFrontTile);
		work.s_Size=work.s_Tiles.Count();
		DInfo("New station size: "+work.s_Size+"/"+work.s_MaxSize,2);
		}
	else	{ // fail to upgrade station
		DInfo("Failure to upgrade "+work.s_Name,1);
		if (allfail)
			{
			work.s_MaxSize = work.s_Size;
			DInfo("Cannot upgrade "+work.s_Name+" anymore !",1);
			}
		success=false;
		}
	if (!work.s_Owner.IsEmpty())	INSTANCE.main.builder.RouteIsDamage(work.s_Owner.Begin());
	// ask ourselves a check for one route that own that station
	if (success)	{ work.s_MoneyUpgrade = 0; work.s_DateLastUpgrade = null; }
	return success;
}

function cBuilder::BuildRoadStationOrDepotAtTile(tile, direction, stationtype, stationnew)
// Build a road depot or station, add tile to blacklist on critical failure
// Also build the entry tile with road if need. Try also to find a compatible depot near the wanted position and re-use it
//
// @param tile the tile where to put the structure
// @param direction the tile where the structure will be connected
// @param stationtype if AIRoad.ROADVEHTYPE_BUS+100000 build a depot, else build a station of stationtype type
// @param stationnew invalid station id to build a new station, else joint the station with stationid
// @return tile position on success. -1 on error, set CriticalError

{
// before spending money on a "will fail" structure, check the structure could be connected to a road
if (AITile.IsStationTile(tile))	return -1; // don't destroy a station, might even not be our
INSTANCE.main.bank.RaiseFundsBigTime(); 
if (!AIRoad.IsRoadTile(direction))
	{
	if (!cTileTools.DemolishTile(direction))
		{
		DWarn("Can't remove the tile front structure to build a road at "+direction,2); cDebug.PutSign(direction,"X");
		INSTANCE.main.builder.IsCriticalError();
		return -1;
		}
	}
INSTANCE.main.builder.CriticalError=false;
if (!cTileTools.DemolishTile(tile))
	{
	DWarn("Can't remove the structure tile position at "+tile,2); cDebug.PutSign(tile,"X");
	INSTANCE.main.builder.IsCriticalError();
	return -1;
	}
local success=false;
local newstation=0;
if (AIStation.IsValidStation(stationnew))	newstation=stationnew;
						else	newstation=AIStation.STATION_NEW;
if (stationtype == (AIRoad.ROADVEHTYPE_BUS+100000))
	{
	INSTANCE.main.bank.RaiseFundsBigTime();
	// first let's hack another depot if we can
	local hackdepot=INSTANCE.main.builder.RoadFindCompatibleDepot(tile);
	if (hackdepot == -1)	success=AIRoad.BuildRoadDepot(tile,direction);
			else	{
				tile=hackdepot;
				direction=AIRoad.GetRoadDepotFrontTile(tile);
				success=true;
				}
	//cDebug.PutSign(tile,"D");
	if (!success)
		{
		DWarn("Can't built a road depot at "+tile,2);
		INSTANCE.main.builder.IsCriticalError();
		}
	else	{
		if (hackdepot == -1)	DInfo("Built a road depot at "+tile,0);
				else	DInfo("Found a road depot near "+tile+", reusing that one",0);
		}
	}
else	{
	INSTANCE.main.bank.RaiseFundsBigTime(); cDebug.ClearSigns();
	DInfo("Road info: "+tile+" direction"+direction+" type="+stationtype+" mod="+newstation,2);
	//cDebug.PutSign(tile,"s"); cDebug.PutSign(direction,"c");
	success=AIRoad.BuildRoadStation(tile, direction, stationtype, newstation);
	if (!success)
		{
		DWarn("Can't built the road station at "+tile,2);
		INSTANCE.main.builder.IsCriticalError();
		}
	else	DInfo("Built a road station at "+tile,0);
	}
if (!success)
	{
	return -1;
	}
else	{
	if (!AIRoad.AreRoadTilesConnected(tile, direction))
		if (!AIRoad.BuildRoad(tile, direction))
		{
		DWarn("Fail to connect the road structure with the road in front of it",2);
		INSTANCE.main.builder.IsCriticalError();
		if (!cTileTools.DemolishTile(tile))
			{
			DWarn("Can't remove bad road structure !",2);
			}
		return -1;
		}
	return tile;
	}
}

function cBuilder::RoadRunner(source, target, road_type, walkedtiles=null, origin=null)
// Follow all directions to walk through the path starting at source, ending at target
// check if the path is valid by using road_type (railtype, road)
// return true if we reach target by running the path
{
local max_wrong_direction=15;
if (origin == null)	origin=AITile.GetDistanceManhattanToTile(source, target);
if (walkedtiles == null)	{ walkedtiles=AIList(); }
local valid=false;
local direction=null;
local found=(source == target);
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
			if (road_type == AIVehicle.VT_ROAD)
				if (AIRoad.AreRoadTilesConnected(endat, endat+where))	{ guessTile=endat+where; }
			if (road_type == AIVehicle.VT_RAIL)
				if (cBuilder.AreRailTilesConnected(endat, endat+where))	{ guessTile=endat+where; }
			}
		if (guessTile != null)
			{
			source=guessTile;
			direction=source+voisin;
			}
		}
	if (road_type==AIVehicle.VT_ROAD)	valid=AIRoad.AreRoadTilesConnected(source, direction);
	if (road_type==AIVehicle.VT_RAIL)	valid=cBuilder.AreRailTilesConnected(source, direction);
	local currdistance=AITile.GetDistanceManhattanToTile(direction, target);
	if (currdistance > origin+max_wrong_direction)	{ valid=false; }
	if (walkedtiles.HasItem(direction))	{ valid=false; } 
	if (valid)	walkedtiles.AddItem(direction,0);
//	if (valid && INSTANCE.debug)	cDebug.PutSign(direction,"+");
	//if (INSTANCE.debug) DInfo("Valid="+valid+" curdist="+currdistance+" origindist="+origin+" source="+source+" dir="+direction+" target="+target,2);
	if (!found && valid)	found=INSTANCE.main.builder.RoadRunner(direction, target, road_type, walkedtiles, origin);
	if (found) return found;
	}
return found;
}

function cBuilder::IsRoadStationBusy(stationid)
// Check if a road station is busy and return the vehicle list that busy it
// Station must be AIStation.StationType==STATION_TRUCK_STOP
// We will valuate it with cargo type each vehicle use before return it
// Return false if not
{
if (!AIStation.HasStationType(stationid,AIStation.STATION_TRUCK_STOP))	return false;
local veh_using_station=AIVehicleList_Station(stationid);
if (veh_using_station.IsEmpty())	return false;
local station_tiles=cTileTools.FindRoadStationTiles(AIStation.GetLocation(stationid));
local station_index=INSTANCE.chemin.GListGetStationIndex(stationid);
if (station_index == false)	return false;
local station_obj=INSTANCE.chemin.GListGetItem(station_index);
veh_using_station.Valuate(AITile.GetDistanceManhattanToTile, AIStation.GetLocation(stationid));
}

function cBuilder::AsyncConstructRoadROAD(src, dst, stationID)
// this construct (build) the road we get from path
{
	local head1=[src,0];
	local head2=[0,dst];
	local status=cPathfinder.GetStatus(head1, head2, stationID);
	local path=cPathfinder.GetSolve(head1, head2);
	local smallerror = 0;
	if (path == null)	smallerror = -2;
	switch (status)
		{
		case	0:	// still pathfinding
		return 0;
		case	-1:	// failure
		return -1;
		case	2:	// succeed
		return 1;
		case	3:	// waiting child to end
		return 0;
		}
	// 1 is non covered as it's end of pathfinding, and should call us to build

	INSTANCE.main.bank.RaiseFundsBigTime();
	DInfo("Building road structure",0);
	local prev = null;
	local prevprev = null;
	local prevprevprev = null;
	local counter=0;
	local walked=[];
	cBanker.RaiseFundsBigTime();
	while (path != null && smallerror == 0)
		{
		if (prev != null)
			{
			if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1)
				{
				if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile())
					{
					if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, prev))
						{
						DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),2);
						smallerror=cBuilder.EasyError(AIError.GetLastError());
						if (smallerror == -1)
							{
							DInfo("That tunnel would be too expensive. Construction aborted.",2);
							return false;
							}
						if (smallerror == -2)	break;
						}
					else	{
						cTileTools.BlackListTile(prev, -stationID); // i mark them as blacklist and assign to -stationID, so i could recover them later
						cTileTools.BlackListTile(path.GetTile(), -stationID);
						}
					}
				else	{
					local bridgeID = cBridge.GetCheapBridgeID(AIVehicle.VT_ROAD, AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
					if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridgeID, prev, path.GetTile()))
						{
						DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),2);
						smallerror=cBuilder.EasyError(AIError.GetLastError());
						if (smallerror == -1)
							{
							DInfo("That bridge would be too expensive. Construction aborted.",2);
							return false;
							}
						if (smallerror==-2)	break;
						}
					else	{
						cTileTools.BlackListTile(prev, -stationID);
						cTileTools.BlackListTile(path.GetTile(), -stationID);
						}
					cBridge.IsBridgeTile(prev); // force bridge check
					}
				prev = path.GetTile();
				path = path.GetParent();
				walked.push(prev);
				}
			 else {
				// check for small up/down hills correction
				local targetTile=path.GetTile();
				if (prevprevprev != null)
					{
					if (AITile.GetSlope(prevprevprev) == AITile.SLOPE_FLAT && AITile.GetSlope(targetTile) == AITile.SLOPE_FLAT && AITile.GetSlope(prevprev) != AITile.SLOPE_FLAT)
						{
						DInfo("Smoothing land to build road",1);
						INSTANCE.NeedDelay(30);
						cTileTools.TerraformLevelTiles(targetTile, prevprevprev);
						}
					}
				if (!AIRoad.BuildRoad(prev, targetTile))
					{
					smallerror=cBuilder.EasyError(AIError.GetLastError());
					if (smallerror==-1)
						{
						DInfo("An error occured while I was building the road: " + AIError.GetLastErrorString(),2);
						return false;
						}
					if (smallerror==-2)	break;
					}
				else	{
					cTileTools.BlackListTile(prev, -stationID);
					}
				}
			}
		if (path != null)
			{
			prevprevprev= prevprev;
			prevprev = prev;
			prev = path.GetTile();
			path = path.GetParent();
			walked.push(prev);
			}
	}

	local mytask=cPathfinder.GetPathfinderObject(cPathfinder.GetUID(head1, head2));
	local source=cPathfinder.GetUID(mytask.r_source, mytask.r_target);
	if (smallerror == -2)
		{
		DError("Pathfinder has detect a failure.",1);
		if (walked.len() < 4)
			{
			DInfo("Pathfinder cannot do more",1);
			// unroll all tasks and fail
			source=cPathfinder.GetUID(mytask.source, mytask.target);
			while (source != null)
				{ // remove all sub-tasks
				DInfo("Pathfinder helper task "+source+" failure !",1);
				source=cPathfinder.GetUID(mytask.r_source, mytask.r_target);
				if (source != null)
					{
					cPathfinder.CloseTask(mytask.source, mytask.target);
					mytask=cPathfinder.GetPathfinderObject(source);
					}
				}
			DInfo("Pathfinder task "+mytask.UID+" failure !",1);
			mytask.status=-1;
			local badtiles=AIList();
			badtiles.AddList(cTileTools.TilesBlackList); // keep blacklisted tiles for -stationID
			badtiles.KeepValue(-realtask.stationID);
			cBuilder.RailCleaner(badtiles); // remove all rail we've built
			foreach (tiles, dummy in badtiles)	cTileTools.UnBlackListTile(tiles); // and release them for others
			INSTANCE.main.builder.CriticalError=true;
			return false;
			}
		else	{
			local maxstepback=10;
			local curr=walked.pop(); // dismiss last one, it's the failure
			if (walked.len() < maxstepback)	maxstepback=walked.len()-1;
			local alist=AIList();
			for (local ii=1; ii < maxstepback; ii++)
				{
				prev=walked.pop();
				alist.AddItem(prev, 0);
				AIRoad.RemoveRoad(prev, curr);
				curr=prev;
				}
			//cBuilder.RailCleaner(alist); // TODO: Fix for road
			local newtarget=[0, prev];
			DInfo("Pathfinder is calling an helper task",1);
			// Create the helper task
			local dummy= cPathfinder.GetStatus(head1, newtarget, stationID);
			dummy=cPathfinder.GetPathfinderObject(cPathfinder.GetUID(head1, newtarget));
			dummy.r_source=head1;
			dummy.r_target=head2;
			mytask.status=3; // wait for subtask end
			return false;
			}
		}
	else	{ // we cannot get smallerror==-1 because on -1 it always return, so limit to 0 or -2
		// let's see if we success or an helper task has succeed for us
		if (source != null)
			{
			source=cPathfinder.GetUID(mytask.source, mytask.target);
			while (source != null)
				{ // remove all sub-tasks
				DInfo("Pathfinder helper task "+source+" succeed !",1);
				source=cPathfinder.GetUID(mytask.r_source, mytask.r_target);
				if (source != null)
					{
					//DInfo("Pathfinder helper task "+source+" succeed !",1);
					cPathfinder.CloseTask(mytask.source, mytask.target);
					mytask=cPathfinder.GetPathfinderObject(source); print("now mytask="+mytask+" src="+source);
					}
				}
			}
		DInfo("Pathfinder task "+mytask.UID+" succeed !",1);
		mytask.status=2;
		local bltiles=AIList();
		bltiles.AddList(cTileTools.TilesBlackList);
		bltiles.KeepValue(-stationID);
		return true;
		}
	}
