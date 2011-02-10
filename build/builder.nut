class cBuilder
	{
	root = null;
static	DIR_NE = 2; // gareW+routeE = depot sortie vers E, me=0
static	DIR_NW = 0; // gareS+routeN = depot sortie vers N, me=3
static	DIR_SE = 1; // gareN+routeS = depot sortie vers S, me=1
static	DIR_SW = 3; // gareE+routeW = depot sortie vers W, me=2
	currentRoadType=null;
	
	statile=null;
	stafront = null;
	deptile=null;
	depfront=null;
	statop=null;
	stabottom=null;
	stationdir=null;
	frontfront=null;
	CriticalError=null;
	holestart=null;
	holeend=null;
	holes=null;
	TilesBlacklist=null;
	savedepot = null; 			// the tile of the last depot we have build
	
	constructor(that)
		{
		root = that;
		TilesBlacklist=AIList();
		CriticalError=false;
		}
	}

function cBuilder::BlacklistTile(tile)
// add that tile to our blacklist
{
root.builder.TilesBlacklist.AddItem(tile,0);
}

function cBuilder::RemoveBlacklistTiles(tilelist)
// remove all blacklist tile from tilelist and return it
{
local newTile=AIAbstractList();
newTile.AddList(tilelist);
DInfo("newTile size "+newTile.Count(),2);
if (newTile.IsEmpty()) return;
foreach (tile, dummy in tilelist)
	{
	if (root.builder.TilesBlacklist.HasItem(tile))	newTile.RemoveItem(tile);
	}
tilelist=newTile;
}

function cBuilder::IsCriticalError()
// Check the last error to see if the error is a critical error or temp failure
// we return false when no error or true when error
// we set CriticalError to true for a critcal error or false for a temp failure
{
if (root.builder.CriticalError) return true; // tell everyone we fail until the flag is remove
local lasterror=AIError.GetLastError();
DInfo("Error check: "+AIError.GetLastErrorString(),2);
switch (lasterror)
	{
	case AIError.ERR_NOT_ENOUGH_CASH:
		root.builder.CriticalError=false;
		return true;
	break;
	case AIError.ERR_NONE:
		root.builder.CriticalError=false;
		return false;
	break;
	case AIError.ERR_VEHICLE_IN_THE_WAY:
		root.builder.CriticalError=false;
		return true;
	break;
	case AIError.ERR_LOCAL_AUTHORITY_REFUSES:
		root.builder.CriticalError=false;
		return true;
	break;
	case AIError.ERR_ALREADY_BUILT:
		root.builder.CriticalError=false;
		return false; // let's fake we success in that case
	break;
	default:
		root.builder.CriticalError=true;
		return true; // critical set
	}
}

function cBuilder::ValidateLocation(location, direction, width, depth)
// check a rectangle of 5 length x size width for construction
// true if we are good to go, false on error
{
local tiletester=AITileList();
local checker=null;
switch (direction)
	{
	case AIRail.RAILTRACK_NE_SW:
// gauche/droite
		checker = AIMap.GetTileIndex(depth,width);
	break;
	case AIRail.RAILTRACK_NW_SE:
// haut/bas
		checker = AIMap.GetTileIndex(width,depth);
	break;
	}
tiletester.AddRectangle(location, location+checker);
showLogic(tiletester);
local tile=null;
local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
// we will demolish anything that can prevent us from building, except if that thing is own by us
// this way we clean the path but still keep our previous tracks on, in case anything goes wrong
// we will still have a valid station
foreach (i, dummy in tiletester)
	{
	tile=AITile.GetOwner(i);
	// TODO: i suppose our HQ can make next test fail, so todo is add a check & move the hq
	// HQ is 2 tiles squarre
	// TODO: check also tile is own by us, but at least a train related stuff, else we may destroy
	// a road/air... station and so invaliding ourself a working route
	if (tile == weare)	continue; // tile is ok, it's one of our tile
	DInfo(tile+" my compny "+weare,2);
	// Watchout for roadtile from company X crossing our rail
	tile=cTileTools.DemolishTile(i); // can we delete that tile ? Ignore result, we will care about it on next try
	tile=cTileTools.DemolishTile(i); // demolish it twice, this should remove the crossing roads case
	if (!root.builder.IsCriticalError()) continue;
		else	{ return false; }
	}
ClearSignsALL();
return true;
}

function cBuilder::GetDirection(tilefrom, tileto)
{
	local distx = AIMap.GetTileX(tileto) - AIMap.GetTileX(tilefrom);
	local disty = AIMap.GetTileY(tileto) - AIMap.GetTileY(tilefrom);
	local ret = 0;
	if (abs(distx) > abs(disty)) {
		ret = 2;
		disty = distx;
	}
	if (disty > 0) {ret = ret + 1}
	DInfo("get direction : distx="+distx+" disty="+disty+" ret="+ret,2);
	return ret;	
}

function cBuilder::BuildStation(start)
// Build start station, reroute to the correct station builder depending on the road type to build
{
local what=root.chemin.RListGetItem(root.chemin.nowRoute);
local success=false;
switch (what.ROUTE.kind)
	{
	case AIVehicle.VT_ROAD:
	success=root.builder.BuildRoadStation(start);
	break;
	case AIVehicle.VT_RAIL:
	success=root.builder.BuildTrainStation(start);
	break;
	case AIVehicle.VT_WATER:
	break;
	case AIVehicle.VT_AIR:
	success=root.builder.BuildAirStation(start);
	break;
	}
return success;
}

function cBuilder::BuildRoadByType(idx)
// build the road, reroute to correct function depending on road type
// for all except trains, src & dst = station location of start & destination station
// for trains, src & dst = false stationID for trains pointing to our GList
{
local road=root.chemin.RListGetItem(idx);
local success=false;
switch (road.ROUTE.kind)
	{
	case AIVehicle.VT_ROAD:
	local srcstation=root.chemin.GListGetItem(road.ROUTE.src_station);
	local dststation=root.chemin.GListGetItem(road.ROUTE.dst_station);
	local fromsrc=srcstation.STATION.e_loc; // road only use entry station
	local todst=dststation.STATION.e_loc;
	DInfo("Calling road pathfinder: from src="+fromsrc+" to dst="+todst,2);
	return root.builder.BuildRoadROAD(fromsrc,todst);
	break;

	case AIVehicle.VT_RAIL:
	success=root.builder.CreateStationsConnection(road.ROUTE.src_station, road.ROUTE.dst_station);
	local sentry=false; local dentry=false;
	if (success)	{
			local sSt=root.chemin.GListGetItem(road.ROUTE.src_station);
			local dSt=root.chemin.GListGetItem(road.ROUTE.dst_station);
			local srcpos=sSt.STATION.query;
			local dstpos=dSt.STATION.query;
			local srclink=0; local dstlink=0;
			if (sSt.STATION.e_loc == srcpos)	{ srclink=sSt.STATION.e_link; sentry=true; }
						else		{ srclink=sSt.STATION.s_link; sentry=false; }
			if (dSt.STATION.e_loc == dstpos)	{ dstlink=dSt.STATION.e_link; dentry=true; }
						else		{ dstlink=dSt.STATION.s_link; dentry=false; }
			DInfo("Calling rail pathfinder: src="+srcpos+" dst="+dstpos,2);
			PutSign(srcpos,"Source"+srcpos); PutSign(dstpos,"Target"+dstpos);
			//PutSign(srclink,"Distance: "+srclink); PutSign(dstlink,"LinkTarget"+dstlink);
			success=root.builder.BuildRoadRAIL([srclink,srcpos],[dstlink,dstpos]);
			}
	if (!success)	{ return false; } // leave critical status for caller
	// if we are here we success
	road.ROUTE.src_entry=sentry;
	road.ROUTE.dst_entry=dentry;
	root.chemin.RListUpdateItem(idx,road);
	break;
	case AIVehicle.VT_WATER:
	return true;
	break;
	case AIVehicle.VT_AIR:
	return true;
	break;
	}
return success;
}

function cBuilder::FindCompatibleStationExistForAllCases(source, t_index, s_start, t_start)
// Find if we have a station that can be re-use for nowRoute
// source is our cChemin objet that is looking for a station
// t_index is the index where we have stations to compare with source ones
// s_start = source station start or end
// t_start = target start or end
// return true if compatible
{
local target=root.chemin.RListGetItem(t_index);
local compareStationType=-1;
local comparerealid=root.builder.GetStationID(t_index,t_start);
DInfo("Station id ="+comparerealid);
// check the station is valid
//if (!AIStation.IsValidStation(comparerealid))	{ return false; }
// We need to find if the station can provide or accept the cargo we need
local comparelocation=AIStation.GetLocation(comparerealid);
compareStationType=root.builder.GetStationType(comparerealid);
DInfo("Station is type : "+compareStationType,2);
if (compareStationType == -1) return false;
// first the easy passengers road cases
local cargo=AICargo.GetTownEffect(source.ROUTE.cargo_id);
DInfo("cargo type="+source.ROUTE.cargo_name,2);
if (compareStationType == AIStation.STATION_BUS_STOP && cargo != AICargo.TE_PASSENGERS) return false; // can only do pass
if (compareStationType == AIStation.STATION_TRUCK_STOP && cargo == AICargo.TE_PASSENGERS) return false; // truck cannot do pass
DInfo("We pass thru cargo checking",2);
local radius=AIStation.GetCoverageRadius(compareStationType);
local level=0;
if (s_start)	level=AITile.GetCargoProduction(comparelocation,source.ROUTE.cargo_id,1,1,radius)+7; 
	else	level=AITile.GetCargoAcceptance(comparelocation,source.ROUTE.cargo_id,1,1,radius);
if (s_start)	{ DInfo("Station production level : "+level,2); }
	else	{ DInfo("Station accept level : "+level,2); }
if (compareStationType != 8) // airports are 8, we don't do that check, assume it will be ok
	{
	if (level < 8) { DInfo("Station doesn't accept/provide "+source.ROUTE.cargo_name,2); return false; }
	}
else	{ DInfo("No production check for airports",2); }
// here station are compatible, but still do that station is within our original station area ?
DInfo("Checking if station is within area of our industry/town",2);
local tilecheck = null;
local goal=null;
local startistown=false;
if (s_start)	{ startistown=source.ROUTE.src_istown; goal=source.ROUTE.src_id; }
	else	{ startistown=source.ROUTE.dst_istown; goal=source.ROUTE.dst_id; }
if (startistown)
	{ // check if the station is also influencing our town
	tilecheck=AIStation.IsWithinTownInfluence(comparerealid,goal);
	if (compareStationType ==8)	// airports: as i don't really want to find the airport width and height
		{ 			// and then compare each points within that w*h area for town influce
		local aircheck=null;	// i just assume the airport was nicelly put and so if both id are equal
		if (t_start)	{ aircheck=target.ROUTE.src_id; } // the airport is under the town influence
			else	{ aircheck=target.ROUTE.dst_id; }
		if (aircheck == goal)	tilecheck=true;
				else	tilecheck=false;
		}
	if (tilecheck)	
		{ DInfo("Station is within "+AITown.GetName(goal)+" influence",2); }
	else	{
		DInfo("Station is outside "+AITown.GetName(goal)+" influence",2);
		return false;
		}
	}
else	{ // check the station is within our industry
	if (s_start)	tilecheck=AITileList_IndustryProducing(goal, radius);
		else	tilecheck=AITileList_IndustryAccepting(goal, radius);
	// if the station is in that list, the station touch the industry, nice
	local touching=tilecheck.HasItem(comparelocation);
	if (touching)
		{ DInfo("Station is within our industry radius",2); }
	else	{ DInfo("Station is outside "+AIIndustry.GetName(goal)+" radius",2);
		return false;
		}
	}

DInfo("Checking if station can accept more vehicles",1);
if (!root.carrier.CanAddNewVehicle(t_index, t_start))
	{
	DInfo("Station cannot get more vehicle, even compatible, we need a new one",1);
	return false;
	}

local ss=null;
local ds=null;
if (s_start) ss="Source start";
else	ss="Source end";
if (t_start) ds="destination start";
else	ds="destination end";
DInfo(ss+" station is compatible with "+ds,1);
return true;
}

function cBuilder::FindCompatibleStationExists(idx)
// Find if we already have a station on a place
// if compatible, we could link to use that station too
// we will directly set the 
{
local road=root.chemin.RListGetItem(idx);
local sdepot=-1;
local sstation=-1;
local edepot=-1;
local estation=-1;
local sfound=false;
local efound=false;
local sidx=-1;
local eidx=-1;
local success=false;
DInfo("Looking for a compatible station",1);
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	if (i == idx)	continue; // ignore ourself
	local temp=root.chemin.RListGetItem(i); // load our compare chemin
	if (!temp.ROUTE.isServed)	continue; // we only work on fully functional station
	if (temp.ROUTE.kind != road.ROUTE.kind)	continue; // not same road type, station cannot be re-used
	// upper filters should have removed a lot of incompatibles cases
	DInfo("Analysing route "+i,2);
	root.chemin.RListDumpOne(i);
	local test=false;
	if (!sfound)
		{
		test=root.builder.FindCompatibleStationExistForAllCases(road,i,true,true);
		if (test)	{ sidx=i; sfound=true; sdepot=temp.ROUTE.src_entry; sstation=temp.ROUTE.src_station; }
		}
	if (!sfound)
		{
		test=root.builder.FindCompatibleStationExistForAllCases(road,i,true,false);
		if (test)	{ sidx=i; sfound=true; sdepot=temp.ROUTE.dst_entry; sstation=temp.ROUTE.dst_station; }
		}
	if (!efound)
		{
		test=root.builder.FindCompatibleStationExistForAllCases(road,i,false,true);
		if (test)	{ eidx=i; efound=true; edepot=temp.ROUTE.src_entry; estation=temp.ROUTE.src_station; }
		}
	if (!efound)
		{
		test=root.builder.FindCompatibleStationExistForAllCases(road,i,false,false);
		if (test)	{ eidx=i; efound=true; edepot=temp.ROUTE.dst_entry; estation=temp.ROUTE.dst_station; }
		}
	if (sfound && efound)	break; // we have all we need
	}
if (sfound)	{
		DInfo("Found a compatible station for our source station !",1);
		road.ROUTE.src_entry=sdepot; road.ROUTE.src_station=sstation; }
	else { DInfo("Failure, creating a new station for our source station.",1); }
if (efound)	{
		DInfo("Found a compatible station for our destination station !",1);
		road.ROUTE.dst_entry=edepot; road.ROUTE.dst_station=estation; }
	else { DInfo("Failure, creating a new station for our destination station.",1); }
if (sfound && efound)
	{ // this indicate we have found a starting & ending station re-usable -> that was our goal
	  // But our new road and that road could be a dual road
	  // like the case BUS:PASS:Paris->Nice and BUS:PASS:Nice->Paris
	  // We should delete Nice->Paris or Paris->Nice to keep only one route to enforce our vehicle limitation / route
	  // but it also could be not the case !!!
	  // like ROAD:GOLD:Paris->Nice & ROAD:MAIL:Nice->Paris or ROAD:MAIL:Paris-Nice, not doing the same work, but using the same
	  // road stations to carry the gold & mail, it would be really bad to remove such a route
	if (eidx == sidx)
		{ // both station have the same road idx, so it's two stations from same road == still we're not a dup if we don't
		  // carry the same thing. Like we do ROAD:MAIL:Paris->Nice/Paris and we just found a ROAD:GOLD:Paris/Nice route
		local temp=root.chemin.RListGetItem(sidx);
		if (road.ROUTE.cargo_id == temp.ROUTE.cargo_id)
				{ // now we're sure it's a dup (a twoway route and oneway is already running)
				DInfo("Dup dual route found ! Ignoring it",1);
				root.chemin.RouteIsNotDoable(idx);
				root.builder.CriticalError=false; // tell caller about it
				// here 2 choices: telling CriticalError=true so caller will just build 2 new stations & continue
				// or CriticalError=false so caller will stop construction thinking we lack funds or something not
				// critical, caller will end stopping construction
				return false;
				}
			else	success=true;
		}
	else	{ success=true; }
	}
else	success=true;
root.chemin.RListUpdateItem(idx,road); // save it
return success;
}

function cBuilder::TryBuildThatRoute(idx)
// advance the route construction
{
local rr=root.chemin.RListGetItem(idx);
local success=false;
success=root.carrier.GetVehicle(idx);
// this check we could pickup a vehicle to validate road type can be use
if (!success)
	{
	root.chemin.RouteIsNotDoable(idx); // retry that road real later
	return false;
	}
else	{ root.chemin.RouteStatusChange(idx,3); } // advance to phase 3
root.bank.RaiseFundsBigTime();
rr=root.chemin.RListGetItem(idx); // reload datas
if (rr.ROUTE.status==3)
	{
	success=root.builder.FindCompatibleStationExists(idx);
	if (!success)
		{
		// failure to find a compatible station isn't critical, just mean we don't find one
		// but we might have find one that wasn't able to be upgrade for a reason
		if (!root.builder.CriticalError)
			{ // reason is not critical, lacking funds...
			root.chemin.RouteMalusHigher(idx);
			return false; // let's get out, so we still have a chance to upgrade the station & find its compatibility
			}
		// for a critical reason, we just continue to build with a new station
		root.builder.CriticalError=false; // unset it
		}
	root.chemin.RouteStatusChange(idx,4);
	}

rr=root.chemin.RListGetItem(idx); // reload datas
if (rr.ROUTE.status==4)
	{
	if (rr.ROUTE.src_station==-1)	{ success=root.builder.BuildStation(true); }
		else	{ success=true; DInfo("Source station is already build, we're reusing an existing one",0); }
	if (!success)
		{ // it's bad we cannot build our source station, that's really bad !
		if (root.builder.CriticalError)
			{
			root.builder.CriticalError=false;
			root.chemin.RouteIsNotDoable(idx); // get back to retry everything
			return false;
			}
		else	{ root.chemin.RouteMalusHigher(idx); return false; }
		}
	else { root.chemin.RouteStatusChange(idx,5); }
	}

rr=root.chemin.RListGetItem(idx); // reload datas
if (rr.ROUTE.status==5)	
	{
	if (rr.ROUTE.dst_station==-1)	{ success=root.builder.BuildStation(false); }
		else	{ success=true; DInfo("Destination station is already build, we're reusing an existing one",0); }
	if (!success)
		{ // we cannot do destination station
		if (root.builder.CriticalError)
			{
			root.builder.CriticalError=false;
			root.chemin.RouteIsNotDoable(idx);
			return false;
			}
		else	{ root.chemin.RouteMalusHigher(idx); return false; }
		}
	else	{ root.chemin.RouteStatusChange(idx,6); }
	}

rr=root.chemin.RListGetItem(idx); // reload datas
if (rr.ROUTE.status==6)
	{
	success=root.builder.BuildRoadByType(idx);
	if (success) 	{
			DInfo("Route contruction complete ! "+rr.ROUTE.src_name+" to "+rr.ROUTE.dst_name,0);
			rr.ROUTE.isServed=true;
			rr.ROUTE.groupe_id=AIGroup.CreateGroup(rr.ROUTE.kind);
			local groupname = AICargo.GetCargoLabel(rr.ROUTE.cargo_id)+" - "+rr.ROUTE.src_name;
			if (groupname.len() > 29) groupname = groupname.slice(0, 28);
			rr.ROUTE.groupe_name=groupname;
			AIGroup.SetName(rr.ROUTE.groupe_id, rr.ROUTE.groupe_name);
			root.chemin.RListUpdateItem(idx,rr);
			root.chemin.RouteStatusChange(idx,100);
			}
		else	{
			if (root.builder.CriticalError)
				{
				root.builder.CriticalError=false;
				root.chemin.RouteIsNotDoable(idx);
				root.builder.DeleteStation(idx);
				return false;
				}
			else	{ return false; }
			}
	}
if (rr.ROUTE.status==666)
	{
	// TODO: per type check: road or rail
	// TODO: pathfind from station-> depot for source & destination
	success=root.builder.BuildRoadByType(idx);
	if (success)	
		{
		DInfo("Route #"+idx+" repair successfuly",0);
		root.chemin.RouteStatusChange(idx,100);
		}
	}
/*rr=root.chemin.RListGetItem(idx); // reload datas
if (rr.ROUTE.status==10)
	{
	root.chemin.buildmode=true; // build best !
	success=root.carrier.BuildAndStartVehicle(idx,false);
	if (success)	{ root.chemin.RouteStatusChange(idx,20); root.carrier.BuildAndStartVehicle(idx,true); }
		else	{ DInfo("Report first vehicle failure at creation ! "+success,1); return false; }
	}*/
return success;
}

