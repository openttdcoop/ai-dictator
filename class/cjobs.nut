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



class cJobs extends cClass
{
static	database = {};
static	jobIndexer = AIList();	// this list have all UID in the database, value = date of last refresh for that UID infos
static	jobDoable = AIList();	// same as upper, but only doable ones, value = ranking
static	distanceLimits = [0, 0];// store [min, max] distances we can do, share to every instance so we can discover if this change
static	TRANSPORT_DISTANCE=[60,150,250, 40,80,150, 40,100,130, 80,200,300]; // 130 max before water report dest_too_far
static	CostTopJobs = [0,0,0,0];// price of best job for rail, road, water & air
static	badJobs=AIList();		// List of jobs we weren't able to do
static	WagonType=AIList();		// engine wagon to use for cargo : item=cargo, value= wagon engine id
static	rawJobs=AIList();		// Primary jobs list, item (if industry=industryID, if town=townID+10000), value 0=done, >0=need handling
static	TownAbuse = AIList();	// List of towns we use already to drop/take passenger/mail
static	deadIndustry = AIList();// List all industries that are dead and so jobs using them need to be removed


static	function GetJobObject(UID)
		{
		return UID in cJobs.database ? cJobs.database[UID] : null;
		}

	Name			= null;	// name of jobs
	sourceObject	= null;	// source process object
	targetObject	= null;	// target process object
	cargoID		    = null;	// cargo id
	roadType		= null;	// RouteType type
	UID			    = null;	// a UID for the job
	parentID		= null;	// a UID that a similar job will share with another (like other tansport or other destination)
	isUse			= null;	// is build & in use
	cargoValue		= null;	// value for that cargo
	cargoAmount		= null;	// amount of cargo at source
	distance		= null;	// distance from source to target
	moneyToBuild	= null;	// money need to build the job
	moneyGains		= null;	// money we should grab from doing the job
	isdoable		= null;	// true if we can actually do that job (if isUse -> false)
	ranking		    = null;	// our ranking system
	subsidy	    	= null;	// the subsity id aiming that job

	constructor()
		{
		this.ClassName	= "cJobs";
		Name			= "unknown job";
		sourceObject	= null;
		targetObject	= null;
		cargoID	    	= null;
		roadType		= null;
		UID			    = null;
		parentID		= 0;
		isUse			= false;
		subsidy		    = null;
		cargoValue		= 0;
		cargoAmount		= 0;
		distance		= 0;
		moneyToBuild	= 0;
		moneyGains		= 0;
		isdoable		= true;
		ranking		    = 0;
		}
}

