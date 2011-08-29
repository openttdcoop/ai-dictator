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
static	function GetEngineObject(engineID)
		{
		return engineID in cEngine.enginedatabase ? cEngine.enginedatabase[engineID] : null;
		}

	engineID		= null;	// id of industry/town
	name			= null;	// name
	length		= null;	// size of the engine
	price			= null;	// As AIEngine.GetPrice, but may add the refit cost to the price
	cargo_list		= null;	// cargo_list item=cargoID, value=capacity when refit
	cargo_price		= null;	// price to refit item=cargoID, value=refit cost
	isKnown		= null;	// true if we know it already
	incompatible	= null;	// AIList of wagons imcompatible with a train engine
	
	constructor()
		{
		engineID		= null;
		name			= "unknow";
		length		= 14; // max size i saw for a wagon
		price			= 0;
		cargo_list		= AIList();
		cargo_price		= AIList();
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
		this.cargo_price.AddItem(crg,-1); // so we knows if we ever met that cargo refit price yet (see SetRefitCost)
		if (AIEngine.CanRefitCargo(this.engineID, crg))
				this.cargo_list.AddItem(crg,255);
				// 255 so it will appears to be a top carrier if not test yet
			else	this.cargo_list.AddItem(crg,0);
		}
	local crgtype=AIEngine.GetCargoType(this.engineID);
	this.cargo_list.SetValue(crgtype, AIEngine.GetCapacity(this.engineID));
	this.name=AIEngine.GetName(this.engineID);
	this.price=AIEngine.GetPrice(this.engineID);
	cEngine.enginedatabase[this.engineID] <- this;
	DInfo("Adding "+this.name+" to cEngine database",2,"cEngine:Save");
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
	
function cEngine::GetLength(eID)
	{
	local eng=cEngine.Load(eID);
	return eng.length;
	}

function cEngine::Update(vehID)
	{
	local new_engine=AIVehicle.GetEngineType(vehID);
	local engObj=cEngine.Load(new_engine);
	//print("new_engine="+new_engine+" know="+engObj.isKnown);
	if (engObj.isKnown)	return;
	DInfo("Grabbing vehicle properties for "+engObj.name,1,"cEngine::Update");
	engObj.length=AIVehicle.GetLength(vehID);
	local crgList=AICargoList();
	foreach (cargoID, dummy in crgList)
		{
		local testing=AIVehicle.GetRefitCapacity(vehID, cargoID);
		if (testing < 0)	testing=0;
		engObj.cargo_list.SetValue(cargoID, testing);
		}
	engObj.isKnown=true;
	}

function cEngine::GetCapacity(eID, cargoID=null)
// can be use as valuator
	{
	local engObj=cEngine.Load(eID);
	if (cargoID==null)	cargoID=AIEngine.GetCargoType(eID); // return current capacity
	return engObj.cargo_list.GetValue(cargoID);
	}

function cEngine::Incompatible(eng1, eng2)
// mark eng1 incompatible with eng2 (one must be a wagon, other must not)
{
if ( !(AIEngine.IsWagon(eng1) && AIEngine.IsWagon(eng2)) || (!AIEngine.IsWagon(eng1) && AIEngine.IsWagon(eng2)) )
	{ DError("One engine must be a wagon and the other must not",1,"cEngine::Incompatible"); return false; }
local eng1O=cEngine.Load(eng1);
local eng2O=cEngine.Load(eng2);
eng1O.incompatible.AddItem(eng2);
eng2O.incompatible.AddItem(eng1);
DInfo("Setting "+eng1O.name" incompatible with "+eng2O.name,2,"cEngine::Incompatible");
}

function cEngine::SetRefitCost(engine, cargo, cost)
// set the refit cost for an engine to use cargo
// per default, assume all refit costs will be == for all cargos
{
local eng=cEngine.Load(engine);
if (eng.cargo_price.GetValue(cargo) == -1) // this test prove we never met a refitprice for that engine
	foreach (crg, refitprice in eng.cargo_price)	if (refitprice == -1)	eng.cargo_price.SetValue(crg, cost);
eng.cargo_price.SetValue(cargo, cost);
DInfo("Setting refit cost to "+cost+" to handle "+AICargo.GetCargoLabel(cargo)+" for "+eng.name,2,"cEngine::SetRefitCost");
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
if (cargo==null)	return eng.price;
local refitcost=0;
if (eng.cargo_price.HasItem(cargo))	refitcost=eng.cargo_price.GetValue(cargo);
return eng.price+refitcost;
}

