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



class cBasicStation
	{
static	database = {};
static	jobIndexer = AIList();	// this list have all uniqID in the database, 1 when doable as value
static	jobDoable = AIList();	// same as upper, but all 0 are gone and now value = ranking
static	distanceLimits = [0, 0];	// store [min, max] distances we can do, share to every instance so we can discover if this change
static	TRANSPORT_DISTANCE=[50,150,200, 40,80,110, 40,90,150, 50,150,200];


static	function GetJobObject(uniqID)
		{
		return uniqID in cJobs.database ? cJobs.database[uniqID] : null;
		}

	sourceID = null;	// id of industry/town
	source_location= null;	// location of source
	targetID = null;	// id of industry/town
	target_location = null;	// location of target
	cargoID = null;		// cargo id
	roadType = null;	// AIVehicle.RoadType + 256 for aircraft network
	uniqID = null;		// a uniqID for the job
	parentID = null;	// a uniqID that a similar job will share with another similar (like other tansport or other destination)
	isUse = false;		// is build & in use
	cargoValue = 0;		// value for that cargo
	cargoAmount = 0;	// amount of cargo at source
	distance = 0;		// distance from source to target
	moneyToBuild = 0;	// money need to build the job
	moneyGains = 0;		// money we should grab from doing the job
	source_istown = null;	// if source is a town
	target_istown = null;	// if target is a town
	isdoable = true;	// true if we can actually do that job (if isUse -> false)
	ranking = 0;		// our ranking system
	foule = 0;		// number of opponent/stations near it

	constructor()
		{
		//CheckLimitedStatus();
		}
}

class cRawStation
	{
	id = null;
	
