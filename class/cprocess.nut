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


// I've learned a lot from rondje's code about squirrel, thank you guys !

class cProcess extends cClass
// Process are industries + towns
{
static	database = {};
static	statueTown = AIList();			// list of towns we use, for statues, decrease everytime a statue is there

static	function GetProcessObject(UID)
		{
		return UID in cProcess.database ? cProcess.database[UID] : null;
		}

	UID			= null;	// id of industry/town
	ID			= null;	// id of industry/town
	Name			= null;	// name of industry/town
	Location		= null;	// location of source
	CargoAccept		= null;	// item=cargoID
	CargoProduce	= null;	// item=cargoID, value=amount produce
	IsTown		= null;	// True if it's a town
	Tracking		= null;	// True to track cargo infos about that industry
	ScoreRating		= null;	// Score by rating for towns only
	ScoreProduction	= null;	// Score by production
	Score			= null;	// Total score


	constructor()
		{
		this.ClassName	= "cProcess";
		}
}

function cProcess::GetProcessList_ProducingCargo(cargoid)
// return an AIList of process that produce that cargo
{
	local cargoList=AIIndustryList_CargoProducing(cargoid);
	local townList=AITownList();
	local cpass=cCargo.GetPassengerCargo();
	local cmail=cCargo.GetMailCargo();
	if ( (cpass != -1 && cpass == cargoid) || (cmail != -1 && cmail == cargoid) )
		{
		foreach (townID, _ in townList)	cargoList.AddItem(townID+10000,0);
		}
	return cargoList;
}

function cProcess::GetProcessList_AcceptingCargo(cargoid)
// return an AIList of process that accept that cargo
{
	local cargoList=AIIndustryList_CargoAccepting(cargoid);
	local townList=AITownList();
	local cpass=cCargo.GetPassengerCargo();
	local cmail=cCargo.GetMailCargo();
	if ( (cpass != -1 && cpass == cargoid) || (cmail != -1 && cmail == cargoid) )
		{
		foreach (townID, _ in townList)	cargoList.AddItem(townID+10000,0);
		}
	return cargoList;
}

function cProcess::AddNewProcess(_id, _istown)
// Add a new process
{
	local p = cProcess();
	p.ID = _id;
	p.IsTown = _istown;
	p.UID = p.GetUID(_id, _istown);
	if (_istown)	
		{
		if (!AITown.IsValidTown(_id)) return;
		p.Name = AITown.GetName(_id);
		p.Location=AITown.GetLocation(_id);
		cProcess.statueTown.AddItem(p.ID,0);
		}
	else	{
		if (!AIIndustry.IsValidIndustry(_id)) return;
		p.Name=AIIndustry.GetName(_id);
		p.Location=AIIndustry.GetLocation(_id);
		}
	p.Name+="("+p.ID+")";
	p.Tracking=true;
	p.CargoProduce=AIList();
	p.CargoAccept=AIList();
	p.ScoreRating=1;
	p.ScoreProduction=0;
	p.CargoCheckSupply();
	p.UpdateScore();
	p.Save();
}

function cProcess::Load(uid)
// Try to load a uid if need, throw error if it fail
{
	local obj=null;
	if (uid == null)	obj=this;
			else	obj=cProcess.GetProcessObject(uid);
	if (obj == null)
		{
		DWarn("cProcess.Load function return NULL",1);
		return false;
		}
	return obj;
}

function cProcess::DeleteProcess(uid=null)
// Remove a process
{
	local obj=cProcess.Load(uid);
	if (!obj)	return false;
	DInfo("Removing process #"+uid+" from database",2);
	delete cProcess.database[uid];
}

// private

function cProcess::UpdateScoreRating(uid=null)
// Update the Rating score
{
	local obj=cProcess.Load(uid);
	if (!obj)	return false;
	if (obj.IsTown)	{
				local rate = AITown.GetRating(obj.ID, AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
				if (rate == AITown.TOWN_RATING_NONE)	rate=AITown.TOWN_RATING_GOOD;
				if (rate < AITown.TOWN_RATING_POOR)	rate = 0;
				obj.ScoreRating = 0 + (80 * rate);
print("town rate="+rate+" score="+obj.ScoreRating);
				}
			else	switch (INSTANCE.fairlevel)
				{	
				case	0:
					obj.ScoreRating= 500 - (500 * AIIndustry.GetAmountOfStationsAround(obj.ID));	// give up when 1 station is present
				break;
				case	1:
					obj.ScoreRating= 500 - (250 * AIIndustry.GetAmountOfStationsAround(obj.ID));	// give up when 2 stations are there
				break;
				case	2:
					obj.ScoreRating= 500 - (100 * AIIndustry.GetAmountOfStationsAround(obj.ID));	// give up after 5 stations
				break;
				}
if (obj.ScoreRating < 0)	obj.ScoreRating=0;
}

function cProcess::UpdateScoreProduction(uid=null)
// Update the production score
{
	local obj=cProcess.Load(uid);
	if (!obj)	return false;
	local best=0;
	local bestcargo=-1;
	foreach (cargoID, value in obj.CargoProduce)
		{
		local api=null;
		if (obj.IsTown)	api=AITown;
				else	api=AIIndustry;
		local current= api.GetLastMonthProduction(obj.ID, cargoID);
		if (best < current)	{ best=current; bestcargo=cargoID; }
		obj.CargoProduce.SetValue(cargoID, current);
		}
	if (bestcargo == cCargo.GetCargoFavorite())	obj.ScoreProduction = best * cCargo.GetCargoFavoriteBonus();
								else	obj.ScoreProduction = best;
}

function cProcess::UpdateScore(uid=null)
// Update score
{
	local obj=cProcess.Load(uid);
	if (!obj)	return false;
	obj.UpdateScoreRating();
	if (obj.Tracking)	obj.UpdateScoreProduction();
	obj.Score = obj.ScoreRating * obj.ScoreProduction;
print("score ="+obj.Score+" rating="+obj.ScoreRating+" prod="+obj.ScoreProduction);
	if (obj.Score < 0)	obj.Score=0;
}

function cProcess::CargoCheckSupply()
// Check and add cargo the process could handle
{
	if (this.IsTown)
		{
		local pass=cCargo.GetPassengerCargo();
		if (AICargo.IsValidCargo(pass))
			{
			this.CargoAccept.AddItem(pass,0);
			this.CargoProduce.AddItem(pass, 0);
			}
		local mail=cCargo.GetMailCargo();
		if (AICargo.IsValidCargo(mail))
			{
			this.CargoAccept.AddItem(mail,0);
			this.CargoProduce.AddItem(mail, 0);
			}
		}
	else	{
		this.CargoAccept=AICargoList_IndustryAccepting(this.ID);
		local cargoList= AICargoList_IndustryProducing(this.ID);
		foreach (cargo, _ in cargoList)	this.CargoProduce.AddItem(cargo, 0);
		}
}

function cProcess::Save()
// save the industry/town
	{
	if (this.UID in database)
			DWarn("Process "+this.UID+" "+this.Name+" already in database",2);
		else	{
			DInfo("Adding process "+this.Score+"-"+this.Name+" to database",2);
			cProcess.database[this.UID] <- this;
			}
	}

function cProcess::GetUID(_id, _istown)
// Create a UID for industry
	{
	local uID=_id;
	if (_istown)	uID+=10000;
	return uID;
	}

