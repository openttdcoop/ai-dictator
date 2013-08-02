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
//static	enginedatabase= {};
//static	EngineBL=AIList();		// list of truck/bus engines we have blacklist to avoid bug with IsArticalted
static	BestEngineList=AIList();	// list of best engine for a couple engine/cargos, item=EUID, value=best engineID

	constructor()
		{
		::cEngineLib.constructor();
		}
}

function cEngine::IsRabbitSet(vehicleID)
// return true if we have a test vehicle already
	{
	local engineID=AIVehicle.GetEngineType(vehicleID);
	local eng=cEngine.Load(engineID);
	if (eng.is_known >= 0 && !AIVehicle.IsValidVehicle(eng.is_known))	eng.is_known=-1;
	return (eng.is_known >= 0);
	}

function cEngine::RabbitSet(vehicleID)
// Set the status of the engine as a rabbit vehicle is on its way for testing
	{
	if (vehicleID == null)	return ;
	local engineID=AIVehicle.GetEngineType(vehicleID);
	if (engineID == null)	return ;
	local eng=cEngine.Load(engineID);
	if (eng.is_known == -1)	{ eng.is_known=vehicleID; INSTANCE.DInfo("Using that vehicle as test vehicle for engine checks",2); }
	}

function cEngine::RabbitUnset(vehicleID)
// Unset the status of the rabbit vehicle, only useful if the rabbit vehicle never reach a depot (crash)
	{
	if (vehicleID == null || !AIVehicle.IsValidVehicle(vehicleID)) return ;
	local engineID=AIVehicle.GetEngineType(vehicleID);
	if (!AIEngine.IsValidEngine(engineID))	return ;
	local eng=cEngine.Load(engineID);
	if (eng == null)	return;
	if (eng.is_known >= 0)	eng.is_known = -1;
	}

function cEngine::CanPullCargo(engineID, cargoID)
// try to really answer if an engine can be use to pull a wagon of a cargo type
// if NicePlay is true we return the AIEngine.CanPullCargo version
// else we return real usable wagons list for a train
	{
	local setting = DictatorAI.GetSetting("use_nicetrain");
	return cEngineLib.CanPullCargo(engineID, cargoID, setting);
	}

function cEngine::GetName(eID)
// return the name of the engine
	{
	local name = "Invalid engine";
	if (AIEngine.IsValidEngine(eID))	name = AIEngine.GetName(eID);
	name+=" (#"+eID+")";
	return name;
	}

function cEngine::GetEUID(engineType, cargoID)
// return the EUID
// engineType : it's AIVehicle.GetEngineType() result for an engine except trains
// engineType : for trains it's RouteType.CHOPPER+2+Railtype value
// cargoID : for road/water/train it's the cargo ID
// cargoID : for aircraft it's the value of RouteType.AIR/AIRNET/CHOPPER
	{
	engineType++; // no 0 base results
	return (engineType*40)+cargoID; // 32 cargos only, so 40 is really enough
	}

function cEngine::GetEngineByCache(engineType, cargoID)
// return the top engine if we knows it already
// return -1 if we have no match but try to find an engine before
	{
	local EUID=cEngine.GetEUID(engineType, cargoID);
	if (cEngine.BestEngineList.HasItem(EUID))	return cEngine.BestEngineList.GetValue(EUID);
	INSTANCE.DInfo("Engine cache miss for "+EUID,2);
	local etype = engineType;
	local rtype = -1;
	if (etype > RouteType.CHOPPER)	{ etype = AIVehicle.VT_RAIL; rtype = engineType - RouteType.CHOPPER - 2; }
	switch (etype)
		{
		case	AIVehicle.VT_ROAD:
			local engine = cCarrier.GetRoadVehicle(null, cargoID);
			if (engine != -1)	cEngine.SetBestEngine(EUID, engine);
			return engine;
		case	AIVehicle.VT_RAIL:
			local engine = cCarrier.ChooseRailCouple(cargoID, rtype);
			if (engine[0] != -1)	cEngine.SetBestEngine(EUID, engine[0]);
			return engine[0];
		case	AIVehicle.VT_AIR:
			local engine = cCarrier.GetAirVehicle(null, cargoID);
			if (engine != -1)	cEngine.SetBestEngine(EUID, engine);
			return engine;
		}
	return -1;
	}

function cEngine::SetBestEngine(EUID, engineID)
// set the best engine for that EUID
	{
	if (EUID==0)	return true;
	local exist=(cEngine.BestEngineList.HasItem(EUID));
	local oldvalue=-1;
	if (exist)	{
			oldvalue=cEngine.BestEngineList.GetValue(EUID);
			cEngine.BestEngineList.SetValue(EUID, engineID);
			if (oldvalue != engineID)	INSTANCE.DInfo("Setting new top engine for EUID #"+EUID+" to "+engineID+"-"+AIEngine.GetName(engineID)+" was "+oldvalue+"-"+AIEngine.GetName(engineID),2);
			}
		else	cEngine.BestEngineList.AddItem(EUID, engineID);
	}

function cEngine::RailTypeIsTop(engineID, cargoID, setTopRail)
// Check if we could use another train with a better engine by changing railtype
// setTopRail : true to set it, false to only grab the value
// return -1 if we are at top already
// return the engineID if we could upgrade
	{
	//if (cargoID == -1)	return -1;
	if (AIEngine.GetVehicleType(engineID) != AIVehicle.VT_RAIL)	return -1;
	local EUID = cEngine.GetEUID(RouteType.RAIL, cargoID);
	local topengine = engineID;
	if (!cEngine.BestEngineList.HasItem(EUID))	setTopRail = true;
	if (setTopRail)	cEngine.SetBestEngine(EUID, engineID);
	topengine = cEngine.BestEngineList.GetValue(EUID);
	if (engineID == topengine)	return -1;
					else	return AIEngine.GetRailType(topengine); // we return the railtype need to upgrade
	}

function cEngine::EngineIsTop(engineID, cargoID, setTopEngine)
// Check if we can use a better engine for a vehicle
// engineID: the engine ID we wish to test for an upgrade
// cargoID: for water/road/rail the cargo ID
// cargoID: for aircraft RouteType.AIR/AIRNET/CHOPPER
// setTopEngine: true to set it, false to only grab the value
// return -1 if we are at top engine already
// return engineID if we can upgrade to a better version
	{
	//if (cargoID == -1)	return -1;
	local vehicleType = AIEngine.GetVehicleType(engineID);
	local special = null;
	if (vehicleType == AIVehicle.VT_RAIL)
		{
		local RT = AIEngine.GetRailType(engineID);
		special = RT+RouteType.CHOPPER+2;
		}
	else	special=vehicleType;
	local EUID=cEngine.GetEUID(special, cargoID);
	local topengine=engineID;
	if (EUID==0)	return -1;	// on error say we're at top
	if (!cEngine.BestEngineList.HasItem(EUID))	setTopEngine=true;
	if (setTopEngine)	cEngine.SetBestEngine(EUID, engineID);
	topengine=cEngine.BestEngineList.GetValue(EUID);
	if (engineID == topengine)	return -1;
					else	{
						INSTANCE.DInfo("Engine "+AIEngine.GetName(engineID)+" can be upgrade for engine "+AIEngine.GetName(topengine),2);
						return topengine;
						}
	}

function cEngine::IsVehicleAtTop(vehID)
// Check if a vehicle is using the best engine already
// return -1 if the vehicle doesn't need upgrade
// return the better engineID if one exist
	{
	if (!AIVehicle.IsValidVehicle(vehID))	{ INSTANCE.DError("Not a valid vehicle",2); return -1; }
	local idx=cCarrier.VehicleFindRouteIndex(vehID);
	if (idx == null)	{ INSTANCE.DError("Fail to find the route used by this vehicle",2); return -1; }
	local road=cRoute.Load(idx);
	if (!road)	return -1;
	local cargoID=road.CargoID;
	local vehType=AIVehicle.GetVehicleType(vehID);
	if (vehType==AIVehicle.VT_AIR)	cargoID=road.VehicleType;
	local engineID=AIVehicle.GetEngineType(vehID);
	return cEngine.EngineIsTop(engineID, cargoID, false);
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

