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

function cLoader::OldSaveWarn()
// Just output a warning for old savegame format
{
	AILog.Error("WARNING");
	AILog.Info("That savegame was made with DictatorAI version "+INSTANCE.main.bank.busyRoute);
	AILog.Info("I have add a compatibility loader to help restoring old savegames but it doesn't support all versions");
	AILog.Info("If the AI crash, please bugreport the savegame version and AI version in use.");
	AILog.Info("If you re-save your game, it will be saved with the new save format.");
	AILog.Error("WARNING");
	INSTANCE.Sleep(20);
}

function cLoader::ConvertOldSave()
// Last action common to old save game
{
	local airlist=AIVehicleList_DefaultGroup(AIVehicle.VT_AIR);
	foreach (veh, dummy in airlist)	AIGroup.MoveVehicle(cRoute.GetVirtualAirPassengerGroup(), veh);
	DInfo("Registering our routes",0);
	foreach (routeUID, dummy in cRoute.RouteIndexer)
		{
		local aroute=cRoute.GetRouteObject(routeUID);
		if (aroute=null)	continue;
		if (aroute.UID < 2)	continue;
		if (!aroute.isWorking)	continue;
		local rt=aroute.route_type;
		if (rt > AIVehicle.VT_AIR)	rt=AIVehicle.VT_AIR;
		local pUID = cProcess.GetUID(aroute.sourceID, aroute.source_istown);
		cJobs.CreateNewJob(pUID, aroute.targetID, aroute.cargoID, rt, 0);
		}
	DInfo("Tagging jobs in use",0);
	foreach (jobID, dummy in cJobs.jobIndexer)
		{
		local ajob=cJobs.Load(jobID);
		if (!ajob)	continue;
		ajob.isUse=true;
		}
}

function cLoader::LoadOldSave()
// loading a savegame with version < 152
{
	cLoader.OldSaveWarn();
	local all_stations=INSTANCE.main.bank.unleash_road;
	DInfo("Restoring stations",0);
	local iter=0;
	local allcargos=AICargoList();
	for (local i=0; i < all_stations.len(); i++)
		{
		local obj=cStation();
		obj.stationID=all_stations[i];
		obj.stationType=all_stations[i+1];
		obj.specialType=all_stations[i+2];
		obj.size=all_stations[i+3];
		obj.maxsize=all_stations[i+4];
		obj.depot=all_stations[i+5];
		obj.radius=all_stations[i+6];
		local counter=all_stations[i+7];
		local nextitem=i+8+counter;
		local temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[i+8+z]);
		obj.locations=cMisc.ArrayToList(temparray);
		counter=all_stations[nextitem];
		temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]);
		i=nextitem+counter;
		iter++;
		obj.StationSave();
		}
	DInfo(iter+" stations found.",0);
	DInfo("base size: "+INSTANCE.main.bank.unleash_road.len()+" dbsize="+cStation.stationdatabase.len()+" savedb="+OneMonth,1);
	DInfo("Restoring routes",0);
	iter=0;
	local all_routes=INSTANCE.main.bank.canBuild;
	for (local i=0; i < all_routes.len(); i++)
		{
		local obj=cRoute();
		obj.UID=all_routes[i];
		obj.sourceID=all_routes[i+1];
		obj.source_location=all_routes[i+2];
		obj.source_istown=all_routes[i+3];
		obj.targetID=all_routes[i+4];
		obj.target_location=all_routes[i+5];
		obj.target_istown=all_routes[i+6];
		obj.route_type=all_routes[i+7];
		obj.station_type=all_routes[i+8];
		obj.isWorking=all_routes[i+9];
		obj.status=all_routes[i+10];
		obj.groupID=all_routes[i+11];
		obj.source_stationID=all_routes[i+12];
		obj.target_stationID=all_routes[i+13];
		obj.cargoID=all_routes[i+14];
		i+=14;
		iter++;
		if (obj.UID > 1)	// don't save old virtual network
				{
				cRoute.database[obj.UID] <- obj;
				if (obj.groupID != null)	cRoute.GroupIndexer.AddItem(obj.groupID,obj.UID);
				cRoute.SetRouteGroupName(obj.groupID, obj.sourceID, obj.targetID, obj.source_istown, obj.target_istown, obj.cargoID, false);
				}
			else	if (AIGroup.IsValidGroup(obj.groupID))	AIGroup.DeleteGroup(obj.groupID);
		obj.RouteCheckEntry(); // re-enable the link to stations
		if (obj.UID > 1)
			{ // don't try this one virtual routes
			if (obj.source_entry)
				{
				obj.source.cargo_produce.AddItem(obj.cargoID,0);
				obj.source.cargo_accept.AddItem(obj.cargoID,0);
				}
			if (obj.target_entry)
				{
				obj.target.cargo_produce.AddItem(obj.cargoID,0);
				obj.target.cargo_accept.AddItem(obj.cargoID,0);
				}
			if (obj.route_type >= RouteType.AIR)	obj.RouteAirportCheck();
			}
		obj.RouteUpdateVehicle();
		}
	cRoute.RouteRebuildIndex();
	DInfo(iter+" routes found.",0,"main");
	DInfo("base size: "+INSTANCE.main.bank.canBuild.len()+" dbsize="+cRoute.database.len()+" savedb="+OneWeek,2,"main");
	ConvertOldSave();
}

function cLoader::Load154()
{
	cLoader.OldSaveWarn();
	local all_stations=INSTANCE.main.bank.unleash_road;
	local revision=false;
	if (INSTANCE.main.bank.busyRoute == 155)	revision=true;
	DInfo("Restoring stations",0,"main");
	local iter=0;
	local allcargos=AICargoList();
	for (local i=0; i < all_stations.len(); i++)
		{
		local obj=cStation();
		obj.stationID=all_stations[i];
		obj.stationType=all_stations[i+1];
		obj.specialType=all_stations[i+2];
		obj.size=all_stations[i+3];
		obj.maxsize=all_stations[i+4]; //1000
		obj.depot=all_stations[i+5];
		obj.radius=all_stations[i+6];
		local counter=all_stations[i+7];
		local nextitem=i+8+counter;
		local temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[i+8+z]);
		obj.locations=cMisc.ArrayToList(temparray);
		counter=all_stations[nextitem];
		temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]);
		obj.platforms=cMisc.ArrayToList(temparray);
		nextitem+=counter+1;
		counter=all_stations[nextitem];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]);
		obj.station_tiles=cMisc.ArrayToList(temparray);
		i=nextitem+counter;
		iter++;
		obj.StationSave();
		}
	DInfo(iter+" stations found.",0);
	DInfo("base size: "+INSTANCE.main.bank.unleash_road.len()+" dbsize="+cStation.stationdatabase.len()+" savedb="+OneMonth,1);
	DInfo("Restoring routes",0);
	iter=0;
	local all_routes=INSTANCE.main.bank.canBuild;
	for (local i=0; i < all_routes.len(); i++)
		{
		local obj=cRoute();
		obj.UID=all_routes[i];
		obj.sourceID=all_routes[i+1];
		obj.source_istown=all_routes[i+2];
		if (obj.UID > 1)	// don't try this on virtual network
			{ 
			if (obj.source_istown)	obj.source_location=AITown.GetLocation(obj.sourceID);
						else	obj.source_location=AIIndustry.GetLocation(obj.sourceID);
			}
		obj.targetID=all_routes[i+3];
		obj.target_istown=all_routes[i+4];
		if (obj.UID > 1)
			{
			if (obj.target_istown)	obj.target_location=AITown.GetLocation(obj.targetID);
						else	obj.target_location=AIIndustry.GetLocation(obj.targetID);
			}
		obj.route_type=all_routes[i+5];
		obj.station_type=all_routes[i+6];
		obj.isWorking=all_routes[i+7];
		obj.status=all_routes[i+8];
		obj.groupID=all_routes[i+9];
		obj.source_stationID=all_routes[i+10];
		obj.target_stationID=all_routes[i+11];
		obj.cargoID=all_routes[i+12];
		obj.primary_RailLink=all_routes[i+13];
		obj.secondary_RailLink=all_routes[i+14];
		obj.twoway=all_routes[i+15];
		if (!revision)	i+=15;
				else	{ // newer savegame from 155
					obj.source_RailEntry=all_routes[i+16];
					obj.target_RailEntry=all_routes[i+17];
					i+=17;
					}
		iter++;
		if (obj.UID > 1)	// don't save old virtual network
				{
				cRoute.database[obj.UID] <- obj;
				if (obj.groupID != null)	cRoute.GroupIndexer.AddItem(obj.groupID,obj.UID);
				cRoute.SetRouteGroupName(obj.groupID, obj.sourceID, obj.targetID, obj.source_istown, obj.target_istown, obj.cargoID, false);
				}
			else	if (obj.groupID!=null && AIGroup.IsValidGroup(obj.groupID))	AIGroup.DeleteGroup(obj.groupID);
		obj.RouteCheckEntry(); // re-enable the link to stations
		if (obj.UID > 1)
			{ // don't try this on virtual routes
			if (obj.source_entry)
				{
				obj.source.cargo_produce.AddItem(obj.cargoID,0);
				obj.source.cargo_accept.AddItem(obj.cargoID,0);
				}
			if (obj.target_entry)
				{
				obj.target.cargo_produce.AddItem(obj.cargoID,0);
				obj.target.cargo_accept.AddItem(obj.cargoID,0);
				}
			if (obj.route_type >= RouteType.AIR)	obj.RouteAirportCheck();
			}
		}
	DInfo(iter+" routes found.",0);
	DInfo("base size: "+INSTANCE.main.bank.canBuild.len()+" dbsize="+cRoute.database.len()+" savedb="+OneWeek,2);
	DInfo("Restoring trains",0);
	local all_trains=SixMonth;
	for (local i=0; i < all_trains.len(); i++)
		{
		local obj=cTrain();
		obj.vehicleID=all_trains[i];
		obj.srcStationID=all_trains[i+1];
		obj.dstStationID=all_trains[i+2];
		obj.src_useEntry=all_trains[i+3];
		obj.dst_useEntry=all_trains[i+4];
		obj.stationbit=all_trains[i+5];
		obj.full=all_trains[i+6];
		i+=6;
		cTrain.vehicledatabase[obj.vehicleID] <- obj;
		cTrain.Update(obj.vehicleID);
		}
	cRoute.RouteRebuildIndex();
	ConvertOldSave();
}

function cLoader::LoadSaveGame()
// The latest load function
	{
	local all_stations=INSTANCE.main.bank.unleash_road;
	DInfo("...Restoring stations",0);
	local iter=0;
	local allcargos=AICargoList();
	local saveit=true;
	for (local i=0; i < all_stations.len(); i++)
		{
		saveit=true;
		local obj=cStation();
		obj.stationID=all_stations[i];
		if (!AIStation.IsValidStation(obj.stationID))	saveit=false;
			else	obj.stationType=cStation.FindStationType(obj.stationID);
		obj.specialType=all_stations[i+1];
		obj.size=all_stations[i+2];
		obj.depot=all_stations[i+3];
		if (obj.stationType == AIStation.STATION_AIRPORT)	obj.radius=AIAirport.GetAirportCoverageRadius(obj.specialType);
										else	obj.radius=AIStation.GetCoverageRadius(obj.stationType);
		local counter=all_stations[i+4];
		local nextitem=i+5+counter;
		local temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[i+5+z]);
		obj.locations=cMisc.ArrayToList(temparray);
		counter=all_stations[nextitem];
		temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]);
		obj.platforms=cMisc.ArrayToList(temparray);
		obj.maxsize=1;
		if (obj.stationType == AIStation.STATION_BUS_STOP || obj.stationType == AIStation.STATION_TRUCK_STOP)	obj.maxsize=INSTANCE.main.carrier.road_max;
		if (obj.stationType == AIStation.STATION_TRAIN)	obj.maxsize=INSTANCE.main.carrier.rail_max;
		i=nextitem+counter;
		iter++;
		if (saveit)	obj.StationSave();
		}
	DInfo("Found "+iter+" stations.",0);
	local all_routes=INSTANCE.main.bank.canBuild;
	DInfo("...Restoring routes",0);
	iter=0;
	for (local i=0; i < all_routes.len(); i++)
		{
		saveit=true;
		local obj=cRoute();
		obj.route_type=all_routes[i+0];
		obj.status=all_routes[i+1];
		obj.groupID=all_routes[i+2];
		obj.source_stationID=all_routes[i+3];
		obj.target_stationID=all_routes[i+4];
		obj.primary_RailLink=all_routes[i+5];
		obj.secondary_RailLink=all_routes[i+6];
		obj.source_RailEntry=all_routes[i+7];
		obj.target_RailEntry=all_routes[i+8];
		i+=8;
		iter++;
		local gname=AIGroup.GetName(obj.groupID);
		local cc=0;
		local workstr=gname.slice(2); // discard 2 first char
		for (cc=0; cc < workstr.len(); cc++)
			if (workstr.slice(cc,cc+1)=="*")	{ obj.cargoID=workstr.slice(0,cc).tointeger(); break; }
		workstr=workstr.slice(cc+1);
		obj.source_istown=(workstr.slice(0,1)=="T");
		workstr=workstr.slice(1);
		for (cc=0; cc < workstr.len(); cc++)
			if (workstr.slice(cc,cc+1)=="*")	{ obj.sourceID=workstr.slice(0,cc).tointeger(); break; }
		workstr=workstr.slice(cc+1);
		obj.target_istown=(workstr.slice(0,1)=="T");
		workstr=workstr.slice(1);
		obj.targetID=workstr.tointeger();
		obj.twoway=false;
		switch (obj.route_type)
			{
			case	RouteType.RAIL:
				obj.station_type=AIStation.STATION_TRAIN;
			break;
			case	RouteType.ROAD:
				obj.station_type=AIStation.STATION_TRUCK_STOP;
				if (obj.cargoID == cCargo.GetPassengerCargo())	obj.station_type=AIStation.STATION_BUS_STOP;
			break;
			case	RouteType.WATER:
				obj.station_type=AIStation.STATION_DOCK;
			break;
			case	RouteType.AIR:
			case	RouteType.AIRMAIL:
			case	RouteType.AIRNET:
			case	RouteType.AIRNETMAIL:
			case	RouteType.SMALLAIR:
			case	RouteType.SMALLMAIL:
			case	RouteType.CHOPPER:
				obj.station_type=AIStation.STATION_AIRPORT;
			break;
			}
		obj.isWorking=(obj.status==100);
		local jrt=obj.route_type;
		local crg=obj.cargoID;
		if (jrt >= RouteType.AIR)	{ crg=cCargo.GetPassengerCargo(); jrt=RouteType.AIR; }
		local pUID = cProcess.GetUID(obj.sourceID, obj.source_istown);
		cJobs.CreateNewJob(pUID, obj.targetID, crg, jrt, 0);	// recreate the job with the infos we knows
		foreach (idx, val in cJobs.database)
			{
			if (cJobs.jobDoable.HasItem(idx))	continue;
								else	{ // that's a new job, must be the one we seek
									cJobs.jobDoable.AddItem(idx,0);
									local thatjob=cJobs.Load(idx);
									if (!thatjob)	{ saveit=true; continue; } // ie: dual job will not be create and so == null there
									thatjob.isUse=true;
									obj.UID=thatjob.UID;
									break;
									}
			}
		if (saveit && obj.UID != null)
			{
			cRoute.database[obj.UID] <- obj;
			if (obj.UID>1 && obj.target_istown && obj.route_type != RouteType.WATER && obj.route_type != RouteType.RAIL && (obj.cargoID==cCargo.GetPassengerCargo() || obj.cargoID==cCargo.GetMailCargo()) )	cJobs.TargetTownSet(obj.targetID);
			obj.RouteCheckEntry(); // re-enable the link to stations
			if (obj.source_entry && AIStation.IsValidStation(obj.source_stationID))
				{
				obj.rail_type=AIRail.GetRailType(AIStation.GetLocation(obj.source_stationID));
				obj.RouteSetDistance();
				}
			if (obj.groupID != null)	cRoute.GroupIndexer.AddItem(obj.groupID,obj.UID);
			if (!obj.source_entry || !obj.target_entry)	continue;
			obj.source.cargo_produce.AddItem(obj.cargoID,0);
			obj.source.cargo_accept.AddItem(obj.cargoID,0);
			obj.target.cargo_produce.AddItem(obj.cargoID,0);
			obj.target.cargo_accept.AddItem(obj.cargoID,0);
			local sp=obj.source.IsCargoProduce(obj.cargoID);
			local sa=obj.source.IsCargoAccept(obj.cargoID);
			local tp=obj.target.IsCargoProduce(obj.cargoID);
			local ta=obj.target.IsCargoAccept(obj.cargoID);
			if (sp && sa && tp && ta)	obj.twoway=true; // mark it twoway
			DInfo("Proccess... "+cRoute.RouteGetName(obj.UID),0);
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
		cTrain.Update(obj.vehicleID);
		iter++;
		}
	DInfo("Found "+iter+" trains.",0);
	local planelist=AIVehicleList_Group(INSTANCE.main.bank.mincash); // restore the network aircraft
	foreach (veh, dummy in planelist)	AIGroup.MoveVehicle(cRoute.VirtualAirGroup[0],veh);
	planelist=AIVehicleList_Group(INSTANCE.TwelveMonth);
	foreach (veh, dummy in planelist)	AIGroup.MoveVehicle(cRoute.VirtualAirGroup[1],veh);
	AIGroup.DeleteGroup(INSTANCE.main.bank.mincash);
	AIGroup.DeleteGroup(TwelveMonth);
	cRoute.RouteRebuildIndex();
	}

function cLoader::LoadingGame()
{
	try
	{
	if (INSTANCE.main.bank.busyRoute < 152)	cLoader.LoadOldSave();
		else	if (INSTANCE.main.bank.busyRoute < 156)	cLoader.Load154();
			else	cLoader.LoadSaveGame();
	} catch (e)
		{
		AILog.Error("Cannot load that savegame !");
		AILog.Info("As a last chance, the AI will try to continue ignoring the error, with a total random result...");
		local grouplist=AIGroupList();
		grouplist.RemoveItem(cRoute.VirtualAirGroup[0]);
		grouplist.RemoveItem(cRoute.VirtualAirGroup[1]);
		foreach (grp, dummy in grouplist)	AIGroup.DeleteGroup(grp);
		local vehlist=AIVehicleList();
		foreach (veh, dummy in vehlist)	{ cCarrier.VehicleOrdersReset(veh); INSTANCE.main.carrier.VehicleMaintenance_Orders(veh); }
		}
	OneWeek=0;
	OneMonth=0;
	SixMonth=0;
	TwelveMonth=0;
	INSTANCE.main.bank.canBuild=false;
	INSTANCE.main.bank.unleash_road=false;
	INSTANCE.main.bank.busyRoute=false;
	INSTANCE.main.bank.mincash=10000;
	cCargo.SetCargoFavorite();
	local trlist=AIVehicleList();
	trlist.Valuate(AIVehicle.GetVehicleType);
	trlist.KeepValue(AIVehicle.VT_RAIL);
	trlist.Valuate(AIVehicle.GetState);
	trlist.KeepValue(AIVehicle.VS_IN_DEPOT);
	if (!trlist.IsEmpty())
		{
		DInfo("Restarting stopped trains",0);
		foreach (veh, dummy in trlist)	cCarrier.StartVehicle(veh);
		}
	local alltowns=AITownList();
	INSTANCE.main.builder.CheckRouteStationStatus();
}
