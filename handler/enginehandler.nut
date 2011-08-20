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
	cargo_list		= null;	// cargo_list item=cargoID, value=capacity when refit
	isKnown		= null;	// true if we know it already
	
	constructor()
		{
		engineID		= null;
		name			= null;
		length		= 14; // max size i saw for a wagon
		cargo_list		= AIList();
		isKnown		= false;
		}
}

function cEngine::Save()
// Save the engine in the database
	{
	if (this.engineID == null)	{ this.isKnown=true; return; }
	if (this.engineID in cEngine.enginedatabase)	return;
	local crglist=AICargoList();
	foreach (crg, dummy in crglist)
		if (AIEngine.CanRefitCargo(this.engineID, crg))	this.cargo_list.AddItem(crg,255);
						// 255 so it will appears to be a top carrier if not test yet
										else	this.cargo_list.AddItem(crg,0);
	local crgtype=AIEngine.GetCargoType(this.engineID);
	this.cargo_list.SetValue(crgtype, AIEngine.GetCapacity(this.engineID));
	this.name=AIEngine.GetName(this.engineID);
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
	print("new_engine="+new_engine+" know="+engObj.isKnown);
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
