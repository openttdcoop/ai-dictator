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

class cRailAnalyzer
{
static	RailList = AIList();		// list of rails, item=tile index, value=owner route or -1 if none own it

	railUID		= null;	// it's tile index
	ownerRoute		= null;	// the companyID of the owner of the bridge
	
	constructor()
		{
		}
}

function cRailAnalyzer::FindRailOwner(tilelist)
// find all rails owner from the tilelist of rails provide
{

}

