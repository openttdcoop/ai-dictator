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
class cEngine extends AIEngine
{
static	enginedatabase= {};
static	EngineInUseList=AIList();	// list of engines that are use by a vehicle. item=EUID, value=number of vehicle
static	BestEngineList=AIList();	// list of best engine for a couple engine/cargos, item=EUID, value=best engineID

static	function GetEngineObject(engineID)
		{
		return engineID in cEngine.enginedatabase ? cEngine.enginedatabase[engineID] : null;
		}

	engineID		= null;	// id of the engine
	name			= null;	// name
	cargo_capacity	= null;	// capacity per cargo item=cargoID, value=capacity when refit
	cargo_price		= null;	// price to refit item=cargoID, value=refit cost
	cargo_length	= null;	// that's the length of a vehicle depending on its current cargo setting
	isKnown		= null;	// true if we know it already
	incompatible	= null;	// AIList of wagons imcompatible with a train engine
	
	constructor()
		{
		engineID		= null;
		name			= "unknow";
		cargo_capacity	= AIList();
		cargo_price		= AIList();
		cargo_length	= AIList();
		isKnown		= false;
		incompatible	= AIList();
		}
}

function cEngine::Save()
// Save the engine in the database
	{
	if (this.engineID == null)	{ this.isKnown=true; return; }
	if (this.engineID in cEngine.enginedatabase)	return;
	local crglist=AICargoList();
	foreach (crg, dummy in crglist)
		{
		this.cargo_length.AddItem(crg, 8); // default to 8, a classic length
		this.cargo_price.AddItem(crg,-1);
// 2 reasons: make the engine appears cheaper by 1 vs an already test one & allow us to know if we met it already (see SetRefitCost)
		if (AIEngine.CanRefitCargo(this.engineID, crg))
				this.cargo_capacity.AddItem(crg,255);
// 255 so it will appears to be a better carrier vs an already test engine
// This two properties set as-is will force the AI to think a non-test engine is better to use than an already test one
			else	this.cargo_capacity.AddItem(crg,0);
		}
	local crgtype=AIEngine.GetCargoType(this.engineID);
	this.cargo_capacity.SetValue(crgtype, AIEngine.GetCapacity(this.engineID));
	this.name=AIEngine.GetName(this.engineID);
	cEngine.enginedatabase[this.engineID] <- this;
	DInfo("Adding "+this.name+" to cEngine database",2,"cEngine::Save");
	DInfo("List of known engines : "+(cEngine.enginedatabase.len()),1,"cEngine::Save");
	}

function cEngine::Load(eID)
	{
	local cobj=cEngine();
	cobj.engineID=eID;
	if (eID in cEngine.enginedatabase)	cobj=cEngine.GetEngineObject(eID);
						else	cobj.Save();
	return cobj;
	}
	
function cEngine::GetLength(eID, cargoID=null)
	{
	local eng=cEngine.Load(eID);
	if (cargoID==null)	cargoID=AIEngine.GetCargoType(eID);
	return eng.cargo_length.GetValue(cargoID);
	}

function cEngine::Update(vehID)
	{
	local new_engine=AIVehicle.GetEngineType(vehID);
	local engObj=cEngine.Load(new_engine);
	if (engObj.isKnown)	return;
	DInfo("Grabbing vehicle properties for "+engObj.name,2,"cEngine::Update");
	local crgList=AICargoList();
	foreach (cargoID, dummy in crgList)
		{
		local testing=AIVehicle.GetRefitCapacity(vehID, cargoID);
		if (testing < 0)	testing=0;
		engObj.cargo_capacity.SetValue(cargoID, testing);
		engObj.cargo_length.SetValue(cargoID, AIVehicle.GetLength(vehID)); // assume all cargo will gave same length
		}
	engObj.isKnown=true;
	}

function cEngine::GetCapacity(eID, cargoID=null)
// can be use as valuator
	{
	local engObj=cEngine.Load(eID);
	if (cargoID==null)	cargoID=AIEngine.GetCargoType(eID);
	//DInfo(engObj.name+" have a capacity of "+engObj.cargo_capacity.GetValue(cargoID)+" for "+AICargo.GetCargoLabel(cargoID),2,"cEngine::GetCapacity");
	return engObj.cargo_capacity.GetValue(cargoID);
	}

function cEngine::Incompatible(eng1, eng2)
// mark eng1 incompatible with eng2 (one must be a wagon, other must not)
	{
	if ( (!AIEngine.IsWagon(eng1) && !AIEngine.IsWagon(eng2)) || (AIEngine.IsWagon(eng1) && AIEngine.IsWagon(eng2)) )
		{ DError("One engine must be a wagon and the other must not",1,"cEngine::Incompatible"); return false; }
	local eng1O=cEngine.Load(eng1);
	local eng2O=cEngine.Load(eng2);
	eng1O.incompatible.AddItem(eng2,eng1);
	eng2O.incompatible.AddItem(eng1,eng2);
	DInfo("Setting "+eng1O.name+" incompatible with "+eng2O.name,2,"cEngine::Incompatible");
	}

function cEngine::SetRefitCost(engine, cargo, cost, vlen)
// set the refit cost for an engine to use cargo
// per default, assume all refit costs will be == for all cargos
	{
	local eng=cEngine.Load(engine);
	local update=false;
	if (eng.cargo_price.GetValue(cargo) == -1) // this test prove we never met a refitprice for that engine
		{
		foreach (crg, refitprice in eng.cargo_price)	if (refitprice == -1)	eng.cargo_price.SetValue(crg, cost);
		update=true;
		}
	if (eng.cargo_length.GetValue(cargo) != vlen)
		{
		eng.cargo_length.SetValue(cargo, vlen);
		DInfo("Setting "+eng.name+" length to "+vlen+" when handling "+AICargo.GetCargoLabel(cargo),2,"cEngine::SetRefitCost");
		}
	if (eng.cargo_price.GetValue(cargo) != cost)	update=true;
	if (update)
		{
		eng.cargo_price.SetValue(cargo, cost);
		DInfo("Setting "+eng.name+" refit costs to "+cost+" when handling "+AICargo.GetCargoLabel(cargo),2,"cEngine::SetRefitCost");
		}
	}

function cEngine::IsCompatible(engine, compareengine)
// return true/false if both are compatible
// can be use as valuator
	{
	local engO=cEngine.Load(compareengine);
	return !(engO.incompatible.HasItem(engine));
	}

function cEngine::GetPrice(engine, cargo=null)
// return the price to build an engine, add refit cost when we must refit the vehicle to handle cargo
// can be use as valuator
	{
	local eng=cEngine.Load(engine);
	if (engine==null)	return 0;
	if (cargo==null)	return AIEngine.GetPrice(engine);
	local refitcost=0;
	if (eng.cargo_price.HasItem(cargo))	refitcost=eng.cargo_price.GetValue(cargo);
	return (AIEngine.GetPrice(engine)+refitcost);
	}

function cEngine::CanPullCargo(engineID, cargoID)
// try to really answer if an engine can be use to pull a wagon of a cargo type
// if NicePlay is true we return the AIEngine.CanPullCargo version
// else we return real usable wagons list for a train
	{
	local NicePlay=DictatorAI.GetSetting("use_nicetrain");
	if (!AIEngine.IsValidEngine(engineID) || !AICargo.IsValidCargo(cargoID) || AIEngine.IsWagon(engineID))
		{ DError("Preconditions fail engineID="+engineID+" cargoID="+cargoID,2,"cEngine.CanPullCargo"); return false; }
	if (!NicePlay)	return AIEngine.CanPullCargo(engineID, cargoID);
	local engine=cEngine.Load(engineID);
	local wagonlist=AIEngineList(AIVehicle.VT_RAIL);
	wagonlist.Valuate(AIEngine.IsWagon);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(cEngine.IsCompatible, engineID);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.CanRefitCargo, cargoID);
	wagonlist.KeepValue(1);
	return (!wagonlist.IsEmpty());
	}

function cEngine::GetName(eID)
// return the name of the engine
	{
	local eng=cEngine.Load(eID);
	return eng.name;
	}

function cEngine::GetEUID(engineType, cargoID)
// return the EUID
// engineType : it's AIVehicle.GetEngineType() result for an engine except trains
// engineType : for trains it's RouteType.CHOPPER+1+Railtype value
// cargoID : for road/water/train it's the cargo ID
// cargoID : for aircraft it's the value of RouteType.AIR/AIRNET/CHOPPER
	{
	engineType++; // no 0 base results
	return (engineType*40)+cargoID; // 32 cargos only, so 40 is really enought
	}

function cEngine::GetEngineByCache(engineType, cargoID)
// return the top engine if we knows it already
// return -1 if we have no match
	{
	local EUID=cEngine.GetEUID(engineType, cargoID);
	if (cEngine.BestEngineList.HasItem(EUID))	return cEngine.BestEngineList.GetValue(EUID);
	return -1;
	}

function cEngine::EngineCacheInit()
// browse vehicle so our cache will get fill
	{
	local cargoList=AICargoList();
	local engList=AIEngineList(AIVehicle.VT_ROAD);
	engList.AddList(AIEngineList(AIVehicle.VT_RAIL));
	DInfo("Caching engines: "+engList.Count(),0,"");
	foreach (engID, dummy in engList)	local dum=cEngine.GetName(engID);
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
			if (oldvalue != engineID)	DInfo("Setting new top engine for EUID #"+EUID+" to "+engineID+" - "+cEngine.GetName(engineID),2,"cEngine::SetBestEngine");
			}
		else	cEngine.BestEngineList.AddItem(EUID, engineID);
	}

function cEngine::RailTypeIsTop(engineID, cargoID, setTopRail)
// Check if we could use another train with a better engine by changing railtype
// setTopRail : true to set it, false to only grab the value
// return -1 if we are at top already
// return the engineID if we could upgrade
	{
	if (cargoID==null)	return -1;
	if (AIEngine.GetVehicleType(engineID)!=AIVehicle.VT_RAIL)	return -1;
	local EUID=cEngine.GetEUID(RouteType.RAIL, cargoID);
	local topengine=engineID;
	if (!cEngine.BestEngineList.HasItem(EUID))	setTopRail=true;
	if (setTopRail)	cEngine.SetBestEngine(EUID, engineID);
	topengine=cEngine.BestEngineList.GetValue(EUID);
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
	if (cargoID==null)	return -1;
	local vehicleType=AIEngine.GetVehicleType(engineID);
	local special=null;
	if (vehicleType==AIVehicle.VT_RAIL)
		{
		local RT=AIEngine.GetRailType(engineID);
		special=RT+RouteType.CHOPPER+1;
		}
	else	special=vehicleType;
	local EUID=cEngine.GetEUID(special, cargoID);
	local topengine=engineID;
	if (EUID==0)	return -1;	// on error say we're at top
	if (!cEngine.BestEngineList.HasItem(EUID))	setTopEngine=true;
	if (setTopEngine)	cEngine.SetBestEngine(EUID, engineID);
	topengine=cEngine.BestEngineList.GetValue(EUID);
	if (engineID == topengine)	return -1;
					else	return topengine;
	}

function cEngine::IsVehicleAtTop(vehID)
// Check if a vehicle is using the best engine already
// return -1 if the vehicle doesn't need upgrade
// return the better engineID if one exist
	{
	if (!AIVehicle.IsValidVehicle(vehID))	{ DError("Not a valid vehicle",2,"cEngine::GetVehicleEUID"); return -1; }
	local idx=cCarrier.VehicleFindRouteIndex(vehID);
	if (idx==null)	{ DError("Fail to find the route in use by this vehicle",2,"cEngine::IsVehicleAtTop"); return -1; }
	local road=cRoute.GetRouteObject(idx);
	local cargoID=road.cargoID;
	local vehType=AIVehicle.GetVehicleType(vehID);
	if (vehType==AIVehicle.VT_AIR)	cargoID=road.route_type;
	local engineID=AIVehicle.GetEngineType(vehID);
	return cEngine.EngineIsTop(engineID, cargoID, false);
	}


