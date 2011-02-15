// cChemin is class that handle all routes

class cChemin
	{
static	IDX_HELPER = 256;		// use to create an uniq ID (also use to set handicap value)
static	AIR_NET_CONNECTOR=3000;		// town is add to air network when it reach that value population
	root = null;
	Item = null;            // Item = our values for a route define by CCheminItem class
	RList = null;		// the array of Starting Item (our routes, because all our route start at producing location)
	DList = null; 		// Destinations List
	GList = null;		// List of our trains stations
	Item = null;
	badLocation = null;
	route=null;
	rail_max=null;		// maximum trains vehicle a station can handle
	road_max=null;		// maximum road vehicle a station can handle
	air_max=null;		// maximum aircraft a station can handle
	airnet_max=null;	// maximum aircraft on a network
	airnet_count=null;	// current number of aircrafts running the network
	water_max=null;		// maximum ships a station can handle
	road_max_onroute=null;  // maximum road vehicle on a route
	nowRoute=null;		// the current route index we work on
	buildmode=null;		// true build best, false build cheap
	cargo_fav=null;		// that cargo is our favorite cargo
	virtual_air=null;	// this is the list of towns in our virtual air network
	virtual_air_group_pass=null	// groupid for virtual air for passengers
	virtual_air_group_mail=null	// groupid for virtual air for mail
	under_upgrade=null;	// true when we are doing upgrade on something
	
	constructor(that)
		{
		root = that;
		Item = cCheminItem();
		badLocation= this.Item.badLocation;
		route=this.Item.ROUTE;
		buildmode=true;
		cargo_fav=-1;
		airnet_count=0;
		virtual_air=[];
		under_upgrade=false;
		RList = [];	// this is our routes list
		DList = [];	// this is our cEndDepot list, use to find a destination station
		GList = [];	// this is our Station list (rail station only)
		}
	}

function cChemin::RouteGetRailType(idx)
// return rail type use in that idx route
{
local road=root.chemin.RListGetItem(idx);
local stationobj=root.chemin.GListGetItem(road.ROUTE.src_station);
local stype=stationobj.STATION.railtype;
return stype;
}

function cChemin::GetStartDepotRanking(road)
// calc a start depot ranking for route, return its ranking
{
local valuerank=0;
local stationrank=0;
if (road.ROUTE.src_istown)
		{
		valuerank=(road.ROUTE.cargo_value)*(road.ROUTE.cargo_amount);
		// for towns, we remove percent transport (to avoid crowd town)
		stationrank=(100-(road.ROUTE.foule));
		if (root.fairlevel==2) stationrank=100; // no malus for level 2
		}
	else	{
		valuerank=(road.ROUTE.cargo_value)*(road.ROUTE.cargo_amount)
		stationrank=(100-(road.ROUTE.foule*25));
		switch (root.fairlevel)
			{
			case 0:
			stationrank=(100-(road.ROUTE.foule*50)); // give up when 2 stations are present
			break;
			case 1:
			stationrank=(100-(road.ROUTE.foule*25)); // give up for 4
			break;
			case 0:
			stationrank=(100-(road.ROUTE.foule*10)); // give up for 6
			break;
			}
		}
if (stationrank <= 0) { stationrank=1; }
// even crowd, let's still give it a chance to be pick
if (root.chemin.cargo_fav == road.ROUTE.cargo_id) // it's our favorite cargo
	{ valuerank+=valuerank; }
road.ROUTE.ranking=(stationrank*valuerank);
if (road.ROUTE.handicap > 0)	road.ROUTE.ranking-=road.ROUTE.handicap;
return road.ROUTE.ranking;
}

function cChemin::VirtualAirNetworkUpdate()
// update our list of airports that are in the air network
{
local newadd=0;
local road=null;
local townlist=AIList();
local templist=AIList();
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	road=root.chemin.RListGetItem(i);
	if (!road.ROUTE.isServed) continue;
	if (road.ROUTE.kind == 1000) continue; // a virtual route is 1000
	if (!road.ROUTE.src_istown) continue; // only towns can be in it
	if (!road.ROUTE.dst_istown) continue;
	local srcstation=root.chemin.GListGetItem(road.ROUTE.src_station);
	if (srcstation.STATION.railtype == 1) continue; // don't add small airport to network
	local dststation=root.chemin.GListGetItem(road.ROUTE.dst_station);
	if (dststation.STATION.railtype == 1) continue; // don't add small airport to network	
	if (road.ROUTE.kind == AIVehicle.VT_AIR)
		{
		// TODO: we shouldn't add the destination airport in it, maybe we have source town with 4+ but not a proof destination town >=4k
		// TODO: add airport station in the network instead of the route itself
		local population = AITown.GetPopulation(road.ROUTE.src_id);
		if (population > root.chemin.AIR_NET_CONNECTOR)
			{ // that town is in our list
			DInfo("Adding route "+i+" to the aircraft network",1);
			road.ROUTE.status=999; // setup the route to be in virtual network
			townlist.AddItem(road.ROUTE.src_id,population);
			templist.AddItem(srcstation.STATION.e_loc,road.ROUTE.src_id);
			population = AITown.GetPopulation(road.ROUTE.dst_id);
			townlist.AddItem(road.ROUTE.dst_id,population);
			templist.AddItem(dststation.STATION.e_loc,road.ROUTE.dst_id);
			root.chemin.RListUpdateItem(i,road);
			// now moving aircraft in the virtual group id
			local tomail=null;
			tomail=AICargo.GetTownEffect(road.ROUTE.cargo_id) == AICargo.TE_MAIL;
			local vehlist=AIVehicleList_Group(road.ROUTE.groupe_id);
			/*foreach (vehicle, dummy in vehlist)
				{
				root.carrier.VehicleOrdersReset(vehicle);
				AIOrder.UnshareOrders(vehicle);
				if (tomail)	AIGroup.MoveVehicle(root.chemin.virtual_air_group_mail,vehicle);
					else	AIGroup.MoveVehicle(root.chemin.virtual_air_group_pass,vehicle);
				newadd++;
				}*/
			}
		}
	}
townlist.Sort(AIList.SORT_BY_VALUE,false);
local first=townlist.Begin();
local bigdest=AITown.GetLocation(first);

townlist.Valuate(AITown.GetDistanceManhattanToTile,bigdest);
townlist.Sort(AIList.SORT_BY_VALUE,true);
local impair=false;
local pairlist=AIList();
local impairlist=AIList();
root.chemin.virtual_air=[];
foreach (i, dummy in townlist)
	{
	if (impair)	impairlist.AddItem(i,dummy);
		else	pairlist.AddItem(i,dummy);
	impair=!impair;
	}
pairlist.Sort(AIList.SORT_BY_VALUE,true);
impairlist.Sort(AIList.SORT_BY_VALUE,false);
townlist.Clear();
foreach (i, dummy in pairlist) townlist.AddItem(i,0);
foreach (i, dummy in impairlist) townlist.AddItem(i,0);
local finalList=AIList();
foreach (town, townvalue in townlist)
	{
	foreach (stationloc, townid in templist)
		{
		if (town == townid)	
			{
			root.chemin.virtual_air.push(stationloc);
			}
		}
	}
if (newadd > 0)	{ DInfo("Adding "+newadd+" aircrafts to the air network",1); }
root.carrier.AirNetworkOrdersHandler();
}

function cChemin::GetAmountOfCompetitorStationAround(IndustryID)
// Like AIIndustry::GetAmountOfStationAround but doesn't count our stations, so we only grab competitors stations
// return 0 or numbers of stations not own by us near the place
{
local counter=0;
local place=AIIndustry.GetLocation(IndustryID);
local radius=AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
local tiles=AITileList();
local produce=AITileList_IndustryAccepting(IndustryID, radius);
local accept=AITileList_IndustryProducing(IndustryID, radius);
tiles.AddList(produce);
tiles.AddList(accept);
tiles.Valuate(AITile.IsStationTile);
tiles.KeepValue(1); // keep station only
tiles.Valuate(AIStation.GetStationID);
local uniq=AIList();
foreach (i, dummy in tiles)
	{ // remove duplicate id
	if (!uniq.HasItem(dummy))	uniq.AddItem(dummy,i);
	}
uniq.Valuate(AIStation.IsValidStation);
uniq.KeepValue(0);
return uniq.Count();
}

function cChemin::UpdateStartRoute(idx)
// Update a starting depot infos
{
local fast=root.chemin.RListGetItem(idx);
if (fast.ROUTE.kind == 1000)	{ return; }
if (fast.ROUTE.src_istown)
	{
	fast.ROUTE.cargo_amount=AITown.GetLastMonthProduction(fast.ROUTE.src_id,fast.ROUTE.cargo_id);
	fast.ROUTE.cargo_amount-=AITown.GetLastMonthTransported(fast.ROUTE.src_id,fast.ROUTE.cargo_id);
	// remove already transported guys, lower town
	fast.ROUTE.src_name=AITown.GetName(fast.ROUTE.src_id);
	fast.ROUTE.foule=AITown.GetLastMonthTransportedPercentage(fast.ROUTE.src_id,fast.ROUTE.cargo_id);
	// for towns, we assign to foule the % already trasnported pass/mail to lower that town interrest
	// this should reduce us going to a crowd town
	}
else	{
	fast.ROUTE.cargo_amount=AIIndustry.GetLastMonthProduction(fast.ROUTE.src_id,fast.ROUTE.cargo_id);
	fast.ROUTE.foule=root.chemin.GetAmountOfCompetitorStationAround(fast.ROUTE.src_id);
	// this time industry, but the more stations near, the lower our interrest to be there too.
	fast.ROUTE.src_name=AIIndustry.GetName(fast.ROUTE.src_id);
	}
fast.ROUTE.ranking=root.chemin.GetStartDepotRanking(fast);
root.chemin.RListUpdateItem(idx,fast);
}

function cChemin::RouteMalusLower(idx)
// lower our handicap for that road
{
local road=root.chemin.RListGetItem(idx);
road.ROUTE.handicap-=(10*root.chemin.IDX_HELPER);
if (road.ROUTE.handicap <= 0 && road.ROUTE.status==0)	{ road.ROUTE.handicap=0; road.ROUTE.status=1; }
// gone to 0, we wait enough, we also reset our doable status to retry the road
root.chemin.RListUpdateItem(idx,road);
}

function cChemin::RouteMalusHigher(idx)
// We set an handicap on that road
// RETURN road, upto you to save it !
{
local road=root.chemin.RListGetItem(idx);
road.ROUTE.handicap+=road.ROUTE.ranking;
road.ROUTE.ranking=root.chemin.GetStartDepotRanking(road);
root.chemin.RListUpdateItem(idx,road);
}

function cChemin::RouteIsNotDoable(idx)
// We set our undoable status on that road
{
root.chemin.RouteStatusChange(idx,0);
local road=root.chemin.RListGetItem(idx);
road.ROUTE.handicap=road.ROUTE.ranking;
root.chemin.RListUpdateItem(idx,road);
}

function cChemin::CreateNewRoute(cargoID, industryID, isTown)
// Create a new route & add it
// fill some values that will stay stable in game
{
local road=cCheminItem();
road.ROUTE.isServed=false;
road.ROUTE.cargo_id=cargoID;
road.ROUTE.cargo_name=AICargo.GetCargoLabel(cargoID);
road.ROUTE.cargo_value=root.chemin.ValuateCargo(cargoID);
road.ROUTE.src_id=industryID;
road.ROUTE.src_istown=isTown;
if (isTown)	{
		road.ROUTE.src_name=AITown.GetName(industryID);
		road.ROUTE.src_place=AITown.GetLocation(industryID);
		}
	else	{
		road.ROUTE.src_name=AIIndustry.GetName(industryID);
		road.ROUTE.src_place=AIIndustry.GetLocation(industryID);
		}
road.ROUTE.uniqID=RouteGetUniqID(cargoID,industryID,isTown);
root.chemin.RListAddItem(road);
DInfo("Creating a new service: "+((root.chemin.RList.len()/road.ROUTE.len())-1)+":"+road.ROUTE.uniqID+" "+road.ROUTE.src_name+" for "+road.ROUTE.cargo_name,1);
}

function cChemin::CreateVirtualRoute()
// Create a virtual route & add it
// The virtual route is a route use to connect aircraft on a network of route
{
local road=cCheminItem();
road.ROUTE.cargo_id=root.carrier.GetPassengerCargo();
road.ROUTE.cargo_name=AICargo.GetCargoLabel(road.ROUTE.cargo_id);
road.ROUTE.cargo_value=root.chemin.ValuateCargo(road.ROUTE.cargo_id);
road.ROUTE.src_id=-10;
road.ROUTE.dst_id=-10;
road.ROUTE.kind=1000; // aircraft network
road.ROUTE.status=999;
road.ROUTE.uniqID=root.chemin.IDX_HELPER*4;
road.ROUTE.src_name="Virtual aircraft network";
road.ROUTE.dst_name="Virtual aircraft network";
road.ROUTE.groupe_name="Virtual airnet pass";
road.ROUTE.groupe_id=AIGroup.CreateGroup(AIVehicle.VT_AIR);
root.chemin.virtual_air_group_pass=road.ROUTE.groupe_id;
road.ROUTE.isServed=true;
road.ROUTE.src_istown=true;
road.ROUTE.dst_istown=true;
road.ROUTE.ranking=0;
AIGroup.SetName(road.ROUTE.groupe_id, road.ROUTE.groupe_name);
root.chemin.RListAddItem(road);
DInfo("Creating a new service: "+((root.chemin.RList.len()/road.ROUTE.len())-1)+":"+road.ROUTE.uniqID+" "+road.ROUTE.src_name+" for "+road.ROUTE.cargo_name,1);

road.ROUTE.uniqID++;
road.ROUTE.cargo_id=root.carrier.GetMailCargo();
road.ROUTE.cargo_name=AICargo.GetCargoLabel(road.ROUTE.cargo_id);
road.ROUTE.cargo_value=root.chemin.ValuateCargo(road.ROUTE.cargo_id);
road.ROUTE.groupe_name="Virtual airnet mail";
road.ROUTE.groupe_id=AIGroup.CreateGroup(AIVehicle.VT_AIR);
root.chemin.virtual_air_group_mail=road.ROUTE.groupe_id;
AIGroup.SetName(road.ROUTE.groupe_id, road.ROUTE.groupe_name);
root.chemin.RListAddItem(road);
DInfo("Creating a new service: "+((root.chemin.RList.len()/road.ROUTE.len())-1)+":"+road.ROUTE.uniqID+" "+road.ROUTE.src_name+" for "+road.ROUTE.cargo_name,1);

}

function cChemin::ValuateCargo(cargoID)
// return value of cargo for a static distance/delay
{
return AICargo.GetCargoIncome(cargoID,80,10);
}

function cChemin::RouteGetUniqID(cargoID,industryID,istown)
// return an uniq ID
{
if (istown)
		{ return (industryID+1)*root.chemin.IDX_HELPER+cargoID; }
	else 	{ return (industryID+1)*(root.chemin.IDX_HELPER*2)+cargoID; }
}

function cChemin::RouteCreateIndustry(industryID)
// Create & add one new industry to list of jobs
{
local ct = AICargoList();
foreach(c, dummy in ct)
	{
	if (AIIndustry.GetLastMonthProduction(industryID,c) >=0)
		{ // industry like that cargo	
		root.chemin.CreateNewRoute(c,industryID,false);
		}
	}
}

function cChemin::RouteCreateALL()
// Create all new routes, must be a game start
{
local it=AIIndustryList();
DInfo(it.Count()+" industries on map",0);
local cargoList=AICargoList();
local villeList=AITownList();
DInfo(villeList.Count()+" towns on map",0);
// first, let's find industries
foreach(i, dummy in it)	{ root.chemin.RouteCreateIndustry(i); }
// now towns
/*
foreach(c, dummy in cargoList)
	{
	local vt=AITownList();
	if (AICargo.HasCargoClass(c,AICargo.CC_PASSENGERS) || AICargo.HasCargoClass(c,AICargo.CC_MAIL))
		{
		foreach(v, dummy in vt)
			{
			root.chemin.CreateNewRoute(c,v,true);
			}
		}
	}
*/
root.chemin.CreateVirtualRoute();
}

function cChemin::RouteCreateEndingList(idx)
// Build a DList with all possible place to drop our cargo for the idx starting
{
root.chemin.DList=[];
local who=root.chemin.RListGetItem(idx);
local cargoeffect = AICargo.GetTownEffect(who.ROUTE.cargo_id);
local dstlist=null;
local dstDepot=cEndDepot();
if (cargoeffect == AICargo.TE_NONE || cargoeffect == AICargo.TE_WATER)
	{ // not a cargo for a town
	dstDepot.DEPOT.istown=false;
	dstlist=AIIndustryList_CargoAccepting(who.ROUTE.cargo_id);
	dstlist.Valuate(AIIndustry.GetDistanceManhattanToTile, who.ROUTE.src_place);
	}
else	{ // that's cargo for a town
	dstDepot.DEPOT.istown=true;
	dstlist=AITownList();
	dstlist.Valuate(AITown.GetDistanceManhattanToTile, who.ROUTE.src_place);
	}
dstlist.KeepBetweenValue(30,400); // filter distance <15 >400 are not really doable
if (!root.bank.unleash_road)	{ dstlist.KeepBetweenValue(30,100); } // filter again if we are limit by money
who.ROUTE.isServed=false;
// we now have a list of distinations id & distance from starting point
// let's build our possible list to futher choose the best one
if (dstlist.Count()==0)
	{ // empty list, nothing we can do about that
	root.chemin.DListReset();
	// just reset DList so caller will see the list is empty
	}
else	{
	root.chemin.DListReset();
	foreach (i, val in dstlist)
		{
		dstDepot.DEPOT.id=i;
		dstDepot.DEPOT.ranking=0;
		if (dstDepot.DEPOT.istown)
			{ dstDepot.DEPOT.name=AITown.GetName(i); dstDepot.DEPOT.ranking=AITown.GetPopulation(dstDepot.DEPOT.id); }
		else	{ dstDepot.DEPOT.name=AIIndustry.GetName(i); }
		dstDepot.DEPOT.distance=val;

		root.chemin.DListAddItem(dstDepot);
		}
	}
}

function cChemin::RouteRefresh()
// Refresh our routes datas
{
local listCounter=(root.chemin.RList.len()/root.chemin.Item.ROUTE.len());
for (local i=0; i < listCounter; i++)
	{
	root.chemin.RouteMalusLower(i); // decrease a bit our malus on road
	root.chemin.UpdateStartRoute(i);
	//root.chemin.RListUpdateItem(i,road);
	}
}

function cChemin::RouteMaintenance()
// Update our starting depot infos
{
local listCounter=root.chemin.RListGetSize();
DInfo("Checking "+(listCounter-1)+" routes for maintenance",0);
local uniqList=[];
for (local i=0; i < listCounter; i++)
	{
	local purgeit="";
	local road=root.chemin.RListGetItem(i);
	root.chemin.RouteMalusLower(i);
	if ((!road.ROUTE.src_istown) && (!AIIndustry.IsValidIndustry(road.ROUTE.src_id)))
		{ 	// not a town and not a valid industry
		purgeit="Bad starting industry";
		}
	if (road.ROUTE.uniqID in uniqList)
		{	// dup uniqID
		purgeit="Duplicate uniqID";
		}
	else	{ uniqList.push(road.ROUTE.uniqID); }
	if (purgeit != "")
		{ // found something to remove
		root.chemin.RListDumpOne(i);
		DInfo("Removing route "+i+" - Reason: "+purgeit,0);
		root.builder.RouteDelete(i);
		break;
		}
	} // for loop
}

function cChemin::RouteIsValid(start,end)
// set all values for that route
{
local sroad=root.chemin.RListGetItem(start);
local eroad=root.chemin.DListGetItem(end);
sroad.ROUTE.dst_id=eroad.DEPOT.id;
sroad.ROUTE.dst_name=eroad.DEPOT.name;
sroad.ROUTE.dst_istown=eroad.DEPOT.istown;
if (sroad.ROUTE.dst_istown)	{ sroad.ROUTE.dst_place=AITown.GetLocation(sroad.ROUTE.dst_id); }
			else	{ sroad.ROUTE.dst_place=AIIndustry.GetLocation(sroad.ROUTE.dst_id); }
sroad.ROUTE.length=eroad.DEPOT.distance;
sroad.ROUTE.status=2;
root.chemin.RListUpdateItem(start,sroad);
DInfo("Route created: "+sroad.ROUTE.cargo_name+" from "+sroad.ROUTE.src_name+" to "+sroad.ROUTE.dst_name+" "+sroad.ROUTE.length+"m",0);
}

function cChemin::EndingJobFinder(idx)
// Try find where to drop cargo for a route
{
local endroute=root.chemin.RListGetItem(idx);
if (endroute.ROUTE.status!=1)	return idx; // tell caller we know where to go already
DInfo("Finding where to drop cargo ("+endroute.ROUTE.cargo_name+") for service "+idx,0);
root.chemin.RouteCreateEndingList(idx);
endroute=root.chemin.RListGetItem(idx);
DInfo("DList size: "+root.chemin.DList.len(),2);
if (root.chemin.DList.len() == 0)
	{ // DList is reset on error or size = 0 if nothing is found
	DInfo("Can't find a place who accept "+endroute.ROUTE.cargo_name+" from "+endroute.ROUTE.src_name,1);
	root.chemin.RouteIsNotDoable(idx);
	return -1;
	}
// our list is filtered from 30-200 distance and range from farer to closer
// so first one is the best, except for towns
local dest=root.chemin.DListGetItem(0);
local bestDest=-1;
if (dest.DEPOT.istown)
	{ // we're going to a town, better pickup the biggest one so
	local toprank=-1;
	for (local i=0; i < (root.chemin.DList.len()/dest.DEPOT.len()); i++)
		{
		dest=root.chemin.DListGetItem(i);
		if (toprank < dest.DEPOT.ranking)  { toprank=dest.DEPOT.ranking; bestDest=i; }
		}
	
	}
else	{ bestDest=0; }
// ok now pickup how we will carry that
dest=root.chemin.DListGetItem(bestDest);
local kind=AICargo.GetTownEffect(endroute.ROUTE.cargo_id);
// distance
// 20-60 road can do it, assign as 1,
// 40-200 trains can do it, assign as 2, when low money limit to 100
// 40-150 air can do it assign as 3
// 40-150 for boat, assign as 4
local v_train=1;
local v_boat =1;
local v_air  =1;
local v_road =1;
if (!root.use_train) v_train=0;
if (!root.use_boat) v_boat=0;
if (!root.use_air) v_air=0;
if (!root.use_road) v_road=0;
local tweaklist=AIList();
if (kind==AICargo.TE_MAIL || kind==AICargo.TE_PASSENGERS)
	{
	if (dest.DEPOT.distance < 40)	{ tweaklist.AddItem(1,1*v_road); }
	if (dest.DEPOT.distance >= 150)	{ tweaklist.AddItem(2,2*v_train); }
	if (dest.DEPOT.distance >= 40 && dest.DEPOT.distance <80)
		{
		tweaklist.Clear();
		tweaklist.AddItem(1,1*v_road);
		tweaklist.AddItem(2,2*v_train);
		tweaklist.AddItem(3,3*v_air);
		tweaklist.AddItem(4,4*v_boat);
		}
	if (dest.DEPOT.distance >= 80 && dest.DEPOT.distance <150)
		{
		tweaklist.Clear();
		tweaklist.AddItem(2,2*v_train);
		tweaklist.AddItem(3,3*v_air);
		tweaklist.AddItem(4,4*v_boat);
		}
	}
else	{ // indudstries have that effect, i won't allow something other than trucks&trains
	if (dest.DEPOT.distance< 40)	{ tweaklist.AddItem(1,1*v_road); }
	if (dest.DEPOT.distance>=90)	{ tweaklist.AddItem(2,2*v_train); }
	if (dest.DEPOT.distance>=40 && dest.DEPOT.distance<90)
		{
		tweaklist.Clear();
		tweaklist.AddItem(1,1*v_road);
		tweaklist.AddItem(2,2*v_train);
		}
	}
root.chemin.DListDump();
if (root.debug) foreach (i, dummy in tweaklist) { DInfo("tweaklist i="+i+" dummy="+dummy,2); }
// here we cannot have 0 items in list, but list might have 0 in it when a vehicle is disable/not allow
tweaklist.RemoveValue(0);
// now we could :/
if (tweaklist.IsEmpty())
	{
	DInfo("Can't pickup a road type with the current vehicle limitation",1); 
	root.chemin.RouteIsNotDoable(idx);
	return -1;
	}
local res=tweaklist.Begin();
local roadtype="";
switch (res)
	{
	case	1:
		endroute.ROUTE.kind=AIVehicle.VT_ROAD;
		roadtype="Bus & truck";
	break;
	case	2:	
		endroute.ROUTE.kind=AIVehicle.VT_RAIL;
		roadtype="Train";
	break;
	case	3:
		endroute.ROUTE.kind=AIVehicle.VT_AIR;
		roadtype="Aircraft";
	break;
	case	4:
		endroute.ROUTE.kind=AIVehicle.VT_WATER;
		roadtype="Boat";
	break;
	default	:
		bestDest=-1;
	break;
	}
DInfo("Choosen road: "+endroute.ROUTE.kind+" "+roadtype,2);
root.chemin.RListUpdateItem(idx,endroute);
return bestDest;
}

function cChemin::StartingJobFinder()
{
DInfo("Finding something to do...",0);
local madLoop=0;
local madLoopIter=20; // only 8 try and we drop
local bestJob=-1;
local startidx=-1;
local endidx=-1;
local chemSize=root.chemin.RListGetSize();
if (chemSize<madLoopIter) madLoopIter=chemSize;
// no need to iter more than our # of routes
local goodRoute=false;
root.chemin.RouteRefresh();
local task=null;
local tasktry=null;
local gotmalus=0; // i use that to count how many route have a malus, if = numbers of route -> means we check all routes and fail
// fresh infos for accurate calc
do 	{
	bestJob=-1;
	startidx=-1;
	gotmalus=0;
	for (local i=0; i < chemSize; i++)
		{
		task=root.chemin.RListGetItem(i);
		local rnk=task.ROUTE.ranking;
		if (task.ROUTE.handicap > 0)	gotmalus++;
		if (task.ROUTE.isServed) { continue; } // we already own & run that route
		if (task.ROUTE.status==0) { continue; } // ignore that route, undoable we recheck it later
		if (task.ROUTE.ranking <= root.minRank) { continue; } // too poor to be useful //root.minRank
		if (bestJob < rnk) 
			{
			bestJob=rnk; startidx=i; tasktry=task.ROUTE.src_name;
			}
		}
	if (startidx==-1)
		{
		DInfo("Can't find any good routes to do for now",0);
		madLoop=madLoopIter; break;
		}
	else 	{
		DInfo(" ");
		DInfo("Checking service #"+startidx+" - "+tasktry+" "+bestJob,0);
		root.chemin.RListDumpOne(startidx);
		endidx=root.chemin.EndingJobFinder(startidx);
		}
	if (startidx >-1 && endidx >-1)	{ goodRoute=true; }
	if (gotmalus >= chemSize)	root.secureStart=0; // disable it, we try all routes and none can be done with road vehicle
	if (root.secureStart > 0)
		{
		local isroad=root.chemin.RListGetItem(startidx);
		if (isroad.ROUTE.kind == AIVehicle.VT_ROAD)	{ root.secureStart--; }
				else	{ root.chemin.RouteMalusHigher(startidx); goodRoute=false; }
		}
	madLoop++;
	} while (!goodRoute && madLoop < madLoopIter);
if (!goodRoute)	{ return -1; }
	else	{ if (endidx!=startidx)	root.chemin.RouteIsValid(startidx,endidx); } // only if route is not already known
return startidx;
}

function cChemin::RouteStatusChange(idx,status)
// Change the status of the idx route
{
local road=root.chemin.RListGetItem(idx);
DInfo("Route "+idx+" status change to "+status,1);
road.ROUTE.status=status;
root.chemin.RListUpdateItem(idx,road);
}

function cChemin::DutyOnAirNetwork()
// handle the traffic for the aircraft network
{
if (root.chemin.virtual_air.len()==0) return;
local vehlist=AIList();
local totalcapacity=0;
local mailroute=0;
local passroute=0;
local onecapacity=44;
local passcargo=root.carrier.GetPassengerCargo();
for (local j=0; j < root.chemin.RListGetSize(); j++)
	{
	local road=root.chemin.RListGetItem(j);
	if (road.ROUTE.kind == 1000)
		{
		if (road.ROUTE.cargo_id == passcargo)	passroute=j;
						else	mailroute=j;
		//continue;
		}
	if (road.ROUTE.status != 999) continue;
	if (!road.ROUTE.isServed) continue;
	local vehingroup=AIVehicleList_Group(road.ROUTE.groupe_id);
	foreach(vehicle, dummy in vehingroup)
		{
		totalcapacity+=AIEngine.GetCapacity(AIVehicle.GetEngineType(vehicle));
		if (onecapacity==44)	onecapacity=AIEngine.GetCapacity(AIVehicle.GetEngineType(vehicle));
		vehlist.AddItem(vehicle,1);
		}
	}
local vehnumber=vehlist.Count();
DInfo("Aircrafts in network: "+vehnumber,2);
DInfo("Total capacity of network: "+totalcapacity,2);
vehlist.Valuate(AIVehicle.GetAge);
vehlist.Sort(AIList.SORT_BY_VALUE,true); // younger first
local age=0;
if (vehlist.IsEmpty())	age=1000;
		else	age=vehlist.GetValue(vehlist.Begin());
if (age < 90) { DInfo("Too young buy "+age+" count="+vehlist.Count(),2); return; }
local bigairportlocation=root.chemin.virtual_air[0];
local bigairportID=AIStation.GetStationID(bigairportlocation);
local cargowaiting=AIStation.GetCargoWaiting(bigairportID,passcargo);
local vehneed=0;
cargowaiting-=totalcapacity;
if (cargowaiting > 0)	vehneed=cargowaiting / onecapacity;
		else	vehneed=0;
PutSign(bigairportlocation,"Network Airport "+cargowaiting);
vehlist.Valuate(AIVehicle.GetProfitThisYear);
vehlist.Sort(AIList.SORT_BY_VALUE,true);
local profit=(vehlist.GetValue(vehlist.Begin()) > 0);
local duplicate=true;
//if (totalcapacity > 0)	vehneed=cargowaiting / totalcapacity;
//		else	{ vehneed=1; profit=true; duplicate=false; }
//if ((cargowaiting % totalcapacity) !=0) vehneed++;
local vehdelete=vehnumber - vehneed;
vehdelete-=2; // allow 2 more "unneed" aircrafts
DInfo("vehdelete="+vehdelete+" vehneed="+vehneed+" cargowait="+cargowaiting+" airportid="+bigairportID+" loc="+bigairportlocation,2);
if (profit) // making profit
	{ // adding aircraft
	if (vehneed > vehnumber)
		{
		local thatnetwork=0;
		for (local k=0; k < vehneed; k++)
			{
			if (vehnumber % 6 == 0)	thatnetwork=mailroute;
					else	thatnetwork=passroute;
			if (root.carrier.BuildAndStartVehicle(thatnetwork,false))
				{
				DInfo("Adding an aircraft to network",0);
				vehnumber++;
				}
			}
			root.carrier.AirNetworkOrdersHandler();
		}
	}
}

function cChemin::VehicleGroupProfitRatio(groupID)
// check a vehicle group and return a ratio representing it's value
// it's just (groupprofit * 1000 / numbervehicle)
{
if (!AIGroup.IsValidGroup(groupID))	return 0;
local vehlist=AIVehicleList_Group(groupID);
vehlist.Valuate(AIVehicle.GetProfitThisYear);
local vehnumber=vehlist.Count();
if (vehnumber == 0) return 0; // avoid / per 0
local totalvalue=0;
foreach (vehicle, value in vehlist)
	{ totalvalue+=value*1000; }
return totalvalue / vehnumber;
}

function cChemin::DutyOnRoute()
// this is where we add vehicle and tiny other things to max our money
{
if (root.chemin.under_upgrade)
	{
	root.bank.busyRoute=true;
	return;
	}
root.carrier.VehicleMaintenance();
local firstveh=false;
root.bank.busyRoute=false; // setup the flag
local profit=false;
local prevprofit=0;
local vehprofit=0;
local oldveh=false;
local priority=AIList();
local road=null;
root.chemin.DutyOnAirNetwork(); // we handle the network load here
for (local j=0; j < root.chemin.RListGetSize(); j++)
	{
	road=root.chemin.RListGetItem(j);
	if (!road.ROUTE.isServed) continue;
	if (road.ROUTE.kind == 1000) continue;	// ignore the network routes
	if (road.ROUTE.status == 999) continue; // ignore route that are part of the network
	local work=road.ROUTE.kind;
	if (road.ROUTE.vehicule == 0)	{ firstveh=true; } // everyone need at least 2 vehicule on a route
	local maxveh=0;
	local cargoid=road.ROUTE.cargo_id;
	local estimateCapacity=1;
	switch (work)
		{
		case AIVehicle.VT_ROAD:
			maxveh=root.chemin.road_max_onroute;
			estimateCapacity=15;
		break;
		case AIVehicle.VT_AIR:
			maxveh=root.chemin.air_max;
			cargoid=root.carrier.GetPassengerCargo(); // for aircraft, force a check vs passenger
			// so mail aircraft runner will be add if passenger is high enough, this only affect routes not in the network
		break;
		case AIVehicle.VT_WATER:
			maxveh=root.chemin.water_max;
		break;
		case AIVehicle.VT_RAIL:
			maxveh=1;
			continue; // no train upgrade for now will do later
		break;
		}
	local vehList=AIVehicleList_Group(road.ROUTE.groupe_id);
	vehList.Valuate(AIVehicle.GetProfitThisYear);
	vehList.Sort(AIAbstractList.SORT_BY_VALUE,true); // poor numbers first
	local vehsample=vehList.Begin();  // one sample in the group
	local vehprofit=vehList.GetValue(vehsample);
	local prevprofit=AIVehicle.GetProfitLastYear(vehsample);
	local capacity=root.carrier.VehicleGetFullCapacity(vehsample);
	DInfo("vehicle="+vehsample+" capacity="+capacity+" engine="+AIEngine.GetName(AIVehicle.GetEngineType(vehsample)),2);
	local stationid=root.builder.GetStationID(j,true);
	local dstationid=root.builder.GetStationID(j,false);
	local vehonroute=road.ROUTE.vehicule;
	local srccargowait=AIStation.GetCargoWaiting(stationid,cargoid);
	local dstcargowait=AIStation.GetCargoWaiting(dstationid,cargoid);
	local cargowait=srccargowait;
	if (road.ROUTE.src_istown && dstcargowait < srccargowait) cargowait=dstcargowait;
	
	local vehneed=0;
	if (capacity > 0)	{ vehneed=cargowait / capacity; }
			else	{// This happen when we don't have a vehicle sample -> 0 vehicle = new route certainly
				local producing=0;
				if (road.ROUTE.src_istown)	{ producing=AITown.GetLastMonthProduction(road.ROUTE.src_id,road.ROUTE.cargo_id); }
					else	{ producing=AIIndustry.GetLastMonthProduction(road.ROUTE.src_id,road.ROUTE.cargo_id); }
				if (work == AIVehicle.VT_ROAD)	{ vehneed= producing / estimateCapacity; }
				}
	if (firstveh) 
		{
		if (vehneed < 2)	vehneed=2;
		if (vehneed > 4)	vehneed=2;
		}
	if (vehneed >= vehonroute) vehneed-=vehonroute;
	if (vehneed > maxveh) vehneed=maxveh-vehonroute;
	DInfo("Route="+j+"-"+road.ROUTE.src_name+"/"+road.ROUTE.dst_name+"/"+road.ROUTE.cargo_name+" capacity="+capacity+" vehicleneed="+vehneed+" cargowait="+cargowait+" vehicule#="+road.ROUTE.vehicule+" firstveh="+firstveh,2);
	if (vehprofit <=0)	profit=true; // hmmm on new years none is making profit and this fail
		else		profit=true;
	vehList.Valuate(AIVehicle.GetAge);
	vehList.Sort(AIAbstractList.SORT_BY_VALUE,true);
	if (vehList.GetValue(vehList.Begin()) > 90)	oldveh=true; // ~ 8 months
						else	oldveh=false;
	// adding vehicle
	if (vehneed > 0)
		{
		if (root.carrier.vehnextprice > 0)
			{
			DInfo("We're upgrading some vehicles, not adding new vehicle until its done to keep the money... "+root.carrier.vehnextprice,0);
			root.carrier.vehnextprice-=(root.carrier.vehnextprice / 20);
			if (root.carrier.vehnextprice < 0) root.carrier.vehnextprice=0;
			root.bank.busyRoute=true;
			continue; // no add... while we have an vehicle upgrade on its way
			}
		/*if (vehList.GetValue(vehList.Begin()) > 90)	oldveh=true;
							else	oldveh=false;*/
		if (firstveh) // special cases where we must build the vehicle
			{ profit=true; oldveh=true; }

		if (profit)
			{
			root.bank.busyRoute=true;
			if (firstveh && vehneed > 0 && oldveh)
				{
				if (root.carrier.BuildAndStartVehicle(j,false))
					{
					DInfo("Adding a vehicle to route #"+j+" "+road.ROUTE.cargo_name+" from "+road.ROUTE.src_name+" to "+road.ROUTE.dst_name,0);
					firstveh=false;
					}
				}
			if (!firstveh && vehneed > 1)
					{
					priority.AddItem(road.ROUTE.groupe_id,vehneed-1);
					continue; // skip to next route, we won't check removing for that turn
					}
			}
		}

// Removing vehicle when station is too crowd & vehicle get stuck
	if (cargowait == 0 && oldveh) // this happen if we load everything at the station
		{
		local busyList=AIVehicleList_Group(road.ROUTE.groupe_id);
		local runningList=AIList();
		if (busyList.IsEmpty()) continue;
		busyList.Valuate(AIVehicle.GetState);
		runningList.AddList(busyList);
		busyList.KeepValue(AIVehicle.VS_AT_STATION); // the loading vehicle
		runningList.KeepValue(AIVehicle.VS_RUNNING); // healthy vehicle
		if (busyList.IsEmpty())	continue; // no need to continue if noone is at station
		runningList.Valuate(AIVehicle.GetLocation);
		runningList.Valuate(AITile.GetDistanceManhattanToTile,AIStation.GetLocation(stationid));
		runningList.KeepBelowValue(10); // only keep vehicle position < 10 the station
		runningList.Valuate(AIVehicle.GetCurrentSpeed);
		runningList.KeepValue(0); // running but at 0 speed
		if (runningList.IsEmpty())	continue; // all vehicles are moving
		runningList.Valuate(AIVehicle.GetAge); // better sold the oldest one
		runningList.Sort(AIList.SORT_BY_VALUE,true);
		if (runningList.Count() < 2)	continue; // we will not remove last vehicles, upto "profitlost" to remove them
		// now send that one to depot & sell it
		local veh=runningList.Begin();
		DInfo("Vehicle "+veh+"-"+AIVehicle.GetName(veh)+" is not moving and station is busy, selling it for balancing",2);
		root.carrier.VehicleToDepotAndSell(veh);
		AIVehicle.ReverseVehicle(veh); // try to make it move away from the queue
		}
	}
// now we can try add others needed vehicles here but base on priority
if (priority.IsEmpty())	return;
local priosave=AIList();
priosave.AddList(priority); // save it because value is = number of vehicle we need
priority.Valuate(root.chemin.VehicleGroupProfitRatio);
priority.Sort(AIList.SORT_BY_VALUE,false);
local vehneed=0;
foreach (groupid, ratio in priority)
	{
	if (priosave.HasItem(groupid))	vehneed=priosave.GetValue(groupid);
				else	vehneed=0;
	for (local i=0; i < root.chemin.RListGetSize(); i++)
		{
		road=root.chemin.RListGetItem(i);
		if (road.ROUTE.groupe_id == groupid)
			{
			for (local z=0; z < vehneed; z++)
				{
				if (root.carrier.BuildAndStartVehicle(i,true))
					{
					DInfo("Adding a vehicle to route #"+i+" "+road.ROUTE.cargo_name+" from "+road.ROUTE.src_name+" to "+road.ROUTE.dst_name,0);
					}
				}
			}
		}
	}
}

