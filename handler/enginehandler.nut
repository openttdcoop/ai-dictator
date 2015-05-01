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

class cEngine extends cEngineLib
{
static	BestEngineList=AIList();	// list of best engine for a couple engine/cargos, item=EUID, value=best engineID

    rabbit = null;
	constructor()
		{
		::cEngineLib.constructor();
		this.rabbit = -1; // the rabbit is a vehicle with engine that is going to depot for upgrade, blocking others upgrade
		}
}

function cEngine::GetEngineName(engineID)
{
	local name = "invalid";
	if (engineID != null && engineID >= 0)	name = AIEngine.GetName(engineID);
	name+="("+engineID+")";
	return name;
}

function cEngine::GetRailTrackName(tr)
{
	local name = "invalid";
	if (tr != null && tr >= 0)	name = AIRail.GetName(tr);
	name+="("+tr+")";
	return name;
}

function cEngine::IsRabbitSet(vehicleID)
// return true if we have a test vehicle already set
	{
	local engineID = AIVehicle.GetEngineType(vehicleID);
	local eng = cEngine.Load(engineID);
    if (eng == null)    return;
	if (!AIVehicle.IsValidVehicle(eng.is_known))	{ eng.is_known = -2; }
	return (eng.is_known > -1);
	}

function cEngine::RabbitSet(vehicleID)
// Set the status of the engine as a rabbit vehicle is on its way for testing
	{
	if (vehicleID == null)	{ return ; }
	local engineID=AIVehicle.GetEngineType(vehicleID);
	if (engineID == null)	{ return ; }
	local eng = cEngine.Load(engineID);
	if (eng.is_known == -2)	{
                            eng.is_known = vehicleID;
                            INSTANCE.DInfo("Using "+AIVehicle.GetName(vehicleID)+" as test vehicle for "+cEngine.GetEngineName(engineID),1);
                            }
	}

function cEngine::RabbitUnset(vehicleID)
// Unset the status of the rabbit vehicle, only useful if the rabbit vehicle never reach a depot (crash)
	{
	if (vehicleID == null || !AIVehicle.IsValidVehicle(vehicleID)) return ;
	local engineID = AIVehicle.GetEngineType(vehicleID);
	if (!AIEngine.IsValidEngine(engineID))	return ;
    local eng=cEngine.Load(engineID);
    if (eng == null)	return;
	if (eng.is_known >= 0)	eng.is_known = -2;
	}

function cEngine::CanPullCargo(engineID, cargoID)
// try to really answer if an engine can be use to pull a wagon of a cargo type
// if NicePlay is true we return the AIEngine.CanPullCargo version
// else we return real usable wagons list for a train
	{
	local setting = !DictatorAI.GetSetting("use_nicetrain");
	return cEngineLib.CanPullCargo(engineID, cargoID, setting);
	}

function cEngine::GetEUID(engineType, cargoID)
// return the EUID
// engineType : it's AIVehicle.GetEngineType() result for an engine
// engineType : rail engine can pass their track value with 2000+track value
// cargoID : for road/water/train it's the cargo ID
// cargoID : for aircraft it's the value of RouteType.AIR/AIRNET/CHOPPER
	{
	if (engineType < 2000)	engineType = (engineType + 1) * 40;
					else	cargoID = cargoID * 40;
	return engineType + cargoID; // 32 cargos only, so 40 is really enough
	}

function cEngine::GetEngineByCache(engineType, cargoID)
// return the top engine if we knows it already
// return -1 if we have no match but try to find an engine before
	{
	local EUID = cEngine.GetEUID(engineType, cargoID);
	if (cEngine.BestEngineList.HasItem(EUID))	return cEngine.BestEngineList.GetValue(EUID);
	INSTANCE.DInfo("Engine cache miss for "+EUID,2);
	switch (engineType)
		{
		case	AIVehicle.VT_ROAD:
			local engine = cCarrier.GetRoadVehicle(null, cargoID);
			if (engine != -1)	cEngine.SetBestEngine(EUID, engine);
			return engine;
		case	AIVehicle.VT_RAIL:
			local engine = cCarrier.ChooseRailCouple(cargoID, -1);
/*			if (engine[0] != -1)
				{
				cEngine.SetBestEngine(EUID, engine[0]);
				print("EUID="+EUID);
				// Also set best engine for the railtrack found
				local id = cEngine.GetEUID(2000 + engine[2], cargoID);
				print("id ="+id);
				cEngine.SetBestEngine(id, engine[0]);
				}*/
			if (cJobs.WagonType.HasItem(cargoID))	cJobs.WagonType.RemoveItem(cargoID);
			cJobs.WagonType.AddItem(cargoID, engine[1]);
			return engine[0];
		case	AIVehicle.VT_AIR:
			local engine = cCarrier.GetAirVehicle(null, cargoID);
			if (engine != -1)	cEngine.SetBestEngine(EUID, engine);
			return engine;
		case	AIVehicle.VT_WATER:
			local engine = cCarrier.GetWaterVehicle(null, cargoID);
			if (engine != -1)	cEngine.SetBestEngine(EUID, engine);
			return engine;
		}
	return -1;
	}

function cEngine::SetBestEngine(EUID, engineID)
// set the best engine for that EUID
	{
	local exist=(cEngine.BestEngineList.HasItem(EUID));
	local oldvalue=-1;
	if (exist)
				{
				oldvalue=cEngine.BestEngineList.GetValue(EUID);
				cEngine.BestEngineList.SetValue(EUID, engineID);
				if (oldvalue != engineID)	INSTANCE.DInfo("New best engine for EUID #"+EUID+" to "+cEngine.GetEngineName(engineID)+" was "+oldvalue+"-"+cEngine.GetEngineName(oldvalue),2);
				}
		else	cEngine.BestEngineList.AddItem(EUID, engineID);
	}

function cEngine::IsEngineAtTop(engineID, cargoID, set_engine)
// Check if we can use a better engine for a vehicle
// engineID: the engine ID we wish to test for an upgrade
// cargoID: for water/road/rail the cargo ID
// cargoID: for aircraft RouteType.AIR/AIRNET/CHOPPER
// setTopEngine: <0 to not set engine, >0 to set engine
// setTopEngine: Rail can pass track info by giving track value + 10 (so <= 10 to set, >=10 to not set)
// return -1 if we are at top engine already
// return engineID if we can upgrade to a better version
	{
	local setTopEngine = (set_engine > 0);
	local vehicleType = AIEngine.GetVehicleType(engineID);
	if (vehicleType == RouteType.RAIL)
		{
		// RouteType.RAIL : best engine without knowing track to use
		// <-9 or > 9 : best engine with track value of 0, 1...
		local RT = RouteType.RAIL;
		if (set_engine <= -10 || set_engine >= 10)	RT = (abs(set_engine) - 10) + 2000;
        vehicleType = RT;
        }
	local EUID = cEngine.GetEUID(vehicleType, cargoID);
	local topengine = engineID;
	if (!cEngine.BestEngineList.HasItem(EUID))	setTopEngine=true;
	if (setTopEngine)	cEngine.SetBestEngine(EUID, engineID);
	topengine = cEngine.BestEngineList.GetValue(EUID);
	if (engineID == topengine)	return -1;
					else	{
							INSTANCE.DInfo("Engine "+cEngine.GetEngineName(engineID)+" can be upgrade for engine "+cEngine.GetEngineName(topengine),2);
							foreach (euid, engine in cEngine.BestEngineList)	print("EUID= "+euid+" engine ="+cEngine.GetName(engine));
							return topengine;
							}
	}

function cEngine::IsRailAtTop(vehID)
// Check if we could use better rail to use a better engine for this vehicle
// return -1 if the vehicle doesn't need upgrade
// return the better RailTrack type if one exist
{
	local current_rt = cEngineLib.VehicleGetRailTypeUse(vehID);
	if (current_rt == AIRail.RAILTYPE_INVALID)	return -1;
	local best_rt = cEngineLib.RailTypeGetFastestType();
	if (current_rt != best_rt)	return best_rt;
	return -1;
}

function cEngine::IsVehicleAtTop(vehID)
// Check if a vehicle is using the best engine already
// return -1 if the vehicle doesn't need upgrade
// return the better engineID if one exist
	{
	if (!AIVehicle.IsValidVehicle(vehID))	{ INSTANCE.DError("Not a valid vehicle",2); return -1; }
	local idx = cCarrier.VehicleFindRouteIndex(vehID);
	if (idx == null)	{ INSTANCE.DError("Fail to find the route used by this vehicle: "+cCarrier.GetVehicleName(vehID),2); return -1; }
	local road = cRoute.Load(idx);
	if (!road)	return -1;
	local cargoID = road.CargoID;
	local vehType = AIVehicle.GetVehicleType(vehID);
	if (vehType == AIVehicle.VT_AIR)	cargoID = road.VehicleType;
	local engineID = AIVehicle.GetEngineType(vehID);
	local justread = -1;
	if (vehType == RouteType.RAIL)	justread = 0 - (road.RailType + 10);
	return cEngine.IsEngineAtTop(engineID, cargoID, justread);
	}

function cEngine::CheckMaxSpeed(engineID)
// Check the max speed of vehicle and see if top speed for that vehicle type should be this one or not
{
	local topspeed = cEngine.GetMaxSpeed(engineID);
	local typeveh = cEngine.GetVehicleType(engineID);
	switch (typeveh)
		{
		case	AIVehicle.VT_RAIL:
			if (INSTANCE.main.carrier.speed_MaxTrain < topspeed)
				{
				INSTANCE.DInfo("Setting maximum speed for trains vehicle to "+topspeed,0);
				INSTANCE.main.carrier.speed_MaxTrain = topspeed;
				}
		return;
		case	AIVehicle.VT_ROAD:
			if (INSTANCE.main.carrier.speed_MaxRoad < topspeed)
				{
				INSTANCE.DInfo("Setting maximum speed for roads vehicle to "+topspeed,0);
				INSTANCE.main.carrier.speed_MaxRoad = topspeed;
				}
		return;
		}
}

