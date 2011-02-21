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


// cChemin is class that handle all routes

class cChemin
	{
static	IDX_HELPER = 512;		// use to create an uniq ID (also use to set handicap value)
static	AIR_NET_CONNECTOR=3000;		// town is add to air network when it reach that value population
static	TRANSPORT_DISTANCE=[40,150,200, 30,80,110, 40,90,150, 40,150,200];
// min, limited, max distance for rail, road, water & air vehicle
	root = null;
	Item = null;            // Item = our values for a route define by CCheminItem class
	RList = null;		// the array of Starting Item (our routes, because all our route start at producing location)
	DList = null; 		// Destinations List
	GList = null;		// List of our trains stations
	Item = null;
	route=null;
	rail_max=null;		// maximum trains vehicle a station can handle
	road_max=null;		// maximum road vehicle a station can handle
	air_max=null;		// maximum aircraft a station can handle
	airnet_max=null;	// maximum aircraft on a network
	airnet_count=null;	// current number of aircrafts running the network
	water_max=null;		// maximum ships a station can handle
	road_max_onroute=null;  // maximum road vehicle on a route
	nowRoute=null;		// the current route index we work on
	cargo_fav=null;		// that cargo is our favorite cargo
	virtual_air=null;	// this is the list of towns in our virtual air network
	virtual_air_group_pass=null;	// groupid for virtual air for passengers
	virtual_air_group_mail=null;	// groupid for virtual air for mail
	under_upgrade=null;	// true when we are doing upgrade on something
	repair_routes=null; 	// list of routes that need repairs
	global_malus=null;	// we remove that global malus from any route malus as soon as we can
	max_transport_distance=null;	// maximum distance to transport cargo
	min_transport_distance=null;	// minimum distance to transport cargo
	map_group_to_route=null;	// a list of group and value = index of the route that have that group, faster checks
	max_town_jobs=null;
	
	constructor(that)
		{
		root = that;
		Item = cCheminItem();
		route=this.Item.ROUTE;
		nowRoute=-1;
		cargo_fav=-1;
		airnet_count=0;
		virtual_air=[];
		under_upgrade=false;
		global_malus=0;
		RList = [];		// this is our routes list
		DList = AIList();	// this is our cEndDepot list, use to find a destination station
		GList = [];		// this is our Station list (rail station only)
		repair_routes = AIList();
		map_group_to_route=AIList();
		max_transport_distance = 400;
		max_town_jobs=200;	// maximum jobs we will do with towns
		}
	}

function cChemin::RemapGroupsToRoutes()
// reset and rebuild the match_group_to_route list with proper group->route that use it
{
root.chemin.map_group_to_route.Clear();
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	local road=root.chemin.RListGetItem(i);
	root.chemin.map_group_to_route.AddItem(road.ROUTE.group_id, i);
	}
}

function cChemin::GetTransportDistance(transport_type, get_max)
// Return the transport distance a transport_type could do
// if get_max=true return maximum distance, else return minimum distance
{
local small=1000;
local big=0;
local target=transport_type * 3;
local toret=0;
for (local i=0; i < root.chemin.TRANSPORT_DISTANCE.len(); i++)
	{
	local min=root.chemin.TRANSPORT_DISTANCE[i];
	local lim=root.chemin.TRANSPORT_DISTANCE[i+1];
	local max=root.chemin.TRANSPORT_DISTANCE[i+2];
	if (target == i)
		{
		if (get_max)
			{
			if (root.bank.unleash_road)	toret=max;
						else	toret=lim;
			}
		else	toret=min;
		}
	if (min < small)	small=min;
	if (max > big)		big=max;
	i+=2; // next iter
	}
root.chemin.max_transport_distance=big;
root.chemin.min_transport_distance=small;
return toret;
}

function cChemin::RouteTownsInjector_GetUniqID(srctown, dsttown, cargo, kind)
// create a uniqID for the routes we pre-build
{
if (dsttown == -1)	return 
return (root.chemin.IDX_HELPER*3*srctown+dsttown)+(kind*4)+cargo;
}

function cChemin::RouteTownsInjector_CreateRoute(src_id, dst_id, distance, cargo, roadtype)
// Add a new town pre-build town job
{
local road=cCheminItem();
road.ROUTE.isServed=false;
road.ROUTE.cargo_id=cargo;
road.ROUTE.cargo_name=AICargo.GetCargoLabel(cargo);
road.ROUTE.cargo_value=root.chemin.ValuateCargo(cargo);
road.ROUTE.src_id=src_id;
road.ROUTE.dst_id=dst_id;
road.ROUTE.src_place=AITown.GetLocation(src_id);
road.ROUTE.dst_place=AITown.GetLocation(dst_id);
road.ROUTE.src_istown=true;
road.ROUTE.dst_istown=true;
road.ROUTE.src_name=AITown.GetName(src_id);
road.ROUTE.dst_name=AITown.GetName(dst_id);
road.ROUTE.status=1;
road.ROUTE.kind=roadtype;
if (road.ROUTE.dst_id==-1)	road.ROUTE.vehicule=0;
			else	road.ROUTE.vehicule=-1;
road.ROUTE.length=distance;
road.ROUTE.uniqID=root.chemin.RouteTownsInjector_GetUniqID(src_id, dst_id, cargo, roadtype);
root.chemin.RListAddItem(road);
local rtypename=root.chemin.RouteTypeToString(road.ROUTE.kind);
DInfo("Creating a new service: "+((root.chemin.RList.len()/road.ROUTE.len())-1)+":"+road.ROUTE.uniqID+" "+road.ROUTE.src_name+" to "+road.ROUTE.dst_name+" for "+road.ROUTE.cargo_name+", "+road.ROUTE.length+"m"+" using "+rtypename,1);
}

function cChemin::RouteTownsInjector()
// Inject prebuild jobs for towns
// prebuild jobs are : pass & bus, pass & aircraft, pass & boats and mail & aircraft
// this way each town can get 1 airport handling mail+pass + 1 bus station + 1 boat station for passengers
// mail will still have 1 chance to be pick by : boat or truck (trains simply don't do town)
// We also remove undoable/unwanted connections (like dup connections)
// We will keep only bigtowns->smalltowns jobs and drop smalltowns->bigtowns jobs, this will force shared station limit to be reach faster on bigtowns and new stations build on big towns to handle the flow
{
//local transport_list=[AIVehicle.VT_AIR, AIVehicle.VT_ROAD, AIVehicle.VT_WATER];
local transport_list=[AIVehicle.VT_AIR, AIVehicle.VT_ROAD];
local towns=AITownList();
local alttowns=AIList();
local town_connector=[];
local towndone=AIList();
towns.Valuate(AITown.GetPopulation);
towns.Sort(AIList.SORT_BY_VALUE,false);
//towns.KeepTop(20);
alttowns.AddList(towns);
alttowns.KeepTop(20); // TODO: fixme
foreach (town, dummy in towns)
	{ //DInfo("doing town "+town+" connect="+town_connector.len()+" done="+towndone.Count());
	AIController.Sleep(2);
	foreach (alttown, dummy2 in alttowns)
		{
		local towncheck=1000+(town*alttown);
		if (!towndone.HasItem(towncheck) && town != alttown)
			{ //DInfo("add "+town+" -> "+alttown+" "+(town != alttown)+" "+(towndone.HasItem(towncheck))+" "+towncheck);
			towndone.AddItem(towncheck, 0);
			town_connector.push(town);
			town_connector.push(alttown);
			}
		}
	}
/*
for (local i=0; i < town_connector.len(); i++)
	{
	DInfo("Source town = "+AITown.GetName(town_connector[i])+"("+AITown.GetPopulation(town_connector[i])+") -> "+AITown.GetName(town_connector[i+1])+"("+AITown.GetPopulation(town_connector[i+1])+")",0);
	i++
	}
*/
local mailcargo=root.carrier.GetMailCargo();
local passcargo=root.carrier.GetPassengerCargo();
root.bank.unleash_road=true; // make sure it's true before filtering distances
for (local i=0; i < town_connector.len(); i++)
	{
	local srctown=town_connector[i];
	local dsttown=town_connector[i+1];
	local distance=AITile.GetDistanceManhattanToTile(AITown.GetLocation(srctown), AITown.GetLocation(dsttown));
	if (distance > root.chemin.max_transport_distance)	{ i++; continue; }
	if (distance < root.chemin.min_transport_distance)	{ i++; continue; }
	foreach (transport in transport_list)
		{
		local maxdist=root.chemin.GetTransportDistance(transport,true);
		if (distance > maxdist)	continue;
		root.chemin.RouteTownsInjector_CreateRoute(srctown, dsttown, distance, passcargo, transport);
		}
	AIController.Sleep(2);
	i++;
	}
root.bank.unleash_road=false;
root.chemin.RouteMaintenance();
root.NeedDelay(200);
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
			stationrank=(100-(road.ROUTE.foule*100)); // give up when 1 station is present
			break;
			case 1:
			stationrank=(100-(road.ROUTE.foule*100)); // give up for 2
			break;
			case 0:
			stationrank=(100-(road.ROUTE.foule*50)); // give up for 4
			break;
			}
		}
if (stationrank <= 0 && root.fairlevel >0) { stationrank=1; }
// even crowd, let's still give it a chance to be pick, lower fairlevel will never do that station
if (root.chemin.cargo_fav == road.ROUTE.cargo_id) // it's our favorite cargo
	{ valuerank+=valuerank; }
road.ROUTE.ranking=(stationrank*valuerank);
//DInfo("Ranking="+road.ROUTE.ranking+" station="+stationrank+" value="+valuerank,2);
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
			local vehlist=AIVehicleList_Group(road.ROUTE.group_id);
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
road.ROUTE.handicap-=root.chemin.global_malus;
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
road.ROUTE.isServed=false;
root.chemin.RListUpdateItem(idx,road);
root.chemin.nowRoute=-1; // reset it when we found an invalid route
root.builder.route_start=-1;
root.builder.RouteIsInvalid(idx); // look for vehicle & stations there to remove them
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
road.ROUTE.uniqID=root.chemin.IDX_HELPER*10;
road.ROUTE.src_name="Virtual aircraft network";
road.ROUTE.dst_name="Virtual aircraft network";
road.ROUTE.group_name="Virtual airnet pass";
road.ROUTE.group_id=AIGroup.CreateGroup(AIVehicle.VT_AIR);
root.chemin.virtual_air_group_pass=road.ROUTE.group_id;
road.ROUTE.isServed=true;
road.ROUTE.src_istown=true;
road.ROUTE.dst_istown=true;
road.ROUTE.ranking=0;
AIGroup.SetName(road.ROUTE.group_id, road.ROUTE.group_name);
root.chemin.RListAddItem(road);
DInfo("Creating a new service: "+((root.chemin.RList.len()/road.ROUTE.len())-1)+":"+road.ROUTE.uniqID+" "+road.ROUTE.src_name+" for "+road.ROUTE.cargo_name,1);

road.ROUTE.uniqID++;
road.ROUTE.cargo_id=root.carrier.GetMailCargo();
road.ROUTE.cargo_name=AICargo.GetCargoLabel(road.ROUTE.cargo_id);
road.ROUTE.cargo_value=root.chemin.ValuateCargo(road.ROUTE.cargo_id);
road.ROUTE.group_name="Virtual airnet mail";
road.ROUTE.group_id=AIGroup.CreateGroup(AIVehicle.VT_AIR);
root.chemin.virtual_air_group_mail=road.ROUTE.group_id;
AIGroup.SetName(road.ROUTE.group_id, road.ROUTE.group_name);
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
		{ return (industryID+1)*(root.chemin.IDX_HELPER*2)+cargoID; }
	else 	{ return (industryID+1)*(root.chemin.IDX_HELPER)+cargoID; }
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
DInfo("Finding routes...",0);
root.chemin.RouteTownsInjector();
// first, let's find industries
foreach(i, dummy in it)	{ root.chemin.RouteCreateIndustry(i); }
//² now towns

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
root.chemin.RouteMaintenance();
}

function cChemin::RouteCreateEndingList(idx)
// Build a DList with all possible place to drop our cargo for the idx starting
{
root.chemin.DList.Clear();
local who=root.chemin.RListGetItem(idx);
local cargoeffect = AICargo.GetTownEffect(who.ROUTE.cargo_id);
local dstlist=null;
local istown=false;
if (cargoeffect == AICargo.TE_NONE || cargoeffect == AICargo.TE_WATER)
	{ // not a cargo for a town
	istown=false;
	dstlist=AIIndustryList_CargoAccepting(who.ROUTE.cargo_id);
	dstlist.Valuate(AIIndustry.GetDistanceManhattanToTile, who.ROUTE.src_place);
	}
else	{ // that's cargo for a town
	istown=true;
	dstlist=AITownList();
	dstlist.Valuate(AITown.GetDistanceManhattanToTile, who.ROUTE.src_place);
	}
dstlist.KeepBetweenValue(min_transport_distance,max_transport_distance); // filter distances not really doable
if (istown)	dstlist.Valuate(AITown.GetPopulation);
dstlist.Sort(AIList.SORT_BY_VALUE, true); // biggest distance first for industry, highest population first for town
who.ROUTE.isServed=false;
// we now have a list of destinations id
// let's build our possible list to futher choose the best one
if (dstlist.Count() !=0)
	{
	foreach (i, val in dstlist)
		{
		if (istown)	root.chemin.DList.AddItem(i, 1);
			else	root.chemin.DList.AddItem(i, 0);
		}
	}
}

function cChemin::RouteRefresh()
// Refresh our routes datas
{
local listCounter=root.chemin.RListGetSize();
DInfo("Refresh "+listCounter+" routes...",1);
for (local i=0; i < listCounter; i++)
	{
	root.chemin.RouteMalusLower(i); // decrease our malus on road
	root.chemin.UpdateStartRoute(i);
	AIController.Sleep(1);
	}
root.chemin.global_malus=0;
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
	if ((!road.ROUTE.src_istown) && (!AIIndustry.IsValidIndustry(road.ROUTE.src_id)))
		{ 	// not a town and not a valid industry
		purgeit="Bad source industry";
		}
	if ((!road.ROUTE.dst_istown) && (!AIIndustry.IsValidIndustry(road.ROUTE.dst_id)))
		{ 	// not a town and not a valid industry
		purgeit="Bad destination industry";
		}
	if (road.ROUTE.uniqID in uniqList)
		{	// dup uniqID
		purgeit="Duplicate uniqID";
		}
	else	{ uniqList.push(road.ROUTE.uniqID); }
	if (purgeit != "")
		{ // found something to remove
		root.chemin.RListDumpOne(i);
		DInfo("-> Removing route "+i+" - Reason: "+purgeit,0);
		root.builder.RouteDelete(i);
		break;
		}
	} // for loop
}

function cChemin::RouteIsValid(idx)
// set all values for that route
{
root.chemin.RouteStatusChange(idx,2);
local road=root.chemin.RListGetItem(idx);
road.ROUTE.money=root.bank.GetConstructionsCosts(idx);
root.chemin.RListUpdateItem(idx, road);
DInfo("Route created: "+road.ROUTE.cargo_name+" from "+road.ROUTE.src_name+" to "+road.ROUTE.dst_name+" "+road.ROUTE.length+"km using "+root.chemin.RouteTypeToString(road.ROUTE.kind),0);
}

function cChemin::RouteTypeToString(routetype)
// return a string representing current road type
{
switch (routetype)
	{
	case	AIVehicle.VT_ROAD:
		return "bus & trucks";
	case	AIVehicle.VT_AIR:
		return	"aircrafts";
	case	AIVehicle.VT_WATER:
		return	"boats";
	case	AIVehicle.VT_RAIL:
		return	"trains";
	}
return "";
}

function cChemin::RouteFindDestinationForCargo(idx)
// Try find where to drop cargo for a route
// return -1 on failure, the index in DList on success
{
local endroute=root.chemin.RListGetItem(idx);
if (endroute.ROUTE.status!=1)	return -2; // tell caller we know where to go already
if (endroute.ROUTE.vehicule==-1)	return -2; // fixed routes will have it set to -1 until they works
DInfo("Finding where to drop cargo ("+endroute.ROUTE.cargo_name+") for service "+idx,0);
local previous_try=endroute.ROUTE.dst_entry; // we store in dst_entry the value of the previous try
root.chemin.RouteCreateEndingList(idx);
DInfo("Found "+root.chemin.DList.Count()+" possible destinations",2);
if (root.chemin.DList.Count() == 0)
	{ // DList is reset on error or size = 0 if nothing is found
	DWarn("Can't find a place who accept "+endroute.ROUTE.cargo_name+" from "+endroute.ROUTE.src_name,1);
	root.chemin.RouteIsNotDoable(idx);
	return -1;
	}
// our list is filtered a bit by range and also filter by biggest range or biggest population order
local new_try=previous_try+1;
if (new_try > root.chemin.DList.Count())	new_try=0;
return new_try;
}

function cChemin::RouteFindDestination(idx)
// Find a destination station & pickup transport type for it
{
local bestDest=root.chemin.RouteFindDestinationForCargo(idx);
DInfo("Pickup destination #"+bestDest,2);
if (bestDest < 0)	return bestDest; // fail to find a destination or we know it already
local road=root.chemin.RListGetItem(idx);
road.ROUTE.dst_id=ListGetItem(root.chemin.DList, bestDest);
road.ROUTE.dst_entry=bestDest;
road.ROUTE.dst_istown=(root.chemin.DList.GetValue(bestDest)==1);
if (road.ROUTE.dst_istown)	
	{
	road.ROUTE.dst_name=AITown.GetName(road.ROUTE.dst_id);
	road.ROUTE.dst_place=AITown.GetLocation(road.ROUTE.dst_id);
	}
else	{
	road.ROUTE.dst_name=AIIndustry.GetName(road.ROUTE.dst_id);
	road.ROUTE.dst_place=AIIndustry.GetLocation(road.ROUTE.dst_id);
	}
road.ROUTE.length=AITile.GetDistanceManhattanToTile(road.ROUTE.src_place, road.ROUTE.dst_place);
root.chemin.RListUpdateItem(idx,road);
DInfo("Choosing transport type",2);
if (!root.chemin.PickupTransportType(idx)) return -1;
return idx+1; // make sure return isn't = idx
}

function cChemin::PickupTransportType(idx)
// Pickup a road transport type if none exist for that route
// If it exist, just verify the distances are ok
// return true/false
{
local road=root.chemin.RListGetItem(idx);
if (road == -1) return false;
local kind=AICargo.GetTownEffect(road.ROUTE.cargo_id);
// road assign as 1,
// trains assign as 2
// air assign as 3
// boat, assign as 4
local v_train=1;
local v_boat =1;
local v_air  =1;
local v_road =1;
if (!root.use_train) v_train=0;
if (!root.use_boat) v_boat=0;
if (!root.use_air) v_air=0;
if (!root.use_road) v_road=0;
if (road.ROUTE.vehicule==-1) // prebuild roads, we disable others transport type so
	switch (road.ROUTE.kind)
		{
		case	AIVehicle.VT_ROAD:
			v_air=0; v_boat=0; v_train=0;
		break;
		case	AIVehicle.VT_AIR:
			v_road=0; v_boat=0; v_train=0;
		break;
		case	AIVehicle.VT_WATER:
			v_air=0; v_road=0; v_train=0;
		break;
		case	AIVehicle.VT_RAIL:
			v_air=0; v_boat=0; v_road=0;
		break;
		}
local tweaklist=AIList();
local road_maxdistance=root.chemin.GetTransportDistance(AIVehicle.VT_ROAD,true);
local road_mindistance=root.chemin.GetTransportDistance(AIVehicle.VT_ROAD,false);
local rail_maxdistance=root.chemin.GetTransportDistance(AIVehicle.VT_RAIL,true);
local rail_mindistance=root.chemin.GetTransportDistance(AIVehicle.VT_RAIL,false);
local air_maxdistance=root.chemin.GetTransportDistance(AIVehicle.VT_AIR,true);
local air_mindistance=root.chemin.GetTransportDistance(AIVehicle.VT_AIR,false);
local water_maxdistance=root.chemin.GetTransportDistance(AIVehicle.VT_WATER,true);
local water_mindistance=root.chemin.GetTransportDistance(AIVehicle.VT_WATER,false);
DInfo("Distances: Truck="+road_mindistance+"/"+road_maxdistance+" Aircraft="+air_mindistance+"/"+air_maxdistance+" Train="+rail_mindistance+"/"+rail_maxdistance+" Boat="+water_mindistance+"/"+water_maxdistance,2);
local goal=road.ROUTE.length;
DInfo("Goal distance="+goal,2);
if (kind==AICargo.TE_MAIL || kind==AICargo.TE_PASSENGERS)
	{
	if (goal >= road_mindistance && goal <= road_maxdistance)	{ tweaklist.AddItem(1,1*v_road); }
	if (goal >= rail_mindistance && goal <= rail_maxdistance)	{ tweaklist.AddItem(2,2*v_train); }
	if (goal >= air_mindistance && goal <= air_maxdistance)		{ tweaklist.AddItem(3,3*v_air); }
	if (goal >= water_mindistance && goal <= water_maxdistance)	{ tweaklist.AddItem(4,4*v_boat); }
	}
else	{ // indudstries have that effect, i won't allow something other than trucks&trains
	if (goal >= road_mindistance && goal <= road_maxdistance)	{ tweaklist.AddItem(1,1*v_road); }
	if (goal >= rail_mindistance && goal <= rail_maxdistance)	{ tweaklist.AddItem(2,2*v_train); }
	}
if (root.debug) foreach (i, dummy in tweaklist) { DInfo("roadtype="+i+" possible="+dummy,2); }
tweaklist.RemoveValue(0);
if (tweaklist.IsEmpty())
	{
	DWarn("Can't pickup a transport type with the current vehicle limitation",1); 
	root.chemin.RouteIsNotDoable(idx);
	return false;
	}
local res=AIBase.RandRange(tweaklist.Count());
res=ListGetItem(tweaklist,res);
local roadtype="";
switch (res)
	{
	case	1:
		road.ROUTE.kind=AIVehicle.VT_ROAD;
	break;
	case	2:	
		road.ROUTE.kind=AIVehicle.VT_RAIL;
	break;
	case	3:
		road.ROUTE.kind=AIVehicle.VT_AIR;
	break;
	case	4:
		road.ROUTE.kind=AIVehicle.VT_WATER;
	break;
	}
roadtype=root.chemin.RouteTypeToString(road.ROUTE.kind);
DInfo("Choosen road: "+road.ROUTE.kind+" "+roadtype,2);
root.chemin.RListUpdateItem(idx,road);
local success=root.carrier.GetVehicle(idx);
if (success < 0)
	{
	DWarn("There's no vehicle for that transport type we could use to carry that cargo",2);
	return false;
	root.chemin.RouteIsNotDoable(idx);
	}
return true;
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
local industryList=AIIndustryList();
do 	{
	bestJob=-1;
	startidx=-1;
	gotmalus=0;
	for (local i=0; i < chemSize; i++)
		{
		task=root.chemin.RListGetItem(i);
		local rnk=task.ROUTE.ranking;
		local badindustry=false;
		if (!task.ROUTE.src_istown && !industryList.HasItem(task.ROUTE.src_id))	badindustry=true;
		if (!task.ROUTE.dst_istown && !industryList.HasItem(task.ROUTE.dst_id))	badindustry=true;
		if (badindustry)	{ root.chemin.RouteMaintenance(); return -1; }
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
		endidx=root.chemin.RouteFindDestination(startidx);
		}
	root.NeedDelay(2);
	if (endidx == -2)	endidx=startidx;	// -2 = we know where to go already
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
	else	{ root.chemin.RouteIsValid(startidx); }
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
	local vehingroup=AIVehicleList_Group(road.ROUTE.group_id);
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
	local vehList=AIVehicleList_Group(road.ROUTE.group_id);
	vehList.Valuate(AIVehicle.GetProfitThisYear);
	vehList.Sort(AIList.SORT_BY_VALUE,true); // poor numbers first
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
	if (firstveh) { vehneed = 2; }
	if (vehneed >= vehonroute) vehneed-=vehonroute;
	if (vehneed+vehonroute > maxveh) vehneed=maxveh-vehonroute;
	local canaddonemore=root.carrier.CanAddNewVehicle(j, true);
	if (!canaddonemore)	vehneed=0; // don't let us buy a new vehicle if we won't be able to buy it	
	DInfo("CanAddNewVehicle for source station says "+canaddonemore,2);
	canaddonemore=root.carrier.CanAddNewVehicle(j, false);
	DInfo("CanAddNewVehicle for destination station says "+canaddonemore,2);
	if (!canaddonemore)	vehneed=0;
	DInfo("Route="+j+"-"+road.ROUTE.src_name+"/"+road.ROUTE.dst_name+"/"+road.ROUTE.cargo_name+" capacity="+capacity+" vehicleneed="+vehneed+" cargowait="+cargowait+" vehicule#="+road.ROUTE.vehicule+"/"+maxveh+" firstveh="+firstveh,2);
	if (vehprofit <=0)	profit=true; // hmmm on new years none is making profit and this fail
		else		profit=true;
	vehList.Valuate(AIVehicle.GetAge);
	vehList.Sort(AIList.SORT_BY_VALUE,true);
	if (vehList.GetValue(vehList.Begin()) > 90)	oldveh=true; // ~ 8 months
						else	oldveh=false;
	// adding vehicle
	if (vehneed > 0)
		{
		if (root.carrier.vehnextprice > 0)
			{
			DInfo("We're upgrading some vehicles, not adding new vehicle until its done to keep the money... "+root.carrier.vehnextprice,1);
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
					firstveh=false; vehneed--;
					}
				}
			if (!firstveh && vehneed > 0)
					{
					priority.AddItem(road.ROUTE.group_id,vehneed);
					continue; // skip to next route, we won't check removing for that turn
					}
			}
		}

// Removing vehicle when station is too crowd & vehicle get stuck
	if (cargowait == 0 && oldveh) // this happen if we load everything at the station
		{
		local busyList=AIVehicleList_Group(road.ROUTE.group_id);
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
		DInfo("Vehicle "+veh+"-"+AIVehicle.GetName(veh)+" is not moving and station is busy, selling it for balancing",1);
		root.carrier.VehicleSendToDepot(veh);
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
local vehvalue=0;
foreach (groupid, ratio in priority)
	{
	if (priosave.HasItem(groupid))	vehneed=priosave.GetValue(groupid);
				else	vehneed=0;
	if (vehneed == 0) continue;
	local vehvaluegroup=AIVehicleList_Group(groupid);	
	vehvalue=AIEngine.GetPrice(AIVehicle.GetEngineType(vehvaluegroup.Begin()));
	for (local i=0; i < root.chemin.RListGetSize(); i++)
		{
		road=root.chemin.RListGetItem(i);
		if (road.ROUTE.group_id == groupid)
			{
			for (local z=0; z < vehneed; z++)
				{
				if (root.bank.CanBuyThat(vehvalue))
					if (root.carrier.BuildAndStartVehicle(i,true))
						{
						DInfo("Adding a vehicle to route #"+i+" "+road.ROUTE.cargo_name+" from "+road.ROUTE.src_name+" to "+road.ROUTE.dst_name,0);
						}
				}
			}
		}
	}
}

