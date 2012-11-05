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

class cDebug extends cClass
{
	constructor()	{ this.ClassName="cDebug"; }
}

function cDebug::PutSign(place,msg)
// put a sign at place
{
	if (!INSTANCE.debug) return;
	if (DictatorAI.GetSetting("debug") < 3) return;
	if (place != null) AISign.BuildSign(place,msg.tostring());
}

function cDebug::ClearSigns()
// this just clear any signs we can
{
	if (!INSTANCE.debug)	return;
	if (DictatorAI.GetSetting("debug") < 3) return;
	local sweeper=AISignList();
	sweeper.Valuate(AISign.GetLocation);
	sweeper.RemoveValue(INSTANCE.main.SCP.SCPTile);
	AIController.Sleep(20);
	foreach (i, dummy in sweeper)	{ AISign.RemoveSign(i); }
}

function cDebug::showLogic(item)
// this will draw sign with item so we see item influence
{
	if (!INSTANCE.debug) return;
	foreach (i, dummy in item)
		{
		cDebug.PutSign(i,dummy);
		}
}

function cBuilder::DumpRoute(idx=null)
{
local road=null;
if (idx == null)	road=INSTANCE.main.route;
		else	road=cRoute.GetRouteObject(idx);
DInfo("Route #"+road.UID+" "+cRoute.RouteGetName(road.UID),2);
local srcname="";
local tgtname="";
if (road.source_istown)	srcname=AITown.GetName(road.sourceID);
			else	srcname=AIIndustry.GetName(road.sourceID);
if (road.target_istown)	tgtname=AITown.GetName(road.targetID);
			else	tgtname=AIIndustry.GetName(road.targetID);
srcname=road.sourceID+":"+srcname;
tgtname=road.targetID+":"+tgtname;
DInfo("Source: "+srcname+" Target: "+tgtname+" route_type: "+cRoute.RouteTypeToString(road.route_type)+" status: "+road.status+" Cargo:"+AICargo.GetCargoLabel(road.cargoID),2);
if (!road.source_entry) return;
DInfo("Source station "+road.source_stationID+"("+AIStation.GetName(road.source_stationID)+")",2);
DInfo("# "+road.source.stationID+" Station type: "+road.source.stationType+" specialType: "+road.source.specialType+" produce "+road.source.cargo_produce.Count()+" cargos, accept "+road.source.cargo_accept.Count()+" cargos");
if (!road.target_entry) return;
DInfo("# "+road.target.stationID+" Station type: "+road.target.stationType+" specialType: "+road.target.specialType+" produce "+road.target.cargo_produce.Count()+" cargos, accept "+road.target.cargo_accept.Count()+" cargos",2);
}

function cBuilder::DumpJobs(uid)
{
	local tjob=cJobs.GetJobObject(uid);
	local src=tjob.sourceObject.Name;
	local dst=tjob.targetObject.Name;
	DInfo("Jobs #"+uid+" "+src+"->"+dst+" Ranking="+tjob.ranking+" "+cCargo.GetCargoLabel(tjob.cargoID)+" value="+tjob.cargoValue+" cargo="+tjob.cargoAmount+" "+cRoute.RouteTypeToString(tjob.roadType)+" Cost: "+tjob.moneyToBuild+" doable? "+tjob.isdoable,2);
}

function cBuilder::DumpTopJobs()
{
	local i=0;
	foreach (uid, ranking in INSTANCE.main.jobs.jobDoable)
		{
		INSTANCE.main.builder.DumpJobs(uid);
		if (i==12)	break;
		i++;
		}
}

function cBuilder::ShowStationCapacity()
{
if (!INSTANCE.debug) return;
local stations=null;
local sta_list=AIStationList(AIStation.STATION_BUS_STOP);
if (!sta_list.IsEmpty())	foreach (sta_id, dummy in sta_list)
	{
	stations=cStation.GetStationObject(sta_id);
	local stuck="CLOSE - ";
	if (stations.CanUpgradeStation()) stuck="UPGRADE -";
	local outtxt=stuck+stations.vehicle_count+" - "+stations.vehicle_max;
	local outpos=stations.locations.Begin();
	PutSign(outpos,outtxt);
	}
}

function cBuilder::ShowTrainStationDepot()
{
local alist=AIStationList(AIStation.STATION_TRAIN);
foreach (station, dummy in alist)
	{
	local thatstation=cStation.GetStationObject(station);
	AISign.BuildSign(thatstation.depot,cStation.StationGetName(station));
	}
}

function cBuilder::ShowBlackList()
{
foreach (tile, value in cTileTools.TilesBlackList)	PutSign(tile,"BL:"+value);
}

function cBuilder::ShowPlatformStatus(stationID)
{
if (!INSTANCE.debug)	return;
local station=cStation.GetStationObject(stationID);
foreach (platform, status in station.platform_entry)
	if (status==1)	PutSign(platform,"O");
			else	PutSign(platform,"X");
foreach (platform, status in station.platform_exit)
	if (status==1)	PutSign(platform,"O");
			else	PutSign(platform,"X");
}
