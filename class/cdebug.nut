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
	if (!DictatorAI.GetSetting("debug_sign")) return;
	if (place != null) AISign.BuildSign(place,msg.tostring());
}

function cDebug::ClearSigns()
// this just clear any signs we can
{
	if (!DictatorAI.GetSetting("debug_sign")) return;
	local sweeper=AISignList();
	sweeper.Valuate(AISign.GetLocation);
	sweeper.RemoveValue(INSTANCE.main.SCP.SCPTile);
	AIController.Sleep(20);
	foreach (i, dummy in sweeper)	{ AISign.RemoveSign(i); }
}

function cDebug::showLogic(item)
// this will draw sign with item so we see item influence
{
	foreach (i, dummy in item)
		{
		cDebug.PutSign(i,dummy);
		}
	//AIController.Break("logic first "+cMisc.Locate(item.Begin()));
	print("logic at "+cMisc.Locate(item.Begin()));
	AIController.Sleep(40);
	cDebug.ClearSigns();
}

function cBuilder::DumpRoute(idx=null)
{
	if (!INSTANCE.debug)	return;
	local road=null;
	if (idx == null)	road=INSTANCE.main.route;
			else	road=cRoute.Load(idx);
	DInfo("Route "+road.Name+" VehicleType: "+cRoute.RouteTypeToString(road.VehicleType)+" status: "+road.Status+" Cargo:"+cCargo.GetCargoLabel(road.CargoID),2);
	if (typeof(road.SourceStation) != "instance") return;
	DInfo(road.SourceStation.s_Name+" Station type: "+road.SourceStation.s_Type+" subType: "+road.SourceStation.s_SubType+" produce "+road.SourceStation.s_CargoProduce.Count()+" cargos, accept "+road.SourceStation.s_CargoAccept.Count()+" cargos");

	if (typeof(road.TargetStation) != "instance") return;
	DInfo(road.TargetStation.s_Name+" Station type: "+road.TargetStation.s_Type+" subType: "+road.TargetStation.s_SubType+" produce "+road.TargetStation.s_CargoProduce.Count()+" cargos, accept "+road.TargetStation.s_CargoAccept.Count()+" cargos");
}

function cBuilder::DumpJobs(uid)
{
	if (!INSTANCE.debug)	return;
	local tjob=cJobs.GetJobObject(uid);
	local src=tjob.sourceObject.Name;
	local dst=tjob.targetObject.Name;
	DInfo("Jobs #"+uid+" "+src+"->"+dst+" Ranking="+tjob.ranking+" "+cCargo.GetCargoLabel(tjob.cargoID)+" value="+tjob.cargoValue+" cargo="+tjob.cargoAmount+" "+cRoute.RouteTypeToString(tjob.roadType)+" Cost: "+tjob.moneyToBuild+" doable? "+tjob.isdoable,1);
}

function cBuilder::DumpTopJobs()
{
	if (!INSTANCE.debug)	return;
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
local sta_list=AIStationList(AIStation.STATION_ANY);
if (!sta_list.IsEmpty())	foreach (sta_id, dummy in sta_list)
	{
	stations=cStation.Load(sta_id);
	local stuck="CLOSE - ";
	if (stations.CanUpgradeStation()) stuck="UPGRADE -";
	local outtxt=stuck+stations.vehicle_count+" - "+stations.vehicle_max;
	local outpos=stations.s_Location;
	cDebug.PutSign(outpos,outtxt);
	}
}

function cBuilder::ShowStationOwners()
{
if (!INSTANCE.debug) return;
local stations=null;
local sta_list=AIStationList(AIStation.STATION_ANY);
if (!sta_list.IsEmpty())	foreach (sta_id, dummy in sta_list)
	{
	stations=cStation.Load(sta_id);
	if (!stations)	continue;
	if (stations.s_Owner.IsEmpty())	{ cDebug.PutSign(stations.s_Location, "NOT OWN"); }
	}
}


function cBuilder::ShowTrainStationDepot()
{
local alist=AIStationList(AIStation.STATION_TRAIN);
foreach (station, dummy in alist)
	{
	local thatstation=cStation.GetStationObject(station);
	AISign.BuildSign(thatstation.depot,cStation.GetStationName(station));
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

function cDebug::ShowRailTrack()
{
    local atrack = AIRailTypeList();
    foreach (r, _ in atrack)
        {
        print("track #"+r+" name: "+AIRail.GetName(r)+" speed: "+AIRail.GetMaxSpeed(r));
        }
}

