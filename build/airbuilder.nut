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

function cBuilder::AirportNeedUpgrade(stationid)
// this upgrade an existing airport to a newer one
{

// better check criticals stuff before stopping our traffic and find we're going to fail
local station=cStation.GetStationObject(stationid);
local townrating=0;
local noiselevel=0;
local townid=-1;
local start=false;
local saved_owners=AIList();
saved_owners.AddList(station.owner);
local firstroute=cRoute.GetRouteObject(station.owner.Begin());
if (firstroute == null)	{ DInfo("Found an airport attach to no route ! Giving up.",1); return false }
if (firstroute.source_stationID == stationid)	{ start=true; townid=firstroute.sourceID; }
							else	{ start=false; townid=firstroute.targetID; }

local airporttype=INSTANCE.builder.GetAirportType();
townrating=AITown.GetRating(townid,AICompany.COMPANY_SELF);
noiselevel=AITown.GetAllowedNoise(townid);
local ourloc=0;

local ournoise=AIAirport.GetNoiseLevelIncrease(station.locations.Begin(),airporttype);
DInfo("Town rating = "+townrating+" noiselevel="+noiselevel,2);
if (townrating < AITown.TOWN_RATING_MEDIOCRE)
	{ DInfo("Cannot upgrade airport, town will refuse that.",1); return false; }
local cost=AIAirport.GetPrice(airporttype);
cost+=1000; // i'm not sure how much i need to destroy old airport
INSTANCE.bank.RaiseFundsBy(cost);
if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < cost)
	{ DInfo("Cannot upgrade airport, need "+cost+" money for success.",1); return false; }
DInfo("Trying to upgrade airport #"+stationid+" "+AIStation.GetName(stationid),0);
// find traffic that use that airport & reroute it
//INSTANCE.chemin.under_upgrade=true;
// prior to reroute aircraft, make sure they have a route to go
foreach (ownID, dummy in station.owner)
	{
	local dummyObj=cRoute.GetRouteObject(ownID);
	INSTANCE.carrier.VehicleBuildOrders(dummyObj.groupID);
	}
INSTANCE.carrier.AirNetworkOrdersHandler(); // or maybe it's one from our network that need orders

INSTANCE.carrier.VehicleHandleTrafficAtStation(stationid,true);
local oldtype=station.specialType;
local oldplace=AIStation.GetLocation(stationid);
local counter=0;
local maxcount=100;
local result=false;
// time to pray a bit for success, we could invalidate a working route here
do	{
	result=AIAirport.RemoveAirport(station.locations.Begin());
	counter++;
	if (!result) 
		{
		AIController.Sleep(10);
		INSTANCE.carrier.VehicleIsWaitingInDepot(); // try remove aircraft from airport
		}
	} while (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 1000 && !result && counter < maxcount);	
if (!result)	{
			INSTANCE.carrier.VehicleHandleTrafficAtStation(station.stationID,false);
			return false;
			}
result=INSTANCE.builder.BuildAirStation(start, firstroute.UID);
if (!result) // should have pray a bit more, fail to build a bigger airport
	{
	INSTANCE.builder.CriticalError=false;
	local result=INSTANCE.builder.AirportMaker(oldplace, oldtype);
	}
//INSTANCE.chemin.under_upgrade=false;
if (!result) // and we also fail to rebuild the old one! We have kill that route (and maybe many more!)
	{
	foreach (uid, dummy in saved_owners)
		{
		local dead=cRoute.GetRouteObject(uid);
		dead.RouteIsNotDoable();
		}
	return false;
	}
// now routes need to forget old stationid & reclaim the newstationid
station.owner.Clear();
local gotnewID=-1;
if (start)	gotnewID=firstroute.source_stationID;
	else	gotnewID=firstroute.target_stationID;
DInfo("Old airport ID = "+stationid+" New airport ID = "+gotnewID+" owners="+saved_owners.Count(),1);
foreach (uid, dummy in saved_owners)
	{
	local altered=cRoute.GetRouteObject(uid);
	if (altered.source_stationID == stationid)	altered.source_stationID=gotnewID;
	if (altered.target_stationID == stationid)	altered.target_stationID=gotnewID;
	altered.CheckEntry(); // set shortcuts & reclaim the station...
	altered.RouteUpdateVehicle();
	}
INSTANCE.carrier.VehicleHandleTrafficAtStation(gotnewID,false);
if (gotnewID != stationid)	{ cStation.DeleteStation(stationid); }
}

function cBuilder::GetAirportType()
// return an airport type to build or null
{
local AirType=null;
if (AIAirport.IsValidAirportType(AIAirport.AT_SMALL))	{ AirType=AIAirport.AT_SMALL; }
if (AIAirport.IsValidAirportType(AIAirport.AT_LARGE))	{ AirType=AIAirport.AT_LARGE; }
if (AIAirport.IsValidAirportType(AIAirport.AT_METROPOLITAN))	{ AirType=AIAirport.AT_METROPOLITAN; }
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

function cBuilder::BuildAirStation(start, routeID=null)
// Create an airport for our route at start/destination
// if createstation is not given, create a new station, else re-use the createstation index
{
local road=null;
if (routeID==null)	road=INSTANCE.route;
		else		road=cRoute.GetRouteObject(routeID);
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
DInfo("Start="+start+" source="+road.source_istown+" target="+road.target_istown,2);
if (start)
	{
	if (road.source_istown)
		{
		tilelist= cTileTools.GetTilesAroundTown(road.sourceID);
		helipadonly=false;
		}
	else	{
		// no coverage need, we know exactly where we go
		helipadonly=true;
		heliloc=AIIndustry.GetLocation(road.sourceID);
		}
	}
else	{
	if (road.target_istown)
		{
		tilelist= cTileTools.GetTilesAroundTown(road.targetID);
		helipadonly=false;
		}
	else	{
		// we should never have a platform as destination station !!!
		DError("BUG !!! We have select a platform for our destination station for route #"+road.UID+" Please report that error with a savegame if you can",0);
		helipadonly=true;
		return false;
		}
	}
if (!helipadonly)
	{
	DInfo("Building an airport",0);
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.RemoveValue(0);
	tilelist.Valuate(AITile.GetCargoAcceptance, road.cargoID, 1, 1, rad);
	tilelist.RemoveBelowValue(8);
	tilelist.Sort(AIList.SORT_BY_VALUE,false);
	INSTANCE.bank.RaiseFundsBy(AIAirport.GetPrice(airporttype));
	foreach (i, dummy in tilelist)
		{
		local bestplace=cTileTools.IsBuildableRectangleAtThisPoint(i, air_x, air_y);
		if (bestplace > -1)
			{
			success=INSTANCE.builder.AirportMaker(bestplace, airporttype);
			if (success)
					{
					newStation=bestplace;
					allfail=false;
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
DInfo("Success to build airport "+success+" allfail="+allfail,2);
if (success)
	{
	if (!helipadonly)
		{
		if (start)	road.source_stationID=AIStation.GetStationID(newStation);
			else	road.target_stationID=AIStation.GetStationID(newStation);
		road.CreateNewStation(start);
		road.CheckEntry();
		}
	else	{
		road.source_stationID=AIStation.GetStationID(heliloc);
		road.route_type = RouteType.CHOPPER;
		road.CreateNewStation(start);
		road.CheckEntry();
		DInfo("Chopper says depot is "+road.source.depot);
		road.source.depot=null;
		}
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

