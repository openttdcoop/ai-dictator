/* -*- Mode: C++; tab-width: 4 -*- */
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

function cCarrier::AirNetworkOrdersHandler()
// Create orders for aircrafts that run the air network
	{
	local road=null;
	local isfirst=true;
	local mailrabbit=null; // this will be our rabbit aircraft that take orders & everyone share them with it
	local passrabbit=null;
	local mailgroup=AIVehicleList_Group(cRoute.GetVirtualAirMailGroup());
	local passgroup=AIVehicleList_Group(cRoute.GetVirtualAirPassengerGroup());
	mailgroup.RemoveList(cCarrier.ToDepotList);
	passgroup.RemoveList(cCarrier.ToDepotList);
	mailgroup.Valuate(AIVehicle.GetState);
	passgroup.Valuate(AIVehicle.GetState);
	mailgroup.RemoveValue(AIVehicle.VS_CRASHED);
	mailgroup.RemoveValue(AIVehicle.VS_IN_DEPOT);
	passgroup.RemoveValue(AIVehicle.VS_CRASHED);
	passgroup.RemoveValue(AIVehicle.VS_IN_DEPOT);
	passrabbit = passgroup.Begin();
	mailrabbit = mailgroup.Begin();
	local numorders = null;
	if (!passgroup.IsEmpty())
			{
			passrabbit = passgroup.Begin();
			local temp = AIList(); temp.AddList(passgroup);
			foreach (vehicle, _ in temp)
				{
				local dest = AIOrder.GetOrderDestination(vehicle, AIOrder.ORDER_CURRENT);
				if (!AIOrder.IsCurrentOrderPartOfOrderList(vehicle))	{ dest = AIStation.GetLocation(AIStation.GetStationID(dest)); }
				// When servicing, it should be done at destination airport hangar, but won't be in the order list, so find its real destination
				passgroup.SetValue(vehicle, dest);
				if (vehicle == passrabbit)	{ continue; }
				AIOrder.ShareOrders(vehicle, passrabbit);
				}
			numorders = AIOrder.GetOrderCount(passrabbit);
			if (numorders != cCarrier.VirtualAirRoute.len())
					{
					AIOrder.UnshareOrders(passrabbit);
					cEngineLib.VehicleOrderClear(passrabbit);
					numorders = 0;
					for (local i=0; i < cCarrier.VirtualAirRoute.len(); i++)
							{
							local destination = cCarrier.VirtualAirRoute[i];
							if (AIOrder.AppendOrder(passrabbit, destination, AIOrder.OF_NONE))
									{ numorders++; }
							else
									{
									DError("Passenger rabbit refuse order, destination: "+destination,2);
									cCarrier.VirtualAirRoute.remove(i);
									}
							}
					foreach (vehicle, destination in passgroup)
						{
						// now try to get it back to its initial station destination
						local wasorder = VehicleFindDestinationInOrders(vehicle, AIStation.GetStationID(destination));
						if (wasorder != -1)	{ AIOrder.SkipToOrder(vehicle, wasorder); }
                                    else	{ AIOrder.SkipToOrder(vehicle, AIBase.RandRange(numorders)); }
						}
					}
			}
	if (!mailgroup.IsEmpty())
			{
			local temp = AIList();
			temp.AddList(mailgroup);
			foreach (vehicle, _ in temp)
				{
				local dest = AIOrder.GetOrderDestination(vehicle, AIOrder.ORDER_CURRENT);
				if (!AIOrder.IsCurrentOrderPartOfOrderList(vehicle))	{ dest = AIStation.GetLocation(AIStation.GetStationID(dest)); }
				mailgroup.SetValue(vehicle, dest);
				if (vehicle == mailrabbit)	{ continue; }
				AIOrder.ShareOrders(vehicle, mailrabbit);
				}
			// save current order for each vehicle
			numorders = AIOrder.GetOrderCount(mailrabbit);
			if (numorders != cCarrier.VirtualAirRoute.len())
					{
					AIOrder.UnshareOrders(mailrabbit);
					cEngineLib.VehicleOrderClear(mailrabbit);
					numorders = 0;
					for (local i=0; i < cCarrier.VirtualAirRoute.len(); i++)
							{
							local destination = cCarrier.VirtualAirRoute[((cCarrier.VirtualAirRoute.len()-1)-i)];
							if (AIOrder.AppendOrder(mailrabbit, destination, AIOrder.OF_NONE))
									{ numorders++; }
							else
									{
									DError("Mail rabbit refuse order, destination: "+destination,2);
									cDebug.PutSign(destination, "REFUSE_ORDER");
									}
							}
					foreach (vehicle, destination in mailgroup)
						{
						// now try to get it back to its initial station destination
						local wasorder=VehicleFindDestinationInOrders(vehicle, AIStation.GetStationID(destination));
						if (wasorder != -1)	{ AIOrder.SkipToOrder(vehicle, wasorder); }
                                    else	{ AIOrder.SkipToOrder(vehicle, AIBase.RandRange(numorders)); }
						}
					}
			}
	}

function cCarrier::RebuildGroupOrders(groupID, force)
{
	if (groupID == null)	return false;
	local veh_list = AIVehicleList_Group(groupID);
	if (!force)	{ veh_list.Valuate(AIOrder.GetOrderCount); veh_list.RemoveValue(2); }
	local done = true;
	foreach (veh, _ in veh_list)	if (!cCarrier.VehicleSetOrders(veh))	done = false;
	return done;
}

function cCarrier::VehicleFindDestinationInOrders(vehicle, stationID)
// browse vehicle orders and return index of order that target that stationID
	{
	local numorders = AIOrder.GetOrderCount(vehicle);
	if (numorders == 0) { return -1; }
	for (local j=0; j < numorders; j++)
			{
			local tiletarget = AIOrder.GetOrderDestination(vehicle,AIOrder.ResolveOrderPosition(vehicle, j));
			if (!AITile.IsStationTile(tiletarget)) continue;
			local targetID = AIStation.GetStationID(tiletarget);
			if (targetID == stationID)	return j;
			}
	return -1;
	}

function cCarrier::FindClosestHangarForAircraft(veh)
// return closest airport where we could send an aircraft
	{
	if (AIVehicle.GetVehicleType(veh) != AIVehicle.VT_AIR) { return -1; } // only for aircraft
	local vehloc=AIVehicle.GetLocation(veh);
	local temp = AIStationList(AIStation.STATION_AIRPORT);
	local airports = AIList();
	temp.Valuate(AIStation.GetLocation);
	foreach (staID, locations in temp)	if (AIAirport.GetNumHangars(locations) != 0)	{ airports.AddItem(staID,0); }
	// remove station without hangars
	if (!airports.IsEmpty())
			{
			airports.Valuate(AIStation.GetDistanceManhattanToTile, vehloc);
			airports.Sort(AIList.SORT_BY_VALUE, true); // closest one
			return AIAirport.GetHangarOfAirport(AIStation.GetLocation(airports.Begin()));
			}
	return -1;
	}

function cCarrier::VehicleHaveDepotOrders(veh)
// return true if the vehicle is going to a depot or if it have orders to going to one
{
	if (cEngineLib.VehicleIsGoingToStopInDepot(veh))	return true;
    for (local i = 0; i < AIOrder.GetOrderCount(veh); i++)
		{
		if (AIOrder.IsGotoDepotOrder(veh, i))	return true;
		}
	return false;
}

function cCarrier::TrainSetDepotOrder(veh)
// Set orders to force a train going to depot
	{
	if (veh == null)	{ return; }
	local idx = cCarrier.VehicleFindRouteIndex(veh);
	local road = cRoute.LoadRoute(idx, true);
	if (!road)
			{
			DError("Gonna be a hard time, i don't know who own that train "+cCarrier.GetVehicleName(veh),1);
			if (!cEngineLib.VehicleIsGoingToStopInDepot(veh))	AIVehicle.SendVehicleToDepot(veh);
			if (cEngineLib.VehicleIsGoingToStopInDepot(veh))	cCarrier.ToDepotList.AddItem(veh, DepotAction.SELL);
			return false;
			}
	local srcDepot = cRoute.GetDepot(idx, 1);
	local dstDepot = cRoute.GetDepot(idx, 2);
	if (!AIRail.IsRailDepotTile(srcDepot))	{ srcDepot = dstDepot; }
	if (!AIRail.IsRailDepotTile(dstDepot))	{ dstDepot = srcDepot; }
	if (!AIRail.IsRailDepotTile(srcDepot))	{ DError("Cannot send train to a depot as i cannot find any valid depot where sent it.",1); AIVehicle.SendVehicleToDepot(veh); return false; }
	if (AIOrder.GetOrderCount(veh) < 2)
			{
			DWarn("Train "+cCarrier.GetVehicleName(veh)+" doesn't have valid number of orders.",1);
			cCarrier.VehicleSetOrders(veh);
			}
	if (!AIOrder.InsertOrder(veh, 1, srcDepot, AIOrder.OF_STOP_IN_DEPOT))
			{ DError("Train refuse goto depot order",2); }
	if (!AIOrder.InsertOrder(veh, 3, dstDepot, AIOrder.OF_STOP_IN_DEPOT))
			{ DError("Train refuse goto depot order",2); }
	}

function cCarrier::VehicleSetDepotOrder(veh)
// set all orders of the vehicle to force it going to a depot
	{
	if (veh == null)	{ return; }
	if (AIVehicle.GetVehicleType(veh) == AIVehicle.VT_RAIL)	{ cCarrier.TrainSetDepotOrder(veh); return; }
	local idx = cCarrier.VehicleFindRouteIndex(veh);
	local road = cRoute.LoadRoute(idx, true);
	local homedepot = null;
	local srcValid = false;
	local dstValid = false;
	local isAircraft = (AIVehicle.GetVehicleType(veh) == AIVehicle.VT_AIR);
	if (road != false)
			{
			homedepot = road.GetDepot(idx);
			srcValid = cMisc.ValidInstance(road.SourceStation);
			dstValid = cMisc.ValidInstance(road.TargetStation);
			}
	local prevDest=AIOrder.GetOrderDestination(veh, AIOrder.ORDER_CURRENT);
	AIOrder.UnshareOrders(veh);
	cEngineLib.VehicleOrderClear(veh);
	if (homedepot == null || !cEngineLib.IsDepotTile(homedepot))
			{
			local vehloc = AIVehicle.GetLocation(veh);
			if (AIVehicle.GetVehicleType(veh) == AIVehicle.VT_ROAD)
					{
					cCarrier.StopVehicle(veh);
					// first stop it from running everywhere
					vehloc = AIVehicle.GetLocation(veh); // now that the vehicle is stopped
					local possibleplace = cTileTools.GetTilesAroundPlace(AIVehicle.GetLocation(veh),100);
					local depottile = AIList();
					depottile.AddList(possibleplace);
					depottile.Valuate(AIRoad.IsRoadDepotTile);
					depottile.KeepValue(1);
					depottile.Valuate(AITile.GetOwner);
					depottile.KeepValue(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
					if (!depottile.IsEmpty())
							{
							foreach (depotloc, dummy in depottile)
							if (cBuilder.RoadRunner(vehloc, depotloc, AIVehicle.VT_ROAD))
									{ homedepot = depotloc; DInfo("Sending "+cCarrier.GetVehicleName(veh)+" to a backup depot we found near it",1); break; }
							}
					else
							{
							DInfo("Trying to build a depot to sent "+cCarrier.GetVehicleName(veh)+" there",1);
							homedepot = cBuilder.BuildRoadDepotAtTile(vehloc, -1);
							if (homedepot == -1)	{ homedepot == null; }
							}
					cCarrier.StartVehicle(veh);
					if (homedepot == null)	{ return; }
					}
			}
	if (srcValid && !isAircraft)	{ AIOrder.AppendOrder(veh, road.SourceStation.s_Location, AIOrder.OF_NONE); }
	local orderindex = 0;
	if (isAircraft)
			{
			local shortpath = cCarrier.FindClosestHangarForAircraft(veh);
			DInfo("Routing aircraft " + cCarrier.GetVehicleName(veh) + " to the closest airport at " + shortpath,2);
			homedepot = shortpath;
			if (!AIOrder.AppendOrder(veh, shortpath, AIOrder.OF_STOP_IN_DEPOT))
					{ DError("Vehicle refuse goto closest airport order",2); }
			}
	// Adding depot orders 3 time, so we should endup with at least 3 orders minimum to avoid get caught again by orders check
	if (homedepot != null)
			{
			if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.OF_STOP_IN_DEPOT))
					{ DError("Vehicle refuse goto source depot order",2); }
			if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.OF_STOP_IN_DEPOT))
					{ DError("Vehicle refuse goto source depot order",2); }
			if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.OF_STOP_IN_DEPOT))
					{ DError("Vehicle refuse goto source depot order",2); }
			}
	if (dstValid)
		{
		local ddepot = cStation.GetStationDepot(road.TargetStation.s_ID);
		if (ddepot != -1)	homedepot = ddepot;
		if (isAircraft)	AIOrder.AppendOrder(veh, road.TargetStation.s_Location, AIOrder.OF_NONE);
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
	if (road != false && !isAircraft)
		for (local jjj = 0; jjj < AIOrder.GetOrderCount(veh); jjj++)
			// this send vehicle to met dropoff station before its depot
				{
				if (!dstValid)	{ break; }
				if (AIVehicle.GetVehicleType(veh) == AIVehicle.VT_RAIL)
						{
						if (AIOrder.GetOrderDestination(veh, AIOrder.ORDER_CURRENT) != prevDest)
								{
								AIOrder.SkipToOrder(veh, jjj + 1);
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
	if (isAircraft)
			{
			// try to force it going at order 0 instead of current destination. openttd orders are weak
			AIOrder.SkipToOrder(veh, 1);
			AIOrder.SkipToOrder(veh, 0);
			}
	DInfo("Setting depot order for vehicle "+cCarrier.GetVehicleName(veh),2);
	}

function cCarrier::VehicleOrderIsValid(vehicle,orderpos)
// Really check if a vehicle order is valid
	{
	local ordercount = AIOrder.GetOrderCount(vehicle);
	if (ordercount == 0)	{ return true; }
	local ordercheck = AIOrder.ResolveOrderPosition(vehicle, orderpos);
	if (!AIOrder.IsValidVehicleOrder(vehicle, ordercheck)) { DInfo("caught bad order from AIOrder.IsValidOrder", 2); return false; }
	local tiletarget = AIOrder.GetOrderDestination(vehicle, ordercheck);
	local vehicleType = AIVehicle.GetVehicleType(vehicle);
	local stationID = AIStation.GetStationID(tiletarget);
	switch (vehicleType)
			{
			case	AIVehicle.VT_RAIL:
				local is_station = AIStation.HasStationType(stationID,AIStation.STATION_TRAIN);
				local is_depot = AIRail.IsRailDepotTile(tiletarget);
				if (!is_depot && !is_station) { return false; }
				break;
			case	AIVehicle.VT_WATER:
				local is_station = AIStation.HasStationType(stationID,AIStation.STATION_DOCK);
				local is_depot = AIMarine.IsWaterDepotTile(tiletarget);
				if (!is_station && !is_depot) { return false; }
				break;
			case	AIVehicle.VT_AIR:
				local is_station = AIStation.HasStationType(stationID,AIStation.STATION_AIRPORT);
				local is_depot = AIAirport.GetHangarOfAirport(tiletarget);
				if (!is_station && !is_depot)	{ return false; }
				break;
			case	AIVehicle.VT_ROAD:
				local truckcheck = AIStation.HasStationType(stationID,AIStation.STATION_TRUCK_STOP);
				local buscheck = AIStation.HasStationType(stationID,AIStation.STATION_BUS_STOP);
				local depotcheck = AIRoad.IsRoadDepotTile(tiletarget);
				if (!truckcheck && !buscheck && !depotcheck) { return false; }
				break;
			}
	return true;
	}

function cCarrier::VehicleSetOrders(vehicle_id)
// This will build orders for the vehicle
{
	local uid = cCarrier.VehicleFindRouteIndex(vehicle_id);
	if (uid == null)	{ DError("Cannot find the route that vehicle is on "+cCarrier.GetVehicleName(vehicle_id),1); return false; }
	local road = cRoute.LoadRoute(uid, true);
	if (!road || road.GroupID == null || !AIGroup.IsValidGroup(road.GroupID))	return false;
	local srcplace, dstplace, oneorder, twoorder;
	AIOrder.UnshareOrders(vehicle_id);
	switch (road.VehicleType)
			{
			case AIVehicle.VT_ROAD:
				oneorder = AIOrder.OF_NON_STOP_INTERMEDIATE;
				twoorder = AIOrder.OF_NON_STOP_INTERMEDIATE;
				if (!road.Twoway) { oneorder += AIOrder.OF_FULL_LOAD_ANY; twoorder += AIOrder.OF_NO_LOAD; }
				srcplace = road.SourceStation.s_Location;
				dstplace = road.TargetStation.s_Location;
				break;
			case AIVehicle.VT_RAIL:
				oneorder = AIOrder.OF_NON_STOP_INTERMEDIATE;
				twoorder = AIOrder.OF_NON_STOP_INTERMEDIATE;
				if (!road.Twoway) { oneorder += AIOrder.OF_FULL_LOAD_ANY; twoorder += AIOrder.OF_NO_LOAD; }
				srcplace = road.SourceStation.s_Location;
				dstplace = road.TargetStation.s_Location;
				break;
			case RouteType.AIR:
			case RouteType.AIRMAIL:
			case RouteType.SMALLAIR:
			case RouteType.SMALLMAIL:
				oneorder = AIOrder.OF_NONE;
				twoorder = AIOrder.OF_NONE;
				srcplace = road.SourceStation.s_Location;
				dstplace = road.TargetStation.s_Location;
				break;
			case AIVehicle.VT_WATER:
				oneorder = AIOrder.OF_NONE;
				twoorder = AIOrder.OF_NONE;
				if (!road.Twoway) { oneorder += AIOrder.OF_FULL_LOAD_ANY; twoorder += AIOrder.OF_NO_LOAD; }
				srcplace = road.SourceStation.s_Location;
				dstplace = road.TargetStation.s_Location;
				break;
			case RouteType.AIRNET:
			case RouteType.AIRNETMAIL: // it's the air network
				cCarrier.AirNetworkOrdersHandler();
				return true;
				break;
			case RouteType.CHOPPER:
				oneorder = AIOrder.OF_NONE;
				twoorder = AIOrder.OF_NONE;
				srcplace = road.SourceStation.s_Location;
				dstplace = road.TargetStation.s_Location;
				break;
			}
	if (srcplace == -1 || dstplace == -1) return false;
	for (local j = AIOrder.GetOrderCount(vehicle_id); j >= 0; j--)	if (AIOrder.IsGotoDepotOrder(vehicle_id, j))	AIOrder.RemoveOrder(vehicle_id, j);
	DInfo("Setting orders for "+cCarrier.GetVehicleName(vehicle_id)+" twoway="+road.Twoway,2);
	if (AIOrder.GetOrderCount(vehicle_id) != 2)	cEngineLib.VehicleOrderClear(vehicle_id);
	if (AIOrder.GetOrderDestination(vehicle_id, 0) != srcplace)
        if (!AIOrder.AppendOrder(vehicle_id, srcplace, oneorder))	DError("First order refuse : " + cMisc.Locate(srcplace),2);
	if (AIOrder.GetOrderDestination(vehicle_id, 1) != dstplace)
		if (!AIOrder.AppendOrder(vehicle_id, dstplace, twoorder))	DError("Second order refuse : " + cMisc.Locate(dstplace),2);
	return true;
}
