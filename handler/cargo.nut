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


class cCargo
	{
	constructor()	{ }
	}

function cCargo::GetMailCargo()
// Return the cargo ID for mail
	{
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist)	if (AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL) return cargo;
	return null;
	}

function cCargo::GetPassengerCargo()
// Return the cargo ID for passenger
	{
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist)	if (AICargo.GetTownEffect(cargo) == AICargo.TE_PASSENGERS) return cargo;
	return null;
	}


function cCargo::IsCargoForTown(cargo)
// return true if the cargo should be drop to a town
	{
	local effet= AICargo.GetTownEffect(cargo);
	if (effet == AICargo.TE_NONE || effet == AICargo.TE_WATER)	return false;
	return true;
	}


