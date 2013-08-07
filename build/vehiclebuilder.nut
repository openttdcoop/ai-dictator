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

// generic vehicle building functions

function cCarrier::VehicleGetCargoType(veh)
// return cargo type the vehicle is handling
{
local cargotype=AICargoList();
foreach (cargo, dummy in cargotype)
	{
	if (AIVehicle.GetCapacity(veh, cargo) > 0)	return cargo;
	}
}

function cCarrier::VehicleGetProfit(veh)
// add a vehicle to do_profit list, calc its profit and also return it
{
local profit=AIVehicle.GetProfitThisYear(veh);
local oldprofit=0;
if (INSTANCE.main.carrier.do_profit.HasItem(veh))	oldprofit=INSTANCE.main.carrier.do_profit.GetValue(veh);
                                            else	INSTANCE.main.carrier.do_profit.AddItem(veh,0);
if (profit > oldprofit)	oldprofit=profit - oldprofit;
			else	oldprofit=oldprofit+profit;
INSTANCE.main.carrier.do_profit.SetValue(veh, oldprofit);
return oldprofit;
}

function cCarrier::CanAddNewVehicle(roadidx, start, max_allow)
// check if we can add another vehicle at the start/end station of that route
{
	local chem=cRoute.Load(roadidx);
	if (!chem) return 0;
	chem.RouteUpdateVehicle();
	local thatstation=null;
	//local thatentry=null;
	local otherstation=null;
	if (start)	{ thatstation=chem.SourceStation; otherstation=chem.TargetStation; }
		else	{ thatstation=chem.TargetStation; otherstation=chem.SourceStation; }
	local divisor=0; // hihi what a bad default value to start with
	local sellvalid=( (AIDate.GetCurrentDate() - chem.DateVehicleDelete) > 60);
	// prevent buy a new vehicle if we sell one less than 60 days before (this isn't affect by replacing/upgrading vehicle)
	if (!sellvalid)	{ max_allow=0; DInfo("Route sold a vehicle not a long time ago",1); return 0; }
	local virtualized=cStation.IsStationVirtual(thatstation.s_ID);
	local othervirtual=cStation.IsStationVirtual(otherstation.s_ID);
	local airportmode="(classic)";
	local shared=false;
	if (thatstation.s_Owner.Count() > 1)	{ shared=true; airportmode="(shared)"; }
	if (virtualized)	airportmode="(network)";
	local airname=thatstation.s_Name+"-> ";
	switch (chem.VehicleType)
		{
		case AIVehicle.VT_ROAD:
			DInfo("Road station "+thatstation.s_Name+" limit "+thatstation.s_VehicleCount+"/"+thatstation.s_VehicleMax,1);
			if (thatstation.CanUpgradeStation())
				{ // can still upgrade
				if (chem.VehicleCount+max_allow > INSTANCE.main.carrier.road_max_onroute)	max_allow=(INSTANCE.main.carrier.road_max_onroute-chem.VehicleCount);
				// limit by number of vehicle per route
				if (!INSTANCE.use_road)	max_allow=0;
				// limit by vehicle disable (this can happen if we reach max vehicle game settings too
//			if (thatstation.vehicle_count+1 > thatstation.size)
				if ( (thatstation.s_VehicleCount+max_allow) > thatstation.s_VehicleMax)
					{ // we must upgrade
					INSTANCE.main.builder.RoadStationNeedUpgrade(roadidx, start);
					local fake=thatstation.CanUpgradeStation(); // to see if upgrade success
					}
				if (thatstation.s_VehicleCount+max_allow > thatstation.s_VehicleMax)	max_allow=thatstation.s_VehicleMax-thatstation.s_VehicleCount;
				// limit by the max the station could handle
				}
			else	{ // max size already
				if (thatstation.s_VehicleCount+max_allow > thatstation.s_VehicleMax)	max_allow=INSTANCE.main.carrier.road_max_onroute-thatstation.s_VehicleCount;
				// limit by the max the station could handle
				if (chem.VehicleCount+max_allow > INSTANCE.main.carrier.road_max_onroute)	max_allow=INSTANCE.main.carrier.road_max_onroute-chem.VehicleCount;
				// limit by number of vehicle per route
				}
		break;
		case AIVehicle.VT_RAIL:
			if (thatstation.CanUpgradeStation())
				{
				if (!INSTANCE.use_train)	max_allow = 0;
				if (thatstation.s_VehicleCount+max_allow > thatstation.s_VehicleMax)	max_allow=thatstation.s_VehicleMax-thatstation.s_VehicleCount;
				// don't try upgrade if we cannot add a new train
				if (!INSTANCE.main.builder.TrainStationNeedUpgrade(roadidx, start))	max_allow=0; // if we fail to upgrade...
				}
			else	{
				if (!INSTANCE.use_train) max_allow=0;
				if (thatstation.s_VehicleCount+max_allow > thatstation.s_VehicleMax)	max_allow=thatstation.s_VehicleMax-thatstation.s_VehicleCount;
				}
		break;
		case AIVehicle.VT_WATER:
			if (!INSTANCE.use_boat)	max_allow=0;
			if (thatstation.s_VehicleCount+max_allow > thatstation.s_VehicleMax)	max_allow=thatstation.s_VehicleMax-thatstation.s_VehicleCount;
		break;
		case RouteType.AIRNET:
		case RouteType.AIRNETMAIL:
			thatstation.CheckAirportLimits(); // force recheck limits
			if (thatstation.CanUpgradeStation())
				{
				INSTANCE.main.builder.AirportNeedUpgrade(thatstation.s_ID);
				return 0;
				// get out after an upgrade, station could have change place...
				}
			DInfo(airname+"Limit for that route (network): "+chem.VehicleCount+"/"+INSTANCE.main.carrier.airnet_max*cCarrier.VirtualAirRoute.len(),1);
			DInfo(airname+"Limit for that airport (network): "+chem.VehicleCount+"/"+thatstation.s_VehicleMax,1);
			if (chem.VehicleCount+max_allow > INSTANCE.main.carrier.airnet_max*cCarrier.VirtualAirRoute.len()) max_allow=(INSTANCE.main.carrier.airnet_max*cCarrier.VirtualAirRoute.len()) - chem.VehicleCount;
			if (chem.VehicleCount+max_allow > thatstation.s_VehicleMax)	max_allow=thatstation.s_VehicleMax-chem.VehicleCount;
		break;
		case RouteType.CHOPPER:
			DInfo(airname+"Limit for that route (choppers): "+chem.VehicleCount+"/4",1);
			DInfo(airname+"Limit for that airport "+airportmode+": "+thatstation.s_VehicleMax,1);
			if (chem.VehicleCount+max_allow > 4)	max_allow=4-chem.VehicleCount;
		break;
		case RouteType.AIR: // Airport upgrade is not related to number of aircrafts using them
		case RouteType.AIRMAIL:
		case RouteType.SMALLAIR:
		case RouteType.SMALLMAIL:
			thatstation.CheckAirportLimits(); // force recheck limits
			if (thatstation.CanUpgradeStation())
				{
				INSTANCE.main.builder.AirportNeedUpgrade(thatstation.s_ID);
				max_allow=0;
				}
			local limitmax=INSTANCE.main.carrier.air_max;
			if (shared)
				{
				if (thatstation.s_Owner.Count()>0)	limitmax=limitmax / thatstation.s_Owner.Count();
				if (limitmax < 2)	limitmax=2;
				}
			if (virtualized)	limitmax=4; // only 4 aircrafts when the airport is also in network
			local dualnetwork=false;
			local routemod="(classic)";
			if (virtualized && othervirtual)
				{
				limitmax=2;	// no aircrafts at all on that route if both airport are in the network
				dualnetwork=true;
				routemod="(dual network)";
				}
			DInfo(airname+"Limit for that route "+routemod+": "+chem.VehicleCount+"/"+limitmax,1);
			DInfo(airname+"Limit for that airport "+airportmode+": "+thatstation.s_VehicleCount+"/"+thatstation.s_VehicleMax,1);
			if (!INSTANCE.use_air)	max_allow=0;
			if (chem.VehicleCount+max_allow > limitmax)	max_allow=limitmax - chem.VehicleCount;
			// limit by route limit
			if (thatstation.s_VehicleCount+max_allow > thatstation.s_VehicleMax)	max_allow=thatstation.s_VehicleMax-thatstation.s_VehicleCount;
			// limit by airport capacity
		break;
		}
	if (max_allow < 0)	max_allow=0;
	return max_allow;
}

function cCarrier::BuildAndStartVehicle(routeid)
// Create a new vehicle on route
{
	local road=cRoute.Load(routeid);
	if (!road)	return false;
	local res=false;
	switch (road.VehicleType)
		{
		case AIVehicle.VT_ROAD:
			res=INSTANCE.main.carrier.CreateRoadVehicle(routeid);
		break;
		case AIVehicle.VT_RAIL:
			res=INSTANCE.main.carrier.CreateRailVehicle(routeid);
		break;
		case AIVehicle.VT_WATER:
		break;
		case RouteType.AIRNET:
		case RouteType.AIRNETMAIL:
		case RouteType.CHOPPER:
		case RouteType.AIR:
		case RouteType.AIRMAIL:
		case RouteType.SMALLAIR:
		case RouteType.SMALLMAIL:
			res=INSTANCE.main.carrier.CreateAirVehicle(routeid);
		break;
		}
	if (res)	road.RouteUpdateVehicle();
	return res;
}

function cCarrier::GetVehicle(routeidx)
// return the vehicle we will pickup if we build a vehicle for that route
{
	local road=cRoute.Load(routeidx);
	if (!road)	return null;
	switch (road.VehicleType)
		{
		case	RouteType.RAIL:
			return INSTANCE.main.carrier.ChooseRailCouple(road.CargoID, road.RailType, road.GetDepot(routeidx));
		break;
		case	RouteType.WATER:
			return null;
		break;
		case	RouteType.ROAD:
			return INSTANCE.main.carrier.GetRoadVehicle(routeidx);
		break;
		default: // to catch all AIR type
			return INSTANCE.main.carrier.GetAirVehicle(routeidx);
		break;
		}
}

function cCarrier::GetEngineEfficiency(engine, cargoID)
// engine = enginetype to check
// return an index, the smallest = the better of ratio cargo/runningcost+cost of engine
{
local price=cEngine.GetPrice(engine, cargoID);
local capacity=cEngine.GetCapacity(engine, cargoID);
local lifetime=AIEngine.GetMaxAge(engine);
local runningcost=AIEngine.GetRunningCost(engine);
local speed=AIEngine.GetMaxSpeed(engine);
if (capacity==0)	return 9999999;
if (price<=0)	return 9999999;
local eff=(100000+ (price+(lifetime*runningcost))) / ((capacity*0.9)+speed).tointeger();
return eff;
}

function cCarrier::GetEngineRawEfficiency(engine, cargoID, fast)
// only consider the raw capacity/speed ratio
// engine = enginetype to check
// if fast=true try to get the fastest engine even if capacity is a bit lower than another
// return an index, the smallest = the better of ratio cargo/runningcost+cost of engine
{
local price=cEngine.GetPrice(engine, cargoID);
local capacity=cEngine.GetCapacity(engine, cargoID);
local speed=AIEngine.GetMaxSpeed(engine);
local lifetime=AIEngine.GetMaxAge(engine);
local runningcost=AIEngine.GetRunningCost(engine);
if (capacity<=0)	return 9999999;
if (price<=0)	return 9999999;
local eff=0;
if (fast)	eff=1000000 / ((capacity*0.9)+speed).tointeger();
	else	eff=1000000-(capacity * speed);
return eff;
}

function cCarrier::GetEngineLocoEfficiency(engine, cargoID, cheap)
// Get a ratio for a loco engine
// if cheap=true return the best ratio the loco have for the best ratio prize/efficiency, if false just the best engine without any costs influence
// return an index, the smallest = the better
{
//cheap = false;
	local price=cEngineLib.GetPrice(engine, cargoID);
//print("price = "+price+" normalprice="+AIEngine.GetPrice(engine));
	local power=AIEngine.GetPower(engine);
	local speed=AIEngine.GetMaxSpeed(engine);
	local lifetime=AIEngine.GetMaxAge(engine);
	local runningcost=AIEngine.GetRunningCost(engine);
	local eff=0;
	local rawidx=((power*(0.9*speed)) * 0.01)+1;
//print("rawidx for "+AIEngine.GetName(engine)+" = "+rawidx);
	if (cheap)	eff=(100000+ (price+(lifetime*runningcost))) / rawidx ;
		else	eff=(200000 - rawidx);
	return eff.tointeger();
}

function cCarrier::GetEngineWagonEfficiency(engine, cargoID)
// Get the ratio for a wagon engine
// return an index, the bigger the better
{
	local capacity = cEngine.GetCapacity(engine, cargoID);
	local speed = AIEngine.GetMaxSpeed(engine);
	local idx = -1;
	if (AIGameSettings.GetValue("wagon_speed_limits") == 1)
		{
		if (speed == 0)	speed = cEngineLib.GetTrainMaximumSpeed();
		idx = speed * capacity;
		}
	else	idx = capacity;
	return idx;
}


function cCarrier::CheckOneVehicleOrGroup(vehID, doGroup)
// Add a vehicle to the maintenance pool
// vehID: the vehicleID to check
// doGroup: if true, we will add all the vehicles that belong to the vehicleID group
{
	if (!AIVehicle.IsValidVehicle(vehID))	return false;
	local vehList=AIList();
	local vehGroup=AIVehicle.GetGroupID(vehID);
	if (doGroup)	vehList.AddList(AIVehicleList_Group(vehGroup));
	if (vehList.IsEmpty())	vehList.AddItem(vehID,0);
	foreach (vehicle, dummy in vehList)
		cCarrier.MaintenancePool.push(vehicle); // allow dup vehicleID in list, this will get clear by cCarrier.VehicleMaintenance()
}

function cCarrier::CheckOneVehicleOfGroup(doGroup)
// Add one vehicle of each vehicle groups we own to maintenance check
// doGroup: true to also do the whole group add, this mean all vehicles we own
{
	local allgroup=AIGroupList();
	foreach (groupID, dummy in allgroup)
		{
		local vehlist=AIVehicleList_Group(groupID);
		vehlist.Valuate(AIVehicle.GetAge);
		vehlist.Sort(AIList.SORT_BY_VALUE,false);
		if (!vehlist.IsEmpty())	cCarrier.CheckOneVehicleOrGroup(vehlist.Begin(),doGroup);
		local pause = cLooper();
		}
}

function cCarrier::VehicleFilterRoad(vehlist, object)
{
	cEngineLib.EngineFilter(vehlist, object.cargo_id, object.engine_roadtype, -1, false);
	vehlist.Valuate(AIEngine.GetPrice);
	vehlist.RemoveValue(0); // remove towncars toys
	vehlist.Valuate(AIEngine.IsArticulated);
	vehlist.KeepValue(0);
	vehlist.Valuate(cEngineLib.GetCapacity, object.cargo_id);
	vehlist.RemoveBelowValue(8); // clean out too small dumb vehicle size
	if (INSTANCE.main.bank.unleash_road)	vehlist.Valuate(cCarrier.GetEngineRawEfficiency, object.cargo_id, true);
							else	vehlist.Valuate(cCarrier.GetEngineEfficiency, object.cargo_id);
	vehlist.Sort(AIList.SORT_BY_VALUE,true);
	if (!vehlist.IsEmpty())	cEngine.EngineIsTop(vehlist.Begin(), object.cargo_id, true); // set top engine for trucks
}

function cCarrier::VehicleFilterAir(vehlist, object)
{
	local passCargo = cCargo.GetPassengerCargo();
	vehlist.Valuate(AIEngine.IsBuildable);
	vehlist.KeepValue(1);
	vehlist.Valuate(AIEngine.GetMaxSpeed);
	vehlist.KeepAboveValue(45); // some newgrf use weird unplayable aircrafts (for our distance usage)
	vehlist.Valuate(AIEngine.GetMaximumOrderDistance);
	vehlist.KeepValue(0); // Add for newGRF distance limit, for now only allow no limit engine
	local special = 0;
	local limitsmall = false;
	local fastengine = false;
	if (object.bypass == 20)
		{
		special = AircraftType.EFFICIENT;
		limitsmall = true;
		}
	switch (object.bypass)
		{
		case	AircraftType.EFFICIENT: // top efficient aircraft for passenger and top speed (not efficient) for mail
			// top efficient aircraft is generally the same as top capacity/efficient one
			vehlist.Valuate(AIEngine.GetMaxSpeed);
			vehlist.RemoveBelowValue(65); // remove too dumb aircraft 65=~250km/h
			vehlist.Valuate(cEngine.GetCapacity, passCargo);
			vehlist.RemoveBelowValue(30);
			if (limitsmall) // small ones
					{
					vehlist.Valuate(AIEngine.GetPlaneType);
					vehlist.KeepValue(AIAirport.PT_SMALL_PLANE);
					special = RouteType.SMALLAIR;
					}
				else	special=RouteType.AIR;
			if (AICargo.GetTownEffect(object.cargo_id) == AICargo.TE_MAIL)
				{ // mail/fast ones
				vehlist.Valuate(AIEngine.GetMaxSpeed);
				special++;	// add one to fall on mail: AIRMAIL OR SMALLMAIL
				vehlist.Sort(AIList.SORT_BY_VALUE,false);
				vehlist.KeepTop(5); // best fastest engine out of the 5 top fast one
				}
			else	{ // passengers
				vehlist.Valuate(AIEngine.GetCapacity);
				vehlist.Sort(AIList.SORT_BY_VALUE,false);
				vehlist.KeepTop(5);
				}
			vehlist.Valuate(cCarrier.GetEngineEfficiency, passCargo); // passenger/big ones
			vehlist.Sort(AIList.SORT_BY_VALUE,true);
		break;
		case	AircraftType.BEST:
			special = RouteType.AIRNET;
			if (AICargo.GetTownEffect(object.cargo_id) == AICargo.TE_MAIL) // fast aircraft
				{
				special++; // mail: AIRNETMAIL
				fastengine=true;
				}
			vehlist.Valuate(cCarrier.GetEngineRawEfficiency, passCargo, fastengine);	// keep top raw efficiency out of remain ones
			vehlist.Sort(AIList.SORT_BY_VALUE,true);					// for fast aircrafts only 5 choices, but big aircrafts have plenty choices
		break;
		case	AircraftType.CHOPPER: // top efficient chopper
			vehlist.Valuate(AIEngine.GetPlaneType);
			vehlist.KeepValue(AIAirport.PT_HELICOPTER);
			vehlist.Valuate(cCarrier.GetEngineEfficiency, passCargo);
			vehlist.Sort(AIList.SORT_BY_VALUE,true);
			special = RouteType.CHOPPER;
		break;
		}
	if (!vehlist.IsEmpty())	cEngine.EngineIsTop(vehlist.Begin(), special, true); // set top engine for aircraft
	//if (!vehlist.IsEmpty())	print("aircraft="+cEngine.GetName(vehlist.Begin())+" r_dist="+distance+" r_distSQ="+(distance*distance)+" e_dist="+AIEngine.GetMaximumOrderDistance(vehlist.Begin()));
}

function cCarrier::VehicleFilterTrain(vehlist, object)
{
	cEngineLib.EngineFilter(vehlist, object.cargo_id, -1, object.engine_id, object.bypass);
	// force roadtype to -1 to prevent filtering by railtype
	if (AIEngine.IsWagon(vehlist.Begin()))
		{
		vehlist.Valuate(cCarrier.GetEngineWagonEfficiency, object.cargo_id);
		vehlist.Sort(AIList.SORT_BY_VALUE, false);
print("filter wagon : "+cEngine.GetName(vehlist.Begin()));
		}
	else	{
		vehlist.Valuate(cCarrier.GetEngineLocoEfficiency, object.cargo_id, !INSTANCE.main.bank.unleash_road);
		vehlist.Sort(AIList.SORT_BY_VALUE, true);
		if (!vehlist.IsEmpty())	cEngine.RailTypeIsTop(vehlist.Begin(), object.cargo_id, true);
		// before railtype filtering, add this engine as topengine using any railtype
		if (object.engine_roadtype != -1)
			{
			vehlist.Valuate(AIEngine.HasPowerOnRail, object.engine_roadtype);
			vehlist.KeepValue(1);
			vehlist.Valuate(cCarrier.GetEngineLocoEfficiency, object.cargo_id, !INSTANCE.main.bank.unleash_road);
			vehlist.Sort(AIList.SORT_BY_VALUE, true);
			}
		//else	object.engine_roadtype = cCarrier.GetRailTypeNeedForEngine(vehlist.Begin()); // get what rails the train want
		if (!vehlist.IsEmpty())	cEngine.EngineIsTop(vehlist.Begin(), object.cargo_id, true); // set top engine for trains
print("filter train : "+cEngine.GetName(vehlist.Begin()));
		}
}

