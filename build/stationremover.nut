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

function cBuilder::DeleteStation(uid, stationid)
// Remove stationid from uid route
// check no one else use it before doing that
{
local exist=false;
local temp=cStation.GetStationObject(stationid);
if (temp != null)	exist=true; // a case where a station exist but not in our base
if (exist)
	{
	if (temp.owner.Count() != 0)
		{
		DInfo("Can't delete station "+AIStation.GetName(stationid)+" ! Station is use by "+temp.owner.Count()+" route",1);
		return false;
		}
	// didn't find someone else use it
	// check if we have a vehicle using it
	INSTANCE.carrier.VehicleGroupSendToDepotAndSell(uid);
	local vehcheck=AIVehicleList_Station(stationid);
	if (!vehcheck.IsEmpty())
		{
		DWarn("Still have "+vehcheck.Count()+" vehicle using station "+AIStation.GetName(stationid),1);
		}
	}
local wasnamed=AIStation.GetName(stationid);
local tilelist=cTileTools.FindStationTiles(AIStation.GetLocation(stationid));
foreach (tile, dummy in tilelist)
	{
	if (!AITile.DemolishTile(tile)) return false;
	}
DInfo("Removing station "+wasnamed,0);
if (exist)
	{
	if (!INSTANCE.builder.DeleteDepot(temp.depot))	{ DInfo("Fail to remove depot link to station "+wasnamed,1); }
								else	{ DInfo("Removing depot link to station "+wasnamed,0); }
	cStation.DeleteStation(stationid);
	}
return true;
}

function cBuilder::DeleteDepot(tile)
{
local isDepot=cStation.IsDepot(tile);
if (isDepot)	return cTileTools.DemolishTile(tile);
}
