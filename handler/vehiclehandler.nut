// main class is in vehiculebuilder

function cCarrier::VehicleCountAtStation(stationID)
// return number of vehicle waiting at the station
{
local vehlist=root.carrier.VehicleListBusyAtStation(stationID);
return vehlist.Count();
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

function cCarrier::VehicleListBusyAtStation(stationID)
// return the list of vehicles that are waiting at the station
{
local vehicles=AIVehicleList_Station(stationID);
local tilelist=cTileTools.GetTilesAroundPlace(AIStation.GetLocation(stationID)); // grab tiles around the station
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

function cCarrier::VehicleOrderSkipCurrent(veh)
// Skip the current order and go to the next one
{
local current=AIOrder.ResolveOrderPosition(veh, AIOrder.ORDER_CURRENT);
local total=AIOrder.GetOrderCount(veh);
if (current+1 == total)	current=0;
	else		current++;
AIOrder.SkipToOrder(veh, current);
}

function cCarrier::VehicleIsLoading(takeone, taketwo)
// compare a list of vehicle (takeone & taketwo) return true if any vehicle is loading
{
if (takeone.Count() != taketwo.Count()) return false; // must be equal list
foreach (x, dummy1 in takeone)
	{
	local before=0;
	local after=0;
	if (x in taketwo)
		{
		before=dummy1;
		after=taketwo.GetValue(x);
		if (before == after) continue;
		if (before < after)	return true;
			else		return false;
		}
	}
return false;
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

function cCarrier::AirNetworkOrdersHandler()
// Create orders for aircrafts that run the air network
{
local road=null;
local isfirst=true;
local rabbit=null;
root.chemin.airnet_count=0;
for (local j=0; j < root.chemin.RListGetSize(); j++)
	{
	road=root.chemin.RListGetItem(j);
	if (road.ROUTE.status!=999) continue; // only check 999 status, it's the "i'm part of network" status
	//if (road.ROUTE.kind == 1000) continue;
	local airlist=AIVehicleList_Group(road.ROUTE.groupe_id);
	if (airlist.IsEmpty()) continue; // no aircrafts on that group
	local numorders=0;
	foreach (vehicle, dummy in airlist)
		{
		if (isfirst)
			{
			rabbit=vehicle;
			isfirst=false;
			root.chemin.airnet_count++;
			numorders=AIOrder.GetOrderCount(rabbit);
			if (numorders != root.chemin.virtual_air.len())
				{
				for (local i=0; i < root.chemin.virtual_air.len(); i++)
				//foreach (town, location in root.chemin.virtual_air)
					{
				local location=root.chemin.virtual_air[i];
PutSign(location,"NetLoc");
					if (!AIOrder.AppendOrder(rabbit, location, AIOrder.AIOF_FULL_LOAD_ANY))
						{ DError("Aircraft network order refuse",2); }
					}
				if (numorders > 0)
					{
					// now remove previous rabbit orders, should not make the aircrafts gone too crazy
					for (local i=0; i < numorders; i++)
						{ AIOrder.RemoveOrder(rabbit, AIOrder.ResolveOrderPosition(rabbit,0)); }
					}
				}
			} // isfirst
		else	{
			AIOrder.ShareOrders(vehicle,rabbit);
			root.chemin.airnet_count++;
			}
		}
	}
DInfo(root.chemin.airnet_count+" aircrafts are on the network",1);
root.NeedDelay(50);
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
if (vehlist.IsEmpty()) return false;
local veh=vehlist.Begin();
local idx=root.carrier.VehicleFindRouteIndex(veh);
local road=root.chemin.RListGetItem(idx);
local oneorder=null;
local twoorder=null;
local srcStation=root.chemin.GListGetItem(road.ROUTE.src_station);
local dstStation=root.chemin.GListGetItem(road.ROUTE.dst_station);
local srcplace=null;
local dstplace=null;
// setup everything before removing orders, as it could be dangerous for the poor vehicle to stay without orders a long time
switch (road.ROUTE.kind)
	{
	case AIVehicle.VT_ROAD:
		oneorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE + AIOrder.AIOF_FULL_LOAD_ANY;
		if (road.ROUTE.dst_istown)
			{ twoorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE + AIOrder.AIOF_FULL_LOAD_ANY; }
		else	{ twoorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE; }
		srcplace= srcStation.STATION.e_loc;
		dstplace= dstStation.STATION.e_loc;
	break;
	case AIVehicle.VT_RAIL:
		oneorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE + AIOrder.AIOF_FULL_LOAD_ANY;
		twoorder=AIOrder.AIOF_NON_STOP_INTERMEDIATE;
		if (srcStation.STATION.haveEntry)	{ srcplace= srcStation.STATION.e_loc; }
				else			{ srcplace= srcStation.STATION.s_loc; }
		if (dstStation.STATION.haveEntry)	{ dstplace= dstStation.STATION.e_loc; }
				else			{ dstplace= dstStation.STATION.s_loc; }
	break;
	case AIVehicle.VT_AIR:
		oneorder=AIOrder.AIOF_FULL_LOAD_ANY;
		twoorder=AIOrder.AIOF_FULL_LOAD_ANY;
		srcplace=srcStation.STATION.e_loc;
		dstplace=dstStation.STATION.e_loc;
	break;
	case AIVehicle.VT_WATER:
	break;
	case 1000: // it's the air network
		root.carrier.AirNetworkOrdersHandler();
		return true;
	break;
	}
if (srcplace == null) srcplace=-1;
if (dstplace == null) dstplace=-1;
DInfo("Setting orders for route "+idx,2);
root.carrier.VehicleOrdersReset(veh);
if (!AIOrder.AppendOrder(veh, srcplace, oneorder))
	{ DError("First order refuse",2); }
if (!AIOrder.AppendOrder(veh, dstplace, twoorder))
	{ DError("Second order refuse",2); }
root.carrier.AirNetworkOrdersHandler(); // re-add network aircraft to route
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

function cCarrier::VehicleHandleTrafficAtStation(stationID, reroute)
// if reroute this function stop all vehicles that use stationID to goto stationID
// if !rereroute this function restore vehicles orders
{
local road=null;
local vehlist=null;
local veh=null;
local orderpos=null;
local group=null;
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	road=root.chemin.RListGetItem(i);
	orderpos=-1;
	local srcstation=root.builder.GetStationID(i,true);
	if (srcstation == stationID)	orderpos=0;
	local dststation=root.builder.GetStationID(i,false);
	if (dststation == stationID)	orderpos=1;
	group=road.ROUTE.groupe_id;
	if (orderpos > -1)
		{ // that route use that station
		if (reroute)
			{
			DInfo("Re-routing traffic on route "+i,0);
			vehlist=AIVehicleList_Group(group);
			veh=vehlist.Begin();
			local orderindex=VehicleFindDestinationInOrders(veh, stationID);
			if (!AIOrder.RemoveOrder(veh, AIOrder.ResolveOrderPosition(veh, orderindex)))
				{ DError("Fail to remove order for vehicle "+veh,2); }
			}
		else	{ root.carrier.VehicleBuildOrders(group); }
		}
	}
}

function cCarrier::VehicleSendToDepot(veh,flag)
// send a vehicle to depot, set its flag for the reason
{
local reason="";
if (cCarrier.VehicleIsFlag(veh))
	{
	return false;
	}
if (!cCarrier.VehicleExists(veh))
	{
	DInfo("That vehicle doesn't exist !",1);
	return false;
	}

switch (flag)
	{
	case DEPOT_SELL:
	reason="to be sold";
	break;
	case DEPOT_REPLACE:
	reason="to be replace";
	break;
	case DEPOT_STOP:
	reason="to stop & wait futher orders";
	break;
	case DEPOT_SAVE:
	reason="to be save & restore";
	break;
	case DEPOT_UPGRADE:
	reason="to be upgrade";
	break;
	case DEPOT_WAGON:
	reason="to add wagons";
	break;
	default:
	reason="for unknow reason #"+flag;
	break;
	}
local understood=false;
understood=AIVehicle.SendVehicleToDepot(veh);
if (!understood) {
	DInfo(AIVehicle.GetName(veh)+" refuse to go to depot",1);
	return false;
	}
else	DInfo(AIVehicle.GetName(veh)+" is going to depot "+reason,0);

if (!root.carrier.VehicleSetFlag(veh,flag))
	{ DError("Fail to flag the vehicle !",2); }
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

function cCarrier::VehicleToDepotAndSell(veh)
// send a vehicle to sell it
{
cCarrier.VehicleSendToDepot(veh,cCarrier.DEPOT_SELL);
}

function cCarrier::VehicleFindRouteIndex(veh)
// return index of the route the veh vehicle is running on
{
local group=AIVehicle.GetGroupID(veh);
local idx=-1;
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	local road=root.chemin.RListGetItem(i);
	if (road.ROUTE.groupe_id == group)	{ idx=i; break; }
	}
return idx;
}

function cCarrier::VehicleUpgradeEngineAndWagons(veh)
// we will try to upgrade engine and wagons for vehicle veh
{
local idx=root.carrier.VehicleFindRouteIndex(veh);
if (idx < 0)
	{
	DInfo("This vehicle is not use by any route !!!",1);
	root.carrier.VehicleSell(veh);
	return false;
	}
local road=root.chemin.RListGetItem(idx);
local group = AIVehicle.GetGroupID(veh);
local engine = null;
local wagon = null;
local numwagon=AIVehicle.GetNumWagons(veh);
local railtype = root.chemin.RouteGetRailType(idx);
local newveh=null;
root.chemin.buildmode=true; // set to find the best wagon/engine
local homedepot=root.builder.GetDepotID(idx,true);
DInfo("Depot is at "+homedepot,2);
PutSign(homedepot,"Depot");
local money=0;
//if (railtype > 20) railtype-=20;
switch (AIVehicle.GetVehicleType(veh))
	{
	case AIVehicle.VT_RAIL:
		AIRail.SetCurrentRailType(railtype);
		engine = root.carrier.ChooseTrainEngine();
		wagon = root.carrier.ChooseWagon(road.ROUTE.cargo_id);
		newveh=AIVehicle.BuildVehicle(homedepot,engine);
		AIVehicle.RefitVehicle(newveh, road.ROUTE.cargo_id);
		local first=null;
		first=AIVehicle.BuildVehicle(homedepot, wagon); 
		for (local i=1; i < numwagon; i++)
			{ AIVehicle.BuildVehicle(homedepot, wagon); }
		AIVehicle.MoveWagonChain(first, 0, newveh, AIVehicle.GetNumWagons(veh) - 1);
	break;
	case AIVehicle.VT_ROAD:
		engine = root.carrier.ChooseRoadVeh(road.ROUTE.cargo_id);
		newveh=AIVehicle.BuildVehicle(homedepot,engine);
		AIVehicle.RefitVehicle(newveh, road.ROUTE.cargo_id);
	break;
	case AIVehicle.VT_AIR:
		local modele=AircraftType.EFFICIENT;
		if (road.ROUTE.kind == 1000)	modele=AircraftType.BEST;
		if (!road.ROUTE.src_entry)	modele=AircraftType.CHOPPER;
		engine = root.carrier.ChooseAircraft(road.ROUTE.cargo_id,modele);
		root.bank.RaiseFundsBy(AIEngine.GetPrice(engine));
		newveh = AIVehicle.BuildVehicle(homedepot,engine);
	break;
	case AIVehicle.VT_WATER:
	return;
	break;
	}
AIOrder.ShareOrders(newveh, veh); // TODO: always fail, look why
AIGroup.MoveVehicle(road.ROUTE.groupe_id,newveh);
local oldenginename=AIEngine.GetName(AIVehicle.GetEngineType(veh));
local newenginename=AIVehicle.GetName(newveh)+"("+AIEngine.GetName(AIVehicle.GetEngineType(newveh))+")";
if (AIVehicle.IsValidVehicle(newveh))
	{
	AIVehicle.StartStopVehicle(newveh);
	AIVehicle.SellWagonChain(veh,0);
	AIVehicle.SellVehicle(veh);
	DInfo("Vehicle "+oldenginename+" replace with "+newenginename,0);
	root.carrier.vehnextprice=0;
	}
else	{
	root.carrier.VehicleRemoveFlag(veh);
	AIVehicle.StartStopVehicle(veh);
	}
}

function cCarrier::VehicleIsTop(veh)
// return engine modele if the vehicle can be upgrade
{
root.chemin.buildmode=true;
local idx=root.carrier.VehicleFindRouteIndex(veh);
if (idx < 0) return -1; // tell we're at top already for unknow vehicle
local road=root.chemin.RListGetItem(idx);
local top=null;
local cargo=road.ROUTE.cargo_id;
switch (AIVehicle.GetVehicleType(veh))
	{
	case AIVehicle.VT_ROAD:
		top = root.carrier.ChooseRoadVeh(cargo);
	break;
	case AIVehicle.VT_RAIL:
		top = root.carrier.ChooseRailVeh(idx);
	break;
	case AIVehicle.VT_WATER:
	return;
	break;
	case AIVehicle.VT_AIR:
		local modele=AircraftType.EFFICIENT;
		if (road.ROUTE.kind == 1000)	modele=AircraftType.BEST;
		if (!road.ROUTE.src_entry)	modele=AircraftType.CHOPPER;
		top = root.carrier.ChooseAircraft(road.ROUTE.cargo_id,modele);
	break;
	}
local ourengine=AIVehicle.GetEngineType(veh);
if (ourengine == top)	return -1;
		else	return top;	
}

function cCarrier::VehicleOrderIsValid(vehicle,orderpos)
// Really check if a vehicle order is valid
{
local ordercount=AIOrder.GetOrderCount(vehicle);
if (ordercount == 0)	return true;
local ordercheck=AIOrder.ResolveOrderPosition(vehicle, orderpos);
if (!AIOrder.IsValidVehicleOrder(vehicle, ordercheck)) return false;
local tiletarget=AIOrder.GetOrderDestination(vehicle, ordercheck);
if (!AICompany.IsMine(AITile.GetOwner(tiletarget)))	return false;
local vehicleType=AIVehicle.GetVehicleType(vehicle);
if (!AITile.IsStationTile(tiletarget)) return false;
local stationID=AIStation.GetStationID(tiletarget);
switch (vehicleType)
	{
	case	AIVehicle.VT_RAIL:
		if (!AIStation.HasStationType(stationID,AIStation.STATION_TRAIN)) return false;
	break;
	case	AIVehicle.VT_WATER:
		if (!AIStation.HasStationType(stationID,AIStation.STATION_DOCK)) return false;
	break;
	case	AIVehicle.VT_AIR:
		if (!AIStation.HasStationType(stationID,AIStation.STATION_AIRPORT)) return false;
	break;
	case	AIVehicle.VT_ROAD:
		local buscheck=true;
		local truckcheck=true;
		truckcheck=AIStation.HasStationType(stationID,AIStation.STATION_TRUCK_STOP);
		buscheck=AIStation.HasStationType(stationID,AIStation.STATION_BUS_STOP);
		if (!truckcheck && !buscheck) return false;
	break;
	}
return true;
}

function cCarrier::VehicleMaintenance()
{
if (root.chemin.under_upgrade)
	{
	root.bank.busyRoute=true;
	return;
	}
local tlist=AIVehicleList();
DInfo("Checking "+tlist.Count()+" vehicles",0);
local age=0;
local name="";
local price=0;
foreach (vehicle, dummy in tlist)
	{
	if (AIVehicle.IsStoppedInDepot(vehicle)) continue;
	age=AIVehicle.GetAgeLeft(vehicle);
	local topengine=root.carrier.VehicleIsTop(vehicle);

	if (topengine == -1)	price=AIEngine.GetPrice(topengine);
		else	 price=AIEngine.GetPrice(AIVehicle.GetEngineType(vehicle));
	name=AIVehicle.GetName(vehicle)+"("+AIEngine.GetName(AIVehicle.GetEngineType(vehicle))+")";
	if (age < 24)
		{
		if (!root.bank.CanBuyThat(price+root.carrier.vehnextprice)) continue;
		root.carrier.vehnextprice+=price;
		DInfo("Vehicle "+name+" is getting old ("+AIVehicle.GetAge(vehicle)+" months), replacing it",0);
		root.carrier.VehicleSendToDepot(vehicle,DEPOT_UPGRADE);
		root.bank.busyRoute=true;
		continue;
		}
	age=AIVehicle.GetReliability(vehicle);
	if (age < 30)
		{
		if (!root.bank.CanBuyThat(price+root.carrier.vehnextprice)) continue;
		root.carrier.vehnextprice+=price;
		DInfo("Vehicle "+name+" reliability is low ("+age+"%), replacing it",0);
		root.carrier.VehicleSendToDepot(vehicle,DEPOT_UPGRADE);
		root.bank.busyRoute=true;
		continue;
		}

	if (topengine != -1)
		{

		if (!root.bank.CanBuyThat((price*0.1)+price+root.carrier.vehnextprice)) continue;
		// add a 10% to price to avoid try changing an engine and running low on money because of fluctuating money
		root.carrier.vehnextprice+=price;
		DInfo("Vehicle "+name+" can be update with a better version, sending it to depot",0);
		root.carrier.VehicleSendToDepot(vehicle,DEPOT_UPGRADE);
		root.bank.busyRoute=true;
		continue;
		}
	age=AIOrder.GetOrderCount(vehicle);
	if (age < 2)
		{
		local groupid=AIVehicle.GetGroupID(vehicle);
		DInfo("Vehicle "+name+" have too few orders, trying to correct it",0);
		root.carrier.VehicleBuildOrders(groupid);
		}
	age=AIOrder.GetOrderCount(vehicle);
	if (age < 2)
		{
		DInfo("Vehicle "+name+" have too few orders, sending it to depot",0);
		root.carrier.VehicleSendToDepot(vehicle,DEPOT_SELL);
		}
	for (local z=AIOrder.GetOrderCount(vehicle)-1; z >=0; z--)
		{ // I check backward to prevent z index gone wrong if an order is remove
		if (!root.carrier.VehicleOrderIsValid(vehicle, z))
			{
			DInfo("Vehicle "+name+" have invalid order, removing order "+z,0);
			AIOrder.RemoveOrder(vehicle, z);
			}
		}
	}
local dlist=AIVehicleList();
dlist.Valuate(AIVehicle.IsStoppedInDepot);
dlist.KeepValue(1);
if (!dlist.IsEmpty())	root.carrier.VehicleIsWaitingInDepot();
}

function cCarrier::VehicleSell(veh)
// sell the vehicle and update route info
{
local idx=root.carrier.VehicleFindRouteIndex(veh);
DInfo("Sold "+AIEngine.GetName(AIVehicle.GetEngineType(veh)),0);
//	if (AIVehicle.GetVehicleType(i) == AIVehicle.VT_RAIL)
AIVehicle.SellWagonChain(veh, 0);
AIVehicle.SellVehicle(veh);
if (idx >= 0)
	{ root.carrier.RouteAndStationVehicleCounter(idx,false); } // remove 1 from vehicle counters
}

function cCarrier::VehicleIsWaitingInDepot()
// this function checks our depot and see if we have a vehcile in it
// and take actions on it if need
{
local tlist=AIVehicleList();
DInfo("Checking vehicles in depots",1);
tlist.Valuate(AIVehicle.IsStoppedInDepot);
tlist.KeepValue(1);
local flag=-1;
foreach (i, dummy in tlist)
	{
	flag=cCarrier.VehicleGetFlag(i); // safe, return -1 on failure
	DInfo("Flag set = "+flag,2);
	//if (flag == -1) flag=DEPOT_RESTART; // set it for a restart
	if (flag == DEPOT_REPLACE) flag=DEPOT_UPGRADE; // never just replace, try upgrade while doing it
	
	switch (flag)
		{
		case DEPOT_SELL:
			root.carrier.VehicleSell(i);
		break;
		case DEPOT_REPLACE:
		break;
		case DEPOT_STOP:
			DInfo("Vehicle "+AIVehicle.GetName(i)+" is waiting new orders",0);
		break;
		case DEPOT_SAVE:
			DInfo("Vehicle "+AIVehicle.GetName(i)+" is waiting for a save & restore service",0);
			root.carrier.SaveVehicleAndDelete(i);
		break;
		case DEPOT_UPGRADE:
			DInfo("Vehicle "+AIVehicle.GetName(i)+" need upgrade",0);
			root.carrier.VehicleUpgradeEngineAndWagons(i);
		break;
		case DEPOT_WAGON:
		break;
		case DEPOT_RESTART:
			AIVehicle.StartStopVehicle(i);
			DInfo("Vehicle "+AIVehicle.GetName(i)+" is waiting for nothing, restarting it",0);
		break;
		default:
			DInfo("Vehicle "+AIVehicle.GetName(i)+" is in depot for unknow reason #"+flag+", selling it",0);
			root.carrier.VehicleSell(i);
		break;
		}
	}
}

