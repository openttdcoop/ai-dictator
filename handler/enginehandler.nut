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
static	enginedatabase = {};
static	engine_cache = [-1, -1, -1, -1, -1];
		// we cache engineID of last query for an engine type : train, wagon, road, air, water
static	function GetEngineObject(engineID)
		{
		return engineID in cEngine.enginedatabase ? cEngine.enginedatabase[engineID] : null;
		}

	engineID		= null;	// id of industry/town
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
		this.cargo_length.AddItem(crg, 8); // default to 8 size, classic size
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
	DInfo("List of known vehicles : "+(cEngine.enginedatabase.len()),1,"cEngine::Save");
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
return (!engO.incompatible.HasItem(engine));
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

