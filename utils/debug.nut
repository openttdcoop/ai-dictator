function PutSign(place,msg)
// put a sign at place
{
if (!root.debug) return;
AISign.BuildSign(place,msg);
}

function ClearSignsALL()
// this just clear any signs we can
{
local sweeper=AISignList();
DInfo("Removing Signs ! "+sweeper.Count(),1);
foreach (i, dummy in sweeper)	{ AISign.RemoveSign(dummy); AISign.RemoveSign(i); }
}

function showLogic(item)
// this will draw sign with item so we see item influence
{
if (!root.debug) return;
foreach (i, dummy in item)
	{
	PutSign(i,dummy);
	}
}

function cChemin::GListDumpOne(idx)
// dump one item
{
if (!root.debug) return;
local start=root.chemin.GListGetIndex(idx);
local wtf="GList["+idx+"] ";
local j=0;
local dummy=cStation();

for (local i=start; i < start+dummy.STATION.len(); i++)
	{
	wtf=wtf+root.chemin.GList[i]+" ";
	}
DInfo(wtf,2);
}

function cChemin::RListDumpOne(idx)
// dump one item
{
if (!root.debug) return;
local start=root.chemin.RListGetIndex(idx);
local wtf="RList["+idx+"] ";
local j=0;
local dummy=cCheminItem();

for (local i=start; i < start+dummy.ROUTE.len(); i++)
	{
	wtf=wtf+root.chemin.RList[i]+" ";
	}
DInfo(wtf,2);
}

function cChemin::RListDumpALL()
// dump the RList table idx
{
if (!root.debug) return;
local dummy=cCheminItem();
for (local i=0; i < (root.chemin.RListGetSize()); i++)
	{
	root.chemin.RListDumpOne(i);
	}
}

function cChemin::DListDump()
// dump the DList table
{
if (!root.debug) return;
local wtf="";
local j=0;
local dummy=cEndDepot();
for (local i=0; i < root.chemin.DList.len(); i++)
	{
	if (j==0)	{ wtf="DList["+(i/dummy.DEPOT.len())+"] "; }
	wtf=wtf+root.chemin.DList[i]+" / ";
	j++;
	if (j > (dummy.DEPOT.len()-1))
		{
		DInfo(wtf,2);
		j=0;
		}
	}
}

function cChemin::RListStatus()
// count route, invalid, done, with handicap... for stats
{
if (!root.debug) return;
local invalid=0;
local running=0;
local advance=0;
local handicap=0;
local notdone=0;
local average=0;
local toopoor=0;
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	local temp=root.chemin.RListGetItem(i);
	switch (temp.ROUTE.status)
		{
		case 0:
		invalid++;
		case 1:
		notdone++;
		}
	if (temp.ROUTE.handicap>0)	{ handicap++; average+=temp.ROUTE.handicap;}
	if (temp.ROUTE.isServed)	running++;
	if (temp.ROUTE.ranking < root.minRank)	toopoor++;
	local ispromote="";
	if (temp.ROUTE.cargo_id == cargo_fav) ispromote="*";
	if (temp.ROUTE.handicap > 0)
		{
		DInfo("#"+i+" "+temp.ROUTE.src_name+"-"+temp.ROUTE.dst_name+"("+ispromote+temp.ROUTE.cargo_name+") rating: "+temp.ROUTE.ranking+" handicap: "+temp.ROUTE.handicap+" foule: "+temp.ROUTE.foule+" status="+temp.ROUTE.status,2);
		}
	}
advance=root.chemin.RListGetSize()-1-running-invalid-toopoor;
if (handicap > 0) { average=average / handicap; }
DInfo("Routes: "+(root.chemin.RListGetSize()-1)+" invalid:"+invalid+" running: "+running+" todo:"+advance+" handcap:"+handicap+" average="+average,2);
}

function cChemin::ShowStationCapacity()
{
return true;
if (!root.debug) return;
local stations=null;
for (local i=0; i < root.chemin.GListGetSize(); i++)
	{
	stations=root.chemin.GListGetItem(i);
	local stuck="CLOSE - ";
	if (stations.STATION.type != 0) stuck="UPGRADE -";
	local outtxt=stuck+stations.STATION.e_count+" - "+stations.STATION.s_count;
	local outpos=stations.STATION.e_loc;
	PutSign(outpos,outtxt);
	}
}

function cChemin::FewRouteDump()
{
local cc=0;
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	local road=root.chemin.RListGetItem(i);
	if (road.ROUTE.isServed) continue;
	DInfo("ID:"+road.ROUTE.uniqID+" status="+road.ROUTE.status+" source="+road.ROUTE.src_name+" cargo="+road.ROUTE.cargo_name+" ranking="+road.ROUTE.ranking+" handicap="+road.ROUTE.handicap+"/"+road.ROUTE.foule);
	cc++;
	if (cc > 12) break;
	}

}



