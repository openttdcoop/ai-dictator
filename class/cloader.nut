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
	local stations = AIList();
	local temp = null;
	temp = AIStationList(AIStation.STATION_TRAIN);
	stations.AddList(temp);
	temp = AIStationList(AIStation.STATION_AIRPORT);
	stations.AddList(temp);
	temp = AIStationList(AIStation.STATION_DOCK);
	stations.AddList(temp);
	temp = AIStationList(AIStation.STATION_TRUCK_STOP);
	stations.AddList(temp);
	temp = AIStationList(AIStation.STATION_BUS_STOP);
	stations.AddList(temp);
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
	AILog.Info("That savegame was made with DictatorAI version "+INSTANCE.main.bank.busyRoute);
	AILog.Info("I have add a compatibility loader to help restoring old savegames but it doesn't support all versions");
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
		local aroute=cRoute.Load(routeUID);
		if (!aroute)	continue;
		if (aroute.UID < 2)	continue;
		if (aroute != 100)	continue;
		local rt=aroute.VehicleType;
		if (rt > AIVehicle.VT_AIR)	rt=AIVehicle.VT_AIR;
		local pUID = aroute.SourceProcess.UID;
		cJobs.CreateNewJob(pUID, aroute.TargetProcess.ID, aroute.CargoID, rt, 0);
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
		local lost = null;
		local _stationID = all_stations[i]; // id
		lost = all_stations[i+1]; // type
		lost = all_stations[i+2]; // subtype
		lost = all_stations[i+3]; // size
		lost = all_stations[i+4]; // maxsize
		local _Depot=all_stations[i+5]; // depot
		lost = all_stations[i+6]; // radius
		local counter=all_stations[i+7];
		local nextitem=i+8+counter;
		local temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[i+8+z]); // locations
		lost=cMisc.ArrayToList(temparray);
		counter=all_stations[nextitem];
		temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]); // lol don't remember what it was, platforms ?
		i=nextitem+counter;
		iter++;
		local info = cStation.Load(_stationID);
		if (!info)	continue;
		info.Depot = _Depot;
		}
	DInfo(iter+" stations found.",0);
	DInfo("base size: "+INSTANCE.main.bank.unleash_road.len()+" dbsize="+cStation.stationdatabase.len()+" savedb="+OneMonth,1);
	DInfo("Restoring routes",0);
	iter=0;
	local all_routes=INSTANCE.main.bank.canBuild;
	for (local i=0; i < all_routes.len(); i++)
		{
		local obj=cRoute();
		local lost=null;
		obj.UID=all_routes[i];
		obj.SourceProcess=all_routes[i+1]; // source id
		lost=all_routes[i+2]; // source location
		lost=all_routes[i+3]; // source is_town
		obj.SourceProcess = cProcess.Load(cProcess.GetUID(obj.SourceProcess, lost));
		obj.TargetProcess=all_routes[i+4]; // target id
		lost=all_routes[i+5]; // target location
		lost=all_routes[i+6]; // target istown
		obj.TargetProcess = cProcess.Load(cProcess.GetUID(obj.TargetProcess, lost));
		obj.VehicleType=all_routes[i+7];
		obj.StationType=all_routes[i+8];
		lost =all_routes[i+9]; //isworking
		obj.Status=all_routes[i+10];
		obj.GroupID=all_routes[i+11];
		obj.SourceStation=all_routes[i+12]; // source station id
		obj.SourceStation = cStation.Load(obj.SourceStation);
		obj.TargetStation=all_routes[i+13]; // target station id
		obj.TargetStation = cStation.Load(obj.TargetStation);
		obj.CargoID=all_routes[i+14];
		i+=14;
		iter++;
		if (obj.UID > 1)	// don't save old virtual network
				{
				cRoute.database[obj.UID] <- obj;
				if (obj.GroupID != null)	cRoute.GroupIndexer.AddItem(obj.GroupID,obj.UID);
				cRoute.SetRouteGroupName(obj.GroupID, obj.SourceProcess.ID, obj.TargetProcess.ID, obj.SourceProcess.IsTown, obj.TargetProcess.IsTown, obj.CargoID, false);
				}
			else	if (AIGroup.IsValidGroup(obj.GroupID))	AIGroup.DeleteGroup(obj.GroupID);
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

function cLoader::Load166()
// The latest load function
	{
	cLoader.OldSaveWarn();
	local all_stations=INSTANCE.main.bank.unleash_road;
	DInfo("...Restoring stations",0);
	local iter=0;
	local allcargos=AICargoList();
	local saveit=true;
	for (local i=0; i < all_stations.len(); i++)
		{
		saveit=true;
		local obj=cStation();
		obj.s_ID=all_stations[i];
		local sobj = cStation.Load(obj.s_ID);
		if (!AIStation.IsValidStation(obj.s_ID))	saveit=false;
								else	obj.s_Type=cStation.FindStationType(obj.s_ID);
		obj.s_SubType=all_stations[i+1];
		obj.s_Size=all_stations[i+2];
		obj.s_Depot=all_stations[i+3];
		if (sobj != false)	sobj.s_Depot = obj.s_Depot;
		local counter=all_stations[i+4];
		local nextitem=i+5+counter;
		local temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[i+5+z]);
		obj.s_Tiles=cMisc.ArrayToList(temparray);
		counter=all_stations[nextitem];
		temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]);
		local lost =cMisc.ArrayToList(temparray); // train plaforms, lost for now
		obj.s_MaxSize=1;
		i=nextitem+counter;
		iter++;
		}
	DInfo("Found "+iter+" stations.",0);
	local all_routes=INSTANCE.main.bank.canBuild;
	DInfo("...Restoring routes",0);
	iter=0;
	for (local i=0; i < all_routes.len(); i++)
		{
		saveit=true;
		local obj=cRoute();
		local temp;
		obj.VehicleType=all_routes[i+0];
		obj.Status=all_routes[i+1];
		obj.GroupID=all_routes[i+2];
		obj.SourceStation = all_routes[i+3];  // source stationid
		obj.SourceStation = cStation.Load(obj.SourceStation);
		obj.TargetStation = all_routes[i+4]; // target stationid
		obj.TargetStation = cStation.Load(obj.TargetStation);
		obj.Primary_RailLink=all_routes[i+5];
		obj.Secondary_RailLink=all_routes[i+6];
		obj.Source_RailEntry=all_routes[i+7];
		obj.Target_RailEntry=all_routes[i+8];
		i+=8;
		iter++;
		local gname=AIGroup.GetName(obj.GroupID);
		// this version use A*CargoID*I###*T### groupname
		local workarr = cMisc.SplitStars(gname);
		local src_IsTown, dst_IsTown;
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
		obj.Twoway=false;
		local jrt=obj.VehicleType;
		local crg=obj.CargoID;
		temp = cJobs();
//	if (this.UID == null && this.SourceProcess.ID != null && this.TargetProcess.ID != null && this.cargoID != null && this.roadType != null)
		temp.UID = null;
		if (jrt >= RouteType.AIR)	{ crg=cCargo.GetPassengerCargo(); jrt=RouteType.AIR; }
		temp.roadType = jrt;
		temp.cargoID = obj.CargoID;
		if (saveit)	saveit = cMisc.ValidInstance(obj.SourceProcess);
		if (saveit)	saveit = cMisc.ValidInstance(obj.TargetProcess);
		if (saveit)
			{
			temp.sourceObject = obj.SourceProcess;
			temp.targetObject = obj.TargetProcess;
			print(temp.GetUID());
			obj.UID = temp.UID;
			cJobs.CreateNewJob(obj.SourceProcess.UID, obj.TargetProcess.ID, crg, jrt, 0);	// recreate the job
			temp = cJobs.Load(obj.UID); // now load it
			if (!temp)	continue;
			temp.isUse = true;
			obj.RouteDone();
			DInfo("Proccess... "+obj.Name,0);
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
		//cTrain.Update(obj.vehicleID);
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

function cLoader::LoadSaveGame()
// Load current savegame version in use
{
}

function cLoader::LoadingGame()
{
	cLoader.RegisterStations();
	try
	{
	if (INSTANCE.main.bank.busyRoute < 152)	cLoader.LoadOldSave();
		else	if (INSTANCE.main.bank.busyRoute < 156)	cLoader.Load154();
			else if (INSTANCE.main.bank.busyRoute < 167)	cLoader.Load166();
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
		foreach (obj, _ in cJobs.database)	{ obj.isUse = false; }
		foreach (veh, dummy in vehlist)
			{
			cCarrier.VehicleOrdersReset(veh);
			INSTANCE.main.carrier.VehicleMaintenance_Orders(veh);
			INSTANCE.main.carrier.VehicleIsWaitingInDepot();
			}
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

