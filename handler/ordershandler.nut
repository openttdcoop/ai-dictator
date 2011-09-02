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
	if (INSTANCE.carrier.ToDepotList.HasItem(vehicle))	allgroup.SetValue(vehicle,AIVehicle.VS_IN_DEPOT);
	INSTANCE.Sleep(1);
	}
allgroup.KeepValue(AIVehicle.VS_RUNNING);
if (allgroup.IsEmpty())	return;
allgroup.Valuate(AIVehicle.GetAge);
allgroup.Sort(AIList.SORT_BY_VALUE, false);
rabbit=allgroup.Begin();
allgroup.RemoveTop(1);
local orderpossave=AIList();
foreach (vehicle, dummy in allgroup)	allgroup.SetValue(vehicle, AIOrder.GetOrderDestination(vehicle, AIOrder.ORDER_CURRENT));
local numorders=AIOrder.GetOrderCount(rabbit);
if (numorders != cCarrier.VirtualAirRoute.len())
	{
	for (local i=0; i < INSTANCE.carrier.VirtualAirRoute.len(); i++)
		{
		local destination=INSTANCE.carrier.VirtualAirRoute[i];
		if (!AIOrder.AppendOrder(rabbit, destination, AIOrder.AIOF_NONE))
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
		{ DError("Cannot remove orders ",2); }
	}
}

function cCarrier::VehicleBuildOrders(groupID)
// Redo all orders vehicles from that group should have
{
local vehlist=AIVehicleList_Group(groupID);
vehlist.Valuate(AIVehicle.GetState);
vehlist.RemoveValue(AIVehicle.VS_STOPPED);
vehlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
vehlist.RemoveValue(AIVehicle.VS_CRASHED);
foreach (veh, dummy in vehlist)
	{
	if (cCarrier.ToDepotList.HasItem(veh))	{ vehlist.SetValue(veh,-1); }
						else		{ vehlist.SetValue(veh, 1); }
	}
vehlist.RemoveValue(-1);
if (vehlist.IsEmpty()) return false;
local veh=vehlist.Begin();
local idx=INSTANCE.carrier.VehicleFindRouteIndex(veh);
local road=cRoute.GetRouteObject(idx);
if (road == null)	return false;
if (!road.source_entry)	return false;
if (!road.target_entry)	return false;
local oneorder=null;
local twoorder=null;
local srcplace=null;
local dstplace=null;
// setup everything before removing orders, as it could be dangerous for the poor vehicle to stay without orders a long time
switch (road.route_type)
	{
	case AIVehicle.VT_ROAD:
		oneorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
		twoorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
		if (!road.source_istown) oneorder+=AIOrder.AIOF_FULL_LOAD_ANY;
		srcplace= AIStation.GetLocation(road.source.stationID);
		dstplace= AIStation.GetLocation(road.target.stationID);
	break;
	case AIVehicle.VT_RAIL:
		oneorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
		twoorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
		if (!road.source_istown)	oneorder+=AIOrder.AIOF_FULL_LOAD_ANY;
		srcplace = AIStation.GetLocation(road.source.stationID);
		dstplace = AIStation.GetLocation(road.target.stationID);
	break;
	case AIVehicle.VT_AIR:
		oneorder=AIOrder.AIOF_NONE;
		twoorder=AIOrder.AIOF_NONE;
		srcplace= AIStation.GetLocation(road.source.stationID);
		dstplace= AIStation.GetLocation(road.target.stationID);
	break;
	case AIVehicle.VT_WATER:
		oneorder=AIOrder.AIOF_FULL_LOAD_ANY;
		twoorder=AIOrder.AIOF_FULL_LOAD_ANY;
		srcplace= AIStation.GetLocation(road.source.stationID);
		dstplace= AIStation.GetLocation(road.target.stationID);
	break;
	case RouteType.AIRNET: // it's the air network
		INSTANCE.carrier.AirNetworkOrdersHandler();
		return true;
	break;
	case RouteType.CHOPPER:
		oneorder=AIOrder.AIOF_FULL_LOAD_ANY;
		twoorder=AIOrder.AIOF_FULL_LOAD_ANY;
		srcplace= AIIndustry.GetHeliportLocation(road.sourceID);
		dstplace= AIStation.GetLocation(road.target.stationID);
	break;
	}
if (srcplace == null || dstplace == null) return false;
DInfo("Setting orders for route "+idx,2);
INSTANCE.carrier.VehicleOrdersReset(veh);
if (!AIOrder.AppendOrder(veh, srcplace, oneorder))
	{ DError("First order refuse",2); }
if (!AIOrder.AppendOrder(veh, dstplace, twoorder))
	{ DError("Second order refuse",2); }
vehlist.RemoveTop(1);
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
local idx=INSTANCE.carrier.VehicleFindRouteIndex(veh);
// One day i should check rogues vehicles running out of control from a route, but this shouldn't happen :p
local road=cRoute.GetRouteObject(idx);
local homedepot = null;
if (road != null)	homedepot=road.GetDepot(idx);
if (homedepot == null)
	{
	local tile=AIVehicle.GetLocation(veh);
	local isDepot=cStation.IsDepot(tile);
	if (isDepot)
		{
		DInfo("Cannot find depot for "+INSTANCE.carrier.VehicleGetFormatString(veh)+" but it is at a depot :P",0,"cCarrier::VehicleSetDepotOrder");
		AIVehicle.StartStopVehicle(veh);
		INSTANCE.Sleep(20);
		tile=AIVehicle.GetLocation(veh);
		isDepot=cStation.IsDepot(tile);
		if (!isDepot)	AIVehicle.StartStopVehicle(veh);
		return;
		}
	if (INSTANCE.carrier.ToDepotList.HasItem(veh))	return false;
	DError("DOH! Cannot find any depot to send "+INSTANCE.carrier.VehicleGetFormatString(veh)+" to !",0,"cCarrier::VehicleSetDepotOrder");
	if (AIVehicle.GetVehicleType(veh)==AIVehicle.VT_AIR)
		{
		local virtgroup=cRoute.GetVirtualAirPassengerGroup();
		local ingroup=AIVehicle.GetGroupID(veh);
		if (ingroup != virtgroup)
			{
			DInfo("Moving the aircraft to virtual network as backup",1,"cCarrier::VehicleSetDepotOrder");
			AIGroup.MoveVehicle(virtgroup, veh);
			return;
			}
		}
	if (AIVehicle.SendVehicleToDepot(veh)) // it might find a depot near, let's hope
		{
		DWarn("Looks like "+INSTANCE.carrier.VehicleGetFormatString(veh)+" found a depot in its way",0,"cCarrier::VehicleSetDepotOrder");
		INSTANCE.carrier.ToDepotList.AddItem(veh,DepotAction.SELL);
		}
	else	{
		DError("DOH DOH ! We're really in bad situation with "+INSTANCE.carrier.VehicleGetFormatString(veh)+". Trying to move it to some other route as last hope!",0,"cCarrier::VehicleSetDepotOrder");
		local veh_in_group = AIVehicle.GetGroupID(veh);
		local vehList = AIVehicleList();
		if (vehList.HasItem(veh))	vehList.SetValue(veh,-1); // remove the bad vehicle from the list
		vehList.RemoveValue(-1);
		vehList.Valuate(AIVehicle.GetVehicleType);
		vehList.KeepValue(AIVehicle.GetVehicleType(veh)); // now keep vehicles of same type as bad vehicle
		vehList.Valuate(AIVehicle.GetGroupID);
		vehList.RemoveValue(veh_in_group); // now remove any vehicle that are in the same bad group as it
		local weird=true;
		if (!vehList.IsEmpty())
			{
			local newgroup=vehList.GetValue(vehList.Begin());
			DWarn("Found group #"+newgroup+AIGroup.GetName(newgroup)+" that can hold "+INSTANCE.carrier.VehicleGetFormatString(veh)+". Moving it there",0,"cCarrier::VehicleSetDepotOrder");
			if (!AIGroup.MoveVehicle(newgroup, veh))	weird=true;
									else	weird=false;
			}
		else	{ DError("Cannot find a group to hold "+INSTANCE.carrier.VehicleGetFormatString(veh),0,"cCarrier::VehicleSetDepotOrder"); }
		if (weird)	DError("LOL ! And this fail, can only hope "+INSTANCE.carrier.VehicleGetFormatString(veh)+" get destroy itself now. Shoot it !",0,"cCarrier::VehicleSetDepotOrder");
		}
	return false;
	}
		
AIOrder.UnshareOrders(veh);
INSTANCE.carrier.VehicleOrdersReset(veh);
if (road.source_stationID != null)	AIOrder.AppendOrder(veh, AIStation.GetLocation(road.source_stationID), AIOrder.AIOF_NONE);
if (road.target_stationID != null)	AIOrder.AppendOrder(veh, AIStation.GetLocation(road.target_stationID), AIOrder.AIOF_NONE);
local orderindex=AIOrder.GetOrderCount(veh);
if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.AIOF_STOP_IN_DEPOT))
	{ DError("Vehicle refuse goto depot order",2,"cCarrier::VehicleSetDepotOrder"); }
if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.AIOF_STOP_IN_DEPOT))
	{ DError("Vehicle refuse goto depot order",2,"cCarrier::VehicleSetDepotOrder"); }
// And another one day i will kills all vehicles that refuse to go to a depot !!!
if (road.target_entry)	homedepot=road.target.depot;
if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.AIOF_STOP_IN_DEPOT))
	{ DError("Vehicle refuse goto depot order",2,"cCarrier::VehicleSetDepotOrder"); }
if (!AIOrder.AppendOrder(veh, homedepot, AIOrder.AIOF_STOP_IN_DEPOT))
	{ DError("Vehicle refuse goto depot order",2,"cCarrier::VehicleSetDepotOrder"); }
AIOrder.SkipToOrder(veh, orderindex);
local target=AIOrder.GetOrderDestination(veh, AIOrder.ORDER_CURRENT);
local dist=AITile.GetDistanceManhattanToTile(AIVehicle.GetLocation(veh), target);
INSTANCE.Sleep(5);	// wait it to move a bit
local newtake=AITile.GetDistanceManhattanToTile(AIVehicle.GetLocation(veh), target);

if (AIVehicle.GetVehicleType(veh)!=AIVehicle.VT_RAIL && newtake > dist)
	{
	DInfo("Reversing direction of "+INSTANCE.carrier.VehicleGetFormatString(veh),1,"cCarrier::VehicleSetDepotOrder");
	AIVehicle.ReverseVehicle(veh);
	}
// twice time, even we get caught by vehicle orders check, it will ask to send the vehicle.... to depot
DInfo("Setting depot order for vehicle "+INSTANCE.carrier.VehicleGetFormatString(veh),2,"cCarrier::VehicleSetDepotOrder");
}

function cCarrier::VehicleOrderIsValid(vehicle,orderpos)
// Really check if a vehicle order is valid
{
// for now i just disable orders check for chopper, find a better fix if this trouble us later
local chopper=INSTANCE.carrier.AircraftIsChopper(vehicle);
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
local uid=INSTANCE.carrier.VehicleFindRouteIndex(trainID);
if (uid==null)	{ DError("Cannot find uid for that train",1,"cCarrier::TrainSetOrders"); return false; }
local road=cRoute.GetRouteObject(uid);
if (road==null)	return false;
DInfo("Append orders to "+AIVehicle.GetName(trainID),2,"cCarrier::TrainSetOrder");
local firstorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
local secondorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
if (!road.source_istown)	firstorder+=AIOrder.AIOF_FULL_LOAD_ANY;
if (!AIOrder.AppendOrder(trainID, AIStation.GetLocation(road.source.stationID), firstorder))
	{ DError(AIVehicle.GetName(trainID)+" refuse first order",2,"cCarrier::TrainSetOrder"); return false; }
if (!AIOrder.AppendOrder(trainID, AIStation.GetLocation(road.target.stationID), secondorder))
	{ DError(AIVehicle.GetName(trainID)+" refuse second order",2,"cCarrier::TrainSetOrder"); return false; }
return true;
}



