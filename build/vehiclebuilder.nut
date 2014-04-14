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
	//if (virtualized)	airportmode="(network)";
	local airname=thatstation.s_Name+"-> ";
	switch (chem.VehicleType)
		{
		case RouteType.ROAD:
			DInfo("Road station "+thatstation.s_Name+" limit "+thatstation.s_VehicleCount+"/"+thatstation.s_VehicleMax,1);
			if (thatstation.CanUpgradeStation())
					{ // can still upgrade
					if (chem.VehicleCount+max_allow > INSTANCE.main.carrier.road_max_onroute)
							{ max_allow=(INSTANCE.main.carrier.road_max_onroute-chem.VehicleCount); }
					// limit by number of vehicle per route
					if (!INSTANCE.use_road)	{ max_allow=0; }
					// limit by vehicle disable (this can happen if we reach max vehicle game settings too
					if ( (thatstation.s_VehicleCount+max_allow) > thatstation.s_VehicleMax)
						{ // we must upgrade
						INSTANCE.main.builder.RoadStationNeedUpgrade(roadidx, start);
						local fake=thatstation.CanUpgradeStation(); // to see if upgrade success
						}
					if (thatstation.s_VehicleCount+max_allow > thatstation.s_VehicleMax)
							{ max_allow=thatstation.s_VehicleMax-thatstation.s_VehicleCount; }
					// limit by the max the station could handle
					}
			else	{ // max size already
					if (thatstation.s_VehicleCount+max_allow > thatstation.s_VehicleMax)
							{ max_allow=INSTANCE.main.carrier.road_max_onroute-thatstation.s_VehicleCount; }
					// limit by the max the station could handle
					if (chem.VehicleCount+max_allow > INSTANCE.main.carrier.road_max_onroute)
							{ max_allow=INSTANCE.main.carrier.road_max_onroute-chem.VehicleCount; }
					// limit by number of vehicle per route
					}
		break;
		case RouteType.RAIL:
			if (!INSTANCE.use_train)	{ max_allow = 0; }
		break;
		case RouteType.WATER:
			if (!INSTANCE.use_boat)	{ max_allow = 0; }
			if (thatstation.s_VehicleCount+max_allow > thatstation.s_VehicleMax)
					{ max_allow=thatstation.s_VehicleMax-thatstation.s_VehicleCount; }
		break;
		case RouteType.AIRNET:
		case RouteType.AIRNETMAIL:
			if (!INSTANCE.use_air)	{ max_allow = 0; }
			local netlimit = cCarrier.VirtualAirRoute.len() * INSTANCE.main.carrier.airnet_max;
			if (max_allow > netlimit)	{ max_allow = netlimit - vehnumber; }
/*			thatstation.CheckAirportLimits(); // force recheck limits
			if (thatstation.CanUpgradeStation())
				{
				INSTANCE.main.builder.AirportNeedUpgrade(thatstation.s_ID);
				return 0;
				// get out after an upgrade, station could have change place...
				}
			DInfo(airname+"Limit for that route (network): "+chem.VehicleCount+"/"+INSTANCE.main.carrier.airnet_max*cCarrier.VirtualAirRoute.len(),1);
			DInfo(airname+"Limit for that airport (network): "+chem.VehicleCount+"/"+thatstation.s_VehicleMax,1);
			if (chem.VehicleCount+max_allow > INSTANCE.main.carrier.airnet_max*cCarrier.VirtualAirRoute.len()) max_allow=(INSTANCE.main.carrier.airnet_max*cCarrier.VirtualAirRoute.len()) - chem.VehicleCount;
			if (chem.VehicleCount+max_allow > thatstation.s_VehicleMax)	max_allow=thatstation.s_VehicleMax-chem.VehicleCount;*/
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
			if (!INSTANCE.use_air)	{ max_allow = 0; }
			if (thatstation.CanUpgradeStation())
				{
				INSTANCE.main.builder.AirportNeedUpgrade(thatstation.s_ID);
				max_allow=0;
				}
			local limitmax = INSTANCE.main.carrier.air_max;
			if (shared)
				{
				if (thatstation.s_Owner.Count()>0)	{ limitmax=limitmax / thatstation.s_Owner.Count(); }
				if (limitmax < 2)	limitmax=2;
				}
//			if (virtualized)	limitmax=4; // only 4 aircrafts when the airport is also in network

/*			local dualnetwork=false;
			local routemod="(classic)";
			if (virtualized && othervirtual)
				{
				limitmax=2;	// no aircrafts at all on that route if both airport are in the network
				dualnetwork=true;
				routemod="(dual network)";
				}*/
			DInfo(airname+"Limit for that route "+airportmode+": "+chem.VehicleCount+"/"+limitmax,1);
			DInfo(airname+"Limit for that airport "+airportmode+": "+thatstation.s_VehicleCount+"/"+thatstation.s_VehicleMax,1);
			if (chem.VehicleCount+max_allow > limitmax)	{ max_allow=limitmax - chem.VehicleCount; }
			// limit by route limit
			if (thatstation.s_VehicleCount+max_allow > thatstation.s_VehicleMax)	{ max_allow=thatstation.s_VehicleMax-thatstation.s_VehicleCount; }
			// limit by airport capacity
		break;
		}
	if (max_allow < 0)	{ max_allow=0; }
	return max_allow;
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
			return INSTANCE.main.carrier.GetWaterVehicle(routeidx);
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

function cCarrier::VehicleFilterWater(vehlist, object)
{
	cEngineLib.EngineFilter(vehlist, object.cargo_id, -1, -1, false);
	vehlist.Valuate(AIEngine.GetPrice);
	vehlist.RemoveValue(0); // remove towncars toys
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
		if (!vehlist.IsEmpty())	cEngine.EngineIsTop(vehlist.Begin(), object.cargo_id, true); // set top engine for trains
		}
}

function cCarrier::RouteNeedVehicle(gid, amount)
// store the vehicle need by all routes
{
    if (amount == 0)    return;
    if (!INSTANCE.main.carrier.vehicle_wishlist.HasItem(gid))	{ INSTANCE.main.carrier.vehicle_wishlist.AddItem(gid, 0); }
    INSTANCE.main.carrier.vehicle_wishlist.SetValue(gid, amount);
}

function cCarrier::PriorityGroup(gid)
{
    local type = AIGroup.GetVehicleType(gid);
    if (type == AIVehicle.VT_RAIL)  return 100;
    if (type == AIVehicle.VT_ROAD)  return 30;
    if (type == AIVehicle.VT_AIR)   return 60;
    return 0;
}

function cCarrier::Lower_VehicleWish(gid, amount)
// dec the wish list for that gid
{
    if (!INSTANCE.main.carrier.vehicle_wishlist.HasItem(gid))   return;
    local value = INSTANCE.main.carrier.vehicle_wishlist.GetValue(gid);
    local x = 0;
    if (value > 1000)   { x = 1000; }
    value -= amount;
    if (value <= x) { INSTANCE.main.carrier.vehicle_wishlist.RemoveItem(gid); return; }
    INSTANCE.main.carrier.vehicle_wishlist.SetValue(gid, value);
}

function cCarrier::Process_VehicleWish()
// buy vehicle need by routes
{
	INSTANCE.main.carrier.highcostAircraft = 0;
    INSTANCE.main.carrier.highcostTrain = 0;
    local uid, engine, gtype;
    local cleanList = AIList();
    cleanList.AddList(INSTANCE.main.carrier.vehicle_wishlist);
    cleanList.Valuate(AIGroup.IsValidGroup);
    foreach (gid, exist in cleanList)
        {
        if (exist == 1) { continue; }
        INSTANCE.main.carrier.vehicle_wishlist.RemoveItem(gid);
        }
    if (INSTANCE.main.carrier.vehicle_wishlist.IsEmpty())   { INSTANCE.main.carrier.vehicle_cash = 0; return; }
    cleanList.KeepValue(1);
    cleanList.Valuate(cCarrier.PriorityGroup);
    cleanList.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
    DInfo(cleanList.Count()+" queries to buy vehicle waiting",1);
    if (INSTANCE.debug)
        {
        foreach (gid, amount in cleanList)
            {
            local uid = cRoute.GroupIndexer.GetValue(gid);
            local r = cRoute.Load(uid);
            if (!r)	{ continue; }
            DInfo(r.Name+" Need: "+INSTANCE.main.carrier.vehicle_wishlist.GetValue(gid),1);
            }
        }
    local amount = 0;
    foreach (gid, _ in cleanList)
        {
        uid = cRoute.GroupIndexer.GetValue(gid);
        local r = cRoute.Load(uid);
        if (!r || r.Status != RouteStatus.WORKING || !AIGroup.IsValidGroup(gid))
			{
			INSTANCE.main.carrier.vehicle_wishlist.RemoveItem(uid);
			continue;
			}
        gtype = AIGroup.GetVehicleType(gid);
        engine = cCarrier.GetVehicle(uid);
        amount = INSTANCE.main.carrier.vehicle_wishlist.GetValue(gid);
        if (engine == null || engine == -1) { continue; }
        if (typeof(engine) == "array")
            {
            if (engine[0] == -1)    { continue; }
            engine = engine[1];
            }
        local price = cEngineLib.GetPrice(engine);
        local aircraft = false;
        if (amount >= 1000)
                {
                amount -= 1000;
                }
        else    {
                INSTANCE.main.carrier.vehicle_cash += (price * amount);
                INSTANCE.main.carrier.vehicle_wishlist.SetValue(gid, 1000 + amount);
                }
        if (amount == 0)    { INSTANCE.main.carrier.vehicle_wishlist.RemoveItem(gid); continue; }
        local creation = null;
        switch  (gtype)
                {
                case    AIVehicle.VT_AIR:
                    creation = cCarrier.CreateAirVehicle;
                    aircraft = true;
                break;
                case    AIVehicle.VT_RAIL:
                    if (cCarrier.IsTrainRouteBusy(uid)) { continue; }
                    cCarrier.AddWagon(uid, amount);
                continue;
                case    AIVehicle.VT_ROAD:
                    creation = cCarrier.CreateRoadVehicle;
                break;
                case    AIVehicle.VT_WATER:
                    creation = cCarrier.CreateWaterVehicle;
                break;
                }
        if (creation == null)   continue;
        for (local z = 0; z < amount; z++)
            {
            if (cBanker.CanBuyThat(price))
                    {
                    if (creation(uid))
                        {
                        cCarrier.Lower_VehicleWish(gid, 1);
                        }
                    }
            else    if (aircraft && INSTANCE.main.carrier.highcostAircraft < price)
                        {
                        INSTANCE.main.carrier.highcostAircraft = price;
                        }
            }
        }
}
