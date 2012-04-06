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

// handle cargos

class cCargo
	{
static	primaryCargo=[null,null]; // 0 for passenger, 1 for mail

	constructor()	{ }
	}

function cCargo::GetMailCargo()
// Return the cargo ID for mail
	{
	if (cCargo.primaryCargo[1] != null)	return cCargo.primaryCargo[1];
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist)	if (AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL) { cCargo.primaryCargo[1]=cargo; break; }
	if (cCargo.primaryCargo[1] == null)	DError("Cannot find mail cargo",1,"cCargo::GetMailCargo");
						else	DInfo("Mail cargo set to "+cCargo.primaryCargo[1]+"-"+AICargo.GetCargoLabel(cCargo.primaryCargo[1]),0,"cCargo::GetMailCargo");
	return cCargo.primaryCargo[1];
	}

function cCargo::GetPassengerCargo()
// Return the cargo ID for passenger
	{
	if (cCargo.primaryCargo[0] != null)	return cCargo.primaryCargo[0];
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist)	if (AICargo.GetTownEffect(cargo) == AICargo.TE_PASSENGERS) { cCargo.primaryCargo[0]=cargo; break; }
	if (cCargo.primaryCargo[0] == null)	DError("Cannot find passenger cargo",1,"cCargo::GetPassengerCargo");
						else	DInfo("Passenger cargo set to "+cCargo.primaryCargo[0]+"-"+AICargo.GetCargoLabel(cCargo.primaryCargo[0]),0,"cCargo::GetPassengerCargo");
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
print("freightlimit="+freightlimit);
if (AICargo.IsFreight(cargoID))	return freightlimit;
return -1;
}

