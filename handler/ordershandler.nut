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

function cCarrier::VehicleOrderSkipCurrent(veh)
// Skip the current order and go to the next one
{
	local current=AIOrder.ResolveOrderPosition(veh, AIOrder.ORDER_CURRENT);
	local total=AIOrder.GetOrderCount(veh);
	if (current+1 == total)	current=0;
			else		current++;
	AIOrder.SkipToOrder(veh, current);
}

function cCarrier::AirNetworkOrdersHandler()
// Create orders for aircrafts that run the air network
{
	local road=null;
	local isfirst=true;
	local rabbit=null; // this will be our rabbit aircraft that take orders & everyone share with it
	local mailgroup=AIVehicleList_Group(cRoute.GetVirtualAirMailGroup());
	local passgroup=AIVehicleList_Group(cRoute.GetVirtualAirPassengerGroup());
	local allgroup=AIList();
	allgroup.AddList(mailgroup);
	allgroup.AddList(passgroup);
	allgroup.Valuate(AIVehicle.GetState);
	foreach (vehicle, dummy in allgroup)
		{ // if vehicle is in our todepotlist, it's going to depot for something, so set it as in depot -> it will be remove from list
		if (INSTANCE.main.carrier.ToDepotList.HasItem(vehicle))	allgroup.SetValue(vehicle,AIVehicle.VS_IN_DEPOT);
		INSTANCE.Sleep(1);
		}
	allgroup.KeepValue(AIVehicle.VS_RUNNING);
	if (allgroup.IsEmpty())	return false;
	allgroup.Valuate(AIVehicle.GetAge);
	allgroup.Sort(AIList.SORT_BY_VALUE, false);
	rabbit=allgroup.Begin();
	allgroup.RemoveTop(1);
	local orderpossave=AIList();
	foreach (vehicle, dummy in allgroup)	allgroup.SetValue(vehicle, AIOrder.GetOrderDestination(vehicle, AIOrder.ORDER_CURRENT));
	local numorders=AIOrder.GetOrderCount(rabbit);
	if (numorders != cCarrier.VirtualAirRoute.len())
		{
		for (local i=0; i < INSTANCE.main.carrier.VirtualAirRoute.len(); i++)
			{
			local destination=INSTANCE.main.carrier.VirtualAirRoute[i];
			if (!AIOrder.AppendOrder(rabbit, destination, AIOrder.OF_NONE))
				{ DError("Aircraft network order refuse",2); }
			}
		if (numorders > 0)
			{
			// now remove previous rabbit orders, should not make the aircrafts gone too crazy
			for (local i=0; i < numorders; i++)
					{ AIOrder.RemoveOrder(rabbit, AIOrder.ResolveOrderPosition(rabbit,0)); }
			}
		}
	foreach (vehicle, stationtile in allgroup)
		{
		AIOrder.ShareOrders(vehicle,rabbit);
		// now try to get it back to its initial station destination
		local wasorder=VehicleFindDestinationInOrders(vehicle, AIStation.GetStationID(stationtile));
		if (wasorder != -1)	AIOrder.SkipToOrder(vehicle, wasorder);
		}
}

function cCarrier::VehicleOrdersReset(veh)
// Remove all orders for veh
{
	while (AIOrder.GetOrderCount(veh) > 0)
		{
		if (!AIOrder.RemoveOrder(veh, AIOrder.ResolveOrderPosition(veh, 0)))
			{ DError("Cannot remove orders ",2); break; }
		}
}

function cCarrier::VehicleBuildOrders(groupID, orderReset)
// Redo all orders vehicles from that group should have
// orderReset true to reset all vehicles orders in the group, false to simply reassign sharing orders to vehicle in the group
{
	if (groupID == null || !AIGroup.IsValidGroup(groupID))	return false;
	local vehlist=AIVehicleList_Group(groupID);
	if (vehlist.IsEmpty()) return false;
	vehlist.Valuate(AIVehicle.GetState);
	vehlist.RemoveValue(AIVehicle.VS_STOPPED);
	vehlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
	vehlist.RemoveValue(AIVehicle.VS_CRASHED);
	foreach (veh, dummy in vehlist)
		{
		if (cCarrier.ToDepotList.HasItem(veh))	{ vehlist.SetValue(veh, 1); } // remove ones going to depot
							else		{ vehlist.SetValue(veh, 0); }
		}
	vehlist.RemoveValue(1);
	if (vehlist.IsEmpty())	return true;
	local veh=vehlist.Begin();
	local filterveh=AIList();
	filterveh.AddList(vehlist);
	filterveh.Valuate(AIOrder.GetOrderCount);
	filterveh.KeepValue(2); // only a 2 orders vehicle is valid for us
	if (filterveh.IsEmpty())	orderReset=true; // no vehicle with valid orders is usable as sharing target
					else	veh=filterveh.Begin();
	local idx=INSTANCE.main.carrier.VehicleFindRouteIndex(veh);
	local road = cRoute.Load(idx);
	if (!road)	return false;
	if (!typeof(road.SourceStation) == "instance")	return false;
	if (!typeof(road.TargetStation) == "instance")	return false;
	local oneorder=null;
	local twoorder=null;
	local srcplace=null;
	local dstplace=null;
	switch (road.VehicleType)
		{
		case AIVehicle.VT_ROAD:
			oneorder=AIOrder.OF_NON_STOP_INTERMEDIATE;
			twoorder=AIOrder.OF_NON_STOP_INTERMEDIATE;
			if (!road.Twoway) { oneorder+=AIOrder.OF_FULL_LOAD_ANY; twoorder+=AIOrder.OF_NO_LOAD; }
			srcplace= road.SourceStation.s_Location;
			dstplace= road.TargetStation.s_Location;
		break;
		case AIVehicle.VT_RAIL:
			oneorder=AIOrder.OF_NON_STOP_INTERMEDIATE;
			twoorder=AIOrder.OF_NON_STOP_INTERMEDIATE;
			if (!road.Twoway)	{ oneorder+=AIOrder.OF_FULL_LOAD_ANY; twoorder+=AIOrder.OF_NO_LOAD; }
			srcplace= road.SourceStation.s_Location;
			dstplace= road.TargetStation.s_Location;
		break;
		case RouteType.AIR:
		case RouteType.AIRMAIL:
		case RouteType.SMALLAIR:
		case RouteType.SMALLMAIL:
			oneorder=AIOrder.OF_NONE;
			twoorder=AIOrder.OF_NONE;
			srcplace= road.SourceStation.s_Location;
			dstplace= road.TargetStation.s_Location;
		break;
		case AIVehicle.VT_WATER:
			oneorder=AIOrder.OF_FULL_LOAD_ANY;
			twoorder=AIOrder.OF_FULL_LOAD_ANY;
			srcplace= road.SourceStation.s_Location;
			dstplace= road.TargetStation.s_Location;
		break;
		case RouteType.AIRNET:
		case RouteType.AIRNETMAIL: // it's the air network
			INSTANCE.main.carrier.AirNetworkOrdersHandler();
			return true;
		break;
		case RouteType.CHOPPER:
			oneorder=AIOrder.OF_NONE;
			twoorder=AIOrder.OF_NONE;
			srcplace= AIIndustry.GetHeliportLocation(road.SourceProcess.ID);
			dstplace= road.TargetStation.s_Location;
		break;
		}
	if (srcplace == -1 || dstplace == -1) return false;
	DInfo("Setting orders for route "+cRoute.GetRouteName(idx),2);
	if (orderReset)
		{
		INSTANCE.main.carrier.VehicleOrdersReset(veh);
		if (!AIOrder.AppendOrder(veh, srcplace, oneorder))
			{ DError("First order refuse",2); }
		if (!AIOrder.AppendOrder(veh, dstplace, twoorder))
			{ DError("Second order refuse",2); }
		}
	vehlist.RemoveItem(veh);
	foreach (vehicle, dummy in vehlist)	AIOrder.ShareOrders(vehicle, veh);
	return true;
}

function cCarrier::VehicleFindDestinationInOrders(vehicle, stationID)
// browse vehicle orders and return index of order that target that destination
{
	local numorders=AIOrder.GetOrderCount(vehicle);
	if (numorders==0) return -1;
	for (local j=0; j < numorders; j++)
		{
		local tiletarget=AIOrder.GetOrderDestination(vehicle,AIOrder.ResolveOrderPosition(vehicle, j));
		if (!AITile.IsStationTile(tiletarget)) continue;
		local targetID=AIStation.GetStationID(tiletarget);
		if (targetID == stationID)	return j;
		}
	return -1;
}

function cCarrier::VehicleSetDepotOrder(veh)
// set all orders of the vehicle to force it going to a depot
{
	if (veh == null)	return;
	local idx=INSTANCE.main.carrier.VehicleFindRouteIndex(veh);
	local road=cRoute.Load(idx);
	local homedepot = null;
	local srcValid = false;
	local dstValid = false;
	if (road != false)
		{
		homedepot=road.GetDepot(idx);
		srcValid = (typeof(road.SourceStation) == "instance");
		dstValid = (typeof(road.TargetStation) == "instance");
		}
	local prevDest=AIOrder.GetOrderDestination(veh, AIOrder.ORDER_CURRENT);
	AIOrder.UnshareOrders(veh);
	INSTANCE.main.carrier.VehicleOrdersReset(veh);
	if (homedepot == null || !cStation.IsDepot(homedepot))
		{
		local vehloc=AIVehicle.GetLocation(veh);
		if (AIVehicle.GetVehicleType(veh)==AIVehicle.VT_AIR)
			{
			local airports=AIStationList(AIStation.STATION_AIRPORT);
			airports.Valuate(AIStation.GetLocation);
			foreach (staID, locations in airports)	if (AIAirport.GetNumHangars(locations)==0)	airports.RemoveItem(staID);
			// remove station without hangars
			if (!airports.IsEmpty())
				{
				airports.Valuate(AIStation.GetDistanceManhattanToTile, vehloc);
				airports.Sort(AIList.SORT_BY_VALUE, true); // closest one
				homedepot=AIAirport.GetHangarOfAirport(AIStation.GetLocation(airports.Begin()));
				DInfo("Sending a lost aircraft "+cCarrier.GetVehicleName(veh)+" to the closest airport hangar found at "+homedepot,1);
				}
			}
		if (AIVehicle.GetVehicleType(veh)==AIVehicle.VT_ROAD)
			{
			cCarrier.StopVehicle(veh);
			// first stop it from running everywhere
			vehloc=AIVehicle.GetLocation(veh); // now that the vehicle is stopped
			local possibleplace=cTileTools.GetTilesAroundPlace(AIVehicle.GetLocation(veh),100);
			local depottile=AIList();
			depottile.AddList(possibleplace);
			depottile.Valuate(AIRoad.IsRoadDepotTile);
			depottile.KeepValue(1);
			depottile.Valuate(AITile.GetOwner);
			depottile.KeepValue(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
			if (!depottile.IsEmpty())
				{
				foreach (depotloc, dummy in depottile)
					if (INSTANCE.main.builder.RoadRunner(vehloc, depotloc, AIVehicle.VT_ROAD))
						{ homedepot=depotloc; DInfo("Sending "+cCarrier.GetVehicleName(veh)+" to a backup depot we found near it",1); break; }
				}
			else	{
				DInfo("Trying to build a depot to sent "+cCarrier.GetVehicleName(veh)+" there",1);
				homedepot=cBuilder.BuildRoadDepotAtTile(vehloc);
				if (homedepot==-1)	homedepot==null;
				}
			if (homedepot == null)	return;
			cCarrier.StartVehicle(veh);
			}
		}
	if (srcValid)	AIOrder.AppendOrder(veh, road.SourceStation.s_Location, AIOrder.OF_NONE);
	local orderindex = 0;
	if (homedepot != null)
		{
		if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.OF_STOP_IN_DEPOT))
			{ DError("Vehicle refuse goto source depot order",2); }
		if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.OF_STOP_IN_DEPOT))
			{ DError("Vehicle refuse goto source depot order",2); }
		if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.OF_STOP_IN_DEPOT))
			{ DError("Vehicle refuse goto source depot order",2); }
		}
	// Adding depot orders 3 time, so we should endup with at least 3 orders minimum to avoid get caught again by orders check
	if (dstValid && cStation.IsDepot(road.TargetStation.s_Depot))	homedepot=road.TargetStation.s_Depot;
	if (dstValid)
		{
		local mainstation = null;
		if (dstValid)	mainstation = road.TargetStation.s_Location;
		if (cCarrier.AircraftIsChopper(veh) && srcValid)	mainstation = road.SourceStation.s_Location;
		if (mainstation != null)	AIOrder.AppendOrder(veh, mainstation, AIOrder.OF_NONE);
		}
	if (homedepot != null)
		{
		if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.OF_STOP_IN_DEPOT))
			{ DError("Vehicle refuse goto destination depot order",2); }
		if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.OF_STOP_IN_DEPOT))
			{ DError("Vehicle refuse goto destination depot order",2); }
		if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.OF_STOP_IN_DEPOT))
			{ DError("Vehicle refuse goto destination depot order",2); }
		}

	if (road != false)
		for (local jjj=0; jjj < AIOrder.GetOrderCount(veh); jjj++)
		// this send vehicle to met dropoff station before its depot, choppers won't have the dropoff station in their orders to lower distance
			{
			if (!dstValid)	break;
			if (AIVehicle.GetVehicleType(veh) == AIVehicle.VT_RAIL)
				{
				if (AIOrder.GetOrderDestination(veh, AIOrder.ORDER_CURRENT) != prevDest)
					{
					AIOrder.SkipToOrder(veh, jjj+1);
					}
				else	{ AIOrder.SkipToOrder(veh, jjj+1); break; }
				}
			else	if (AIOrder.GetOrderDestination(veh, AIOrder.ORDER_CURRENT) != road.TargetStation.s_Location)
					{
					AIOrder.SkipToOrder(veh, jjj+1);
					DInfo("Sending vehicle "+cCarrier.GetVehicleName(veh)+" to destination station",1);
					break;
					}
			}
	DInfo("Setting depot order for vehicle "+INSTANCE.main.carrier.GetVehicleName(veh),2);
}

function cCarrier::VehicleOrderIsValid(vehicle,orderpos)
// Really check if a vehicle order is valid
{
// for now i just disable orders check for chopper, find a better fix if this trouble us later
local chopper=INSTANCE.main.carrier.AircraftIsChopper(vehicle);
if (chopper) return true;

local ordercount=AIOrder.GetOrderCount(vehicle);
if (ordercount == 0)	return true;
local ordercheck=AIOrder.ResolveOrderPosition(vehicle, orderpos);
if (!AIOrder.IsValidVehicleOrder(vehicle, ordercheck)) return false;
local tiletarget=AIOrder.GetOrderDestination(vehicle, ordercheck);
local vehicleType=AIVehicle.GetVehicleType(vehicle);
if (!chopper)
	{ // Skip this test for a chopper, well it a start, we never get there with a chopper for now
	if (!AICompany.IsMine(AITile.GetOwner(tiletarget)))	return false;
	}
local stationID=AIStation.GetStationID(tiletarget);
switch (vehicleType)
	{
	case	AIVehicle.VT_RAIL:
		local is_station=AIStation.HasStationType(stationID,AIStation.STATION_TRAIN);
		local is_depot=AIRail.IsRailDepotTile(tiletarget);
		if (!is_depot && !is_station) return false;
	break;
	case	AIVehicle.VT_WATER:
		local is_station=AIStation.HasStationType(stationID,AIStation.STATION_DOCK);
		local is_depot=AIMarine.IsWaterDepotTile(tiletarget);
		if (!is_station && !is_depot) return false;
	break;
	case	AIVehicle.VT_AIR:
		local is_station=AIStation.HasStationType(stationID,AIStation.STATION_AIRPORT);
		local is_depot=AIAirport.GetHangarOfAirport(tiletarget);
		if (!is_station && !is_depot)	return false;
	break;
	case	AIVehicle.VT_ROAD:
		local truckcheck=AIStation.HasStationType(stationID,AIStation.STATION_TRUCK_STOP);
		local buscheck=AIStation.HasStationType(stationID,AIStation.STATION_BUS_STOP);
		local depotcheck=AIRoad.IsRoadDepotTile(tiletarget);
		if (!truckcheck && !buscheck && !depotcheck) return false;
	break;
	}
return true;
}

function cCarrier::TrainSetOrders(trainID)
// Set orders for a train
{
local uid=INSTANCE.main.carrier.VehicleFindRouteIndex(trainID);
if (uid==null)	{ DError("Cannot find uid for that train",1); return false; }
local road=cRoute.GetRouteObject(uid);
if (road==null)	return false;
DInfo("Append orders to "+cCarrier.GetVehicleName(trainID),2);
local firstorder=AIOrder.OF_NON_STOP_INTERMEDIATE;
local secondorder=AIOrder.OF_NON_STOP_INTERMEDIATE;
if (!road.twoway)	{ firstorder+=AIOrder.OF_FULL_LOAD_ANY; secondorder=AIOrder.OF_NO_LOAD; }
if (!AIOrder.AppendOrder(trainID, AIStation.GetLocation(road.source.stationID), firstorder))
	{ DError(cCarrier.GetVehicleName(trainID)+" refuse first order",2); return false; }
if (!AIOrder.AppendOrder(trainID, AIStation.GetLocation(road.target.stationID), secondorder))
	{ DError(cCarrier.GetVehicleName(trainID)+" refuse second order",2); return false; }
return true;
}



