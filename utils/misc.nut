/* -*- Mode: C++; tab-width: 6 -*- */ 
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

function sliceString(a)
{
local t=20;
if ((a == null) || (a.len() <= 0)) return "NULL!";
if (a.len() >t) { t=a.slice(0,t-1); }
return a;
}

function getLastName(who)
{
local names = ["Castro", "Mussolini", "Lenin", "Stalin", "Batista", "Jong", "Mugabe", "Al-Bashir", "Milosevic",
	"Bonaparte", "Caesar", "Tse-Tung"];
if (who == 666) { who = AIBase.RandRange(12) };
return names[who];
}

function getFirstName(who)
{
local names = ["Fidel", "Benito", "Vladamir", "Joseph", "Fulgencio", "Kim", "Robert", "Omar", "Slobodan",
	"Napoleon", "Julius", "Mao"];
if (who == 666) { who = AIBase.RandRange(12) };
return names[who];
}

function PickCompanyName(who)
{
local nameo = ["Last", "For the", "Militia", "Revolution", "Good", "Bad", "Evil"];
local namet = ["Hope", "People", "Corporation", "Money", "Dope", "Cry", "Shot", "War", "Battle", "Fight"];
local x = 0; local y = 0;
if (who == 666)  { x = AIBase.RandRange(7); y = AIBase.RandRange(10); }
	else	 { x = who; y = who; }
return nameo[x]+" "+namet[y]+" (DictatorAI)"; 

}

function DInfo(putMsg,debugValue=0,func="unkown")
// just output AILog message depending on debug level
{
local debugState = DictatorAI.GetSetting("debug");
if (debugState > 0)	func+="-> ";
			else	func="";
if (debugValue <= debugState )
	{
	AILog.Info(func+putMsg);
	}
}

function DError(putMsg,debugValue=1,func="unkown")
// just output AILog message depending on debug level
{
local debugState = DictatorAI.GetSetting("debug");
debugValue=1; // force error message to always appears when debug is on
if (debugState > 0)	func+="-> ";
			else	func="";
if (debugValue <= debugState )
	{
	AILog.Error(func+putMsg+" Error:"+AIError.GetLastErrorString());
	}
}

function DWarn(putMsg, debugValue=1,func="unkown")
// just output AILog message depending on debug level
{
local debugState = DictatorAI.GetSetting("debug");
if (debugState > 0)	func+="-> ";
			else	func="";
if (debugValue <= debugState )
	{
	AILog.Warning(func+putMsg);
	}
}

function ShowTick()
{
DInfo("ShowTick-> "+this.GetTick(),2);
}

function checkHQ()
{
if (!AIMap.IsValidTile(AICompany.GetCompanyHQ(AICompany.COMPANY_SELF)))
	{
	local townlist = AITownList();
	townlist.Valuate(AIBase.RandItem);
	DictatorAI.BuildHQ(townlist.Begin());
	}
}

function ListGetItem(list, item_num)
{
local new=AIList();
new.AddList(list);
new.RemoveTop(item_num);
return new.Begin();
}

function AIGetCargoFavorite()
{
local crglist=AICargoList();
cargo_favorite=AIBase.RandRange(crglist.Count());
cargo_favorite=ListGetItem(crglist, cargo_favorite);
DInfo("We will promote "+AICargo.GetCargoLabel(cargo_favorite),0,"AIGetCargoFavorite");
}

function AIInit()
{
local myName = "Krinn's Company";
local FinalName = myName;
FinalName = PickCompanyName(666);
AICompany.SetName(FinalName);
AICompany.SetPresidentGender(AICompany.GENDER_MALE);
DInfo("We're now "+FinalName,0,"AIInit");
local randomPresident = 666;
if (DictatorAI.GetSetting("PresidentName")) { randomPresident = AIBase.RandRange(12); }
local lastrand = "";
local nickrand = getFirstName(randomPresident);
lastrand = nickrand + " "+ getLastName(randomPresident);
DInfo(lastrand+" will rules the company with an iron fist",0,"AIInit");
AICompany.SetPresidentName(lastrand);
AIGetCargoFavorite();
}

function OldSaveWarn()
// Just output a warning for old savegame format
{
	AILog.Error("WARNING");
	AILog.Info("That savegame was made with DictatorAI version "+bank.busyRoute);
	AILog.Info("I have add a compatibility loader to help restoring old savegames but it doesn't support all versions");
	AILog.Info("If the AI crash, please bugreport the savegame version and AI version in use.");
	AILog.Info("If you re-save your game, it will be saved with the new save format.");
	AILog.Error("WARNING");
	INSTANCE.Sleep(20);
}

function ConvertOldSave()
// Last action common to old save game
{
local airlist=AIVehicleList_DefaultGroup(AIVehicle.VT_AIR);
foreach (veh, dummy in airlist)	AIGroup.MoveVehicle(cRoute.GetVirtualAirPassengerGroup(), veh);
	DInfo("Registering our routes",0,"LoadingGame");
	foreach (routeUID, dummy in cRoute.RouteIndexer)
		{
		local aroute=cRoute.GetRouteObject(routeUID);
		if (aroute==null)	continue;
		if (aroute.UID < 2)	continue;
		if (!aroute.isWorking)	continue;
		local rt=aroute.route_type;
		if (rt > AIVehicle.VT_AIR)	rt=AIVehicle.VT_AIR;
		cJobs.CreateNewJob(aroute.sourceID, aroute.targetID, aroute.source_istown, aroute.cargoID, rt);
		}
	DInfo("Tagging jobs in use",0,"LoadingGame");
	foreach (jobID, dummy in cJobs.jobIndexer)
		{
		local ajob=cJobs.GetJobObject(jobID);
		if (ajob==null)	continue;
		ajob.isUse=true;
		}
}

function LoadOldSave()
// loading a savegame with version < 152
{
	OldSaveWarn();
	local all_stations=bank.unleash_road;
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
		obj.locations=ArrayToList(temparray);
		counter=all_stations[nextitem];
		temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]);
		i=nextitem+counter;
		iter++;
		obj.StationSave();
		}
	DInfo(iter+" stations found.",0,"main");
	DInfo("base size: "+bank.unleash_road.len()+" dbsize="+cStation.stationdatabase.len()+" savedb="+OneMonth,1,"main");
	DInfo("Restoring routes",0,"main");
	iter=0;
	local all_routes=bank.canBuild;
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
	DInfo("base size: "+bank.canBuild.len()+" dbsize="+cRoute.database.len()+" savedb="+OneWeek,2,"main");
	ConvertOldSave();
}

function Load154()
{
	OldSaveWarn();
	local all_stations=bank.unleash_road;
	local revision=false;
	if (bank.busyRoute == 155)	revision=true;
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
		obj.locations=ArrayToList(temparray);
		counter=all_stations[nextitem];
		temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]);
		obj.platforms=ArrayToList(temparray);
		nextitem+=counter+1;
		counter=all_stations[nextitem];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]);
		obj.station_tiles=ArrayToList(temparray);
		i=nextitem+counter;
		iter++;
		obj.StationSave();
		}
	DInfo(iter+" stations found.",0,"LoadSaveGame");
	DInfo("base size: "+bank.unleash_road.len()+" dbsize="+cStation.stationdatabase.len()+" savedb="+OneMonth,1,"LoadSaveGame");
	DInfo("Restoring routes",0,"LoadSaveGame");
	iter=0;
	local all_routes=bank.canBuild;
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
		//obj.RouteUpdateVehicle();
		}
	DInfo(iter+" routes found.",0,"LoadSaveGame");
	DInfo("base size: "+bank.canBuild.len()+" dbsize="+cRoute.database.len()+" savedb="+OneWeek,2,"LoadSaveGame");
	DInfo("Restoring trains",0,"LoadSaveGame");
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

function LoadSaveGame()
// The latest load function
	{
	local all_stations=bank.unleash_road;
	DInfo("...Restoring stations",0,"LoadSaveGame");
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
		obj.locations=ArrayToList(temparray);
		counter=all_stations[nextitem];
		temparray=[];
		for (local z=0; z < counter; z++)	temparray.push(all_stations[nextitem+1+z]);
		obj.platforms=ArrayToList(temparray);
		obj.maxsize=1;
		if (obj.stationType == AIStation.STATION_BUS_STOP || obj.stationType == AIStation.STATION_TRUCK_STOP)	obj.maxsize=INSTANCE.carrier.road_max;
		if (obj.stationType == AIStation.STATION_TRAIN)	obj.maxsize=INSTANCE.carrier.rail_max;
		i=nextitem+counter;
		iter++;
		if (saveit)	obj.StationSave();
		}
	DInfo("Found "+iter+" stations.",0,"LoadSaveGame");
	local all_routes=bank.canBuild;
	DInfo("...Restoring routes",0,"LoadSaveGame");
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
		cJobs.CreateNewJob(obj.sourceID, obj.targetID, obj.source_istown, crg, jrt); // recreate the job with the infos we knows
		foreach (idx, val in cJobs.database)
			{
			if (cJobs.jobDoable.HasItem(idx))	continue;
								else	{ // that's a new job, must be the one we seek
									cJobs.jobDoable.AddItem(idx,0);
									local thatjob=cJobs.GetJobObject(idx);
									if (thatjob == null)	{ saveit=true; continue; } // ie: dual job will not be create and so == null there
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
			DInfo("Proccess... "+cRoute.RouteGetName(obj.UID),0,"LoadSaveGame");
			}
		}
	DInfo("Found "+iter+" routes.",0,"LoadSaveGame");
	DInfo("Restoring trains",0,"LoadSaveGame");
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
	DInfo("Found "+iter+" trains.",0,"LoadSaveGame");
	local planelist=AIVehicleList_Group(INSTANCE.bank.mincash); // restore the network aircraft
	foreach (veh, dummy in planelist)	AIGroup.MoveVehicle(cRoute.VirtualAirGroup[0],veh);
	planelist=AIVehicleList_Group(INSTANCE.TwelveMonth);
	foreach (veh, dummy in planelist)	AIGroup.MoveVehicle(cRoute.VirtualAirGroup[1],veh);
	AIGroup.DeleteGroup(bank.mincash);
	AIGroup.DeleteGroup(TwelveMonth);
	cRoute.RouteRebuildIndex();
	}

function LoadingGame()
{
	try
	{
	if (bank.busyRoute < 152)	LoadOldSave();
		else	if (bank.busyRoute < 156)	Load154();
			else	LoadSaveGame();
	} catch (e)
		{
		AILog.Error("Cannot load that savegame !");
		AILog.Info("As a last chance, the AI will try to continue ignoring the error, with a total random result...");
		local grouplist=AIGroupList();
		grouplist.RemoveItem(cRoute.VirtualAirGroup[0]);
		grouplist.RemoveItem(cRoute.VirtualAirGroup[1]);
		foreach (grp, dummy in grouplist)	AIGroup.DeleteGroup(grp);
		local vehlist=AIVehicleList();
		foreach (veh, dummy in vehlist)	{ cCarrier.VehicleOrdersReset(veh); INSTANCE.carrier.VehicleMaintenance_Orders(veh); }
		}
	OneWeek=0;
	OneMonth=0;
	SixMonth=0;
	TwelveMonth=0;
	bank.canBuild=false;
	bank.unleash_road=false;
	bank.busyRoute=false;
	bank.mincash=10000;
	AIGetCargoFavorite();
	local trlist=AIVehicleList();
	trlist.Valuate(AIVehicle.GetVehicleType);
	trlist.KeepValue(AIVehicle.VT_RAIL);
	trlist.Valuate(AIVehicle.GetState);
	trlist.KeepValue(AIVehicle.VS_IN_DEPOT);
	if (!trlist.IsEmpty())
		{
		DInfo("Restarting stopped trains");
		foreach (veh, dummy in trlist)	cCarrier.StartVehicle(veh);
		}
	local alltowns=AITownList();
	foreach (townID, dummy in alltowns)
		if (AITown.GetRating(townID, AICompany.COMPANY_SELF) != AITown.TOWN_RATING_NONE)	cJobs.statueTown.AddItem(townID,0);
	INSTANCE.builder.CheckRouteStationStatus();
}
