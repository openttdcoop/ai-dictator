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
AIController.Sleep(100);
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
local myName = "Krinn Company";
local FinalName = myName;
FinalName = PickCompanyName(666);
AIController.Sleep(15);
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

function LoadOldSave()
// loading a savegame with version < 152
{
	AILog.Error("WARNING");
	AILog.Info("That savegame was made with DictatorAI version "+bank.busyRoute);
	AILog.Info("I have add a compatibility loader to help restoring old savegames but it doesn't support all versions");
	AILog.Info("If the AI crash, please bugreport the savegame version and AI version in use.");
	AILog.Info("If you re-save your game, it will be saved with the new save format.");
	AILog.Error("WARNING");
	AIController.Sleep(20);
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
		cRoute.database[obj.UID] <- obj;
		if (obj.UID>1 && obj.target_istown && obj.route_type != RouteType.WATER && obj.route_type != RouteType.RAIL && (obj.cargoID==cCargo.GetPassengerCargo() || obj.cargoID==cCargo.GetMailCargo()) )	cJobs.TargetTownSet(obj.targetID);
		obj.RouteCheckEntry(); // re-enable the link to stations
		if (obj.UID > 1)
			{ // don't try this one virtual routes
			obj.source.cargo_produce.AddItem(obj.cargoID,0);
			obj.source.cargo_accept.AddItem(obj.cargoID,0);
			obj.target.cargo_produce.AddItem(obj.cargoID,0);
			obj.target.cargo_accept.AddItem(obj.cargoID,0);
			if (obj.route_type >= RouteType.AIR)	obj.RouteAirportCheck();
			}
		cRoute.GroupIndexer.AddItem(obj.groupID,obj.UID);
		if (obj.UID == 0)	cRoute.VirtualAirGroup[0]=obj.groupID;
		if (obj.UID == 1)	cRoute.VirtualAirGroup[1]=obj.groupID;
		obj.RouteUpdateVehicle();
		}
	cRoute.RouteRebuildIndex();
	DInfo(iter+" routes found.",0,"main");
	DInfo("base size: "+bank.canBuild.len()+" dbsize="+cRoute.database.len()+" savedb="+OneWeek,2,"main");
}

function LoadSaveGame(revision)
{
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
		if (revision)	i+=15;
				else	{ // newer savegame from 155
					obj.source_RailEntry=all_routes[i+16];
					obj.target_RailEntry=all_routes[i+17];
					i+=17;
					}
		iter++;
		cRoute.database[obj.UID] <- obj;
		if (obj.UID>1 && obj.target_istown && obj.route_type != RouteType.WATER && obj.route_type != RouteType.RAIL && (obj.cargoID==cCargo.GetPassengerCargo() || obj.cargoID==cCargo.GetMailCargo()) )	cJobs.TargetTownSet(obj.targetID);
		if (obj.UID == 0)	cRoute.VirtualAirGroup[0]=obj.groupID;
		if (obj.UID == 1)	cRoute.VirtualAirGroup[1]=obj.groupID;
		obj.RouteCheckEntry(); // re-enable the link to stations
		if (obj.UID > 1)
			{ // don't try this one virtual routes
			obj.source.cargo_produce.AddItem(obj.cargoID,0);
			obj.source.cargo_accept.AddItem(obj.cargoID,0);
			obj.target.cargo_produce.AddItem(obj.cargoID,0);
			obj.target.cargo_accept.AddItem(obj.cargoID,0);
			if (obj.route_type >= RouteType.AIR)	obj.RouteAirportCheck();
			}
		obj.RouteUpdateVehicle();
		cRoute.GroupIndexer.AddItem(obj.groupID,obj.UID);
		}
	DInfo(iter+" routes found.",0,"LoadSaveGame");
	DInfo("base size: "+bank.canBuild.len()+" dbsize="+cRoute.database.len()+" savedb="+OneWeek,2,"LoadSaveGame");
	DInfo("Restoring "+TwelveMonth+" trains",0,"LoadSaveGame");
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
	DInfo("Restoring bridges : "+bank.mincash.len(),0,"LoadSaveGame");
	for (local i=0; i < bank.mincash.len(); i++)	cBridge.IsBridgeTile(bank.mincash[i]);
}

function LoadingGame()
{
	if (bank.busyRoute < 152)	LoadOldSave();
					else	if (bank.busyRoute < 155)	LoadSaveGame(true);
										else	LoadSaveGame(false);
	OneWeek=0;
	OneMonth=0;
	SixMonth=0;
	TwelveMonth=0;
	bank.canBuild=false;
	bank.unleash_road=false;
	bank.busyRoute=false;
	bank.mincash=10000;
	DInfo("We are promoting "+AICargo.GetCargoLabel(cargo_favorite),0,"LoadingGame");
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

	local alltowns=AITownList();
	foreach (townID, dummy in alltowns)
		if (AITown.GetRating(townID, AICompany.COMPANY_SELF) != AITown.TOWN_RATING_NONE)	cJobs.statueTown.AddItem(townID,0);
	INSTANCE.builder.CheckRouteStationStatus();
/*
	local railgroup=AIGroupList();
	railgroup.Valuate(AIGroup.GetVehicleType);
print("railgroup size="+railgroup.Count());
	railgroup.KeepValue(AIVehicle.VT_RAIL);
print("railgroup size="+railgroup.Count());
foreach (gid, dummy in railgroup)
	{
	local uid=cRoute.GroupIndexer.GetValue(gid);
	local thatroute=cRoute.GetRouteObject(uid);
//	thatroute.RouteCheckEntry();
	cBuilder.DumpRoute(uid);
//		PutSign(thatroute.source.depot,"SD");
//		PutSign(thatroute.target.depot,"TD");
	local sdepot=cRoute.GetDepot(uid, 1);
	local ddepot=cRoute.GetDepot(uid, 2);
	if (sdepot != -1 && ddepot != -1)
		{
		PutSign(sdepot,"SD");
		PutSign(ddepot,"TD");
		print("checking depot to depot");
		print("result="+cBuilder.RoadRunner(sdepot, ddepot, AIVehicle.VT_RAIL)); ClearSignsALL();
		}
	else			print("bad depot");
	}*/
cBuilder.BridgeUpgrader();
}
