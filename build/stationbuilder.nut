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

// this file handle stations (mostly handling rail stations) as they are specials


function cBuilder::GetStationType(stationid)
// Check if the stationid have a type and return it
// return the stationtype we found
{
if (!AIStation.IsValidStation(stationid))	return -1;
local stationtype=-1;
stationtype=AIStation.STATION_AIRPORT;
if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
stationtype=AIStation.STATION_TRAIN;
if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
stationtype=AIStation.STATION_DOCK;
if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
stationtype=AIStation.STATION_TRUCK_STOP;
if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
stationtype=AIStation.STATION_BUS_STOP;
if (AIStation.HasStationType(stationid, stationtype))	return stationtype;
return -1;
}

