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

function cStationAir::CheckAirportLimits()
// Set limits for airports
	{
	if (!AIStation.IsValidStation(this.stationID) || !AIStation.HasStationType(this.stationID, AIStation.STATION_AIRPORT))
		{
		DWarn("Invalid airport station ID",1);
		return; // it happen if the airport is moved and now invalid
		}
	locations=cTileTools.FindStationTiles(AIStation.GetLocation(this.stationID));
	this.specialType=AIAirport.GetAirportType(this.locations.Begin());
	if (this.specialType == 255)
		{
		DWarn("Invalid airport type at "+this.locations.Begin(),1);
		PutSign(this.locations.Begin(),"INVALID AIRPORT TYPE !");
		INSTANCE.NeedDelay(50);
		return;
		}
	this.radius=AIAirport.GetAirportCoverageRadius(this.specialType);
	this.depot=AIAirport.GetHangarOfAirport(this.locations.Begin());
	local virtualized=cStation.IsStationVirtual(this.stationID);
	// get out of airnetwork if the network is too poor
	local rawlimit=INSTANCE.main.carrier.AirportTypeLimit[this.specialType];
	DInfo("rawlimit="+rawlimit+" type="+this.specialType,1);
	this.vehicle_max=rawlimit;
	if (virtualized)	this.vehicle_max=INSTANCE.main.carrier.airnet_max * rawlimit;
			else	if (this.vehicle_max > rawlimit)	this.vehicle_max=rawlimit;
	}


