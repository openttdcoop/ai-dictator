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

class cLoader
	{
	constructor()
		{
		this.ClassName="cLoader";
		}
	}

function cLoader::RegisterStations()
// discover and register stations as openttd knows them
// there's still few infos our stations will lack out of this (sadly most of them are important ones, like depot)
{
	DInfo("Looking the map for our stations",0);
	local stations = AIStationList(AIStation.STATION_ANY);
	foreach (stationID, _ in stations)
		{
		cStation.InitNewStation(stationID);
		local pause=cLooper();
		}
}

function cLoader::OldSaveWarn()
// Just output a warning for old savegame format
{
	AILog.Error("WARNING");
	AILog.Info("That savegame was made with DictatorAI version "+INSTANCE.main.carrier.vehicle_cash);
	AILog.Info("I have add a compatibility loader to help restoring old savegames but it doesn't support all versions");
	AILog.Info("If you re-save your game, it will be saved with the new save format.");
	AILog.Error("WARNING");
	AIController.Sleep(40);
}

function cLoader::VehicleFindStationInOrders(vehicle)
// browse vehicle orders and return index of order that target that stationID
{
	local numorders=AIOrder.GetOrderCount(vehicle);
	if (numorders==0) { return -1; }
    local stainfo = -1;
	for (local j=0; j < numorders; j++)
		{
		local tiletarget=AIOrder.GetOrderDestination(vehicle,AIOrder.ResolveOrderPosition(vehicle, j));
		if (!AITile.IsStationTile(tiletarget)) continue;
		stainfo = AIStation.GetStationID(tiletarget);
        for (local k = 0; k < j; k++) AIOrder.RemoveOrder(vehicle, 0);
		return stainfo;
		}
	return -1;
}

function cLoader::IndustryGuesser(staID, cargo, taker)
{
    local statype = cStation.FindStationType(staID);
    if (statype == -1)  { return -1; }
    local radius = AIStation.GetCoverageRadius(staID);
    local tiles = cTileTools.GetTilesAroundPlace(AIStation.GetLocation(staID), AIStation.GetCoverageRadius(statype));
    tiles.Valuate(AIIndustry.GetIndustryID);
    indlist = AIList();
    foreach (tile, id in tiles)
        {
        if (indlist.HasItem(id))  { continue; }
        if (AIIndustry.IsValidIndustry(id)) { indlist.AddItem(id, AITile.GetCargoProduction(tile, cargo, 1, 1, radius)); }
        }
    if (taker)  {
                tiles.KeepAboveValue(1); // production
                }
        else    {
                tiles.Valuate(AIIndustry.IsCargoAccepted, cargo);
                tiles.KeepValue(1);
                }
    if (tiles.IsEmpty())    { return -1; }
                    else    { return tiles.Begin(); }
}


function cLoader::GroupGuesser()
{
    local vehlist = AIVehicleList()
    foreach (veh, _ in vehlist)
        {
        local cargoGuess = cCarrier.GetCurrentCargoType(veh);
        if (cargoGuess == -1)   continue;
        local sourcestation = cLoader.VehicleFindStationInOrders(veh);
        if (sourcestation == -1)    continue;
        local targetstation = cLoader.VehicleFindStationInOrders(veh);
        if (targetstation == -1)    continue;

        local srctown = false;
        local dsttown = false;
        if (cargoGuess == cCargo.GetPassengerCargo())   { srctown = true; dsttown = true; }
        local statype = cStation.FindStationType(statype);
        if (statype == -1)  continue;
        local src_ind = -1; dst_ind = -1;
        local tiles = cTileTools.GetTilesAroundPlace(AIStation.GetLocation(sourcestation), AIStation.GetCoverageRadius(statype));
        if (srctown)    { src_ind = AITile.GetNearestTown(AIStation.GetLocation(sourcestation)); }
                else    { src_ind = IndustryGuesser(sourcestation, cargoGuess, true); }
        if (dsttown)    { dst_ind = AITile.GetNearestTown(AIStation.GetLocation(targetstation)); }
                else    { dst_ind = IndustryGuesser(targetstation, cargoGuess, false); }
        if (src_ind == -1 || dst_ind == -1)   { continue; }
        local grptype = AIVehicle.GetVehicleType(veh);
        local grp = AIGroup.CreateGroup(veh);
        local ok = cRoute.SetRouteGroupName(grp, src_ind, dst_ind, srctown, dsttown, cargoGuess, false, sourcestation, targetstation);
        if (ok)
            {
            local vehgrp = AIVehicle.GetGroupID(veh);
            local otherveh = AIList();
            otherveh.AddItem(veh);
            if (vehgrp != AIGroup.GROUP_DEFAULT)
                {
                otherveh = AIVehicleList_Group(vehgrp);
                }
            foreach (v, _ in otherveh)
                {
                AIGroup.MoveVehicle(grp);
                vehlist.RemoveItem(v);
                }
            }
        }
}

function cLoader::Load169()
// Load savegame from version 169 & 168
{
	cLoader.OldSaveWarn();
	DInfo("Loading savegame version "+INSTANCE.main.carrier.vehicle_cash);
	local all_stations=INSTANCE.main.bank.unleash_road;
	DInfo("...Restoring stations",0);
	local iter=0;
	local allcargos=AICargoList();
	local all_routes=INSTANCE.main.carrier.vehicle_cash;
	local saveit=true;
	for (local i=0; i < all_stations.len(); i++)
		{
		saveit=true;
		local stationID=all_stations[i];
		local sobj = null;
		if (AIStation.IsValidStation(stationID))
			{
			sobj = cStation.Load(stationID);
			if (!sobj)	sobj = cStation.InitNewStation(stationID);
			if (!cMisc.ValidInstance(sobj))	saveit=false;
			}
		else	saveit = false;
		if (saveit)	sobj.s_Depot=all_stations[i+1];
		i+=1;
		if (saveit && sobj instanceof cStationRail)
			{
			local counter=all_stations[i+1];
			i+=2;
			local temparray=[];
			for (local z=0; z < counter; z++)	temparray.push(all_stations[i+z]);
			i+=(counter-1);
			if (saveit)	sobj.s_Platforms=cMisc.ArrayToList(temparray);
			counter=all_stations[i+1];
			i+=2;
			temparray=[];
			for (local z=0; z < counter; z++)	temparray.push(all_stations[i+z]);
			//if (saveit)	sobj.s_TrainSpecs =cMisc.ArrayToList(temparray); // train plaforms, lost for now
			i+=(counter-1);
			}
		}
		iter++;
	DInfo("Found "+iter+" stations.",0);

	DInfo("...Restoring routes",0);
	iter=0;
	for (local i=0; i < all_routes.len(); i++)
		{
		saveit=true;
		local obj=cRoute();
		local temp;
		local _rtype = all_routes[i];
		local _groupid = all_routes[i+1];
		local _one = all_routes[i+2];
		local _two = all_routes[i+3];
		local _three = all_routes[i+4];
		local _four =all_routes[i+5];
		i+=5;
		iter++;
		saveit = (_groupid != null);
		local src_IsTown, dst_IsTown;
		if (saveit)
			{
			local gname=AIGroup.GetName(_groupid);
			// this version use A*CargoID*I###*T###*###*### groupname
			local workarr = cMisc.SplitStars(gname);

			if (workarr.len() != 0)
				{
				obj.CargoID = workarr[1].tointeger();
				src_IsTown = (workarr[2].slice(0,1) == "T");
				dst_IsTown = (workarr[3].slice(0,1) == "T");
				}
			temp=workarr[2].slice(1).tointeger(); // source id
			obj.SourceProcess = cProcess.Load(cProcess.GetUID(temp, src_IsTown));
			temp=workarr[3].slice(1).tointeger(); // target id
			obj.TargetProcess = cProcess.Load(cProcess.GetUID(temp, dst_IsTown));
			temp=workarr[4].tointeger(); // source station id
			obj.SourceStation = cStation.Load(temp);
			temp=workarr[5].tointeger(); // target station id
			obj.TargetStation = cStation.Load(temp);
			if (saveit)	saveit = cMisc.ValidInstance(obj.SourceProcess);
			if (saveit)	saveit = cMisc.ValidInstance(obj.TargetProcess);
			if (saveit)	saveit = cMisc.ValidInstance(obj.SourceStation);
			if (saveit)	saveit = cMisc.ValidInstance(obj.TargetStation);
			if (saveit)	obj.VehicleType = _rtype;
			obj.GroupID = _groupid;
			}
		if (saveit)
			{
			local jrt= obj.VehicleType;
			local crg= obj.CargoID;
			temp = cJobs();
			temp.UID = null;
			if (jrt >= RouteType.AIR)	{ crg=cCargo.GetPassengerCargo(); jrt=RouteType.AIR; }
			temp.roadType = jrt;
			temp.cargoID = crg;
			temp.sourceObject = obj.SourceProcess;
			temp.targetObject = obj.TargetProcess;
			temp.GetUID();
			obj.UID=temp.UID;
			cJobs.CreateNewJob(obj.SourceProcess.UID, obj.TargetProcess.ID, crg, jrt, 0);	// recreate the job
			temp = cJobs.Load(obj.UID); // now load it
			if (!temp)	continue;
			temp.isUse = true;
			obj.SourceStation.OwnerClaimStation(obj.UID);
			obj.TargetStation.OwnerClaimStation(obj.UID);
			obj.VehicleType = jrt;
			cRoute.SetRouteGroupName(obj.GroupID, obj.SourceProcess.ID, obj.TargetProcess.ID, obj.SourceProcess.IsTown, obj.TargetProcess.IsTown, obj.CargoID, false, obj.SourceStation.s_ID, obj.TargetStation.s_ID);
			obj.Source_RailEntry = _one;
			obj.Target_RailEntry = _two;
			obj.Primary_RailLink = _three;
			obj.Secondary_RailLink = _four;
			obj.RouteDone();
			DInfo("Validate... "+obj.Name,0);
			}
		}
	DInfo("Found "+iter+" routes.",0);
	DInfo("Restoring trains",0);
	local all_trains=SixMonth;
	iter=0;
	for (local i=0; i < all_trains.len(); i++)
		{
		local obj=cTrain();
		obj.vehicleID=all_trains[i];
		obj.srcStationID=all_trains[i+1];
		obj.dstStationID=all_trains[i+2];
		obj.src_useEntry=all_trains[i+3];
		obj.dst_useEntry=all_trains[i+4];
		obj.stationbit=all_trains[i+5];
		obj.full=false;
		i+=5;
		cTrain.vehicledatabase[obj.vehicleID] <- obj;
		iter++;
		}
	DInfo("Found "+iter+" trains.",0);
	cRoute.RouteRebuildIndex();

}

function cLoader::LoadSaveGame()
// Load current savegame version
{
	DInfo("Loading savegame version "+INSTANCE.main.carrier.vehicle_cash);
	local num_route_ok = 0;
	local groupList = AIGroupList();
	DInfo("Found "+groupList.Count()+" possible routes");
	foreach(group, _ in groupList)
		{
		local temp_route = cRoute();
		local dead_route = false;
		temp_route.GroupID = group;
		temp_route.VehicleType = AIGroup.GetVehicleType(group);
		local gname = AIGroup.GetName(temp_route.GroupID);
		local info = cMisc.SplitStars(gname);
		if (info.len() != 7)	{ DInfo("Invalid route info length "+info.len(),1); continue; }
		temp_route.CargoID = info[1].tointeger();
		local src_IsTown = (info[2].slice(0,1) == "T");
		local dst_IsTown = (info[3].slice(0,1) == "T");
		local temp = info[2].slice(1).tointeger(); // source id
		temp_route.SourceProcess = cProcess.Load(cProcess.GetUID(temp, src_IsTown));
		temp = info[3].slice(1).tointeger(); // target id
		temp_route.TargetProcess = cProcess.Load(cProcess.GetUID(temp, dst_IsTown));
		temp = info[4].tointeger(); // source station id
		if (temp_route.VehicleType == AIVehicle.VT_AIR && !src_IsTown) // chopper need the platform as station
            {
            local staID = AIStation.GetStationID(temp_route.SourceProcess.Location);
  			local t = cStation.InitNewStation(staID);
  			t.s_SubType = -2;
  			// TODO: fix platform
            }
		temp_route.SourceStation = cStation.Load(temp);
		temp = info[5].tointeger(); // target station id
		temp_route.TargetStation = cStation.Load(temp);
		temp = info[6].tointeger(); // the info for rails
		temp_route.Source_RailEntry = cMisc.CheckBit(temp, 0);
		temp_route.Target_RailEntry = cMisc.CheckBit(temp, 1);
		temp_route.Primary_RailLink = cMisc.CheckBit(temp, 2);
		temp_route.Secondary_RailLink = cMisc.CheckBit(temp, 3);
		if (!cMisc.ValidInstance(temp_route.SourceProcess))	{ DInfo("Bad source process: "+temp_route.SourceProcess,1); dead_route = true; }
		if (!cMisc.ValidInstance(temp_route.TargetProcess))	{ DInfo("Bad target process: "+temp_route.SourceProcess,1); dead_route = true; }
		if (!cMisc.ValidInstance(temp_route.SourceStation))	{ DInfo("Bad source station: "+temp_route.SourceStation,1); dead_route = true; }
		if (!cMisc.ValidInstance(temp_route.TargetStation))	{ DInfo("Bad target station: "+temp_route.TargetStation,1); dead_route = true; }
		if (dead_route) {
						temp_route.Status = RouteStatus.DEAD;
						local veh_list = AIVehicleList_Group(group);
						if (!veh_list.IsEmpty())
							{
							foreach (veh, _ in veh_list)	{ AIVehicle.SendVehicleToDepot(veh); }
							}
						local wait = 0;
						local count = veh_list.Count();
						foreach (veh, _ in veh_list)
							{
							local removed = false;
							while (wait < 100 && AIVehicle.GetState(veh) != AIVehicle.VS_IN_DEPOT)
								{
								AIController.Sleep(10);
								wait++;
								}
							}
						}
		if (dead_route)	{ continue; }
		if (temp_route.VehicleType == AIVehicle.VT_AIR)
			{
			if (AIStation.IsAirportClosed(temp_route.SourceStation.s_ID))	AIStation.OpenCloseAirport(temp_route.SourceStation.s_ID);
			if (AIStation.IsAirportClosed(temp_route.TargetStation.s_ID))	AIStation.OpenCloseAirport(temp_route.TargetStation.s_ID);
			}
        temp = cJobs();
		temp.UID = null;
		temp.cargoID = temp_route.CargoID;
		temp.roadType = temp_route.VehicleType;
		if (temp.roadType >= RouteType.AIR)	{ temp.cargoID = cCargo.GetPassengerCargo(); temp.roadType = RouteType.AIR; }
		temp.sourceObject = temp_route.SourceProcess;
		temp.targetObject = temp_route.TargetProcess;
		temp.GetUID();
		temp_route.UID = temp.UID;
		temp_route.Distance = AIMap.DistanceManhattan(temp_route.SourceProcess.Location, temp_route.TargetProcess.Location);
		cJobs.CreateNewJob(temp_route.SourceProcess.UID, temp_route.TargetProcess.ID, temp.cargoID, temp.roadType, temp_route.Distance);	// recreate the job
		temp = cJobs.Load(temp_route.UID); // now try load it
		if (!temp)	continue;
		temp.isUse = true;
		temp_route.SourceStation.OwnerClaimStation(temp_route.UID);
		temp_route.TargetStation.OwnerClaimStation(temp_route.UID);
		temp_route.RouteDone();
		DInfo("Validate... "+temp_route.Name,0);
		num_route_ok++;
		}
	DInfo("Found "+num_route_ok+" routes");
	DInfo("Restoring "+main.bank.unleash_road.len()+" stations");
		{
		for (local i=0; i < main.bank.unleash_road.len(); i++)
			{
			local sta = cStation.Load(main.bank.unleash_road[i]);
			local valid = (sta != false);
			if (!valid)	{ i++; AISign.BuildSign(main.bank.unleash_road[i], "D"); continue; }

			local depot = main.bank.unleash_road[i+1]; i++;
			sta.s_Depot = depot;
			if (sta instanceof cStationRail)
				{
				sta.s_Train[0] = main.bank.unleash_road[i+1];
				i++;
				for (local j=0; j < sta.s_EntrySide.len(); j++)
					{
					sta.s_EntrySide[j] = main.bank.unleash_road[i+1];
					i++;
					}
				for (local j=0; j < sta.s_ExitSide.len(); j++)
					{
					sta.s_ExitSide[j] = main.bank.unleash_road[i+1];
					i++;
					}
				}
			}
		}
	cRoute.RouteRebuildIndex();
	RailFollower.FindRailOwner();
}

function cLoader::LoadOther()
{
    cLoader.GroupGuesser();
    cLoader.LoadSaveGame();
}

function cLoader::LoadingGame()
{
	cLoader.RegisterStations();
	local planelist=AIVehicleList_Group(INSTANCE.main.bank.mincash); // restore the network aircraft
	foreach (veh, dummy in planelist)	AIGroup.MoveVehicle(cRoute.VirtualAirGroup[0],veh);
	planelist=AIVehicleList_Group(INSTANCE.TwelveMonth);
	foreach (veh, dummy in planelist)	AIGroup.MoveVehicle(cRoute.VirtualAirGroup[1],veh);
	AIGroup.DeleteGroup(INSTANCE.main.bank.mincash);
	AIGroup.DeleteGroup(TwelveMonth);
	local trlist=AIVehicleList();
	//try
	//{
	if (INSTANCE.main.carrier.vehicle_cash < 170)	cLoader.Load169();
                                            else	cLoader.LoadSaveGame();
	local grouplist = AIGroupList();
	grouplist.RemoveList(cRoute.GroupIndexer);
	foreach (grp, _ in grouplist)	AIGroup.DeleteGroup(grp);
	trlist.Valuate(AIVehicle.GetVehicleType);
	trlist.KeepValue(AIVehicle.VT_RAIL);
	trlist.Valuate(AIVehicle.GetState);
	trlist.RemoveValue(AIVehicle.VS_RUNNING);
	if (!trlist.IsEmpty())
		{
		DInfo("Restarting stopped trains",0);
		foreach (veh, dummy in trlist)
			{
			cCarrier.TrainExitDepot(veh);
			}
		}
	//} catch (z)
      /*  {
        try { cLoader.LoadOther(); }
            catch (e)
            {
            AILog.Error("Cannot load that savegame !");
            AILog.Info("As a last chance, the AI will try to continue ignoring the error, with a total random result...");
            local grouplist=AIGroupList();
            grouplist.RemoveItem(cRoute.VirtualAirGroup[0]);
            grouplist.RemoveItem(cRoute.VirtualAirGroup[1]);
            foreach (grp, dummy in grouplist)	AIGroup.DeleteGroup(grp);
            local vehlist=AIVehicleList();
            foreach (veh, dummy in vehlist)	AIVehicle.SendVehicleToDepot(veh);
            foreach (item in cRoute.database)	if (item.UID > 1)	delete cRoute.database[item.UID];
            cRoute.RouteIndexer.Clear();
            cRoute.GroupIndexer.Clear();
            }
        }*/
	OneWeek=0;
	OneMonth=0;
	SixMonth=0;
	TwelveMonth=0;
	cRoute.RouteDamage.Clear(); // static, only clear it
	INSTANCE.main.bank.canBuild=false;
	INSTANCE.main.bank.unleash_road=false;
	INSTANCE.main.carrier.vehicle_cash = 0;
	INSTANCE.main.bank.mincash=10000;
	cCargo.SetCargoFavorite();
	local dead = AIList();
    dead = AIVehicleList_DefaultGroup(AIVehicle.VT_ROAD);
    trlist.AddList(AIVehicleList_DefaultGroup(AIVehicle.VT_AIR));
    dead.AddList(trlist);
	trlist.AddList(AIVehicleList_DefaultGroup(AIVehicle.VT_RAIL));
	dead.AddList(trlist);
	foreach (veh, _ in dead)	AIVehicle.SendVehicleToDepot(veh); // reset ungroup vehicle so we will catch them fast
	local alltowns=AITownList();
	INSTANCE.main.builder.CheckRouteStationStatus();
}

