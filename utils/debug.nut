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
AISign.BuildSign(place,msg);
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

function cBuilder::DumpRoute()
{
DInfo("Route #"+INSTANCE.route.UID+" "+INSTANCE.route.name,2);
local srcname="";
local tgtname="";
if (INSTANCE.route.source_istown)	srcname=AITown.GetName(INSTANCE.route.sourceID);
				else	srcname=AIIndustry.GetName(INSTANCE.route.sourceID);
if (INSTANCE.route.target_istown)	tgtname=AITown.GetName(INSTANCE.route.targetID);
				else	tgtname=AIIndustry.GetName(INSTANCE.route.targetID);
srcname=INSTANCE.route.sourceID+":"+srcname;
tgtname=INSTANCE.route.targetID+":"+tgtname;
DInfo("Source: "+srcname+" Target: "+tgtname+" route_type: "+cRoute.RouteTypeToString(INSTANCE.route.route_type)+" status: "+INSTANCE.route.status+" Cargo:"+AICargo.GetCargoLabel(INSTANCE.route.cargoID),2);
if (!INSTANCE.route.source_entry) return;
DInfo("Source station "+INSTANCE.route.source_stationID+"("+AIStation.GetName(INSTANCE.route.source_stationID)+")",2);
DInfo("# "+INSTANCE.route.source.stationID+" Station type: "+INSTANCE.route.source.stationType+" specialType: "+INSTANCE.route.source.specialType+" produce "+INSTANCE.route.source.cargo_produce.Count()+" cargos, accept "+INSTANCE.route.source.cargo_accept.Count()+" cargos",2);
if (!INSTANCE.route.target_entry) return;
DInfo("# "+INSTANCE.route.target.stationID+" Station type: "+INSTANCE.route.target.stationType+" specialType: "+INSTANCE.route.target.specialType+" produce "+INSTANCE.route.target.cargo_produce.Count()+" cargos, accept "+INSTANCE.route.target.cargo_accept.Count()+" cargos",2);
}

function cBuilder::DumpJobs(uid)
{
local tjob=cJobs.GetJobObject(uid);
DInfo("Jobs #"+uid+" s/t="+tjob.sourceID+"->"+tjob.targetID+" Ranking="+tjob.ranking+" "+AICargo.GetCargoLabel(tjob.cargoID),0);
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
INSTANCE.NeedDelay(60);
}

/*function cChemin::ShowStationCapacity()
{
if (!INSTANCE.debug) return;
local stations=null;
for (local i=0; i < INSTANCE.chemin.GListGetSize(); i++)
	{
	stations=INSTANCE.chemin.GListGetItem(i);
	local stuck="CLOSE - ";
	if (stations.STATION.type != 0) stuck="UPGRADE -";
	local outtxt=stuck+stations.STATION.e_count+" - "+stations.STATION.s_count;
	local outpos=stations.STATION.e_loc;
	PutSign(outpos,outtxt);
	}
}
*/


