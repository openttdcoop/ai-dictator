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

// handle cargos

class cCargo extends cClass
	{
static	primaryCargo=[null,null,0,2]; // 0-passengerCargo, 1-mailCargo, 2-favoriteCargo 3-favoriteBonus

	constructor()
		{
		this.ClassName="cCargo";
		}
	}

function cCargo::GetCargoFavorite()
// return the favorite cargo set
{
	return cCargo.primaryCargo[2];
}

function cCargo::GetCargoFavoriteBonus()
// return the favorite cargo set
{
	return cCargo.primaryCargo[3];
}

function cCargo::SetCargoFavoriteBonus(nbonus = 1)
// Set the bonus for production cargo, reset to 1 if no value is given
{
	cCargo.primaryCargo[3]=nbonus;
}

function cCargo::SetCargoFavorite(cargoid = -1)
// Set our favorite cargo, this gave it a bonus
{
	local cargo_favorite=cCargo.GetCargoFavorite();
	if (cargo_favorite == cargoid)	return;
	if (cargoid == -1)
		{
		local crglist=AICargoList();
		crglist.Valuate(AIBase.RandItem);
		cargoid=crglist.Begin();
		}
	cargo_favorite=cargoid;
	cCargo.primaryCargo[2]=cargoid;
	DInfo("We will now promote "+cCargo.GetCargoLabel(cargo_favorite),0);
}

function cCargo::GetMailCargo()
// Return the cargo ID for mail
	{
	if (cCargo.primaryCargo[1] != null || cCargo.primaryCargo[1] == -1)	return cCargo.primaryCargo[1];
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist)	if (AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL) { cCargo.primaryCargo[1]=cargo; break; }
	if (cCargo.primaryCargo[1] == null)	{ DError("Cannot find mail cargo",1); cCargo.primaryCargo[1]=-1; return -1; }
						else	DInfo("Mail cargo set to "+cCargo.primaryCargo[1]+"-"+AICargo.GetCargoLabel(cCargo.primaryCargo[1]),0);
	return cCargo.primaryCargo[1];
	}

function cCargo::GetPassengerCargo()
// Return the cargo ID for passenger
	{
	if (cCargo.primaryCargo[0] != null || cCargo.primaryCargo[0] == -1)	return cCargo.primaryCargo[0];
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist)	if (AICargo.GetTownEffect(cargo) == AICargo.TE_PASSENGERS) { cCargo.primaryCargo[0]=cargo; break; }
	if (cCargo.primaryCargo[0] == null)	{ DError("Cannot find passenger cargo",1); cCargo.primaryCargo[1]=-1; return -1; }
						else	DInfo("Passenger cargo set to "+cCargo.primaryCargo[0]+"-"+AICargo.GetCargoLabel(cCargo.primaryCargo[0]),0);
	return cCargo.primaryCargo[0];
	}


function cCargo::IsCargoForTown(cargo)
// return true if the cargo should be drop to a town
	{
	local effet= AICargo.GetTownEffect(cargo);
	if (effet == AICargo.TE_NONE || effet == AICargo.TE_WATER)	return false;
	return true;
	}

function cCargo::IsFreight(cargoID)
// Return -1 if !AICargo.IsFreight
// else return number of wagons need to add an extra engine depending on system setting
{
	local level=AIGameSettings.GetValue("freight_trains");
	if (level == 1)	return -1; // no need to handle freight then
	local freightlimit= 8 - level;
	if (freightlimit < 3)	freightlimit=2; // minimum 2 wagons
	if (AICargo.IsFreight(cargoID))	return freightlimit;
	return -1;
}

function cCargo::GetCargoLabel(cargo)
// return a formatted string for cargo
{
	return AICargo.GetCargoLabel(cargo)+"("+cargo+")";
}
