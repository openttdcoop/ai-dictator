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

class cProfiling extends cClass
	{
	ticks	 = null;
	date	 = null;
	constructor()
		{
		ticks=AIController.GetTick();
		date = AIDate.GetCurrentDate();
		this.ClassName="cProfiling";
		DInfo("Task start at "+ticks+" ticks, "+date,1);
		}
	}

function cProfiling::Stop()
{
	local nticks=AIController.GetTick();
	local ndate=AIDate.GetCurrentDate();
	DInfo("Task end at "+nticks+", tooked "+(nticks-this.ticks)+" ticks, "+(ndate-this.date)+" days",1);
}

class cLooper extends cClass
// This class increase a counter, once value is met, it call AIController.Sleep.
// Creating this class inside a loop then gave a tiny break in the loop
	{
	static	tickCounter = [0];
	constructor()
		{
		this.ClassName = "cLooper";
		local fetch = cLooper.tickCounter[0];
		fetch++;
		if (fetch > 200)	{ ::AIController.Sleep(1); fetch = 0; DInfo("Resting...",2); }
		cLooper.tickCounter[0]=fetch;
		}
	}
