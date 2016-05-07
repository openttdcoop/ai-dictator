/* -*- Mode: C++; tab-width: 4 -*- */
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

class Path_Converter
{
	_tile = null;
	_parent = null;

	constructor(tile)
	{
		this._tile = tile;
	}

	function GetTile()
	{
		return this._tile;
	}

	function GetParent()
	{
		return this._parent;
	}
}

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

function RailFollower::FindRouteRails(source, target)
{
	if (!AIMap.IsValidTile(source) || !AIMap.IsValidTile(target))	return AIList();
	local solve = cBuilder.RoadRunnerHelper(source, target, AIVehicle.VT_RAIL);
	return solve;
}

function RailFollower::GetRailPathing(source, target)
// return an AIList with rails from the path, empty AIList on error
{
	local pathwalker = RailFollower();
	pathwalker.InitializePath([source], [target]);
	local path = pathwalker.FindPath(20000);
	if (path == null)	{ DError("Pathwalking failure.",2); return AIList(); }
	local toAIList=AIList();
	local prev = path.GetTile();
	local tile = null;
	while (path != null)
		{
		local tile = path.GetTile();
		toAIList.AddItem(tile, 0);
		prev = tile;
		path = path.GetParent();
		}
	return toAIList;
}

function RailFollower::FindRailOwner()
// find route owning rails
{
	cRoute.RouteDamage.Valuate(AITile.HasTransportType, AITile.TRANSPORT_RAIL);
	cRoute.RouteDamage.KeepValue(1);
	foreach (tile, _ in cRoute.RouteDamage)	cBridge.IsBridgeTile(tile);
	local rail_routes = AIGroupList();
	rail_routes.Valuate(AIGroup.GetVehicleType);
	rail_routes.KeepValue(AIVehicle.VT_RAIL);
	local full_trainlist = AIVehicleList();
	full_trainlist.Valuate(AIVehicle.GetVehicleType);
	full_trainlist.KeepValue(AIVehicle.VT_RAIL);
	local uid_list = [];
	local rebuildentry = [];
	foreach (grp, value in rail_routes)	if (cRoute.GroupIndexer.HasItem(grp))	uid_list.push(cRoute.GroupIndexer.GetValue(grp));
	foreach (uid in uid_list)
		{
		cDebug.ClearSigns();
		local road = cRoute.LoadRoute(uid);
		if (!road)	continue;
		// first re-assign trains state to each station (taker, droppper, using entry/exit)
		local train_list = AIVehicleList_Group(road.GroupID);
		full_trainlist.RemoveList(train_list);
		train_list.Valuate(AIVehicle.GetState);
		foreach (trains, state in train_list)
			{
			cRoute.AddTrainToRoute(uid, trains);
            // We restart all trains here
			if (state == AIVehicle.VS_IN_DEPOT || state == AIVehicle.VS_STOPPED)	cCarrier.StartVehicle(trains);
			cCarrier.HandleTrainStuck(trains);
			}
		DInfo("Finding rails for route "+road.Name);
		local bad = false;
		local src_tiles = AIList();
		local dst_tiles = AIList();
		local forward = cDirection.GetForwardRelativeFromDirection(road.SourceStation.s_Direction);
		local src_tile, src_link, dst_tile, dst_link;
		if (forward != -1)
				{
				src_tile = road.SourceStation.s_MainLine;
				src_link = src_tile - forward;
				dst_tile = road.TargetStation.s_AltLine;
				dst_link = dst_tile + forward;
				src_tiles = RailFollower.GetRailPathing([src_tile, src_link], [dst_tile, dst_link]);
				}
		if (src_tiles.IsEmpty())	bad = true;
		DInfo("Main line rails: " + src_tiles.Count(), 2);
		if (!bad)	{
					forward = cDirection.GetForwardRelativeFromDirection(road.TargetStation.s_Direction);
					src_tile = road.TargetStation.s_MainLine;
					src_link = src_tile - forward;
					dst_tile = road.SourceStation.s_AltLine;
					dst_link = dst_tile + forward;
					dst_tiles = RailFollower.GetRailPathing([src_tile, src_link], [dst_tile, dst_link]);
					}
		DInfo("Alternate line rails : "+ dst_tiles.Count(), 2);
		if (!bad)	bad = (dst_tiles.IsEmpty());
		// Add depot as tile to claims
		local depot = cStation.GetStationDepot(road.SourceStation.s_ID);
		if (depot == -1)	bad = true;
		local depot_front = AIRail.GetRailDepotFrontTile(depot);
		src_tiles.AddItem(depot, 0);
		src_tiles.AddItem(depot_front, 0);
		depot = cStation.GetStationDepot(road.TargetStation.s_ID);
		if (depot == -1)	bad = true;
		depot_front = AIRail.GetRailDepotFrontTile(depot);
		dst_tiles.AddItem(depot, 0);
		dst_tiles.AddItem(depot_front, 0);
		// and claims platform front tiles
		foreach (platidx, _ in road.SourceStation.s_Platforms)
			{
			if (platidx < 0)	continue;
			local f = cStationRail.GetPlatformFront(road.SourceStation, platidx);
			src_tiles.AddItem(f, 0);
			}
		foreach (platidx, _ in road.TargetStation.s_Platforms)
			{
			if (platidx < 0)	continue;
			local f = cStationRail.GetPlatformFront(road.TargetStation, platidx);
			dst_tiles.AddItem(f, 0);
			}
		// Remove all tiles we found from the "unknown" tiles list
		cRoute.RouteDamage.RemoveList(src_tiles);
		cRoute.RouteDamage.RemoveList(dst_tiles);
		// Now assign tiles to their station, and claim them
		cStation.StationClaimTile(src_tiles, road.SourceStation.s_ID);
		cStation.StationClaimTile(dst_tiles, road.TargetStation.s_ID);
		// now setup maxtrain
		cStationRail.DefineMaxTrain(road.SourceStation);
		road.TargetStation.s_VehicleMax = road.SourceStation.s_VehicleMax;
		// Check if founded tiles are of the same railtype type (game saved while we were upgrading them)
		src_tiles.AddList(dst_tiles);
		src_tiles.Valuate(AIRail.GetRailType);
		local checkrailtype = src_tiles.Count();
		src_tiles.KeepValue(src_tiles.GetValue(src_tiles.Begin()));
		// Can hardly do better than just send train to depot and fake an line upgrade... If this fail, well, we had try...
		if (src_tiles.Count() != checkrailtype)
					{
					DInfo("Mismatch railtype for that route...",2);
					foreach (trains, _ in train_list)
						{
						// We must remove orders so they stop trying to reach a station they couldn't reach and goes to depot instead
						cEngineLib.VehicleOrderClear(trains);
						cCarrier.VehicleSendToDepot(trains, DepotAction.LINEUPGRADE);
						cEngineLib.VehicleOrderSkipCurrent(trains);
						}
					}
		if (bad)	{
					DInfo("FindRailOwner mark "+road.UID+" undoable",1);
					full_trainlist.AddList(train_list);
					road.RouteIsNotDoable();
					}
		}
	cRoute.RouteDamage.Valuate(AITile.IsStationTile);
	cRoute.RouteDamage.RemoveValue(1);
	local delay = 0;
	while (delay < 30 && !full_trainlist.IsEmpty())
		{
		foreach (veh, _ in full_trainlist)
				{
				if (AIVehicle.IsValidVehicle(veh))	cCarrier.VehicleSendToDepot(veh, DepotAction.SELL);
											else	full_trainlist.RemoveItem(veh);
				}
        AIController.Sleep(74);
		cCarrier.VehicleIsWaitingInDepot(false);
		delay++;
		}
	DInfo("Unknown rails remaining : " + cRoute.RouteDamage.Count());
	cTrack.RailCleaner(cRoute.RouteDamage);
	cRoute.RouteDamage.Clear();
}

function RailFollower::TryUpgradeLine(vehicle)
// We will always upgrade the line, even if we will not change the railtype in order to catch if some rails aren't of the same type
// return 0 if we cannot, -1 if we fail, 1 if we success
// the only difference for us is that return 0 will continue trying upgrade another line, while -1 will block other upgrade line checks
{
	//print("upgrade line for "+cCarrier.GetVehicleName(vehicle));
	// first: see what cargo it carry
	local wagonproto = cEngineLib.VehicleGetRandomWagon(vehicle);
	if (wagonproto == -1)	{ print("bad proto"); return 0; }
	local wagon_type = AIVehicle.GetWagonEngineType(vehicle, wagonproto);
	local cargo = cEngine.GetCargoType(wagon_type);
	// second: look what engine it use
	local loco_engine = AIVehicle.GetEngineType(vehicle);
	local upgrade_cost = 0;
	local uid = cCarrier.VehicleFindRouteIndex(vehicle);
	if (uid == null)	return -1;
	local road = cRoute.LoadRoute(uid);
	if (!road)	return -1;
	local new_railtype = cEngine.IsRailAtTop(vehicle);
	if (new_railtype == -1)	new_railtype = road.RailType;
	print("Convert to new_railtype "+cEngine.GetRailTrackName(new_railtype));

	local date = AIDate.GetCurrentDate();
    if (road.DateHealthCheck != 0 && date - road.DateHealthCheck < 90)	{ DInfo("We try convert this route not long time ago.", 1); return 0; }
    road.DateHealthCheck = 0; // mark it so we could again upgrade
	if (cPathfinder.CheckPathfinderTaskIsRunning([road.SourceStation.s_ID, road.TargetStation.s_ID]))	{ DInfo("No rail upgrade while pathfinder is working",2); return 0; }
	DInfo(cEngine.GetRailTrackName(road.RailType)+" will be replace with "+cEngine.GetRailTrackName(new_railtype));
	upgrade_cost = road.SourceStation.s_MoneyUpgrade;
	DInfo("Cost to upgrade rails : "+upgrade_cost,2);
	if (!cBanker.CanBuyThat(upgrade_cost))	{ return -1; } // don't try upgrade other if we are already short on money
	local temp = AIList();
	local all_owners = AIList();
	local all_vehicle = AIList();
	local all_rails = AIList();
	local savetable = {};
	temp.AddList(road.SourceStation.s_Owner);
	temp.AddList(road.TargetStation.s_Owner);
	local veh_cost = 0;
	foreach (o_uid, _ in temp)
		{
		local r = cRoute.LoadRoute(o_uid);
		if (!r)	continue;
		if (r.Status != RouteStatus.WORKING)	continue; // keep only good ones
		savetable[r.UID] <- r;
		all_owners.AddList(r.SourceStation.s_Owner);
		all_owners.AddList(r.TargetStation.s_Owner);
		all_rails.AddList(r.SourceStation.s_Tiles);
		all_rails.AddList(r.TargetStation.s_Tiles);
		all_rails.AddList(r.SourceStation.s_TilesOther);
		all_rails.AddList(r.TargetStation.s_TilesOther);
		local veh = AIVehicleList_Group(r.GroupID);
		foreach (v, _ in veh)   { all_vehicle.AddItem(v, r.UID); veh_cost += AIEngine.GetPrice(AIVehicle.GetEngineType(v)); }
		}
	if (!cTrack.CheckCrossingRoad(all_rails, new_railtype))
			{
			DInfo("Cannot convert to "+cEngine.GetRailTrackName(new_railtype)+" because of crossing",1);
			road.DateHealthCheck = date; // mark it so it don't retry before some time
			return 0;
			}
	if (upgrade_cost == 0)
		{
		DInfo("Number of affected rails : "+all_rails.Count(),2);
		cDebug.showLogic(all_rails);
		local raw_basic_cost = AIRail.GetBuildCost(new_railtype, AIRail.BT_TRACK) * all_rails.Count();
		local raw_sig_cost = AIRail.GetBuildCost(new_railtype, AIRail.BT_SIGNAL) * (all_rails.Count() / 2);
		local raw_station_cost = AIRail.GetBuildCost(new_railtype, AIRail.BT_STATION) * (savetable.len() * 10);
		upgrade_cost = raw_basic_cost + raw_sig_cost + raw_station_cost + veh_cost;
		cDebug.ClearSigns();
		foreach (uid in savetable)	{ uid.SourceStation.s_MoneyUpgrade = upgrade_cost; uid.TargetStation.s_MoneyUpgrade = upgrade_cost; }
		}

	if (!cBanker.CanBuyThat(upgrade_cost))	{ return 0; }

	// Ok, let's call trains...
	temp = true;
	local groups_list = AIList();
	foreach (veh, _ in all_vehicle)
		{
		groups_list.AddItem(AIVehicle.GetGroupID(veh),0);
		local state = AIVehicle.GetState(veh);
		if (state != AIVehicle.VS_IN_DEPOT)
			{
			temp = false;
			local sendit = false;
			if (!cCarrier.ToDepotList.HasItem(veh))	sendit = true;
			if (!sendit)
				{
				local why = cCarrier.VehicleSendToDepot_GetReason(cCarrier.ToDepotList.GetValue(veh));
				if (why != DepotAction.LINEUPGRADE)	sendit = true;
				}
			if (sendit)	cCarrier.VehicleSendToDepot(veh, DepotAction.LINEUPGRADE);
			}
		}
	if (!temp)	return 0; // if all stopped or no vehicle, temp will remain true
	cBanker.RaiseFundsBigTime();
	DInfo("Changing "+road.Name+" railtype "+cEngine.GetRailTrackName(road.RailType)+" to "+cEngine.GetRailTrackName(new_railtype),0);
	local safekeeper = all_vehicle.Begin();  //TODO: why using safekeeper?
	local safekeeper_depot = AIVehicle.GetLocation(safekeeper);
	local wagon_lost = [];
	foreach (groups, _ in groups_list)	wagon_lost.push(cCarrier.GetTrainBalancingStats(groups, 0, false));
	foreach (veh, uid in all_vehicle)
            {
            if (veh != safekeeper)  {
                                    cCarrier.VehicleSell(veh, false);
                                    if (cCarrier.ToDepotList.HasItem(veh))  cCarrier.ToDepotList.RemoveItem(veh);
                                    }
            }
	all_rails.RemoveItem(safekeeper_depot); // don't try to convert the depot where the safekeeper is
    foreach (tiles, _ in all_rails)
        {
        AISign.BuildSign(tiles, "c");
        local err = cTrack.ConvertRailType(tiles, new_railtype);
        if (err == -1)	{
                        foreach (o_uid in savetable)
                            {
                            DWarn("TryUpgradeLine mark "+o_uid.UID+" undoable",1);
                            o_uid.RouteIsNotDoable();
                            }
                        return -1;
                        }
        if (err == 0)   {
                        DWarn("Cannot convert all rails, redoing later",1);
                        return 0;
                        }
        }
    cCarrier.VehicleSell(safekeeper, false);
	if (cCarrier.ToDepotList.HasItem(safekeeper))   cCarrier.ToDepotList.RemoveItem(safekeeper);
	if (!cTrack.ConvertRailType(safekeeper_depot, new_railtype))  AITile.DemolishTile(safekeeper_depot);
	foreach (uid in savetable)
		{
		uid.SourceStation.s_MoneyUpgrade = 0;
		uid.TargetStation.s_MoneyUpgrade = 0;
		uid.SourceStation.s_SubType = new_railtype;
		uid.TargetStation.s_SubType = new_railtype;
		uid.RailType = new_railtype;
		// now reset stations max size in order to see if we can retry upgrade it now that we change its railtype
		uid.SourceStation.s_MaxSize = INSTANCE.main.carrier.rail_max;
		uid.TargetStation.s_MaxSize = INSTANCE.main.carrier.rail_max;
		}
	DInfo("We have upgrade route "+road.Name+" to use railtype "+cEngine.GetRailTrackName(new_railtype),0);
    print("wagon_lost="+wagon_lost.len());
	cCarrier.Lower_VehicleWish(road.GroupID, -9000); // kill any try to add wagons after we upgrade
	foreach (store in wagon_lost)
		{
		foreach (item, value in store)	print("item="+item+" value="+value);
		print("sotre="+store.len()+" "+typeof("store"));
		for (local i = 0; i < store.len(); i++)
			{
			local tuid = store[i];
			local dummy = store[i+1];
			local tstats = store[i+2];
			cCarrier.ForceAddTrain(tuid, tstats);
			i += 2;
			}
		}
   /* do
        {
        local uid = wagon_lost.pop();
        local num = wagon_lost.pop();
        cCarrier.ForceAddTrain(uid, num);
        }  while (wagon_lost.len() > 0);*/
    cBuilder.BridgeUpgrader();
	return 1;
}

function cBuilder::Path_OptimizerHill(path)
{
	if (path == null)	return;
	cBanker.RaiseFundsBigTime();
	local p1, p2, p3, p4 = null;
	local walked = [];
	cDebug.ClearSigns();
	while (path != null)
		{
		local p0 = path.GetTile();
		if (p1 != null && AIMap.DistanceManhattan(p0, p1) != 1)
				{
				p1 = null;
				p2 = null;
				p3 = null;
				p4 = null;
				}
//		AISign.BuildSign(p0, AITile.GetMinHeight(p0));
		local slope = AITile.GetSlope(p0);
		// detect if we have a turn
			pftask.pathHandler.cost.max_bridge_length = AIGameSettings.GetValue("max_bridge_length");
			pftask.pathHandler.cost.max_tunnel_length = AIGameSettings.GetValue("max_tunnel_length");
		// put a limit to tiles to analyze depending on the lowest bridge or tunnel
		local max_walked = min(AIGameSettings.GetValue("max_bridge_length"), AIGameSettings.GetValue("max_tunnel_length"));
		local noturn = false;
		if (p1 != null && slope == AITile.SLOPE_FLAT && walked.len() < 2)	{ walked = []; walked.push(p0); }
		if (p1 != null && walked.len() > 0 && (AITile.GetMinHeight(walked[0]) != AITile.GetMinHeight(p0) || AITile.GetMaxHeight(walked[0]) != AITile.GetMaxHeight(p0))) walked.push(p0);
		if (walked.len() > 1 && (slope == AITile.SLOPE_FLAT || p1 == null))
			{
			if (p1 != null)	walked.push(p0); // we had it if it's not a bridge/tunnel only
			local as_list = AIList();
			local s_x = AIMap.GetTileX(walked[0]);
			local s_y = AIMap.GetTileY(walked[0]);
            local min_height = min(AITile.GetMinHeight(walked[0]), AITile.GetMinHeight(walked[walked.len() -1]));
            local max_height = max(AITile.GetMaxHeight(walked[0]), AITile.GetMaxHeight(walked[walked.len() -1]));
            // detect if we have a turn between extremities
			local noturn = true;
            // detect if we should climb or not
            local climbing = (AITile.GetMaxHeight(walked[walked.len() -1]) > AITile.GetMaxHeight(walked[0]));
             // detect a tile higher than the extremities, making
            local barrier = false;
            // detect if tiles in between extremities are going up and down
            local rollercoster = false;
            // detect if extremities are at the same level
            local samelevel = (AITile.GetMinHeight(walked[0]) + AITile.GetMaxHeight(walked[0]) == AITile.GetMinHeight(walked[walked.len() -1]) + AITile.GetMaxHeight(walked[walked.len() -1]));
			for (local i = 0; i < walked.len(); i++)
					{
					cDebug.PutSign(walked[i], "i:" + i +"/"+ AITile.GetSlope(walked[i]));
					as_list.AddItem(walked[i], AITile.GetSlope(walked[i]));
					if (noturn && AIMap.GetTileX(walked[i]) != s_x && AIMap.GetTileY(walked[i]) != s_y)	noturn = false;
					if (!barrier && AITile.GetMaxHeight(walked[i]) > max_height)	barrier = true;
					if (i > 0 && !rollercoster)
								{
								if (AITile.GetMaxHeight(walked[i]) < AITile.GetMaxHeight(walked[i - 1]) && climbing)	rollercoster = true;
								if (AITile.GetMaxHeight(walked[i]) > AITile.GetMaxHeight(walked[i - 1]) && !climbing)	rollercoster = true;
								}
					}
			local terraform = false;
			if (walked.len() > 2) // could be too low if a bridge/tunnel has force us to run
				{
				if (barrier || rollercoster || samelevel)	terraform = true;
				print("terraform: "+terraform+" min_height: "+min_height+" max_height: "+max_height+" barrier: "+barrier+" coster: "+rollercoster+" noturn: "+noturn+" samelevel: "+samelevel);
				if (terraform)	{ print("terraforming tiles"); cTerraform.TerraformLevelTiles(as_list, null); }
				}
			cDebug.ClearSigns();
			walked = [];
            }
		p4 = p3;
		p3 = p2;
		p2 = p1;
		p1 = p0;
		path = path.GetParent();
	}
}

function RailFollower::CanBuildBridge(a, b)
// true if we can build a bridge from a to b
{
	local dist = AIMap.DistanceManhattan(a, b) + 1;
	local bridge_id = cBridge.GetCheapBridgeID(AIVehicle.VT_RAIL, dist, true);
//	print("bridgeid =" + bridge_id + AIBridge.GetName(bridge_id));
	if (bridge_id == -1)	return false;
	local test = AITestMode();
	local c = AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridge_id, a, b);
	//if (c == false) { DError("no bridge build: from "+cMisc.Locate(a)+" to "+cMisc.Locate(b),0); }
	return c;
}

function RailFollower::CanBuildTunnel(a, previous_tile)
// return the other tunnel tile if we can build one, we check that previous_tile is compatible with terraforming
{
	local end_side = AITunnel.GetOtherTunnelEnd(a);
	if (end_side == AIMap.TILE_INVALID)	return -1;
    local tunnel_direction = cDirection.GetDirection(a, end_side);
    local path_direction = cDirection.GetDirection(previous_tile, a);
    local front = cDirection.GetForwardRelativeFromDirection(tunnel_direction);
    local endslope = AITile.GetSlope(end_side + front);
    local exitslope = AITile.GetSlope(end_side);
    local good_slope = -1;
    local good_slope_end = -1;
	switch (tunnel_direction)
		{
		case DIR_NE:
			good_slope = AITile.SLOPE_NE;
			good_slope_end = AITile.SLOPE_SW;
			break;
        case DIR_SW:
			good_slope = AITile.SLOPE_SW;
			good_slope_end = AITile.SLOPE_NE;
			break;
        case DIR_NW:
			good_slope = AITile.SLOPE_NW;
			good_slope_end = AITile.SLOPE_SE;
			break;
        case DIR_SE:
			good_slope = AITile.SLOPE_SE;
			good_slope_end = AITile.SLOPE_SW;
			break;
		default :
			not_reach();
		}
	// If one side of tunnel is not ready for tunnel, openttd will genlty terraform it for us
	// But in order for openttd to succeed we must make sure this side won't be use already by any rails on a "bad" slope.
	// So if we build a tunnel the same direction as the path (tunnel is in front of it), no check is need, openttd will report failure if it cannot terraform its exit
	// But if we build a tunnel the opposite direction as the path (tunnel is build after we have walk its entry), openttd will always fail to terraform it if we previously build a rail on it and its slope prevent us from reaching it.
	// A1->A4 if tunnel entry is at A2 and its exit at A3 : no check need openttd will terraform A3 & A4 for us
	// A1->A4 if tunnel entry is at A3 and its exit at A2, we must make sure A1 can still reach A2, and A1 will not if its slope is not FLAT or compatible with the future tunnel entry slope (and that compatible slope is the exact opposite of what the slope of A2 will be after openttd has terraform it ; if A2 slope became NE then A1 slope must be SW or FLAT, else building any rails on it will prevent terraforming)
	if (tunnel_direction != path_direction && exitslope != good_slope_end && endslope != AITile.SLOPE_FLAT && endslope != good_slope)	{ return -1; }
	local test = AITestMode();
	if (AITunnel.BuildTunnel(AIVehicle.VT_RAIL, a))	return AITunnel.GetOtherTunnelEnd(a);
	return -1;
}

function RailFollower::UnSteepSlope(slope)
// return the slope without the steep part
{
	if (slope == AITile.SLOPE_STEEP_N)	return AITile.SLOPE_N;
	if (slope == AITile.SLOPE_STEEP_E)	return AITile.SLOPE_E;
	if (slope == AITile.SLOPE_STEEP_S)	return AITile.SLOPE_S;
	if (slope == AITile.SLOPE_STEEP_W)	return AITile.SLOPE_W;
	return slope;
}

function RailFollower::SlopeHaveTwoCorners(slope, aim_slope)
// return true if by adding each (0, N, E, S, W) we endup with aim_slope
{
	local corner_list = [0, AITile.SLOPE_N, AITile.SLOPE_W, AITile.SLOPE_S, AITile.SLOPE_E];
	foreach (corners in corner_list)	if (slope + corners == aim_slope)	return true;
	return false;
}

function RailFollower::Is_Forced_Bridge(a, b)
// check if the bridge from a->b must be build or not (if we cannot build in between, we are force to build one
// return true/false
{
	// get list of tiles to consider
	local tile_list = RailFollower.Convert_Jump_To_Tiles(a, b);
	print("force a: "+a+" b: "+b+" tile_list: "+tile_list.len());
	local from_tile = a;
	local z = AITestMode();
	local to_tile;
	for (local i = 0; i < tile_list.len(); i++)
        {
		if (i < tile_list.len() - 1)	to_tile = tile_list[i + 1];
								else	to_tile = b;
		if (!AIRail.BuildRail(from_tile, tile_list[i], to_tile))
			{
			AILog.Warning("cannot build rail at "+cMisc.Locate(tile_list[i])+" forced bridge");
			return true;
			}
		from_tile = tile_list[i];
		}
	return false;
}

function RailFollower::Count_Tiles_Inside(_array_, a, b)
// count number of tiles between a & b in _array_
// return number of tiles
{
	local count = 0;
	local match = false;
	for (local i = 0; i < _array_.len(); i++)
		{
		if (_array_[i] == a)	{ match = true; continue; }
		if (!match)	continue;
		if (_array_[i] == b)	break;
		count++;
		}
	return count;
}

function RailFollower::Convert_Jump_To_Tiles(a, b)
// convert a jump from tile a->b into all tiles between a & b (a & b exclude), like in bridge or tunnel
// return an array
{
	local direction = cDirection.GetDirection(a, b);
	//print("a="+a+" b="+cMisc.Locate(b));
	local front = cDirection.GetForwardRelativeFromDirection(direction);
	local distance = AITile.GetDistanceManhattanToTile(a, b); // our safeguard
	local tile_list = [];
	local start_tile = a;
//	tile_list.push(a);
	while (start_tile + front != b && tile_list.len() < distance +1)
		{
		start_tile += front;
		tile_list.push(start_tile);
        }
	return tile_list;
}

function cBuilder::Path_Optimizer_MoreBridgeTunnel(partial_path)
{
	print("area size: " + partial_path.len());
	if (partial_path.len() < 4)	return partial_path; // 1 tile before entry + 2 tile length + 1 tile at exit
	local bridgecheck = [];
	local tunnelcheck = AIList();
    local tunnel_edge = [AITile.SLOPE_NW, AITile.SLOPE_SE, AITile.SLOPE_SW, AITile.SLOPE_NE];
    local bad_bridge_edge = [AITile.SLOPE_NWS, AITile.SLOPE_WSE, AITile.SLOPE_SEN, AITile.SLOPE_ENW];
	local max_bridge_length = AIGameSettings.GetValue("max_bridge_length");

	// no work on first tile and no work on last two tiles
	for (local i = 1; i < partial_path.len() - 2; i++)
		{
		local tile = partial_path[i];
		local tile_slope = RailFollower.UnSteepSlope(AITile.GetSlope(tile));
		local tile_height_max = AITile.GetMaxHeight(tile);
		local tile_X = AIMap.GetTileX(tile);
		local tile_Y = AIMap.GetTileY(tile);
		print(" ");
		print("tile : "+cMisc.Locate(tile, true)+" XY: "+tile_X+"/"+tile_Y+" h: "+tile_height_max+" slope: "+tile_slope);
		AISign.BuildSign(tile, tile.tostring());
		if (!AITile.IsBuildable(tile))	continue;
		// check tunnels first
        if (cMisc.InArray(tunnel_edge, tile_slope) != -1)
				{
				local istunnel = RailFollower.CanBuildTunnel(tile, partial_path[i - 1]);
				// check the end of tunnel is in our tiles list, we don't want build a tunnel that goes out of path
				if (istunnel != -1 && cMisc.InArray(partial_path, istunnel) != -1)
						{
						if (!tunnelcheck.HasItem(tile) && !tunnelcheck.HasItem(istunnel))
							{
							// we add it both way, as we may use the other side to create it instead, staying blind to tunnel direction
							tunnelcheck.AddItem(tile, istunnel);
							tunnelcheck.AddItem(istunnel, tile);
							continue; // don't let it check for a bridge if we have found a tunnel
							}
						}
				}
		// now find all possibles bridges we can build for each tiles
		// we will never be able to build bridge over these slopes
		if (cMisc.InArray(bad_bridge_edge, tile_slope) != -1)	continue;
		for (local z = i + 1; z  < partial_path.len() - 1; z++)
			{
			local target = partial_path[z];
            local direction = cDirection.GetDirection(tile, target);
            local front_tile = cDirection.GetForwardRelativeFromDirection(direction);
            // check we will have a tile after its end
            if (partial_path[z + 1] != target + front_tile)	continue;
            // check we will have a tile before the start
            if (partial_path[i - 1] != tile - front_tile)	continue;
            // check if the target is already use for tunnels
            if (tunnelcheck.HasItem(target))	continue;
            // check the target tile is in a straight line from tile
			if (tile_X != AIMap.GetTileX(target) && tile_Y != AIMap.GetTileY(target))	continue;
			//	{ print("not straight line c_tile X/Y: "+c_tile_X+"/"+c_tile_Y+" tile x/y: "+AIMap.GetTileX(tile)+"/"+AIMap.GetTileY(tile)); continue; }
			// check start height and end height aren't too big
			if (abs(tile_height_max - AITile.GetMaxHeight(target)) > 1)	continue;
            if (!RailFollower.CanBuildBridge(tile, target))	continue;
            // Check if that bridge is needed or not
            local force = RailFollower.Is_Forced_Bridge(tile, target);
            if (force)	{ bridgecheck.push(tile); bridgecheck.push(target); bridgecheck.push(1); bridgecheck.push(AITile.GetDistanceManhattanToTile(tile, target) + 1); }
				else	{
						// if we have choice to not build it, look if we have any interrest to build it then
						local shorter_path = false;
                        local count = RailFollower.Count_Tiles_Inside(partial_path, tile, target) + 2; // +2 to include tile & target
                        local distance = AITile.GetDistanceManhattanToTile(tile, target) + 1;
                        // Taking a shorter path is worth, but using a bridge may let the train climb to reach its start
                        // I assume the climb penalty is worth if the bridge allow us to jump half its size
                        local shorter_path = ((distance / 2) > count);
                        local max_height = -1;
                        local max_height_target = AITile.GetMaxHeight(target);
//                        local min_height_target = AITile.GetMinHeight(target);
                        local start = tile;
                        local front = cDirection.GetForwardRelativeFromDirection(cDirection.GetDirection(tile, target));
                        // We look at tiles in between the brige (real tiles, not ones from the path given
                        // And get what is the highest height found
                        while (start + front != target)	{
														local h = AITile.GetMaxHeight(start + front);
														if (h > max_height)	max_height = h;
														start += front;
														}
						// if our start and end share the height, and it is only a 2 distance, it's a tiny bridge that goes over 2 non flat tiles
						// as it is better than having vehicle doing down then up at next tile, we allow this to be a shortcut
						if (count == 2)
							{
							if (tile_height_max == max_height_target && tile_slope != AITile.SLOPE_FLAT)	shorter_path = true;
							max_height = tile_height_max; // if shorter_path isn't set, we will not build that bridge
							}
						print("count: "+count+" distance: "+distance+" shorter: "+shorter_path);
                        print("max height in between = "+max_height+ " start_h:"+tile_height_max+" target_h:"+max_height_target);
                        // if our start or end tile aren't higher than ones in between, it's not worth except if we get a shorter_path by building it
                        if ((tile_height_max <= max_height || max_height_target <= max_height) && !shorter_path)	continue;
                        AIController.Break("********* save bridge from "+cMisc.Locate(tile)+" to "+cMisc.Locate(target));
						bridgecheck.push(tile);
						bridgecheck.push(target);
						bridgecheck.push(0);
						bridgecheck.push(distance);
                        }
			}
		}
		print("all bridge list : " + bridgecheck.len() / 4);
		// now filter bridge to keep only the shortest ones if its target isn't worth
		local good_bridge = AIList();
        for (local i = 0; i < bridgecheck.len(); i++)
			{
			local s = bridgecheck[i];
			local e = bridgecheck[i + 1];
			local f = (bridgecheck[i + 2] == 1);
			local d = bridgecheck[i + 3];
			print("from: "+s+" to: "+e+" dist: "+d);
			i += 3;
			if (!good_bridge.HasItem(s))	{ good_bridge.AddItem(s, e); continue; }
			local comp_target = good_bridge.GetValue(s);
			local comp_dist = AITile.GetDistanceManhattanToTile(s, comp_target) + 1;
			print("comp_h: "+AITile.GetMaxHeight(comp_target)+" e_h: "+AITile.GetMaxHeight(e)+" comp_dist: "+comp_dist+" e_dist: "+d);
			if (AITile.GetMaxHeight(comp_target) < AITile.GetMaxHeight(e))
						{ // if our bridge goes to a higher tile, it will be better (and longer): climb longer bridge and that's all
						// else it mean climb short bridge/down short bridge/ than climb the higher height tile a little later
						print("new from "+s+" to "+e);
						good_bridge.SetValue(s, e);
						}
				else	{
						if (d < comp_dist)	good_bridge.SetValue(s, e);
						}
			}
		print("filter bridge 2: "+good_bridge.Count());
		// Now that we have best choice as target, look at best choice as source (the smaller, the better)
		local b_temp = AIList();
		b_temp.AddList(good_bridge);
		foreach (source, target in b_temp)
			{
			// resolve tunnels and bridge conflicts ; kill bridge to keep the tunnel
			if (tunnelcheck.HasItem(source) || tunnelcheck.HasItem(target))    { good_bridge.SetValue(source, -1); continue; }
			foreach (s, t in good_bridge)
				{
				if (t == -1)	continue;
				if (s == source)	continue;
				if (t == target)
					{
					if (AITile.GetMaxHeight(source) == AITile.GetMaxHeight(s))
							{
							if (AIMap.DistanceManhattan(source, target) > AIMap.DistanceManhattan(s, t))	good_bridge.SetValue(source, -1);
							break;
							}
					if (AITile.GetMaxHeight(source) < AITile.GetMaxHeight(s))
							{
							good_bridge.SetValue(source, -1);
							break;
							}
					}
//				if (t == target && AIMap.DistanceManhattan(source, target) > AIMap.DistanceManhattan(s, t))	{ good_bridge.SetValue(source, -1); break; }
				}
			}
		good_bridge.RemoveValue(-1);
        cDebug.ClearSigns();
        AIController.Break("final good bridge: "+good_bridge.Count());
        foreach (c_tile, c_target in good_bridge)	print("p_bridge: "+cMisc.Locate(c_tile)+" target: "+cMisc.Locate(c_target));
		print("tunnels: "+(tunnelcheck.Count() / 2)+" bridge: "+good_bridge.Count());
        local buffer = [];
        local buffering = -1;
        for (local i = 0; i < partial_path.len(); i++)
			{
			local tile = partial_path[i];
			if (tile == buffering)	{ buffer.push(partial_path[i]); buffering = -1; continue; }
			if (buffering == -1)
				{
				// tunnels are better than bridge, you don't need to climb to reach a tunnel entry
				if (tunnelcheck.HasItem(tile))	{
												buffer.push(partial_path[i]);
												buffering = tunnelcheck.GetValue(tile);
												AIController.Break("tunnel from " + cMisc.Locate(tile) + " to " + cMisc.Locate(buffering));
												tunnelcheck.RemoveItem(buffering); // remove the other side of tunnel as we handle it already
												// if we use these tiles for tunnels, remove any bridge trying to use them
												//if (good_bridge.HasItem(buffering))	good_bridge.RemoveItem(buffering);
												//if (good_bridge.HasItem(tile))	good_bridge.RemoveItem(tile);
												}
				if (buffering == -1 && good_bridge.HasItem(tile))
						{
						buffer.push(partial_path[i]);
						buffering = good_bridge.GetValue(tile);
						// Remove any tunnels that wish using these tiles
						//if (tunnelcheck.HasItem(tile))	tunnelcheck.RemoveItem(tile);
						//if (tunnelcheck.HasItem(buffering))	tunnelcheck.RemoveItem(buffering);
						}
				if (buffering == -1)	buffer.push(partial_path[i]);
				}
			}
	//AIController.Break("end partial path");
	return buffer;
}

function cBuilder::Path_Optimizer(path)
{
	return path;
   	if (path == null)	return;
	cBanker.RaiseFundsBigTime();
	local p0, p1;
	local save_path = path;
	local tile_counter = 0;
	local walked = [];
	local optimize_path = [];
    local p_first, p_last, o_first, o_last;
	cDebug.ClearSigns();
	while (path != null)
		{
		p0 = path.GetTile();
		if (p_first == null)	p_first = p0;
        p_last = p0;
		tile_counter++;
		if (p1 == null)	walked.push(p0); // store first point
				else	{
						if (AIMap.DistanceManhattan(p0, p1) != -1)
								{
								local z = RailFollower.Convert_Jump_To_Tiles(p1, p0);
								walked.extend(z);
								}
						walked.push(p0);
						}
		p1 = p0;
		path = path.GetParent();
		}
	optimize_path = cBuilder.Path_Optimizer_MoreBridgeTunnel(walked);
	AIController.Break("end section");
	cDebug.ClearSigns();
	print("path type "+typeof(path));
	print("savepath type "+typeof(save_path));
	AIController.Break("original: " + tile_counter + " optimize: " + optimize_path.len());
	path = save_path; // get original back
	local _path_rebuild = null;
	//local _save_parent = _path_rebuild;
	local _save_parent = null;
	local first_item = null;
	local opti_pos = 0;
	while (path != null && opti_pos < optimize_path.len())
		{
		AISign.BuildSign(path.GetTile(), "*");
		if (o_first == null)	o_first = path.GetTile();
		o_last = path.GetTile();
		path = path.GetParent();
		}
	for (local i = 0; i < optimize_path.len(); i++)
		{
		_path_rebuild = Path_Converter(optimize_path[i]);
		AISign.BuildSign(optimize_path[i],".");
		if (first_item == null)	first_item = _path_rebuild;
		if (_save_parent != null)	{ _save_parent._parent = _path_rebuild; }
		_save_parent = _path_rebuild;
		}
		print("p_first: "+p_first+" p_last: "+p_last);
		print("o_first: "+o_first+" o_last: "+o_last);
		print("arfirst: "+optimize_path[0]+" arlast: "+optimize_path[optimize_path.len()-1]);


		AIController.Break("End opti");
    cDebug.ClearSigns();
    return first_item;
}
