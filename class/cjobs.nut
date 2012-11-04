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



class cJobs extends cClass
{
static	database = {};
static	jobIndexer = AIList();	// this list have all UID in the database, value = date of last refresh for that UID infos
static	jobDoable = AIList();	// same as upper, but only doable ones, value = ranking
static	distanceLimits = [0, 0];// store [min, max] distances we can do, share to every instance so we can discover if this change
static	TRANSPORT_DISTANCE=[60,150,250, 40,100,150, 60,120,250, 90,250,500];
static	CostTopJobs = [0,0,0,0];// price of best job for rail, road, water & air
static	badJobs=AIList();		// List of jobs we weren't able to do
static	rawJobs=AIList();		// Primary jobs list, item (if industry=industryID, if town=townID+10000), value 0=done, >0=need handling
static	targetTown = AIList();	// List of towns we use as target to drop/take passenger/mail by bus & aircraft


static	function GetJobObject(UID)
		{
		return UID in cJobs.database ? cJobs.database[UID] : null;
		}

	sourceObject	= null;	// source process object
	targetObject	= null;	// target process object
	cargoID		= null;	// cargo id
	roadType		= null;	// AIVehicle.RoadType
	UID			= null;	// a UID for the job
	parentID		= null;	// a UID that a similar job will share with another (like other tansport or other destination)
	isUse			= null;	// is build & in use
	cargoValue		= null;	// value for that cargo
	cargoAmount		= null;	// amount of cargo at source
	distance		= null;	// distance from source to target
	moneyToBuild	= null;	// money need to build the job
	moneyGains		= null;	// money we should grab from doing the job
	isdoable		= null;	// true if we can actually do that job (if isUse -> false)
	ranking		= null;	// our ranking system
	foule			= null;	// number of opponent/stations near it
	subsidy		= null;	// the subsity id aiming that job

	constructor()
		{
		this.ClassName	= "cJobs";
		sourceObject	= null;
		targetObject	= null;
		cargoID		= null;
		roadType		= null;
		UID			= null;
		parentID		= 0;
		isUse			= false;
		subsidy		= null;
		cargoValue		= 0;
		cargoAmount		= 0;
		distance		= 0;
		moneyToBuild	= 0;
		moneyGains		= 0;
		isdoable		= true;
		ranking		= 0;
		foule			= 0;
		}
}

