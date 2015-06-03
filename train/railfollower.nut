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
		src_tile = road.SourceStation.s_MainLine;
		src_link = src_tile - forward;
		dst_tile = road.TargetStation.s_AltLine;
		dst_link = dst_tile + forward;
		src_tiles = RailFollower.GetRailPathing([src_tile, src_link], [dst_tile, dst_link]);
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
	local safekeeper = all_vehicle.Begin();
	local safekeeper_depot = AIVehicle.GetLocation(safekeeper);
	local wagon_lost = [];
	foreach (groups, _ in groups_list)	wagon_lost.push(cCarrier.GetTrainBalancingStats(groups, 0, false));
//	AIController.Break("stop");
	foreach (veh, uid in all_vehicle)
            {
/*            local z = cEngineLib.VehicleGetNumberOfWagons(veh);
            wagon_lost.push(z);
            wagon_lost.push(uid);*/
            if (veh != safekeeper)  {
                                    cCarrier.VehicleSell(veh, false);
                                    if (cCarrier.ToDepotList.HasItem(veh))  cCarrier.ToDepotList.RemoveItem(veh);
                                    }
            }
	all_rails.RemoveItem(safekeeper_depot);
    foreach (tiles, _ in all_rails)
        {
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
				AIController.Break("bridge/tunnel");
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
			AIController.Break("walked: "+walked.len());
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
	local dist = AIMap.DistanceManhattan(a, b);
	local bridge_id = cBridge.GetCheapBridgeID(AIVehicle.VT_RAIL, dist, true);
	print("bridgeid ="+bridge_id + AIBridge.GetName(bridge_id));
	if (bridge_id == -1)	return false;
	local test = AITestMode();
	local c = AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridge_id, a, b);
	if (c == false) { DError("no bridge build: ",0); }
	return c;
}

function RailFollower::CanBuildTunnel(a)
// return the other tunnel tile if we can build one
{
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

function cBuilder::Path_Optimizer_MoreBridgeTunnel(p)
{
	print("area size: "+p.len());
	local bridgecheck = AIList();
	local tunnelcheck = AIList();
    local tunnel_edge = [AITile.SLOPE_NW, AITile.SLOPE_SE, AITile.SLOPE_SW, AITile.SLOPE_NE];
    local bad_bridge_edge = [AITile.SLOPE_FLAT, AITile.SLOPE_NWS, AITile.SLOPE_WSE, AITile.SLOPE_SEN, AITile.SLOPE_ENW];
//    local bridge_edge_NW = [AITile.SLOPE_SE, AITile.SLOPE_S, AITile.SLOPE_E];
 //   local bridge_edge_NE = [AITile.SLOPE_SW, AITile.SLOPE_S, AITile.SLOPE_W];
 //   local STEEP_BIT = 16;
	for (local i = 0; i < p.len(); i++)
		{
		local tile = p[i];
		local tile_slope = RailFollower.UnSteepSlope(AITile.GetSlope(tile));
		//local tile_min = AITile.GetMinHeight(tile);
		local tile_max = AITile.GetMaxHeight(tile);
        if (cMisc.InArray(tunnel_edge, tile_slope) != -1)
				{
				local istunnel = RailFollower.CanBuildTunnel(tile);
				if (istunnel != -1 && cMisc.InArray(p, istunnel) != -1) // we don't want build a tunnel that goes out of path
						{
						if (istunnel != tile)	tunnelcheck.AddItem(tile, istunnel);
										else	tunnelcheck.AddItem(istunnel, tile); // because we found it from other side
						}
				}
		if (cMisc.InArray(bad_bridge_edge, tile_slope) != -1)	continue;
		local slope_NW = false;
		local slope_NE = false;
		if (RailFollower.SlopeHaveTwoCorners(tile_slope, AITile.SLOPE_NW) || RailFollower.SlopeHaveTwoCorners(tile_slope, AITile.SLOPE_SE))	slope_NW = true;
		if (RailFollower.SlopeHaveTwoCorners(tile_slope, AITile.SLOPE_NE) || RailFollower.SlopeHaveTwoCorners(tile_slope, AITile.SLOPE_SW))	slope_NE = true;
		if (slope_NW || slope_NE)	bridgecheck.AddItem(tile, -1);
		foreach (c_tile, c_target in bridgecheck)
				{
				if (c_target != -1)	continue; // ignore it, we have the target already
				if (c_tile == tile)	continue; // ignore it, we have just add it
				if (tile_max != AITile.GetMaxHeight(c_tile))	continue; // must be at same max height
				if (AIMap.GetTileX(c_tile) == AIMap.GetTileX(tile))	// going NW_SE
							{ if (slope_NW)	bridgecheck.SetValue(c_tile, tile); }
					else	{ if (slope_NE)	bridgecheck.SetValue(c_tile, tile); }
				}
		}
        print("potentials bridge: "+bridgecheck.Count());
		bridgecheck.RemoveValue(-1); // remove bridge we didnt find a target for
		print("tunnels: "+tunnelcheck.Count()+" bridge: "+bridgecheck.Count());
        local buffer = [];
        local buffering = -1;
        for (local i = 0; i < p.len(); i++)
			{
			local tile = p[i];
			AISign.BuildSign(tile, "o");
			if (tile == buffering)	{ buffer.push(tile); buffering = -1; continue; }
			if (buffering == -1)
				{
				// tunnels are better than bridge, you don't need to climb any tile to reach a tunnel entry
				if (tunnelcheck.HasItem(tile))	{
				// build side like dock
												buffer.push(tile);
												buffering = tunnelcheck.GetValue(tile);
												AIController.Break("tunnel from " + cMisc.Locate(tile) + " to " + cMisc.Locate(buffering));
												}
				if (buffering == -1 && bridgecheck.HasItem(tile))
						{
						local target = bridgecheck.GetValue(tile);
						local dist = AIMap.DistanceManhattan(tile, target);
						if (dist != 1 && RailFollower.CanBuildBridge(tile, target))
									{
									buffer.push(tile);
									buffering = target;
									AIController.Break("bridge from " + cMisc.Locate(tile) + " to " + cMisc.Locate(target));
									}
							else	{ AIController.Break("terraform from " + cMisc.Locate(tile) + " to " + cMisc.Locate(target)); cTerraform.TerraformLevelTiles(tile, target); }
						}
				if (buffering == -1)	buffer.push(tile);
				}
			}
	return buffer;
}

function cBuilder::Path_Optimizer(path)
{
	if (path == null)	return;
	cBanker.RaiseFundsBigTime();
	local p1, p2, p3, p4 = null;
	local min_height, max_height;
	local tile_counter = 0;
	local noturn, barrier;
	local walked = [];
	local optimize_path = [];
	cDebug.ClearSigns();
	local limit = min(AIGameSettings.GetValue("max_bridge_length"), AIGameSettings.GetValue("max_tunnel_length"));
	while (path != null)
		{
		local p0 = path.GetTile();
		tile_counter++;
		if (p1 != null && AIMap.DistanceManhattan(p0, p1) != 1)
				{
				AIController.Break("bridge/tunnel");
				p1 = null;
				optimize_path.push(p0);
				}
		if (p1 != null && AITile.GetSlope(p0) == AITile.SLOPE_FLAT && walked.len() == 0)
				{
				walked = [];
				walked.push(p0);
                noturn = true;
                max_height = AITile.GetMaxHeight(p0);
                min_height = AITile.GetMinHeight(p0);
				}
		local store = false;
		if (p1 != null && walked.len() > 0 && p0 != walked[0] && (AIMap.GetTileX(walked[0]) == AIMap.GetTileX(p0) || AIMap.GetTileY(walked[0]) == AIMap.GetTileY(p0)) && AIMap.DistanceManhattan(p0, walked[0]) <= limit)	{ store = true; walked.push(p0); }
		if (p1 != null && !store && walked.len() > 1)
					{
                    walked = cBuilder.Path_Optimizer_MoreBridgeTunnel(walked);
                    optimize_path.extend(walked);
                    walked = [];
					}
		cDebug.ClearSigns();
		p1 = p0;
		path = path.GetParent();
		}
	if (walked.len() != 0)	{
							walked = cBuilder.Path_Optimizer_MoreBridgeTunnel(walked);
							optimize_path.extend(walked);
							}
	AIController.Break("original: " + tile_counter + " optimize: " + optimize_path.len());
}
