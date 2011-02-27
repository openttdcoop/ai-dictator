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
local road=root.chemin.RListGetItem(idx);
if (!road.ROUTE.isServed) return false; // don't upgrade a non working airport
if (start && !road.ROUTE.src_entry) return false; // plaform are set to false, we cannot upgrade a platform
if (road.ROUTE.kind != AIVehicle.VT_AIR) return false; // not an aircraft route
if (start)	{ if (!road.ROUTE.src_istown) return false; } // make sure we work on a town
	else	{ if (!road.ROUTE.dst_istown) return false; }
local station=null;
local stationfakeid=null;
if (start)	stationfakeid=road.ROUTE.src_station;
	else	stationfakeid=road.ROUTE.dst_station;
station=root.chemin.GListGetItem(stationfakeid);
local townrating=0;
local noiselevel=0;
local townid=0;
local airporttype=root.builder.GetAirportType();
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
root.bank.RaiseFundsTo(cost);
if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < cost)
	{ DInfo("Cannot upgrade airport, need "+cost+" money for success.",0); return false; }

// find traffic that use that airport & reroute it
root.chemin.under_upgrade=true;
// prior to reroute aircraft, make sure they have a route to go
root.carrier.VehicleBuildOrders(road.ROUTE.group_id); // and try to rebuild its orders
root.carrier.AirNetworkOrdersHandler(); // or maybe it's one from our network that need orders

root.carrier.VehicleHandleTrafficAtStation(station.STATION.station_id,true);
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
		root.carrier.VehicleIsWaitingInDepot(); // try remove aircraft from airport
		}
	} while (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 1000 && !result && counter < maxcount);	
if (!result)	{
		root.carrier.VehicleHandleTrafficAtStation(station.STATION.station_id,false);
		return false;
		}
result=root.builder.BuildAirStation(idx,start,stationfakeid);
// TODO: if airport is moved away from previous point, route is still pointing to the old airport, need to correct that
if (!result) // should have pray a bit more
	{
	root.builder.CriticalError=false;
	local result=root.builder.AirportMaker(oldplace, oldtype);
	}
if (!result)
	{ root.chemin.RouteIsNotDoable(idx); }
root.chemin.under_upgrade=false;
root.carrier.VehicleHandleTrafficAtStation(station.STATION.station_id,false);
}

function cBuilder::GetAirportType()
// return an airport type to build or null
{
local AirType=null;
if (AIAirport.IsValidAirportType(AIAirport.AT_SMALL))	{ AirType=StationType.STATION_AIRPORT_SMALL; }
if (AIAirport.IsValidAirportType(AIAirport.AT_LARGE))	{ AirType=StationType.STATION_AIRPORT_LARGE; }
if (AIAirport.IsValidAirportType(AIAirport.AT_METROPOLITAN))	{ AirType=StationType.STATION_AIRPORT_METROPOLITAN; }
if (AIAirport.IsValidAirportType(AIAirport.AT_INTERNATIONAL))	{ AirType=StationType.STATION_INTERNATIONAL; }
if (AIAirport.IsValidAirportType(AIAirport.AT_INTERCON))	{ AirType=StationType.STATION_INTERCON; }
return AirType;
}

function cBuilder::AirportMaker(tile, airporttype)
// Build an airport at tilebase
{
local essai=false;
root.bank.RaiseFundsBy(AIAirport.GetPrice(airporttype));
essai=AIAirport.BuildAirport(tile, airporttype, AIStation.STATION_NEW);
return essai;	
}

function cBuilder::BuildAirStation(road_index, start, createstation=-1)
// Create an airport for road_index at start/destination
// if createstation is not given, create a new station, else re-use the createstation index
{
local rad=AIStation.GetCoverageRadius(AIStation.STATION_AIRPORT);
local road=root.chemin.RListGetItem(road_index);
local helipadonly=false;
// Pickup the airport we can build
local airporttype=cBuilder.GetAirportType();
local air_x=AIAirport.GetAirportWidth(airporttype);
local air_y=AIAirport.GetAirportHeight(airporttype);
local rad=AIAirport.GetAirportCoverageRadius(airporttype);
local tilelist=AITile();
local success=false;
local newStation=cStation();
if (start)
	{
	if (road.ROUTE.src_istown)
		{
		tilelist= cTileTools.GetTilesAroundTown(road.ROUTE.src_id);
		helipadonly=false;
		}
	else	{
		// no coverage need, we know exactly where we go
		helipadonly=true;
		}
	}
else	{
	if (road.ROUTE.dst_istown)
		{
		tilelist= cTileTools.GetTilesAroundTown(road.ROUTE.dst_id);
		helipadonly=false;
		}
	else	{
		// we should never have a platform as destination station !!!
		DInfo("BUG !!! We have select a platform for our destination station !",1);
		helipadonly=true;
		return false;
		}
	}
if (!helipadonly)
	{
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.RemoveValue(0);

	tilelist.Valuate(AITile.GetCargoAcceptance, road.ROUTE.cargo_id, 1, 1, rad);
	tilelist.RemoveBelowValue(8);
	tilelist.Sort(AIList.SORT_BY_VALUE,false);
	root.bank.RaiseFundsBy(AIAirport.GetPrice(airporttype));
	foreach (i, dummy in tilelist)
		{
		local bestplace=cTileTools.IsBuildableRectangleAtThisPoint(i, air_x, air_y);
		if (bestplace > -1) success=root.builder.AirportMaker(bestplace, airporttype);
		if (success) { newStation.STATION.e_loc=bestplace; break; }
		}
	}
else	{ success=true; }
if (success)
	{
	if (helipadonly)
		{
		newStation.STATION.railtype=100; // 100 for platform
		newStation.STATION.e_count=0;	
		newStation.STATION.e_depot=-1;
		newStation.STATION.haveEntry=false;
		newStation.STATION.haveExit=true;
		newStation.STATION.e_loc=AIIndustry.GetHeliportLocation(road.ROUTE.src_id);
		local lastStation=null;
		if (createstation == -1) 
			{
			root.chemin.GListAddItem(newStation); // create the station
			lastStation=root.chemin.GListGetSize()-1;
			}
		else	{ // for upgrading airport
			lastStation=createstation;
			root.chemin.GListUpdateItem(lastStation,newStation);
			}		
		road.ROUTE.src_station = lastStation;
		road.ROUTE.src_entry = false;
		}
	else	{
		newStation.STATION.station_id=AIStation.GetStationID(newStation.STATION.e_loc);
		newStation.STATION.railtype=2; // 2 for big airport
		if (airporttype == AIAirport.AT_SMALL)	newStation.STATION.railtype=1;
		newStation.STATION.type=airporttype;
		newStation.STATION.size=air_x*air_y;
		newStation.STATION.e_count=0;
		newStation.STATION.e_depot=AIAirport.GetHangarOfAirport(newStation.STATION.e_loc);
		local lastStation=null;
		if (createstation == -1)
			{		
			root.chemin.GListAddItem(newStation); // create the station
			lastStation=root.chemin.GListGetSize()-1;
			}
		else	{ // again, for airport upgrade
			lastStation=createstation;
			root.chemin.GListUpdateItem(lastStation,newStation);
			}
		if (start)
			{
			road.ROUTE.src_station = lastStation;
			road.ROUTE.src_entry = true;
			}
	 	else	{
			road.ROUTE.dst_station = lastStation;
			road.ROUTE.dst_entry = true;
			}
		}
	root.chemin.RListUpdateItem(road_index,road);
	}
else	{ // not success tell caller it's a critical failure
	root.builder.CriticalError=true;
	}
ClearSignsALL();
return success;
}

