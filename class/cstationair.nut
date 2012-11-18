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

class cStationAir extends cStation
{
	constructor()
		{
		::cStation.constructor();
	 	this.ClassName	= "cStationAir";
		}
}

function cStation::IsStationVirtual(stationID)
// return true if the station is part of the airnetwork
	{
	return (cCarrier.VirtualAirRoute.len() > 1 && cStation.VirtualAirports.HasItem(stationID));
	}

function cStationAir::CheckAirportLimits()
// Set limits for airports
	{
	if (!AIStation.IsValidStation(this.s_ID) || !AIStation.HasStationType(this.s_ID, AIStation.STATION_AIRPORT))
		{
		DWarn("Invalid airport station ID",1);
		return; // it happen if the airport is moved and now invalid
		}
	local virtualized = cStation.IsStationVirtual(this.s_ID);
	// get out of airnetwork if the network is too poor
	local rawlimit = INSTANCE.main.carrier.AirportTypeLimit[this.s_SubType];
	DInfo("airport rawlimit="+rawlimit+" type="+this.s_SubType,1);
	this.s_VehicleMax=rawlimit;
	if (virtualized)	this.s_VehicleMax = INSTANCE.main.carrier.airnet_max * rawlimit;
			else	if (this.s_VehicleMax > rawlimit)	this.s_VehicleMax = rawlimit;
	}


