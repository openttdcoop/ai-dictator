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


// I've learned a lot from rondje's code about squirrel, thank you guys !

class cProcess extends cClass
	// Process are industries + towns
	{
		static	database = {};
		static	statueTown = AIList();			// list of towns we use, for statues, decrease everytime a statue is there

		UID			    = null;	// id of industry/town
		ID		    	= null;	// id of industry/town
		Name			= null;	// name of industry/town
		Location		= null;	// location of source
		CargoAccept		= null;	// item=cargoID
		CargoProduce	= null;	// item=cargoID, value=amount produce
		IsTown		    = null;	// True if it's a town
		UpdateDate		= null;	// Date of last refresh
		ScoreRating		= null;	// Score by rating for towns only
		ScoreProduction	= null;	// Score by production
		Score			= null;	// Total score
		FailureDate		= null;	// Last date we have building a station and it has fail
		IndustryType    = null; // 1 - produce, 2- accept, 3- both
		WaterAccess     = null; // true if we can use a dock to access it
		StationLocation = null; // this is the location of the station if one exist (dock/heliport)
		UsedBy			= null; // list of jobs UID using that process


		constructor()
			{
			this.ClassName	= "cProcess";
			// everything is init by AddNewProcess
			}
        function GetProcessObject(UID)  { return UID in cProcess.database ? cProcess.database[UID] : null; }
		function Load(uid) {}
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
    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	if (_istown)
			{
			if (!AITown.IsValidTown(_id)) { return; }
			p.Name = AITown.GetName(_id);
			p.Location=AITown.GetLocation(_id);
			if (AIMap.DistanceFromEdge(p.Location) < 50)
                {
                local tiles = cTileTools.GetTilesAroundPlace(p.Location, radius * 3);
                tiles.Valuate(AITile.IsCoastTile);
                tiles.KeepValue(1);
                p.WaterAccess = (!tiles.IsEmpty());
                }
			}
	else
			{
			if (!AIIndustry.IsValidIndustry(_id)) { return; }
			p.Name=AIIndustry.GetName(_id);
			p.Location=AIIndustry.GetLocation(_id);
		    if (AIIndustry.HasDock(_id))        { p.StationLocation = AIIndustry.GetDockLocation(_id); p.WaterAccess = true; }
            if (AIIndustry.HasHeliport(_id))    { p.StationLocation = AIIndustry.GetHeliportLocation(_id); }
			}
	p.Name+="("+p.ID+")";
	p.CargoProduce=AIList();
	p.CargoAccept=AIList();
	p.ScoreRating=1;
	p.ScoreProduction=0;
	p.CargoCheckSupply();
	// must be done after cargo is set
	if (!_istown && !p.WaterAccess && AIMap.DistanceFromEdge(p.Location) < 50)
        {
        local tiles = cTileTools.GetTilesAroundPlace(p.Location, (2* radius));
        tiles.Valuate(AITile.IsCoastTile);
        tiles.KeepValue(1);
        local cargo = -1;
        if (!p.CargoAccept.IsEmpty())
                {  // we need 1 valid cargo, better check acceptance first then
                cargo = p.CargoAccept.Begin();
                tiles.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, radius);
                tiles.KeepAboveValue(7);
                }
        else    {
                cargo = p.CargoProduce.Begin();
                tiles.Valuate(AITile.GetCargoProduction, cargo, 1, 1, radius);
                tiles.KeepAboveValue(0);
                }
        p.WaterAccess = !tiles.IsEmpty();
        }
	p.IndustryType = 0;
	if (!p.CargoAccept.IsEmpty())    p.IndustryType += 2;
	if (!p.CargoProduce.IsEmpty())  p.IndustryType += 1;
	p.UpdateDate=null;
	p.FailureDate = null;
	p.UsedBy = AIList();
	p.UpdateScore();
	p.Save();
	}

function cProcess::Load(uid)
// Try to load a uid if need, throw error if it fail
	{
	local obj=cProcess.GetProcessObject(uid);
	if (obj == null)
			{
			DWarn("cProcess.Load function return NULL with "+uid,1);
			return false;
			}
	return obj;
	}

function cProcess::GetProcessUsage(uid, istown)
// Return the list of jobs using that process
	{
	local puid = cProcess.GetUID(uid, istown)
	local p = cProcess.Load(puid);
	if (!p) { return -1; }
	return p.UsedBy;
	}

function cProcess::GetProcessName(uid, istown)
// Return process name
	{
	local puid = cProcess.GetUID(uid, istown);
	local p = cProcess.Load(puid);
	if (!p)	{ return "Unknown name"; }
	return p.Name;
	}

function cProcess::DeleteProcess(uid=null)
// Remove a process
	{
	local obj=cProcess.Load(uid);
	if (!obj)	{ return false; }
	DInfo("Removing process #"+uid+" from database",2);
	delete cProcess.database[uid];
	}

// private

function cProcess::GetAmountOfCompetitorStationAround(IndustryID)
// Like AIIndustry::GetAmountOfStationAround but doesn't count our stations, so we only grab competitors stations
// return 0 or numbers of stations not own by us near the place
{
	local counter=0;
	local place = AIIndustry.GetLocation(IndustryID);
	local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
	local tiles = AITileList();
	local produce = AITileList_IndustryAccepting(IndustryID, radius);
	local accept = AITileList_IndustryProducing(IndustryID, radius);
	tiles.AddList(produce);
	tiles.AddList(accept);
	tiles.Valuate(AITile.IsStationTile); // force keeping only station tile
	tiles.KeepValue(1);
	tiles.Valuate(AIStation.GetStationID);
	local uniq = AIList();
	foreach (i, dummy in tiles)
		{ // remove duplicate id
		if (!uniq.HasItem(dummy))	uniq.AddItem(dummy, i);
		}
	uniq.Valuate(AIStation.IsValidStation);
	uniq.KeepValue(0); // remove our station tiles
	return uniq.Count();
}

function cProcess::UpdateScoreRating()
// Update the Rating score
	{
	if (this.IsTown)
			{
			local rate = AITown.GetRating(this.ID, AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
			if (rate == AITown.TOWN_RATING_NONE)	{ rate=AITown.TOWN_RATING_GOOD; }
			if (rate < AITown.TOWN_RATING_POOR)	{ rate = 0; }
			this.ScoreRating = 10 * rate;
			}
	else	{
            local competitor = cProcess.GetAmountOfCompetitorStationAround(this.ID);
            local us = AIIndustry.GetAmountOfStationsAround(this.ID) - competitor;
            switch (this.IndustryType)
                {
                case    1: // only produce
                    switch (INSTANCE.fairlevel)
                        {
                        case	0:
                            this.ScoreRating= 80 - (80 * competitor);	// give up when 1 station is present
                        break;
                        case	1:
                            this.ScoreRating= 80 - (40 * competitor);	// give up when 2
                        break;
                        case	2:
                            this.ScoreRating= 80 - (20 * competitor);	// give up after 4
                        break;
                        }
                break;
                case    2: // only accept
                        this.ScoreRating = 80 - (competitor * 15); // at 6 it's crowd and free tiles get rare
                        this.ScoreRating = max(1, this.ScoreRating); // but even crowd, keep a little chance to consider it to drop cargo
                break;
                case    3: // both
                        this.ScoreRating = 80 - (competitor * 10);
                        this.ScoreRating += 50 * us; // give a great bonus if we are doing job there already
                        if (INSTANCE.fairlevel == 0)    { this.ScoreRating = 0; } // Reserve the job for the poor user only
                                                else    { this.ScoreRating = max(1, this.ScoreRating); }
                break;
                }

            }
	}

function cProcess::UpdateScoreProduction()
// Update the production score
	{
	local best=0;
	local bestcargo=-1;
	local temp = AIList();
	temp.AddList(this.CargoProduce);
	foreach (cargoID, value in temp)
		{
		local current = 0;
		if (this.IsTown)	{ current = AITown.GetLastMonthProduction(this.ID, cargoID); }
                    else	{
                            current= AIIndustry.GetLastMonthProduction(this.ID, cargoID);
                            if (INSTANCE.fairlevel == 0)    current -= AIIndustry.GetLastMonthTransported(this.ID, cargoID);
                            // reduce it for fair game setting
                            if (this.IndustryType == 2) { current = 1; } // force non-zero to allow only receiving industry get a rank > 0
                            }
		if (best < current)	{ best=current; bestcargo=cargoID; }
		this.CargoProduce.SetValue(cargoID, current);
		}
	this.ScoreProduction = best;
//	if (bestcargo == cCargo.GetCargoFavorite())	{ this.ScoreProduction = best * cCargo.GetCargoFavoriteBonus(); }
//                                       else	{ this.ScoreProduction = best; }
	}

function cProcess::UpdateScore()
// Update score
	{
	if (this.UpdateDate != null && AIDate.GetCurrentDate() - this.UpdateDate < 7)	{ DInfo("Fresh score for "+this.Name,4); return false; }
	this.UpdateScoreRating();
	this.UpdateScoreProduction();
	this.Score = this.ScoreRating * this.ScoreProduction;
	if (this.Score < 0)	{ this.Score=0; }
	local now = AIDate.GetCurrentDate();
	this.UpdateDate = now;
	if (this.FailureDate != null)
			{
			this.Score = 0;
			if (now - this.FailureDate > 365)	{ this.FailureDate=null; }
			}
	DInfo("Update score for "+this.Name+" to "+this.Score+" Rating="+this.ScoreRating+" Prod="+this.ScoreProduction,3);
	}

function cProcess::ZeroProcess()
// Set the process as bad
	{
	this.FailureDate = AIDate.GetCurrentDate();
	this.UpdateDate = null;
	this.ScoreRating = 0;
	this.Score = 0;
	}

function cProcess::CargoCheckSupply()
// Check and add cargo the process could handle
	{
	local type = 0;
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
            type = 3;
			}
	else
			{
			this.CargoAccept=AICargoList_IndustryAccepting(this.ID);
			local cargoList= AICargoList_IndustryProducing(this.ID);
			foreach (cargo, _ in cargoList)	this.CargoProduce.AddItem(cargo, 0);
			}
	}

function cProcess::Save()
// save the industry/town
	{
	if (this.UID in database)
			{
			DWarn("Process "+this.UID+" "+this.Name+" already in database",2);
			}
	else
			{
			DInfo("Adding process "+this.Score+"-"+this.Name+" to database",2);
			cProcess.database[this.UID] <- this;
			}
	}

function cProcess::GetUID(_id, _istown)
// Create a UID for industry
	{
	local uID=_id;
	if (typeof(uID) == "integer" && _istown)	{ uID+=10000; }
	return uID;
	}

