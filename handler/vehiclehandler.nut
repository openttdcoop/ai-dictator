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


// main class is in vehiculebuilder

function cCarrier::GetCurrentCargoType(vehID)
// return the cargoID in use by this vehicle
{
local cargoList=AICargoList();
foreach (cargoID, dummy in cargoList)
	if (AIVehicle.GetCapacity(vehID, cargoID) > 0)	return cargoID;
return -1;
}

function cCarrier::GetGroupLoadCapacity(groupID)
// return the total capacity a group of vehicle can handle
{
if (!AIGroup.IsValidGroup(groupID))	return 0;
local veh_in_group=AIVehicleList_Group(groupID);
local cargoList=AICargoList();
local total=0;
local biggest=0;
foreach (cargoID, dummy in cargoList)
	{
	veh_in_group.Valuate(AIVehicle.GetCapacity, cargoID);
	total=0;
	foreach (vehicle, capacity in veh_in_group)	total+=capacity;
	if (total > biggest)	biggest=total;
	}
return biggest;
}

function cCarrier::VehicleGetBiggestCapacityUsingStation(stationID)
// return the top capacity vehicles that use that station
{
local vehlist=AIVehicleList_Station(stationID);
vehlist.Valuate(AIEngine.GetCapacity);
vehlist.Sort(AIList.SORT_BY_VALUE,false);
local top=0;
if (!vehlist.IsEmpty())	top=vehlist.GetValue(vehlist.Begin());
return top;
}

function cCarrier::VehicleListBusyAtAirport(stationID)
// return the list of vehicles that are waiting at the station
{
local vehicles=AIVehicleList_Station(stationID);
local tilelist=cTileTools.GetTilesAroundPlace(AIStation.GetLocation(stationID),24); // grab tiles around the station
tilelist.Valuate(AIStation.GetStationID); // look all station ID there
tilelist.KeepValue(stationID); // and keep only tiles with our stationID
vehicles.Valuate(AIVehicle.GetLocation);
foreach (vehicle, location in vehicles)
	{ if (!tilelist.HasItem(location))	vehicles.SetValue(vehicle, -1); }
vehicles.RemoveValue(-1);
//DInfo(vehicles.Count()+" vehicles near that station",2);
vehicles.Valuate(AIVehicle.GetState);
vehicles.KeepValue(AIVehicle.VS_AT_STATION);
return vehicles;
}

function cCarrier::VehicleList_KeepStuckVehicle(vehicleslist)
/**
* Filter a list of vehicle to only keep running ones with a 0 speed (stuck vehicle)
* 
* @param vehicleslist The list of vehicle we should filter
* @return same list with only matching vehicles
*/
{
vehicleslist.Valuate(AIVehicle.GetState);
vehicleslist.KeepValue(AIVehicle.VS_RUNNING);
vehicleslist.Valuate(AIVehicle.GetCurrentSpeed);
vehicleslist.KeepValue(0); // non moving ones
return vehicleslist;
}

function cCarrier::VehicleList_KeepLoadingVehicle(vehicleslist)
/**
* Filter a list of vehicle to only keep ones that are loading at a station
* 
* @param vehicleslist The list of vehicle we should filter
* @return same list with only matching vehicles
*/
{
vehicleslist.Valuate(AIVehicle.GetState);
vehicleslist.KeepValue(AIVehicle.VS_AT_STATION);
return vehicleslist;
}

function cCarrier::VehicleNearStation(stationID)
/**
* return a list with all road vehicles we own near that station with VS_RUNNING && VS_AT_STATION status
*
* @param stationID the station id to check
* @return the vehicle list
*/
{
local vehicles=AIVehicleList_Station(stationID);
local tilelist=cTileTools.GetTilesAroundPlace(AIStation.GetLocation(stationID),24);
tilelist.Valuate(AIStation.GetStationID);
tilelist.KeepValue(stationID); // now tilelist = only the tiles of the station we were looking for
local check_tiles=AITileList();
foreach (tiles, stationid_found in tilelist)
	{
	local stationloc=AIStation.GetLocation(stationid_found);
	local upper=stationloc+AIMap.GetTileIndex(-1,-1);
	local lower=stationloc+AIMap.GetTileIndex(1,1);
	check_tiles.AddRectangle(upper,lower);
	}
vehicles.Valuate(AIVehicle.GetLocation);
foreach (vehicle, location in vehicles)
	{ if (!check_tiles.HasItem(location))	vehicles.SetValue(vehicle, -1); }
vehicles.RemoveValue(-1);
vehicles.Valuate(AIVehicle.GetState);
vehicles.RemoveValue(AIVehicle.VS_STOPPED);
vehicles.RemoveValue(AIVehicle.VS_IN_DEPOT);
vehicles.RemoveValue(AIVehicle.VS_BROKEN);
vehicles.RemoveValue(AIVehicle.VS_CRASHED);
vehicles.RemoveValue(AIVehicle.VS_INVALID);
//DInfo("VehicleListAtRoadStation = "+vehicles.Count(),2);
return vehicles;
}

function cCarrier::VehicleGetName(veh)
// return a vehicle string with the vehicle infos
{
if (!AIVehicle.IsValidVehicle(veh))	return "<Invalid vehicle> #"+veh;
local toret="#"+veh+" "+AIVehicle.GetName(veh)+"("+cEngine.GetName(AIVehicle.GetEngineType(veh))+")";
return toret;
}

function cCarrier::VehicleGetCargoLoad(veh)
// return amout of any cargo loaded in the vehicle
{
if (!AIVehicle.IsValidVehicle(veh)) return 0;
local cargoList=AICargoList();
local amount=0;
local topamount=0;
foreach (i, dummy in cargoList)
	{
	amount=AIVehicle.GetCargoLoad(veh,i);
	if (amount > topamount)	topamount=amount;
	}
return amount;
}

function cCarrier::VehicleGetLoadingPercent(veh)
// return the % load of any cargo on a vehicle
{
if (!AIVehicle.IsValidVehicle(veh)) return 0;
local full=cCarrier.VehicleGetFullCapacity(veh);
local actual=cCarrier.VehicleGetCargoLoad(veh);
local toret=(actual * 100) / full;
return toret;
}

function cCarrier::VehicleHandleTrafficAtStation(stationID, reroute)
// if reroute this function stop all vehicles that use stationID to goto stationID
// if !rereroute this function restore vehicles orders
{
local station=cStation.GetStationObject(stationID);
local road=null;
local vehlist=null;
local veh=null;
local group=null;
local checkgroup=AIList();
checkgroup.AddList(station.owner);
checkgroup.AddItem(0,0); // add virtual group in the list
foreach (ownID, dummy in station.owner)
	{
	if (ownID == 1)	continue; // ignore virtual mail route, route 0 will re-reroute route 1 already
	road=cRoute.GetRouteObject(ownID);
	if (road==null || road.groupID==null)	return;
	if (reroute)
		{
		vehlist=AIVehicleList_Group(road.groupID);
		vehlist.Valuate(AIVehicle.GetState);
		vehlist.RemoveValue(AIVehicle.VS_STOPPED);
		vehlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
		vehlist.RemoveValue(AIVehicle.VS_CRASHED);
		foreach (veh, dummy in vehlist)
			if (cCarrier.ToDepotList.HasItem(veh))	vehlist.RemoveItem(veh); // remove vehicle on their way to depot
		if (vehlist.IsEmpty()) continue;
		veh=vehlist.Begin();
		local orderindex=VehicleFindDestinationInOrders(veh, stationID);
		if (orderindex != -1)
			{
			DInfo("Re-routing traffic on route "+cRoute.RouteGetName(road.UID)+" to ignore "+cStation.StationGetName(stationID),0);
			if (!AIOrder.RemoveOrder(veh, AIOrder.ResolveOrderPosition(veh, orderindex)))
				{ DError("Fail to remove order for vehicle "+INSTANCE.carrier.VehicleGetName(veh),2); }
			}
		}
	else	{ INSTANCE.carrier.VehicleBuildOrders(road.groupID,true); }
	}
}

function cCarrier::VehicleSendToDepot(veh,reason)
// send a vehicle to depot
{
if (!AIVehicle.IsValidVehicle(veh))	return false;
if (INSTANCE.carrier.ToDepotList.HasItem(veh))
	{
	if (AIOrder.GetOrderCount(veh)<3)	INSTANCE.carrier.ToDepotList.RemoveItem(veh); // going to depot with strange orders
						else	return false; // ignore ones going to depot already
	}
INSTANCE.carrier.VehicleSetDepotOrder(veh);
local understood=false;
local target=AIOrder.GetOrderDestination(veh, AIOrder.ORDER_CURRENT);
local dist=AITile.GetDistanceManhattanToTile(AIVehicle.GetLocation(veh), target);
INSTANCE.Sleep(6);	// wait it to move a bit
local newtake=AITile.GetDistanceManhattanToTile(AIVehicle.GetLocation(veh), target);
if (AIVehicle.GetVehicleType(veh)!=AIVehicle.VT_RAIL && newtake > dist)
	{
	DInfo("Reversing direction of "+INSTANCE.carrier.VehicleGetName(veh),1,"cCarrier::VehicleSendToDepot");
	AIVehicle.ReverseVehicle(veh);
	}
local rr="";
local wagonnum=0;
if (reason >= DepotAction.ADDWAGON)	{ wagonnum=reason-DepotAction.ADDWAGON; reason=DepotAction.ADDWAGON; }
switch (reason)
	{
	case	DepotAction.SELL:
		rr="to be sold.";
	break;
	case	DepotAction.LINEUPGRADE:
	case	DepotAction.SIGNALUPGRADE:
	case	DepotAction.UPGRADE:
		rr="to be upgrade.";
	break;
	case	DepotAction.REPLACE:
		rr="to be replace.";
	break;
	case	DepotAction.CRAZY:
		rr="for a crazy action.";
	break;
	case	DepotAction.REMOVEROUTE:
		rr="for removing a dead route.";
	break;
	case	DepotAction.ADDWAGON:
		rr="to add "+wagonnum+" new wagons.";
		reason=wagonnum+DepotAction.ADDWAGON;
	break;
	}
DInfo("Vehicle "+INSTANCE.carrier.VehicleGetName(veh)+" is going to depot "+rr,0,"cCarrier::VehicleSendToDepot");
INSTANCE.carrier.ToDepotList.AddItem(veh,reason);
}

function cCarrier::VehicleGetFullCapacity(veh)
// return total capacity a vehicle can handle
{
if (!AIVehicle.IsValidVehicle(veh)) return -1;
local mod=AIVehicle.GetVehicleType(veh);
local engine=AIVehicle.GetEngineType(veh);
if (mod == AIVehicle.VT_RAIL)
	{ // trains
	local wagonnum=AIVehicle.GetNumWagons(veh);
	local wagonengine=AIVehicle.GetWagonEngineType(veh,1);
	local wagoncapacity=AIEngine.GetCapacity(wagonengine);
	local traincapacity=AIEngine.GetCapacity(engine);
	local total=traincapacity+(wagonnum*wagoncapacity);
	return total;
	}
else	{ // others
	local value=AIEngine.GetCapacity(engine);
	return value;
	}
}

function cCarrier::VehicleFindRouteIndex(veh)
// return UID of the route the veh vehicle is running on
{
local group=AIVehicle.GetGroupID(veh);
if (cRoute.GroupIndexer.HasItem(group))		return cRoute.GroupIndexer.GetValue(group);
return null;
}

function cCarrier::VehicleUpgradeEngine(vehID)
// we will try to upgrade engine and wagons for vehicle veh
{
local idx=INSTANCE.carrier.VehicleFindRouteIndex(vehID);
if (idx == null)
	{
	DWarn("This vehicle "+INSTANCE.carrier.VehicleGetName(vehID)+" is not use by any route !!!",1,"cCarrier::VehicleUpgradeEngine");
	INSTANCE.carrier.VehicleSell(vehID,true);
	INSTANCE.carrier.vehnextprice=0;
	return false;
	}
local betterEngine=cEngine.IsVehicleAtTop(vehID);
if (betterEngine==-1)
	{
	DWarn("That vehicle have its engine already at top, building a new one anyway",1,"cCarrier::VehicleUpgradeEngine");
	betterEngine=AIVehicle.GetEngineType(vehID);
	}
local vehtype=AIVehicle.GetVehicleType(vehID);
local new_vehID=null;
local road=INSTANCE.route.GetRouteObject(idx);
if (road == null)	return;
local homedepot=cRoute.GetDepot(idx);
if (homedepot==-1)	homedepot=AIVehicle.GetLocation(vehID);
DInfo("Upgrading using depot at "+homedepot,2,"cCarrier::VehicleUpgradeEngine");
PutSign(homedepot,"D");
local money=0;
local oldenginename=INSTANCE.carrier.VehicleGetName(vehID);
switch (vehtype)
	{
	case AIVehicle.VT_RAIL:
/* Upgrading the loco engine is doable, but it might get too complexe for nothing, so i will destroy the train, and tell the AddWagon function we need X more wagons, as the train is now removed, the function will have no choice then build another one. This new one (if it's doable) will be an upgraded version of loco and wagons. Problem solve. */
		homedepot=AIVehicle.GetLocation(vehID);
		local numwagon=cCarrier.GetNumberOfWagons(vehID);
		INSTANCE.carrier.VehicleSell(vehID,false);
		INSTANCE.carrier.AddWagon(idx, numwagon);
		DInfo("Train vehicle "+oldenginename+" replace, a new train will be built",0,"cCarrier::VehicleUpgradeEngine");
		return; // for now cannot do more than that
	break;
	case AIVehicle.VT_ROAD:
		INSTANCE.carrier.VehicleSell(vehID,false);
		new_vehID = INSTANCE.carrier.CreateRoadEngine(betterEngine, homedepot, road.cargoID);
	break;
	case AIVehicle.VT_AIR:
		INSTANCE.carrier.VehicleSell(vehID,false);
		new_vehID = INSTANCE.carrier.CreateAircraftEngine(betterEngine, homedepot);
	break;
	case AIVehicle.VT_WATER:
		INSTANCE.carrier.VehicleSell(vehID,false);
	return;
	break;
	}
if (AIVehicle.IsValidVehicle(new_vehID))
	{
	local newenginename=INSTANCE.carrier.VehicleGetName(new_vehID);
	AIGroup.MoveVehicle(road.groupID,new_vehID);
	DInfo("Vehicle "+oldenginename+" replace with "+newenginename,0,"cCarrier::VehicleUpgradeEngine");
	AIVehicle.StartStopVehicle(new_vehID); // Not sharing orders with previous vehicle as its orders are "goto depot" orders
	INSTANCE.carrier.VehicleBuildOrders(road.groupID,false); // need to build its orders
	}
if (INSTANCE.carrier.vehnextprice < 0)	INSTANCE.carrier.vehnextprice=0;
}

function cCarrier::VehicleMaintenance_Orders(vehID)
// try to repair orders for a vehicle, else send it to depot
{
local numorders=AIOrder.GetOrderCount(vehID);
local name=cCarrier.VehicleGetName(vehID);
for (local z=AIOrder.GetOrderCount(vehID)-1; z >=0; z--)
		{ // I check backward to prevent z index gone wrong if an order is remove
		if (!INSTANCE.carrier.VehicleOrderIsValid(vehID, z))
			{
			DInfo("-> Vehicle "+name+" have invalid order, removing orders "+z,0,"cCarrier::VehicleMaintenance_Orders");
			AIOrder.RemoveOrder(vehID, z);
			}
		}
numorders=AIOrder.GetOrderCount(vehID);
if (numorders < 2)
		{
		local groupid=AIVehicle.GetGroupID(vehID);
		DInfo("-> Vehicle "+name+" have too few orders, trying to correct it",0,"cCarrier::VehicleMaintenance_Orders");
		INSTANCE.carrier.VehicleBuildOrders(groupid,false);
		}
numorders=AIOrder.GetOrderCount(vehID);
	if (numorders < 2)
		{
		DInfo("-> Vehicle "+name+" have too few orders, sending it to depot",0,"cCarrier::VehicleMaintenance_Orders");
		INSTANCE.carrier.VehicleSendToDepot(vehID, DepotAction.SELL);
		cCarrier.CheckOneVehicleOrGroup(vehID,true); // push all vehicles to get a check
		}
}

function cCarrier::VehicleMaintenance()
// lookout our vehicles for troubles
{
local tlist=AIList();
while (cCarrier.MaintenancePool.len()>0)	tlist.AddItem(cCarrier.MaintenancePool.pop(),0);
// Get the work and clean the mainteance list
tlist.Valuate(AIVehicle.GetState);
tlist.RemoveValue(AIVehicle.VS_STOPPED);
tlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
tlist.RemoveValue(AIVehicle.VS_CRASHED);
tlist.RemoveValue(AIVehicle.VS_INVALID);
DInfo("Checking "+tlist.Count()+" vehicles",0,"VehicleMaintenance");
local name="";
local tx, ty, price=0; // temp variable to use freely
INSTANCE.carrier.warTreasure=0;
local allroadveh=AIVehicleList();
allroadveh.Valuate(AIVehicle.GetVehicleType);
allroadveh.KeepValue(AIVehicle.VT_ROAD);
allroadveh.Valuate(AIVehicle.GetState);
allroadveh.RemoveValue(AIVehicle.VS_STOPPED);
allroadveh.RemoveValue(AIVehicle.VS_IN_DEPOT);
allroadveh.RemoveValue(AIVehicle.VS_CRASHED);
allroadveh.RemoveValue(AIVehicle.VS_INVALID);

local checkallvehicle=(allroadveh.Count()==tlist.Count());
foreach (vehicle, dummy in tlist)
	{
	local vehtype=AIVehicle.GetVehicleType(vehicle);
	if (AIVehicle.GetVehicleType(vehicle)==AIVehicle.VT_ROAD)	INSTANCE.carrier.warTreasure+=AIVehicle.GetCurrentValue(vehicle);
	local topengine=cEngine.IsVehicleAtTop(vehicle); // new here
	if (topengine != -1)	price=cEngine.GetPrice(topengine);
				else	price=cEngine.GetPrice(AIVehicle.GetEngineType(vehicle));
	name=INSTANCE.carrier.VehicleGetName(vehicle);
	tx=AIVehicle.GetAgeLeft(vehicle);
	if (tx < cCarrier.OldVehicle)
		{
		if (!cBanker.CanBuyThat(price+INSTANCE.carrier.vehnextprice)) continue;
		DInfo("-> Vehicle "+name+" is getting old ("+tx+" days left), replacing it",0,"cCarrier::VehicleMaintenance");
		INSTANCE.carrier.VehicleSendToDepot(vehicle,DepotAction.REPLACE);
		cCarrier.CheckOneVehicleOrGroup(vehicle, true);
		}
	tx=INSTANCE.carrier.VehicleGetProfit(vehicle);
	ty=AIVehicle.GetAge(vehicle);
	if (ty > 240 && tx < 0 && INSTANCE.OneMonth > 6) // (6 months after new year)
		{
		ty=INSTANCE.carrier.VehicleFindRouteIndex(vehicle);
		INSTANCE.builder.RouteIsDamage(ty);
		}
	tx=AIVehicle.GetReliability(vehicle);
	if (tx < 30)
		{
		DInfo("-> Vehicle "+name+" reliability is low ("+tx+"%), sending it for servicing at depot",0,"cCarrier::VehicleMaintenance");
		AIVehicle.SendVehicleToDepotForServicing(vehicle);
		local idx=INSTANCE.carrier.VehicleFindRouteIndex(vehicle);
		INSTANCE.builder.RouteIsDamage(idx);
		cCarrier.CheckOneVehicleOrGroup(vehicle, true);
		}
	local enginecheck=cEngine.IsRabbitSet(vehicle);
	if (topengine != -1 && enginecheck)	topengine=-1; // stop upgrade
	if (topengine != -1)
		{
		// reserving money for the upgrade
		DInfo("Upgrade engine ! "+INSTANCE.bank.CanBuyThat(INSTANCE.carrier.vehnextprice+price)+" price: "+price+" vehnextprice="+vehnextprice,1,"cCarrier::VehicleMaintenance");
		if (!INSTANCE.bank.CanBuyThat(INSTANCE.carrier.vehnextprice+price))	continue; // no way, we lack funds for it
		INSTANCE.carrier.vehnextprice+=price;
		DInfo("-> Vehicle "+name+" can be upgrade with a better version, sending it to depot",0,"cCarrier::VehicleMaintenance");
		cEngine.RabbitSet(vehicle);
		INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.UPGRADE);
		cCarrier.CheckOneVehicleOrGroup(vehicle, true);
		}
	cCarrier.VehicleMaintenance_Orders(vehicle);
	AIController.Sleep(1);
	}
if (!checkallvehicle)
	{ // we need to estimate the fleet value
	local midvalue=0;
	if (allroadveh.Count()>0)	midvalue=INSTANCE.carrier.warTreasure / allroadveh.Count();
	local fleet=allroadveh.Count()-6;
	if (fleet < 0)	fleet=0;
	INSTANCE.carrier.warTreasure=fleet*midvalue;
	DInfo("warTreasure estimate to "+INSTANCE.carrier.warTreasure+" fleet: "+fleet,2,"cCarrier::VehicleMaintenance");
	}
}

function cCarrier::CrazySolder(moneytoget)
// this function send & sold nearly all road vehicle to get big money back
{
local allvehicle=AIVehicleList();
allvehicle.Valuate(AIVehicle.GetVehicleType);
allvehicle.KeepValue(AIVehicle.VT_ROAD);
allvehicle.Valuate(AIVehicle.GetProfitThisYear);
allvehicle.Sort(AIList.SORT_BY_VALUE, false);
allvehicle.RemoveTop(2);
allvehicle.Sort(AIList.SORT_BY_VALUE, true);
foreach (vehicle, dummy in allvehicle)
	{
	INSTANCE.Sleep(1);
	INSTANCE.carrier.VehicleSendToDepot(vehicle,DepotAction.CRAZY);
	if (moneytoget < 0)	break;
	moneytoget-=AIVehicle.GetCurrentValue(vehicle);
	}
}

function cCarrier::VehicleSell(veh, recordit)
// sell the vehicle and update route info
{
DInfo("Selling Vehicle "+INSTANCE.carrier.VehicleGetName(veh),0,"cCarrier::VehicleSell");
local uid=INSTANCE.carrier.VehicleFindRouteIndex(veh);
local road=cRoute.GetRouteObject(uid);
local vehvalue=AIVehicle.GetCurrentValue(veh);
local vehtype=AIVehicle.GetVehicleType(veh);
INSTANCE.carrier.vehnextprice-=vehvalue;
if (INSTANCE.carrier.vehnextprice < 0)	INSTANCE.carrier.vehnextprice=0;
if (AIVehicle.GetVehicleType(veh)==AIVehicle.VT_RAIL)	cTrain.DeleteVehicle(veh);	// must be call before selling the vehicle
AIVehicle.SellVehicle(veh);
if (road == null) return;
road.RouteUpdateVehicle();
if (recordit)	road.date_VehicleDelete=AIDate.GetCurrentDate();
}

function cCarrier::VehicleSellAndDestroyRoute(vehicle)
// This is to watch a group of vehicle to sell, to remove a dead station/route
// We will callback the handler to remove the route, this might fail if last vehicle is crash
{
if (!AIVehicle.IsValidVehicle(vehicle))	return;
local groupID=AIVehicle.GetGroupID(vehicle);
local allvehicles=AIVehicleList_Group(groupID);
allvehicles.Valuate(AIVehicle.GetState);
allvehicles.RemoveValue(AIVehicle.VS_CRASHED);
if (allvehicles.Count()>1)	INSTANCE.carrier.VehicleSell(vehicle, false);
				else	{ // ok we are handling the last one of the group
					local idx=cRoute.GroupIndexer.GetValue(groupID);
					local road=cRoute.GetRouteObject(idx);
					if (road==null)	{ DError("Cannot load that route : "+idx,1,"cCarrier::VehicleSellAndDestroyRoute"); return; }
					INSTANCE.carrier.VehicleSell(vehicle, false);
					road.RouteUndoableFreeOfVehicle();
					}
}

function cCarrier::VehicleGroupSendToDepotAndSell(idx)
// Send & sell all vehicles from that route
{
local road=INSTANCE.route.GetRouteObject(idx);
if (road == null)	return;
local vehlist=null;
if (road.groupID != null)
	{
	vehlist=AIVehicleList_Group(road.groupID);
	if (vehlist.IsEmpty())	return false;
	else	{
		DInfo("Removing a group of vehicle : "+vehlist.Count(),1,"VehicleGroupSendToDepotAndSell");
		foreach (vehicle, dummy in vehlist)	INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.REMOVEROUTE);
		}
	}
else	return false;
return true;
}

function cCarrier::VehicleGroupSendToDepotAndWaitSell(idx)
// Send & sell all vehicles from that route, we will wait 2 months or the vehicles are sold
{
local road=INSTANCE.route.GetRouteObject(idx);
if (road == null)	return;
local vehlist=null;
if (road.groupID != null)
	{
	vehlist=AIVehicleList_Group(road.groupID);
	DInfo("Removing a group of vehicle : "+vehlist.Count(),1,"VehicleGroupSendToDepotAndWait");
	foreach (vehicle, dummy in vehlist)
		{
		INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
		}
	foreach (vehicle, dummy in vehlist)
		{
		local waitmax=444; // 2 month / vehicle, as 444*10(sleep)=4440/74
		local waitcount=0;
		local wait=true;
		do	{
			AIController.Sleep(10);
			INSTANCE.carrier.VehicleIsWaitingInDepot();
			wait=(AIVehicle.IsValidVehicle(vehicle));
			DInfo("wait? "+AIVehicle.IsValidVehicle(vehicle)+" waiting:"+wait+" waitcount="+waitcount,2,"VehicleGroupSendToDepotAndWait");
			waitcount++;
			if (waitcount > waitmax)	wait=false;
			} while (wait);
		}
	}
}

function cCarrier::VehicleIsWaitingInDepot(onlydelete=false)
// this function checks our depots and sell vehicle in it
// if onlydelete set to true, we only remove vehicle, no upgrade/replace...
{
local tlist=AIVehicleList();
DInfo("Checking vehicles in depots:",2,"cCarrier::VehicleWaitingInDepot");
tlist.Valuate(AIVehicle.IsStoppedInDepot);
tlist.KeepValue(1);
foreach (i, dummy in tlist)
	{
	INSTANCE.Sleep(1);
	local reason=DepotAction.SELL;
	local numwagon=0;
	local uid=0;
	local name=INSTANCE.carrier.VehicleGetName(i);
	INSTANCE.carrier.VehicleOrdersReset(i);
	if (INSTANCE.carrier.ToDepotList.HasItem(i))
		{
		reason=INSTANCE.carrier.ToDepotList.GetValue(i);
		INSTANCE.carrier.ToDepotList.RemoveItem(i);
		if (reason >= DepotAction.ADDWAGON)
			{
			numwagon=reason-DepotAction.ADDWAGON;
			reason=DepotAction.ADDWAGON;
			uid=INSTANCE.carrier.VehicleFindRouteIndex(i);
			if (uid==null)	{
						DError("Cannot find the route uid for "+name,2,"cCarrier::VehicleIsWaitingInDepot");
						reason=DepotAction.SELL;
						}
			}
		}
	else	{
		if (AIVehicle.GetVehicleType(i)==AIVehicle.VT_RAIL)
			{
			DInfo("I don't know the reason why "+name+" is at depot, restarting it",1,"VehicleWaitingInDepot");
			cCarrier.TrainSetOrders(i);
			if (AIVehicle.StartStopVehicle(i))	continue;
			}
		else	DInfo("I don't know the reason why "+name+" is at depot, selling it",1,"VehicleWaitingInDepot");
		}
	if (onlydelete && (AIVehicle.GetVehicleType(i) == AIVehicle.VT_AIR || AIVehicle.GetVehicleType(i) == AIVehicle.VT_ROAD))
		{ DInfo("We've been ask to delete all vehicles waiting in depot",1,"VehicleWaitingInDepot"); reason=DepotAction.CRAZY; }
	switch (reason)
		{
		case	DepotAction.SELL:
			DInfo("Vehicle "+name+" is waiting in depot to be sold",1,"VehicleWaitingInDepot");
			INSTANCE.carrier.VehicleSell(i,true);
		break;
		case	DepotAction.UPGRADE:
			DInfo("Vehicle "+name+" is waiting in depot to be upgrade",1,"VehicleWaitingInDepot");
			INSTANCE.carrier.VehicleUpgradeEngine(i);
		break;
		case	DepotAction.REPLACE:
			DInfo("Vehicle "+name+" is waiting in depot to be replace",1,"VehicleWaitingInDepot");
			INSTANCE.carrier.VehicleSell(i,false);
		break;
		case	DepotAction.CRAZY:
			INSTANCE.carrier.VehicleSell(i,false);
		break;
		case	DepotAction.REMOVEROUTE:
			INSTANCE.carrier.VehicleSellAndDestroyRoute(i);
		break;
		case	DepotAction.ADDWAGON:
			DInfo("Vehicle "+name+" is waiting at depot to get "+numwagon+" wagons",2,"cCarrier::VehicleIsWaitingInDepot");
			INSTANCE.carrier.AddWagon(uid, numwagon);
		break;
		case	DepotAction.LINEUPGRADE:
			//TODO: upgrade the train line
		break;
		case	DepotAction.SIGNALUPGRADE:
			local uid=INSTANCE.carrier.VehicleFindRouteIndex(i);
			if (uid == null)	return false;
			cRoute.CanAddTrainToStation(uid); // don't care result, it's just to let the station build its signals
		break;
		}
	if (INSTANCE.carrier.ToDepotList.IsEmpty())	INSTANCE.carrier.vehnextprice=0;
	}
}

