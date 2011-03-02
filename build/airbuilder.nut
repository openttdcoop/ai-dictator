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

function cBuilder::AirportNeedUpgrade(idx,start)
// this upgrade an existing airport to a newer one
{
DInfo("Airport upgrader start for route "+idx,2);
// better check criticals stuff before stopping our traffic and find we're going to fail
local road=INSTANCE.chemin.RListGetItem(idx);
if (!road.ROUTE.isServed) return false; // don't upgrade a non working airport
if (start && !road.ROUTE.src_entry) return false; // plaform are set to false, we cannot upgrade a platform
if (road.ROUTE.kind != AIVehicle.VT_AIR) return false; // not an aircraft route
if (start)	{ if (!road.ROUTE.src_istown) return false; } // make sure we work on a town
	else	{ if (!road.ROUTE.dst_istown) return false; }
local station=null;
local stationfakeid=null;
if (start)	stationfakeid=road.ROUTE.src_station;
	else	stationfakeid=road.ROUTE.dst_station;
station=INSTANCE.chemin.GListGetItem(stationfakeid);
local townrating=0;
local noiselevel=0;
local townid=0;
local airporttype=INSTANCE.builder.GetAirportType();
if (start)	townid=road.ROUTE.src_id;
	else	townid=road.ROUTE.dst_id;
townrating=AITown.GetRating(townid,AICompany.COMPANY_SELF);
noiselevel=AITown.GetAllowedNoise(townid);
local ourloc=0;

local ournoise=AIAirport.GetNoiseLevelIncrease(AIStation.GetLocation(station.STATION.e_loc),airporttype);
DInfo("Upgrading airport "+AIStation.GetName(station.STATION.station_id),0);
DInfo("Town rating = "+townrating+" noiselevel="+noiselevel,2);
if (townrating < AITown.TOWN_RATING_MEDIOCRE)
	{ DInfo("Cannot upgrade airport, town will refuse that.",0); return false; }
local cost=AIAirport.GetPrice(airporttype);
cost+=1000; // i'm not sure how much i need to destroy old airport
INSTANCE.bank.RaiseFundsTo(cost);
if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < cost)
	{ DInfo("Cannot upgrade airport, need "+cost+" money for success.",0); return false; }

// find traffic that use that airport & reroute it
INSTANCE.chemin.under_upgrade=true;
// prior to reroute aircraft, make sure they have a route to go
INSTANCE.carrier.VehicleBuildOrders(road.ROUTE.group_id); // and try to rebuild its orders
INSTANCE.carrier.AirNetworkOrdersHandler(); // or maybe it's one from our network that need orders

INSTANCE.carrier.VehicleHandleTrafficAtStation(station.STATION.station_id,true);
local oldtype=station.STATION.type;
local oldplace=station.STATION.e_loc;
local counter=0;
local maxcount=100;
local result=false;
// time to pray a bit for success, we could invalidate a working route here
do	{
	result=AIAirport.RemoveAirport(station.STATION.e_loc);
	counter++;
	if (!result) 
		{
		AIController.Sleep(10);
		INSTANCE.carrier.VehicleIsWaitingInDepot(); // try remove aircraft from airport
		}
	} while (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 1000 && !result && counter < maxcount);	
if (!result)	{
		INSTANCE.carrier.VehicleHandleTrafficAtStation(station.STATION.station_id,false);
		return false;
		}
result=INSTANCE.builder.BuildAirStation(idx,start,stationfakeid);
// TODO: if airport is moved away from previous point, route is still pointing to the old airport, need to correct that
if (!result) // should have pray a bit more
	{
	INSTANCE.builder.CriticalError=false;
	local result=INSTANCE.builder.AirportMaker(oldplace, oldtype);
	}
if (!result)
	{ INSTANCE.chemin.RouteIsNotDoable(idx); }
INSTANCE.chemin.under_upgrade=false;
INSTANCE.carrier.VehicleHandleTrafficAtStation(station.STATION.station_id,false);
}

function cBuilder::GetAirportType()
// return an airport type to build or null
{
local AirType=null;
if (AIAirport.IsValidAirportType(AIAirport.AT_SMALL))	{ AirType=AIAirport.AT_SMALL; }
if (AIAirport.IsValidAirportType(AIAirport.AT_LARGE))	{ AirType=AIAirport.AT_LARGE; }
if (AIAirport.IsValidAirportType(AIAirport.AT_METROPOLITAN))	{ AirType=AT_METROPOLITAN; }
if (AIAirport.IsValidAirportType(AIAirport.AT_INTERNATIONAL))	{ AirType=AIAirport.AT_INTERNATIONAL; }
if (AIAirport.IsValidAirportType(AIAirport.AT_INTERCON))	{ AirType=AIAirport.AT_INTERCON; }
return AirType;
}

function cBuilder::AirportMaker(tile, airporttype)
// Build an airport at tilebase
{
local essai=false;
INSTANCE.bank.RaiseFundsBigTime();
INSTANCE.bank.RaiseFundsBy(AIAirport.GetPrice(airporttype));
essai=AIAirport.BuildAirport(tile, airporttype, AIStation.STATION_NEW);
DInfo("Building an airport at "+tile+" type: "+airporttype+" success: "+essai,2);
return essai;	
}

function cBuilder::BuildAirStation(start)
// Create an airport for our route at start/destination
// if createstation is not given, create a new station, else re-use the createstation index
{
DInfo("Looking for a place to build an airport",2);
local helipadonly=false;
// Pickup the airport we can build
local airporttype=cBuilder.GetAirportType();
local air_x=AIAirport.GetAirportWidth(airporttype);
local air_y=AIAirport.GetAirportHeight(airporttype);
local rad=AIAirport.GetAirportCoverageRadius(airporttype);
local tilelist=AITile();
local success=false;
local allfail=true;
local newStation=0;
local heliloc=null;
DInfo("Start="+start+" source="+INSTANCE.route.source_istown+" target="+INSTANCE.route.target_istown,2);
if (start)
	{
	if (INSTANCE.route.source_istown)
		{
		tilelist= cTileTools.GetTilesAroundTown(INSTANCE.route.sourceID);
		helipadonly=false;
		}
	else	{
		// no coverage need, we know exactly where we go
		helipadonly=true;
		heliloc=AIIndustry.GetLocation(INSTANCE.route.sourceID);
		}
	}
else	{
	if (INSTANCE.route.target_istown)
		{
		tilelist= cTileTools.GetTilesAroundTown(INSTANCE.route.targetID);
		helipadonly=false;
		}
	else	{
		// we should never have a platform as destination station !!!
		DError("BUG !!! We have select a platform for our destination station for route #"+INSTANCE.route.UID+" Please report that error with a savegame if you can",1);
		helipadonly=true;
		return false;
		}
	}
if (!helipadonly)
	{
	DInfo("Building an airport",2);
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.RemoveValue(0);
	tilelist.Valuate(AITile.GetCargoAccept, INSTANCE.route.cargoID, 1, 1, rad);
	tilelist.RemoveBelowValue(8);
	tilelist.Sort(AIList.SORT_BY_VALUE,false);
	INSTANCE.bank.RaiseFundsBy(AIAirport.GetPrice(airporttype));
	foreach (i, dummy in tilelist)
		{
		local bestplace=cTileTools.IsBuildableRectangleAtThisPoint(i, air_x, air_y);
		if (bestplace > -1)
			{
			success=INSTANCE.builder.AirportMaker(bestplace, airporttype);
			if (success)	{
					newStation=bestplace;
					break;
					}
				else	{
					INSTANCE.builder.IsCriticalError();
					if (!INSTANCE.builder.CriticalError)	allfail=false;
					INSTANCE.builder.CriticalError=false;
					}
			}
		}
	}
else	{ success=true; }
DInfo("Success to build airport "+success);
if (success)
	{
	if (!helipadonly)
		{
		if (start)	INSTANCE.route.source_stationID=AIStation.GetStationID(newStation);
			else	INSTANCE.route.target_stationID=AIStation.GetStationID(newStation);
		INSTANCE.route.CreateNewStation(start);
		}
	else	{ INSTANCE.route.route_type = RouteType.CHOPPER; }
/*	if (helipadonly)
		{
		newStation.stationID = AIStation.GetStationID(AIIndustry.GetLocation(INSTANCE.route.sourceID));
		newStation.stationType = 100;
		newStation.canUpgrade=false;
		newStation.radius=1;
		newStation.size=1;
		newStation.locations.AddItem(AIIndustry.GetHeliportLocation(INSTANCE.route.sourceID));
		newStation.road.ROUTE.src_entry = false;
		}
	else	{
		newStation.size=air_x*air_y;
		newStation.vehicle_count=0;
		}
*/
/*	newStation.StationSave();
	if (start)	INSTANCE.route.source_stationID=newStation.stationID;
		else	INSTANCE.route.target_stationID=newStation.stationID;*/
	}
else	INSTANCE.builder.CriticalError=allfail;
ClearSignsALL();
return success;
}

