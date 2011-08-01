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

function PutSign(place,msg)
// put a sign at place
{
if (!INSTANCE.debug) return;
if (DictatorAI.GetSetting("debug") < 2) return;
if (place != null) AISign.BuildSign(place,msg);
}

function ClearSignsALL()
// this just clear any signs we can
{
local sweeper=AISignList();
DInfo("Removing Signs ! "+sweeper.Count(),2);
foreach (i, dummy in sweeper)	{ AISign.RemoveSign(dummy); AISign.RemoveSign(i); }
}

function showLogic(item)
// this will draw sign with item so we see item influence
{
if (!INSTANCE.debug) return;
foreach (i, dummy in item)
	{
	PutSign(i,dummy);
	}
}

function cBuilder::DumpRoute(idx=null)
{
local road=null;
if (idx == null)	road=INSTANCE.route;
		else	road=cRoute.GetRouteObject(idx);
DInfo("Route #"+road.UID+" "+road.name,2);
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
DInfo("# "+road.source.stationID+" Station type: "+road.source.stationType+" specialType: "+road.source.specialType+" produce "+road.source.cargo_produce.Count()+" cargos, accept "+road.source.cargo_accept.Count()+" cargos",2);
if (!road.target_entry) return;
DInfo("# "+road.target.stationID+" Station type: "+road.target.stationType+" specialType: "+road.target.specialType+" produce "+road.target.cargo_produce.Count()+" cargos, accept "+road.target.cargo_accept.Count()+" cargos",2);
}

function cBuilder::DumpJobs(uid)
{
local tjob=cJobs.GetJobObject(uid);
local src="("+tjob.sourceID+")";
local dst="("+tjob.targetID+")";
if (tjob.source_istown)	src=AITown.GetName(tjob.sourceID)+src;
		else	src=AIIndustry.GetName(tjob.sourceID)+src;
if (tjob.target_istown)	dst=AITown.GetName(tjob.targetID)+dst;
		else	dst=AIIndustry.GetName(tjob.targetID)+dst;
DInfo("Jobs #"+uid+" "+src+"->"+dst+" Ranking="+tjob.ranking+" "+AICargo.GetCargoLabel(tjob.cargoID)+" value="+tjob.cargoValue+" Amount="+tjob.cargoAmount+" "+cRoute.RouteTypeToString(tjob.roadType)+" Cost: "+tjob.moneyToBuild+" doable? "+tjob.isdoable,2);
}

function cBuilder::DumpTopJobs()
{
local i=0;
foreach (uid, ranking in INSTANCE.jobs.jobDoable)
	{
	INSTANCE.builder.DumpJobs(uid);
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

function cBuilder::ShowSlopes()
{
DInfo("running slopes");
local tlist=AITileList();
tlist.AddRectangle(30594,33402);
PutSign(30594,"S");
cTileTools.CheckLandForConstruction(30594,12,15);
}



