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
	local rail_routes = AIGroupList();
	rail_routes.Valuate(AIGroup.GetVehicleType);
	rail_routes.KeepValue(AIVehicle.VT_RAIL);
	local uid_list = [];
	local rebuildentry = [];
	foreach (grp, value in rail_routes)	if (cRoute.GroupIndexer.HasItem(grp))	uid_list.push(cRoute.GroupIndexer.GetValue(grp));
	foreach (uid in uid_list)
		{
		cDebug.ClearSigns();
		local road = cRoute.Load(uid);
		if (!road)	continue;
		// first re-assign trains state to each station (taker, droppper, using entry/exit)
		local train_list = AIVehicleList_Group(road.GroupID);
		foreach (plat, _ in road.SourceStation.s_Platforms)	cBuilder.PlatformConnectors(plat, road.Source_RailEntry);
		foreach (plat, _ in road.TargetStation.s_Platforms)	cBuilder.PlatformConnectors(plat, road.Target_RailEntry);
		train_list.Valuate(AIVehicle.GetState);
		foreach (trains, state in train_list)
			{
			cRoute.AddTrain(uid, trains);
            // We restart all trains here
			if (state == AIVehicle.VS_IN_DEPOT || state == AIVehicle.VS_STOPPED)	cCarrier.StartVehicle(trains);
			}
		DInfo("Finding rails for route "+road.Name);
		if (!road.Primary_RailLink)	{ DInfo("FindRailOwner mark "+road.UID+" undoable",1); road.RouteIsNotDoable(); continue; }
		local stationID = road.SourceStation.s_ID;
		local src_target, dst_target, src_link, dst_link = null;
		if (road.Source_RailEntry)	src_target = road.SourceStation.s_EntrySide[TrainSide.IN];
                            else	src_target = road.SourceStation.s_ExitSide[TrainSide.IN];
		if (road.Target_RailEntry)	dst_target = road.TargetStation.s_EntrySide[TrainSide.OUT];
                            else	dst_target = road.TargetStation.s_ExitSide[TrainSide.OUT];
		print("src_target="+cMisc.Locate(src_target)+" dst_target="+cMisc.Locate(dst_target));
		local bad = false;
		local src_tiles = AIList();
		local dst_tiles = AIList();
		local test_tiles = AIList();
		// Find main line tracks (source station -> destination station)
		src_link = src_target + cStationRail.GetRelativeTileBackward(road.SourceStation.s_ID, road.Source_RailEntry);
		dst_link = dst_target + cStationRail.GetRelativeTileBackward(road.TargetStation.s_ID, road.Target_RailEntry)
		src_tiles = RailFollower.GetRailPathing([src_target, src_link], [dst_target, dst_link]);
		bad = (src_tiles.IsEmpty());
		DInfo("Main line rails : "+src_tiles.Count(), 2);
		if (!src_tiles.IsEmpty())
			{
			road.SourceStation.SetPrimaryLineBuilt();
			road.TargetStation.SetPrimaryLineBuilt();
			}
		local notbad = false; // to find if at least 1 platform is working, else the station is bad/unusable
		// Find each source station platform tracks
		foreach (platnum, _ in road.SourceStation.s_Platforms)
			{
			test_tiles = RailFollower.FindRouteRails(src_target, platnum);
			if (!notbad)	notbad = (!test_tiles.IsEmpty());
			src_tiles.AddList(test_tiles);
			}
			if (!notbad && !bad)	bad = true;
			notbad = false;
		// Find each target station platform tracks
		foreach (platnum, _ in road.TargetStation.s_Platforms)
			{
			test_tiles = RailFollower.FindRouteRails(dst_target, platnum);
			if (!notbad)	notbad = (!test_tiles.IsEmpty());
			dst_tiles.AddList(test_tiles);
			}
		if (!notbad && !bad)	bad = true;
		local bad_alt = false;
		// Find the tracks from source depot -> source station
		local depot = null;
		if (road.Source_RailEntry)	depot = road.SourceStation.s_EntrySide[TrainSide.DEPOT];
                            else	depot = road.SourceStation.s_ExitSide[TrainSide.DEPOT];
		test_tiles = RailFollower.FindRouteRails(src_target, depot);
		src_tiles.AddList(test_tiles);
		// Find the tracks from target depot -> target station
		if (road.Target_RailEntry)	depot = road.TargetStation.s_EntrySide[TrainSide.DEPOT];
                            else	depot = road.TargetStation.s_ExitSide[TrainSide.DEPOT];
		test_tiles = RailFollower.FindRouteRails(dst_target, depot);
		dst_tiles.AddList(test_tiles);
		// Find alternate line tracks (target station -> source station)
		if (road.Source_RailEntry)	dst_target = road.SourceStation.s_EntrySide[TrainSide.OUT];
                            else	dst_target = road.SourceStation.s_ExitSide[TrainSide.OUT];
		if (road.Target_RailEntry)	src_target = road.TargetStation.s_EntrySide[TrainSide.IN];
                            else	src_target = road.TargetStation.s_ExitSide[TrainSide.IN];
		src_link = src_target + cStationRail.GetRelativeTileBackward(road.TargetStation.s_ID, road.Target_RailEntry);
		dst_link = dst_target + cStationRail.GetRelativeTileBackward(road.SourceStation.s_ID, road.Source_RailEntry)
		test_tiles = RailFollower.GetRailPathing([src_target, src_link], [dst_target, dst_link]);
		DInfo("Alternate line rails : "+test_tiles.Count(), 2);
		if (!bad_alt)	bad_alt = (test_tiles.IsEmpty());
		if (!bad_alt)	{ road.SourceStation.SetAlternateLineBuilt(); road.TargetStation.SetAlternateLineBuilt(); }
		dst_tiles.AddList(test_tiles);
/*		// Remove station tiles out of founded tiles : we don't want any station tile assign as a non station tiles
		src_tiles.Valuate(AITile.IsStationTile);
		src_tiles.KeepValue(0);
		dst_tiles.Valuate(AITile.IsStationTile);
		dst_tiles.KeepValue(0);*/
		// Remove all tiles we found from the "unknown" tiles list
		cRoute.RouteDamage.RemoveList(src_tiles);
		cRoute.RouteDamage.RemoveList(dst_tiles);
		// Now assign tiles to their station, and claim them
		cStation.StationClaimTile(src_tiles, road.SourceStation.s_ID, road.Source_RailEntry);
		cStation.StationClaimTile(dst_tiles, road.TargetStation.s_ID, road.Target_RailEntry);
		road.SourceStation.s_Train[TrainType.OWNER] = road.UID;
		road.TargetStation.s_Train[TrainType.OWNER] = road.UID;
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
						cCarrier.VehicleOrdersReset(trains);
						cCarrier.VehicleSendToDepot(trains, DepotAction.LINEUPGRADE);
						}
					road.RailType = -1; // force bad railtype of route to force the upgrade
					road.SourceStation.s_SubType = -1;
					road.TargetStation.s_SubType = -1;
					//	RailFollower.TryUpgradeLine(train_list.Begin());
					}

		local killit = false;
		if (bad)	killit = true;
			else	{
				// Change alternate track state if it doesn't match its real state
				if (bad_alt)
							{
							if (road.Secondary_RailLink)	{ road.Secondary_RailLink = false; road.Route_GroupNameSave(); }
							local r1, r2 = null;
							if (road.Source_RailEntry)	r1 = road.SourceStation.s_EntrySide[TrainSide.OUT];
                                                else	r1 = road.SourceStation.s_ExitSide[TrainSide.OUT];
							if (road.Target_RailEntry)	r2 = road.TargetStation.s_EntrySide[TrainSide.IN];
                                                else	r2 = road.TargetStation.s_ExitSide[TrainSide.IN];
							road.SourceStation.s_TilesOther.AddItem(r1, 0);
							road.TargetStation.s_TilesOther.AddItem(r2, 0);
							cRoute.RouteDamage.RemoveItem(r1);
							cRoute.RouteDamage.RemoveItem(r2);
							if (road.SourceStation.GetRailStationOUT(road.Source_RailEntry) != -1 && road.TargetStation.GetRailStationIN(road.Target_RailEntry) != -1) cBuilder.RailStationPathfindAltTrack(road); // pre-run pathfinding
							}
				if (!road.Secondary_RailLink && !bad_alt)	{ road.Secondary_RailLink = true; road.Route_GroupNameSave(); }
				}
		if (killit)	{
				DInfo("FindRailOwner mark "+road.UID+" undoable",1);
				road.RouteIsNotDoable();
				}
		}
	cRoute.RouteDamage.Valuate(AITile.IsStationTile);
	cRoute.RouteDamage.RemoveValue(1);
	DInfo("Unknown rails remaining : "+cRoute.RouteDamage.Count());
	cTrack.RailCleaner(cRoute.RouteDamage);
	cRoute.RouteDamage.Clear();
}

function RailFollower::TryUpgradeLine(vehicle)
{
	print("upgrade line for "+cCarrier.GetVehicleName(vehicle));
	local wagonproto = cEngineLib.VehicleGetRandomWagon(vehicle);
	if (wagonproto == -1)	{ print("bad proto"); return -1; }
	local wagon_type = AIVehicle.GetWagonEngineType(vehicle, wagonproto);
	local cargo = cEngine.GetCargoType(wagon_type);
	local loco_engine = AIVehicle.GetEngineType(vehicle);
	local upgrade_cost = 0;
	local uid = cCarrier.VehicleFindRouteIndex(vehicle);
	if (uid == null)	{ print("cannot find routeid"); return -1; }
	local road = cRoute.Load(uid);
	if (!road)	{ print("bad road"); return -1; }
	local new_railtype = cEngineLib.RailTypeGetFastestType();
	if (new_railtype == -1 || new_railtype == road.RailType)
            { print("no new railtype roadType: "+road.RailType+" new_railtype: "+new_railtype); return -1; }
    else    {
			if (cPathfinder.CheckPathfinderTaskIsRunning([road.SourceStation.s_ID, road.TargetStation.s_ID]))	{ print("No rail upgrade while pathfinder is working"); return -1; }
			print("BREAKRAIL "+cEngine.GetRailTrackName(road.RailType)+" will be replace with "+cEngine.GetRailTrackName(new_railtype));
			}
	upgrade_cost = road.SourceStation.s_MoneyUpgrade;
	DInfo("Cost to upgrade rails : "+upgrade_cost);
	if (!cBanker.CanBuyThat(upgrade_cost))	{ return 0; }
	local temp = AIList();
	local all_owners = AIList();
	local all_vehicle = AIList();
	local all_rails = AIList();
	local savetable = {};
	temp.AddList(road.SourceStation.s_Owner);
	temp.AddList(road.TargetStation.s_Owner);
	foreach (o_uid, _ in temp)
		{
		local r = cRoute.Load(o_uid);
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
		foreach (v, _ in veh)   { all_vehicle.AddItem(v, r.UID); }
		}
	if (upgrade_cost == 0)
		{
		DInfo("Number of affected rails : "+all_rails.Count());
		cDebug.showLogic(all_rails);
		local raw_basic_cost = AIRail.GetBuildCost(new_railtype, AIRail.BT_TRACK) * all_rails.Count();
		local raw_sig_cost = AIRail.GetBuildCost(new_railtype, AIRail.BT_SIGNAL) * (all_rails.Count() / 2);
		local raw_station_cost = AIRail.GetBuildCost(new_railtype, AIRail.BT_STATION) * (savetable.len() * 10);
		upgrade_cost = raw_basic_cost + raw_sig_cost + raw_station_cost;
		cDebug.ClearSigns();
		foreach (uid in savetable)	{ uid.SourceStation.s_MoneyUpgrade = upgrade_cost; uid.TargetStation.s_MoneyUpgrade = upgrade_cost; }
		}

	if (!cBanker.CanBuyThat(upgrade_cost))	{ return 0; }

	// Ok, let's call trains...
	temp = true;
	foreach (veh, _ in all_vehicle)
		{
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
	foreach (veh, uid in all_vehicle)
            {
            local z = cEngineLib.VehicleGetNumberOfWagons(veh);
            wagon_lost.push(z);
            wagon_lost.push(uid);
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
	INSTANCE.buildDelay = 1;
	DInfo("We have upgrade route "+road.Name+" to use railtype "+cEngine.GetRailTrackName(new_railtype),0);
    do
        {
        local uid = wagon_lost.pop();
        local num = wagon_lost.pop();
        print("uid = "+uid+" num="+num);
        cCarrier.ForceAddTrain(uid, num);
        }  while (wagon_lost.len() > 0);
	return 1;
}

