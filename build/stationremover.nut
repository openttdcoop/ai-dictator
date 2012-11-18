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

function cBuilder::DestroyStation(stationid)
// Remove a station from uid route
// Check no one else use it and the station is old enough before doing that
{
	local exist=true;
	if (stationid == null)	return false;
	local temp=cStation.Load(stationid);
	if (!AIStation.IsValidStation(stationid))
		{
		cStation.DeleteStation(stationid);
		return false;
		}
	local wasnamed = AIStation.GetName(stationid);
	if (!temp)	exist=false; // A case where a station exist but not in our station base
	if (exist)
		{ // check no route still use it
		wasnamed = temp.s_Name;
		if (temp.s_Owner.Count() != 0)
			{
			DInfo("Can't remove station "+wasnamed+" ! Station is still used by "+temp.s_Owner.Count()+" routes",1);
			return false;
			}
		// check station is old enough, it cost money, but keeping it we could reuse it without paying again the rating costs to rebuild one
		local now = AIDate.GetCurrentDate();
		if (now - temp.s_DateBuilt < 180) // kept stations for half a year
			{
			DInfo("Station "+wasnamed+" is not old enough. Keeping it for now.",1);
			return false;
			}
		}
	// check if we have vehicle using it
	local vehcheck=AIVehicleList_Station(stationid);
	if (!vehcheck.IsEmpty())
		{
		DWarn("Sending "+vehcheck.Count()+" vehicles using station "+wasnamed+" to depot",1);
		cCarrier.VehicleListSendToDepotAndWaitSell(vehcheck)
		vehcheck=AIVehicleList_Station(stationid); // recheck
		if (!vehcheck.IsEmpty())
			{
			DWarn("We still have vehicle using station "+wasnamed,1);
			return false;
			}
		}
	// now remove it
	DInfo("Destroying station "+wasnamed,0);
	if (exist)
		{
		foreach (tile, dummy in temp.s_Tiles)	{ cTileTools.UnBlackListTile(tile); }
		if (!temp.s_Tiles.IsEmpty())
			{
			if (temp.s_Type == AIStation.STATION_TRAIN)	cBuilder.RailCleaner(temp.s_Tiles);
			}
		if (!cBuilder.DestroyDepot(temp.s_Depot))	{ DInfo("Fail to remove depot link to station "+wasnamed,1); }
								else	{ DInfo("Removing depot link to station "+wasnamed,0); }
		AIController.Sleep(10);
		if (!cStation.DeleteStation(stationid))	return false;
		}
	local tilelist=cTileTools.FindStationTiles(AIStation.GetLocation(stationid));
	foreach (tile, dummy in tilelist)	AITile.DemolishTile(tile); // still rough to do that, could do it nicer
	return true;
}

function cBuilder::DestroyDepot(tile)
// Remove a depot, sold any vehicle in it that might prevent us doing it
{
	local isDepot=cStation.IsDepot(tile);
	if (!isDepot)	return false;
	local veh = AIVehicleList_Depot(tile);
	if (!veh.IsEmpty())
		{
		DInfo("Selling all vehicles at depot "+tile+" to remove it.",1);
		foreach (vehID, _ in veh)	cCarrier.VehicleSell(vehID, false);
		}
	return cTileTools.DemolishTile(tile);
}

