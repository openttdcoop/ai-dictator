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


class cClass
	{
		ClassName	= null;

		constructor()
			{
			this.ClassName = "cClass";
			}
	}

function cClass::GetName()
	{
	return this.ClassName;
	}

function cClass::DInfo(putMsg, debugValue=0)
// just output AILog message depending on debug level
	{
	INSTANCE.DInfo(putMsg, debugValue, this.GetName());
	}

function cClass::DError(putMsg,debugValue=1)
// just output AILog message depending on debug level
	{
	INSTANCE.DError(putMsg, debugValue, this.GetName());
	}

function cClass::DWarn(putMsg, debugValue=1)
// just output AILog message depending on debug level
	{
	INSTANCE.DWarn(putMsg, debugValue, this.GetName());
	}

class cMain extends cClass
	{
		bank		= null;
		builder	    = null;
		carrier	    = null;
		route		= null;
		jobs		= null;
		bridge	    = null;
		cargo		= null;
		SCP	    	= null;
		event		= null;

		constructor()
			{
			this.ClassName = "cMain";
			SCP = cSCP();
			bank = cBanker();
			builder = cBuilder();
			carrier = cCarrier();
			jobs = cJobs();
			route = cRoute();
			bridge = cBridge();
			cargo = cCargo();
			event = cEvents();
			}
	}

function cMain::Init()
	{
	cEngineLib.EngineCacheInit();
	SCP.Init();
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	builder.SetRailType();
	route.RouteInitNetwork();
	cargo.SetCargoFavorite();
	local pList=AITownList();
	foreach (pID, dummy in pList)	cProcess.AddNewProcess(pID, true);
	local pList=AIIndustryList();
	foreach (pID, dummy in pList)	cProcess.AddNewProcess(pID, false);
	SCP.WaitReady();
	}

function cMain::CheckAccount()
	{
	local ourLoan = AICompany.GetLoanAmount();
	local maxLoan = AICompany.GetMaxLoanAmount();
	local cash = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	local goodcash = bank.mincash;
	if (ourLoan == 0 && cash >= bank.mincash)	{ bank.unleash_road=true; }
	if (!cBanker.CanBuyThat(goodcash))	{ DInfo("Low on cash, disabling build : "+goodcash,1); bank.canBuild=false; }
	if (ourLoan +(4*AICompany.GetLoanInterval()) < maxLoan)	{ bank.canBuild=true; }
	if (maxLoan > 2000000 && ourLoan > 0 && route.RouteIndexer.Count() > 6)
			{ DInfo("Trying to repay loan",1); bank.canBuild=false; } // wait to repay loan
	local veh=AIVehicleList();
	if (bank.busyRoute)	{ DInfo("Delaying build: we have work to do with vehicle : money="+carrier.vehnextprice,1); bank.canBuild=false; }
	if (INSTANCE.buildDelay > 0)	{ DInfo("Builds delayed: "+INSTANCE.buildDelay,1); bank.canBuild=false; }
	if (carrier.vehnextprice >0 && !cBanker.CanBuyThat(carrier.vehnextprice))	{ DInfo("Delaying build: we save money for upgrade : money="+carrier.vehnextprice,1); bank.canBuild=false; }
	local veh=AIVehicleList();
	if (veh.IsEmpty() && cRoute.database.len()==0)
			{
			DInfo("Forcing build: We have 0 vehicle running !");
			bank.canBuild=true;
			if (cJobs.rawJobs.IsEmpty())	{ DInfo("Hard times going on, unleashing routes"); bank.unleash_road=true; }
			} // we have 0 vehicles force a build
	DInfo("canBuild="+bank.canBuild+" unleash="+bank.unleash_road+" building_main.route."+builder.building_route+" warTreasure="+carrier.warTreasure+" vehnextprice="+carrier.vehnextprice+" RemainJobs="+cJobs.jobDoable.Count(),1);
	}
