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

class cCarrier extends cClass
{
static	AirportTypeLimit=[6, 10, 2, 16, 30, 5, 6, 60, 8]; // limit per airport type
static	IDX_HELPER = 512;			// use to create an uniq ID (also use to set handicap value)
static	AIR_NET_CONNECTOR=2500;		// town is add to air network when it reach that value population
static	ToDepotList=AIList();		// list vehicle going to depot, value=DepotAction for trains we also add wagons need
static	vehicle_database={};		// database for vehicles
static	VirtualAirRoute=[];		// the air network destinations list
static 	OldVehicle=1095;			// age left we consider a vehicle is old
static	MaintenancePool=[];		// list of vehicles that need maintenance
static	function GetVehicleObject(vehicleID)
		{
		return vehicleID in cCarrier.vehicle_database ? cCarrier.vehicle_database[vehicleID] : null;
		}

	rail_max		=null;	// maximum trains vehicle a station can handle
	road_max		=null;	// maximum a road station can upgarde (max: 6)
	road_upgrade	=null;	// maximum vehicle a road station can support before upgarde itself
	air_max	    	=null;	// maximum aircraft a station can handle
	airnet_max		=null;	// maximum aircraft on a network
	airnet_count	=null;	// current number of aircrafts running the network
	water_max		=null;	// maximum ships a station can handle
	road_max_onroute=null;	// maximum road vehicle on a route
	train_length	=null;	// maximum length for train/rail station
	vehicle_cash    =null;	// amount of money we need to buy vehicle
	warTreasure		=null;	// total current value of nearly all our road vehicle
	highcostAircraft=null;	// the highest cost for an aircraft we need
	highcostTrain	=null;	// the highest cost for a train
	speed_MaxTrain	=null;	// maximum speed a train could do
	speed_MaxRoad	=null;	// maximum speed a road vehicle could do
	running_vehicle	=null;	// number of vehicle per type we own
	vehicle_wishlist=null;  // our list of engines to buy

	constructor()
		{
		this.ClassName="cCarrier";
		rail_max		= 0;
		road_max		= 0;
		road_upgrade	= 0;
		air_max		    = 0;
		airnet_max		= 0;
		airnet_count	= 0;
		water_max		= 0;
		road_max_onroute= 0;
		train_length	= 0;
		vehicle_cash	= 0;
		warTreasure		= 0;
		highcostAircraft= 0;
		highcostTrain	= 0;
		speed_MaxTrain	= 0;
		speed_MaxRoad	= 0;
		running_vehicle	= [0,0,0,0];
        vehicle_wishlist= AIList();
		}
}

function cCarrier::GetVehicleName(veh)
// return a vehicle string with the vehicle infos
{
	if (!AIVehicle.IsValidVehicle(veh))	return "<Invalid vehicle> #"+veh;
	local toret="#"+veh+" "+AIVehicle.GetName(veh)+"("+cEngine.GetName(AIVehicle.GetEngineType(veh))+")";
	return toret;
}

function cCarrier::GetVehicleCount(vehtype)
// return number of vehicle we own
// return 0 on error
{
	return INSTANCE.main.carrier.running_vehicle[vehtype];
}

function cCarrier::VehicleCountUpdate()
// update the vehicle counter for vehtype
{
	local allvehlist=AIVehicleList();
	allvehlist.Valuate(AIVehicle.GetVehicleType);
	local ro=0, tr=0, sh=0, ai=0;
	foreach (veh, vtype in allvehlist)
		{
		switch (vtype)
			{
			case AIVehicle.VT_RAIL:
				tr++;
			break;
			case AIVehicle.VT_ROAD:
				ro++;
			break;
			case AIVehicle.VT_WATER:
				sh++;
			break;
			case AIVehicle.VT_AIR:
				ai++;
			break;
			}
		}
	running_vehicle[AIVehicle.VT_RAIL]=tr;
	running_vehicle[AIVehicle.VT_ROAD]=ro;
	running_vehicle[AIVehicle.VT_WATER]=sh;
	running_vehicle[AIVehicle.VT_AIR]=ai;
}

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

function cCarrier::VehicleList_KeepStuckVehicle(vehicleslist)
// Filter a list of vehicle to only keep running ones with a 0 speed (stuck vehicle)
// @param vehicleslist The list of vehicle we should filter
// @return same list with only matching vehicles
{
	vehicleslist.Valuate(AIVehicle.GetState);
	vehicleslist.KeepValue(AIVehicle.VS_RUNNING);
	vehicleslist.Valuate(AIVehicle.GetCurrentSpeed);
	vehicleslist.KeepValue(0); // non moving ones
	return vehicleslist;
}

function cCarrier::VehicleList_KeepLoadingVehicle(vehicleslist)
// Filter a list of vehicle to only keep ones that are loading at a station
// @param vehicleslist The list of vehicle we should filter
// @return same list with only matching vehicles
{
	vehicleslist.Valuate(AIVehicle.GetState);
	vehicleslist.KeepValue(AIVehicle.VS_AT_STATION);
	return vehicleslist;
}

function cCarrier::VehicleNearStation(stationID)
// return a list with all road vehicles we own near that station with VS_RUNNING && VS_AT_STATION status
// @param stationID the station id to check
// @return the vehicle list
{
	local vehicles = AIVehicleList_Station(stationID);
	local tilelist = cTileTools.GetTilesAroundPlace(AIStation.GetLocation(stationID),24);
	tilelist.Valuate(AIStation.GetStationID);
	tilelist.KeepValue(stationID); // now tilelist = only the tiles of the station we were looking for
	local check_tiles = AITileList();
	local stationloc=AIStation.GetLocation(stationID);
	foreach (tiles, stationid_found in tilelist)
		{
		local upper=stationloc+AIMap.GetTileIndex(-1,-1);
		local lower=stationloc+AIMap.GetTileIndex(1,1);
		check_tiles.AddRectangle(upper,lower);
		}
	local altVehicle = AIList();
	foreach (vehicle, _ in vehicles)
		{
		if (check_tiles.HasItem(AIVehicle.GetLocation(vehicle)))	altVehicle.AddItem(vehicle, AIVehicle.GetState(vehicle));
		}
	altVehicle.RemoveValue(AIVehicle.VS_STOPPED);
	altVehicle.RemoveValue(AIVehicle.VS_IN_DEPOT);
	altVehicle.RemoveValue(AIVehicle.VS_BROKEN);
	altVehicle.RemoveValue(AIVehicle.VS_CRASHED);
	altVehicle.RemoveValue(AIVehicle.VS_INVALID);
return altVehicle;
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
		amount = AIVehicle.GetCargoLoad(veh,i);
		if (amount > topamount)	topamount=amount;
		}
	return amount;
}

function cCarrier::VehicleHandleTrafficAtStation(stationID, reroute)
// if reroute this function stop all vehicles that use stationID to goto stationID
// if !rereroute this function restore vehicles orders
{
	local station=cStation.Load(stationID);
	if (!station)	return;
	local road=null;
	local vehlist=null;
	local veh=null;
	local group=null;
	local checkgroup=AIList();
	checkgroup.AddList(station.s_Owner);
	checkgroup.AddItem(0,0); // add pass virtual group in the list
	checkgroup.AddItem(1,0); // add mail virtual
	foreach (ownID, dummy in checkgroup)
		{
		road = cRoute.Load(ownID);
		if (!road || road.Status != 100)	continue;
		if (reroute)
			{
			vehlist = AIVehicleList_Group(road.GroupID);
			vehlist.Valuate(AIVehicle.GetState);
			vehlist.RemoveValue(AIVehicle.VS_STOPPED);
			vehlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
			vehlist.RemoveValue(AIVehicle.VS_CRASHED);
			vehlist.RemoveList(cCarrier.ToDepotList); // remove vehicle on their way to depot
			if (vehlist.IsEmpty()) continue;
			veh = vehlist.Begin();
			local orderindex=cCarrier.VehicleFindDestinationInOrders(veh, stationID);
			if (orderindex != -1)
				{
				DInfo("Re-routing traffic on route "+road.Name+" to ignore "+station.s_Name,0);
				if (!AIOrder.RemoveOrder(veh, AIOrder.ResolveOrderPosition(veh, orderindex)))
					{ DError("Fail to remove order for vehicle "+cCarrier.GetVehicleName(veh),2); }
				}
			}
		else	{ cCarrier.VehicleBuildOrders(road.GroupID,true); }
		}
}

function cCarrier::VehicleSendToDepot_GetReason(reason)
// return the real reason why a vehicle is in SendToDepot list
{
	if (reason >= DepotAction.ADDWAGON && reason < DepotAction.LINEUPGRADE)	return DepotAction.ADDWAGON;
	if (reason >= DepotAction.LINEUPGRADE && reason < DepotAction.SIGNALUPGRADE)	return DepotAction.LINEUPGRADE;
	if (reason >= DepotAction.SIGNALUPGRADE && reason < DepotAction.WAITING)	return DepotAction.SIGNALUPGRADE;
	if (reason >= DepotAction.WAITING && reason < DepotAction.WAITING+200)	return DepotAction.WAITING;
	return reason;
}

function cCarrier::VehicleSendToDepot_GetParam(reason)
// return the parameter found inside the reason or -1 if it's not valid
{
	if (reason >= DepotAction.ADDWAGON && reason < DepotAction.LINEUPGRADE) return (reason - DepotAction.ADDWAGON);
	if (reason >= DepotAction.LINEUPGRADE && reason < DepotAction.SIGNALUPGRADE)	return (reason - DepotAction.LINEUPGRADE);
	if (reason >= DepotAction.SIGNALUPGRADE && reason < DepotAction.WAITING)	return (reason - DepotAction.SIGNALUPGRADE);
	if (reason >= DepotAction.WAITING && reason < DepotAction.WAITING+200)	return (reason - DepotAction.WAITING);
	return -1;
}

function cCarrier::VehicleSendToDepot(veh,reason)
// send a vehicle to depot
{
	if (!AIVehicle.IsValidVehicle(veh))	return false;
	local real_reason = cCarrier.VehicleSendToDepot_GetReason(reason);
	if (INSTANCE.main.carrier.ToDepotList.HasItem(veh))
		{
		if (reason < DepotAction.LINEUPGRADE)	return false;
							// ignore order if we already have one, but not ignoring LINEUPGRADE, SIGNALUPGRADE or WAITING to crush previous one
		}
	if (AIVehicle.GetVehicleType(veh) == AIVehicle.VT_RAIL)
				cCarrier.TrainSetDepotOrder(veh);
		else	cCarrier.VehicleSetDepotOrder(veh);
	local target=AIOrder.GetOrderDestination(veh, AIOrder.ORDER_CURRENT);
	local dist=AITile.GetDistanceManhattanToTile(AIVehicle.GetLocation(veh), target);
	AIController.Sleep(6);	// wait it to move a bit
	local newtake=AITile.GetDistanceManhattanToTile(AIVehicle.GetLocation(veh), target);
	if (AIVehicle.GetVehicleType(veh)!=AIVehicle.VT_RAIL && newtake > dist)
		{
		DInfo("Reversing direction of "+cCarrier.GetVehicleName(veh),1);
		AIVehicle.ReverseVehicle(veh);
		}
	local rr="";
	local wagonnum = cCarrier.VehicleSendToDepot_GetParam(reason);
	switch (real_reason)
		{
		case	DepotAction.SELL:
			rr="to be sold.";
		break;
		case	DepotAction.LINEUPGRADE:
            rr="to change railtype";
        break;
		case	DepotAction.SIGNALUPGRADE:
            rr="to upgrade signals";
        break;
		case	DepotAction.WAITING:
			rr="to wait";
		break;
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
		break;
		}
	DInfo("Vehicle "+ cCarrier.GetVehicleName(veh)+" is going to depot "+rr,0);
	INSTANCE.main.carrier.ToDepotList.AddItem(veh,reason);
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
	local idx = cCarrier.VehicleFindRouteIndex(vehID);
	local oldenginename=cCarrier.GetVehicleName(vehID);
	if (idx == null)
		{
		DWarn("This vehicle "+oldenginename+" is not use by any route !!!",1);
		cCarrier.VehicleSell(vehID, false);
		return false;
		}
	local vehtype=AIVehicle.GetVehicleType(vehID);
	local new_vehID=null;
	local road=cRoute.Load(idx);
	if (!road)	{ cCarrier.VehicleSell(vehID, false); return false; }
	local betterEngine=cEngine.IsVehicleAtTop(vehID);
	if (betterEngine == -1)
		{
		DWarn("That vehicle have its engine already at top",1);
		}
	local homedepot=cRoute.GetDepot(idx);
	if (homedepot==-1)	homedepot=AIVehicle.GetLocation(vehID);
	DInfo("Upgrading using depot at "+homedepot,2);
	local money=0;
	switch (vehtype)
		{
		case AIVehicle.VT_RAIL:
		// Upgrading the loco engine is doable, but it might get too complexe for nothing, so i will destroy the train, and X more wagons
			local numwagon = cEngineLib.VehicleGetNumberOfWagons(vehID);
			cCarrier.VehicleSell(vehID, false);
			DInfo("Train vehicle "+oldenginename+" removed, a new train will be built with "+numwagon+" wagons",0);
			cCarrier.ForceAddTrain(idx, numwagon);
			return;
		break;
		case AIVehicle.VT_ROAD:
			cCarrier.VehicleSell(vehID,false);
			new_vehID = cEngineLib.VehicleCreate(homedepot, betterEngine, road.CargoID);
		break;
		case AIVehicle.VT_AIR:
			cCarrier.VehicleSell(vehID,false);
			new_vehID = cEngineLib.VehicleCreate(homedepot, betterEngine, cCargo.GetPassengerCargo());
		break;
		case AIVehicle.VT_WATER:
			cCarrier.VehicleSell(vehID,false);
		return;
		break;
		}
	if (AIVehicle.IsValidVehicle(new_vehID))
		{
		local newenginename = cCarrier.GetVehicleName(new_vehID);
		AIGroup.MoveVehicle(road.GroupID,new_vehID);
		DInfo("Vehicle "+oldenginename+" replace with "+newenginename,0);
		cCarrier.StartVehicle(new_vehID); // Not sharing orders with previous vehicle as its orders are "goto depot" orders
		cCarrier.VehicleBuildOrders(road.GroupID,false); // need to build its orders
		}
}

function cCarrier::VehicleMaintenance_Orders(vehID)
// try to repair orders for a vehicle, else send it to depot
{
	local numorders=AIOrder.GetOrderCount(vehID);
	local name=cCarrier.GetVehicleName(vehID);
	for (local z=AIOrder.GetOrderCount(vehID)-1; z >=0; z--)
		{ // I check backward to prevent z index gone wrong if an order is remove
		if (!cCarrier.VehicleOrderIsValid(vehID, z))
			{
			DInfo("-> Vehicle "+name+" have invalid order, removing orders "+z,0);
			AIOrder.RemoveOrder(vehID, z);
			}
		}
	numorders=AIOrder.GetOrderCount(vehID);
	if (numorders < 2)
		{
		local groupid=AIVehicle.GetGroupID(vehID);
		DInfo("-> Vehicle "+name+" have too few orders, trying to correct it",0);
		cCarrier.VehicleBuildOrders(groupid,false);
		}
	numorders=AIOrder.GetOrderCount(vehID);
	if (numorders < 2)
		{
		DInfo("-> Vehicle "+name+" have too few orders, sending it to depot",0);
		cCarrier.VehicleSendToDepot(vehID, DepotAction.SELL);
		cCarrier.CheckOneVehicleOrGroup(vehID,true); // push all vehicles to get a check
		}
}

function cCarrier::IsTrainRouteBusy(uid = -1)
{
    local grp = null;
    local l = AIList();
    l.AddList(cCarrier.ToDepotList);
	foreach (veh, reason in l)
		{
        if (!AIVehicle.IsValidVehicle(veh)) { cCarrier.ToDepotList.RemoveItem(veh); continue; }
		if (uid != -1)  {
                        grp = cCarrier.VehicleFindRouteIndex(veh);
                        if (grp != uid) continue;
                        }
		local real = cCarrier.VehicleSendToDepot_GetReason(reason);
		if (real == DepotAction.LINEUPGRADE || real == DepotAction.SIGNALUPGRADE || real == DepotAction.BALANCE)	return true;
		}
	return false;
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
DInfo("Checking "+tlist.Count()+" vehicles",0);
local name="";
local tx, ty, price=0; // temp variable to use freely
INSTANCE.main.carrier.warTreasure=0;
local allroadveh=AIVehicleList();
allroadveh.Valuate(AIVehicle.GetState);
allroadveh.RemoveValue(AIVehicle.VS_STOPPED);
allroadveh.RemoveValue(AIVehicle.VS_CRASHED);
allroadveh.RemoveValue(AIVehicle.VS_INVALID);
allroadveh.RemoveValue(AIVehicle.VS_IN_DEPOT);

local checkallvehicle=(allroadveh.Count()==tlist.Count());
	if (checkallvehicle)
		{
		allroadveh.Valuate(AIVehicle.GetVehicleType);
		allroadveh.KeepValue(AIVehicle.VT_ROAD);
		}
local line_upgrade = !cCarrier.IsTrainRouteBusy();
foreach (vehicle, dummy in tlist)
	{
	cCarrier.VehicleMaintenance_Orders(vehicle);
	local vehtype=AIVehicle.GetVehicleType(vehicle);
	if (vehtype == AIVehicle.VT_ROAD)	INSTANCE.main.carrier.warTreasure+=AIVehicle.GetCurrentValue(vehicle);
	local topengine = cEngine.IsVehicleAtTop(vehicle);
	if (topengine != -1)	price=cEngine.GetPrice(topengine);
                    else	price=cEngine.GetPrice(AIVehicle.GetEngineType(vehicle));
	name = cCarrier.GetVehicleName(vehicle);
	if (vehtype == AIVehicle.VT_RAIL && line_upgrade)
		{ // check train can use better rails
		local nRT = cEngine.IsRailAtTop(vehicle);
		if (nRT == -1)	{ line_upgrade = false; continue; }
        local ret = RailFollower.TryUpgradeLine(vehicle);
        if (ret == 0)   { continue; }
        if (ret == 1)   { continue; }
		}
	tx=AIVehicle.GetAgeLeft(vehicle);
	if (tx < cCarrier.OldVehicle)
		{
		if (!cBanker.CanBuyThat(price+INSTANCE.main.carrier.vehicle_cash)) { continue; }
		DInfo("-> Vehicle "+name+" is getting old ("+tx+" days left), replacing it",0);
		cCarrier.VehicleSendToDepot(vehicle,DepotAction.REPLACE);
		cCarrier.CheckOneVehicleOrGroup(vehicle, true);
		INSTANCE.main.carrier.vehicle_cash += price;
		continue;
		}
	tx=AIVehicle.GetReliability(vehicle);
	if (tx < 30)
		{
		DInfo("-> Vehicle "+name+" reliability is low ("+tx+"%), sending it for servicing at depot",0);
		AIVehicle.SendVehicleToDepotForServicing(vehicle);
		local idx = cCarrier.VehicleFindRouteIndex(vehicle);
		//cBuilder.RouteIsDamage(idx);
		cCarrier.CheckOneVehicleOrGroup(vehicle, true);
		}
	local enginecheck = cEngine.IsRabbitSet(topengine);
	if (topengine != -1 && enginecheck)	topengine = -1; // stop upgrade
	if (topengine != -1)
		{
		// reserving money for the upgrade
		DInfo("Upgrade engine ! "+cBanker.CanBuyThat(INSTANCE.main.carrier.vehicle_cash+price)+" price: "+price,4);
		if (!cBanker.CanBuyThat(INSTANCE.main.carrier.vehicle_cash + price))	continue; // no way, we lack funds for it
		INSTANCE.main.carrier.vehicle_cash += price;
		DInfo("-> Vehicle "+name+" can be upgrade with a better version, sending it to depot",0);
		cEngine.RabbitSet(vehicle, topengine);
		cCarrier.VehicleSendToDepot(vehicle, DepotAction.UPGRADE);
		}
	local pause = cLooper();
	}
if (!checkallvehicle)
	{ // we need to estimate the fleet value
	local midvalue=0;
	if (allroadveh.Count() > 0)	midvalue=INSTANCE.main.carrier.warTreasure / allroadveh.Count();
	local fleet = allroadveh.Count()-6;
	if (fleet < 0)	fleet=0;
	INSTANCE.main.carrier.warTreasure = fleet * midvalue;
	DInfo("warTreasure estimate to "+INSTANCE.main.carrier.warTreasure+" fleet: "+fleet,2);
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
		local c = cLooper();
		cCarrier.VehicleSendToDepot(vehicle,DepotAction.CRAZY);
		if (moneytoget < 0)	break;
		moneytoget -= AIVehicle.GetCurrentValue(vehicle);
		}
}

function cCarrier::VehicleSell(veh, recordit)
// sell the vehicle and update route info
{
	DInfo("Selling Vehicle "+cCarrier.GetVehicleName(veh),0);
	local uid = cCarrier.VehicleFindRouteIndex(veh);
	local road = cRoute.Load(uid);
	local vehvalue = AIVehicle.GetCurrentValue(veh);
	local vehtype = AIVehicle.GetVehicleType(veh);
	INSTANCE.main.carrier.vehicle_cash -= vehvalue;
	if (INSTANCE.main.carrier.vehicle_cash < 0)	INSTANCE.main.carrier.vehicle_cash = 0;
	if (AIVehicle.GetVehicleType(veh) == AIVehicle.VT_RAIL)	cTrain.DeleteVehicle(veh);	// must be call before selling the vehicle
	cEngine.RabbitUnset(veh);
	AIVehicle.SellVehicle(veh);
	if (!road) return;
	road.RouteUpdateVehicle();
	if (recordit)	road.DateVehicleDelete=AIDate.GetCurrentDate();
}

function cCarrier::VehicleSendToDepotAndSell(uid)
// Send and sell all vehicles from route uid, used by checks.nut to repair road
{
	local road=cRoute.Load(uid);
	if (!road)	return;
	local vehlist = AIVehicleList_Group(road.GroupID);
	if (!vehlist.IsEmpty())	foreach (veh, _ in vehlist)	cCarrier.VehicleSendToDepot(veh, DepotAction.SELL);
}

function cCarrier::FreeDepotOfVehicle(depotID)
// this function remove any vehicle in depot
{
	if (!cStation.IsDepot(depotID))	{ return true; }
	DInfo("Selling all vehicles at depot "+depotID+" to remove it.",2);
	local vehlist = AIVehicleList();
	vehlist.Valuate(AIVehicle.GetLocation);
	vehlist.KeepValue(depotID);
	if (vehlist.IsEmpty())	{ return true; }
	foreach (veh, _ in vehlist)	{ cCarrier.VehicleSell(veh, false); local pause = cLooper(); }
	vehlist.Valuate(AIVehicle.IsValidVehicle);
	vehlist.RemoveValue(1);
	return (vehlist.IsEmpty());
}

function cCarrier::VehicleIsWaitingInDepot(onlydelete=false)
// this function checks our depots and sell vehicle in it
// if onlydelete set to true, we only remove vehicle, no upgrade/replace...
{
local tlist=AIVehicleList();
tlist.Valuate(AIVehicle.IsStoppedInDepot);
tlist.KeepValue(1);
DInfo("Checking vehicles in depots: "+tlist.Count(),2);
foreach (i, dummy in tlist)
	{
	local kk = cLooper();
	if (!AIVehicle.IsValidVehicle(i))	continue;
	local reason=DepotAction.SELL;
	local parameter=0;
	local uid=0;
	local name = cCarrier.GetVehicleName(i);
	cCarrier.VehicleOrdersReset(i);
	if (INSTANCE.main.carrier.ToDepotList.HasItem(i))
		{
		reason=INSTANCE.main.carrier.ToDepotList.GetValue(i);
		INSTANCE.main.carrier.ToDepotList.RemoveItem(i);
		parameter = cCarrier.VehicleSendToDepot_GetParam(reason);
		reason = cCarrier.VehicleSendToDepot_GetReason(reason);
		if (reason == DepotAction.ADDWAGON)
			{
			uid= cCarrier.VehicleFindRouteIndex(i);
			if (uid==null)	{
						DError("Cannot find the route uid for "+name,2);
						reason = DepotAction.SELL;
						}
			}
		if (reason == DepotAction.SIGNALUPGRADE)
			{
			local invalid = false;
			if (!AIStation.IsValidStation(parameter))	invalid = true;
				else	{
					uid = cCarrier.VehicleFindRouteIndex(i);
					if (uid == null)	invalid = true;
							else	{
								uid = cRoute.Load(uid);
								if (!uid)	invalid=true;
								}
					}
			if (invalid)	{
						reason = DepotAction.SELL;
						DError("Invalid stationID pass to SIGNALUPGRADE = "+parameter);
						}
			}
		}
	else	{
		if (AIVehicle.GetVehicleType(i)==AIVehicle.VT_RAIL)
			{
			DInfo("I don't know the reason why "+name+" is at depot, restarting it",1);
			cCarrier.TrainExitDepot(i);
			continue;
			}
		else	DInfo("I don't know the reason why "+name+" is at depot, selling it",1);
		}
	if (onlydelete && (AIVehicle.GetVehicleType(i) == AIVehicle.VT_AIR || AIVehicle.GetVehicleType(i) == AIVehicle.VT_ROAD))
		{ DInfo("We've been ask to delete all vehicles waiting in depot",1); reason=DepotAction.CRAZY; }
	switch (reason)
		{
		case	DepotAction.SELL:
			DInfo("Vehicle "+name+" is waiting in depot to be sold",1);
			cCarrier.VehicleSell(i,true);
		break;
		case	DepotAction.UPGRADE:
			DInfo("Vehicle "+name+" is waiting in depot to be upgrade",1);
			cCarrier.VehicleUpgradeEngine(i);
		break;
		case	DepotAction.REPLACE:
			DInfo("Vehicle "+name+" is waiting in depot to be replace",1);
			cCarrier.VehicleUpgradeEngine(i);
		break;
		case	DepotAction.CRAZY:
			cCarrier.VehicleSell(i,false);
		break;
		case	DepotAction.REMOVEROUTE:
			cCarrier.VehicleSell(i, false);
		break;
		case	DepotAction.ADDWAGON:
			DInfo("Vehicle "+name+" is waiting at depot to get "+parameter+" wagons",1);
			cCarrier.AddWagon(uid, parameter);
		break;
		case	DepotAction.LINEUPGRADE:
			cCarrier.ToDepotList.AddItem(i, DepotAction.LINEUPGRADE);
			local all_vehicle = AIList();
			all_vehicle.AddList(cCarrier.ToDepotList);
			local good_vehicle = AIList();
			foreach (veh, reason in all_vehicle)
				{
				local real_reason = cCarrier.VehicleSendToDepot_GetReason(reason);
				if (real_reason == DepotAction.LINEUPGRADE)	good_vehicle.AddItem(veh, AIVehicle.GetState(veh));
				}
			local runnercount = good_vehicle.Count();
			good_vehicle.KeepValue(AIVehicle.VS_IN_DEPOT);
			runnercount -= good_vehicle.Count();
			if (runnercount == 0)	{ RailFollower.TryUpgradeLine(i); }
                            else	{ DInfo("Waiting "+runnercount+" more trains to upgrade line.",1); }
		break;
		case	DepotAction.WAITING:
			DInfo("Vehicle "+name+" is waiting at depot for "+parameter+" times",1);
			parameter--;
			if (parameter <= 0)
				{
				DInfo("Vehicle "+name+" has wait enough, releasing it to the wild",1);
				cCarrier.StartVehicle(i);
				}
			else	INSTANCE.main.carrier.ToDepotList.AddItem(i, DepotAction.WAITING + parameter);
		break;
		case	DepotAction.SIGNALUPGRADE:
			local vehlist = AIVehicleList_Station(parameter);
			vehlist.Valuate(AIVehicle.GetState);
			vehlist.RemoveValue(AIVehicle.VS_IN_DEPOT);
			if (vehlist.IsEmpty())	{
							// don't care result, it's just to let the station build its signals
							cBuilder.RailStationGrow(uid.TargetStation.s_ID, uid.Target_RailEntry, false);
							// but we must add a non taker train, and do it to the target station to prevent station growing while making that
							// as trains are currently stopped waiting for the signal to be made, it will cause hell if station try to grow and
							// so cannot remove depot
							}
						else	{
							DInfo("Waiting "+vehlist.Count()+" more vehicles to stop at depot",1);
							INSTANCE.main.carrier.ToDepotList.AddItem(i, DepotAction.WAITING+50); // making it wait to not get stuck forever
							}
		break;
		}
	}
}

function cCarrier::TrainExitDepot(vehID)
// release a train that was in depot, setting its order, starting it and moving it to the best station
{
	if (!AIVehicle.GetVehicleType(vehID) == AIVehicle.VT_RAIL || !AIVehicle.GetState(vehID) == AIVehicle.VS_IN_DEPOT) return;
	local loaded=cCarrier.VehicleGetCargoLoad(vehID);
	cCarrier.TrainSetOrders(vehID);
	if (loaded > 0)	AIOrder.SkipToOrder(vehID, 1);
			else	AIOrder.SkipToOrder(vehID, 0);
	cCarrier.StartVehicle(vehID);
	if (cCarrier.ToDepotList.HasItem(vehID))	cCarrier.ToDepotList.RemoveItem(vehID);
}

function cCarrier::StartVehicle(vehID)
// This try to make sure we will start the vehicle and not stop it because of the weak cCarrier.StartVehicle function
{
	if (!AIVehicle.IsValidVehicle(vehID))	return false;
	local	wait=false;
	while (AIVehicle.GetState(vehID) == AIVehicle.VS_BROKEN)	{ wait=true; AIController.Sleep(15); }
	if (wait)	AIController.Sleep(40); // wait a few it just restart
	local state = AIVehicle.GetState(vehID);
	if (state == AIVehicle.VS_STOPPED || state == AIVehicle.VS_IN_DEPOT)
		{
		AIVehicle.StartStopVehicle(vehID);
		DInfo("Starting "+cCarrier.GetVehicleName(vehID)+"...",0);
		return true;
		}
	return false; // crash/invalid...
}

function cCarrier::StopVehicle(vehID)
// Try to stop a vehicle that is running, and not restart it...
{
	if (AIVehicle.GetState(vehID) == AIVehicle.VS_RUNNING && AIVehicle.StartStopVehicle(vehID))
		{
		DInfo("Stopping "+cCarrier.GetVehicleName(vehID)+"...",0);
		return true;
		}
	return false;
}
