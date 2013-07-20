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

class cBuilder extends cClass
	{
	currentRoadType=null;
	
	statile=null;
	stafront = null;
	deptile=null;
	depfront=null;
	statop=null;
	stabottom=null;
	stationdir=null;
	frontfront=null;
	CriticalError=null;
	holestart=null;
	holeend=null;
	holes=null;
	savedepot = null; 		// the tile of the last depot we have build
	building_route= null;		// Keep here what main.route.we are working on
	
	constructor()
		{
		building_route= -1;
		this.ClassName="cBuilder";
		}
	}

function cBuilder::SetRailType(rtype=null)
// set current railtype
{
	if (rtype == null)
		{
		local railtypes = AIRailTypeList();
		if (railtypes.IsEmpty())	{ DWarn("There's no railtype available !",1); return false; }
		rtype=railtypes.Begin();
		}
	if (!AIRail.IsRailTypeAvailable(rtype))	{ DWarn("Railtype "+rtype+" is not available !",1); return false; }
	AIRail.SetCurrentRailType(rtype);
}

