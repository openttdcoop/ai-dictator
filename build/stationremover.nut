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
	if (!temp)	exist = false; // A case where a station exist but not in our station base
	if (exist)
		{ // check no route still use it
		wasnamed = temp.s_Name;
		if (temp.s_Owner.Count() != 0)
			{
			DInfo("Can't remove station "+wasnamed+" ! Station is still used by "+temp.s_Owner.Count()+" routes",1);
			return false;
			}
		local now = AIDate.GetCurrentDate();
		if (now - temp.s_DateBuilt < 30 && !AIController.GetSetting("infrastructure_maintenance"))
			{
			DInfo("Station "+wasnamed+" is not old enough. Keeping it for now.",1);
			return false;
			}
		}
	DInfo("Destroying station "+wasnamed,0);
	if (exist)
		{
		if (temp.s_SubType != -2) //don't try destroy virtual station tiles, some player play with magic buldozer cheat
            {
            foreach (tile, dummy in temp.s_Tiles)	{ cTileTools.UnBlackListTile(tile); }
            foreach (tile, dummy in temp.s_TilesOther)	{ cTileTools.UnBlackListTile(tile); }
            if (!temp.s_TilesOther.IsEmpty())
                {
                if (temp.s_Type == AIStation.STATION_TRAIN)	{ cTrack.RailCleaner(temp.s_TilesOther); }
													else	{ cTrack.RoadCleaner(temp.s_TilesOther); }
                }
            }
        if (!cTrack.DestroyDepot(temp.s_Depot))	{ DInfo("Fail to remove depot link to station "+wasnamed,1); }
										else	{ DInfo("Removing depot link to station "+wasnamed,0); }
		if (!cStation.DeleteStation(stationid))	{ return false; }
		if (temp.s_SubType == -2)   { return true; }
		}
	local tilelist=cTileTools.FindStationTiles(AIStation.GetLocation(stationid));
	tilelist.Valuate(AITile.GetOwner);
	tilelist.KeepValue(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)); // Prevent magic bulldozer destroying platform
	foreach (tile, dummy in tilelist)	AITile.DemolishTile(tile); // still rough to do that, could do it nicer
	return true;
}
