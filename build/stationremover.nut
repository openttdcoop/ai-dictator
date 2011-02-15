function cBuilder::DeleteStationSourceOrDestination(idx, start)
// remove a start or end station from idx
// check no one else use it before doing that
{
local exist=false;
local obj=root.chemin.RListGetItem(idx);
local realidobj=root.builder.GetStationID(idx,start);
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	if (i == idx) continue; // ignore ourselves
	local temp=root.chemin.RListGetItem(i);
	if (!temp.ROUTE.isServed) continue; // we need an already built route, even our isn't ready
	local realidtemp=root.builder.GetStationID(i,start);
	if (realidtemp == realidobj)
		{
		DInfo("Can't delete station "+AIStation.GetName(realidobj)+" ! Station is use by another route",0);
		return false;
		}
	}
// didn't find someone else use it

// check if we have a vehicle using it
local vehcheck=AIVehicleList_Station(realidobj);
if (!vehcheck.IsEmpty())
	{
	DInfo("Can't delete station "+AIStation.GetName(realidobj)+" ! Station is use by "+vehcheck.Count()+" vehicles",0);
	return false;
	}
local wasnamed=AIStation.GetName(realidobj);
// blacklist that tile
root.builder.BlacklistTile(AIStation.GetLocation(realidobj));
if (!AITile.DemolishTile(AIStation.GetLocation(realidobj))) return false;
DInfo("Removing station "+wasnamed+" unused by anyone",0);
local fakeid=-1;
if (start)	fakeid=obj.ROUTE.src_station;
	else	fakeid=obj.ROUTE.dst_station;
for (local j=0; j < root.chemin.RListGetSize(); j++)
	{
	local road=root.chemin.RListGetItem(j);
	//if (!road.ROUTE.isServed) continue; // don't care non working route
	if (road.ROUTE.src_station >= fakeid) road.ROUTE.src_station--;	
	if (road.ROUTE.dst_station >= fakeid) road.ROUTE.dst_station--;
	root.chemin.RListUpdateItem(j,road);
	}
root.chemin.GListDeleteItem(fakeid);
return true;
}

function cBuilder::DeleteDepot(tile)
{
local isDepot=(AIMarine.IsWaterDepotTile(tile) || AIRoad.IsRoadDepotTile(tile) || AIRail.IsRailDepotTile(tile));
if (isDepot)	cTileTools.DemolishTile(tile);
}

function cBuilder::DeleteStation(idx)
{
local realidobj=root.builder.GetStationID(idx,true);
DInfo("DEBUG removing a station, realidobj is stationID, should be -1 ="+realidobj,2);
if (realidobj!=-1)	root.builder.DeleteStationSourceOrDestination(idx,true);
realidobj=root.builder.GetStationID(idx,false);
if (realidobj!=-1)	root.builder.DeleteStationSourceOrDestination(idx,false);
local depot=root.builder.GetDepotID(idx,true);
root.builder.DeleteDepot(depot);
depot=root.builder.GetDepotID(idx,false);
root.builder.DeleteDepot(depot);
}

function cBuilder::RouteDelete(idx)
// Delete a route, we may have vehicule on it...
{
root.builder.DeleteStation(idx);
root.chemin.RListDeleteItem(idx);
}



