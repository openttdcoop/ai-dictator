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

class cStationRoad extends cStation
{
	constructor()
		{
		::cStation.constructor();
		this.ClassName	= "cStationRoad";
		}
}

function cStationRoad::GetRoadStationEntry(entrynum=-1)
// return the front road station entrynum
{
	if (entrynum == -1)	entrynum=this.s_Tiles.Begin();
	return this.s_Tiles.GetValue(entrynum);
}


