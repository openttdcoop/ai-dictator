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
	cTrack.SetRailType();
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
	local mintobuild = INSTANCE.main.bank.mincash;
	if (INSTANCE.main.carrier.vehicle_cash < 0) { INSTANCE.main.carrier.vehicle_cash = 0; }
	if (ourLoan == 0 && cash >= 3*mintobuild)	{ INSTANCE.main.bank.unleash_road=true; }
	if (!cBanker.GetMoney(mintobuild))	{ DInfo("Low on cash, disabling build : "+mintobuild,1); INSTANCE.main.bank.canBuild=false; }
								else    INSTANCE.main.bank.canBuild = true;
/*	if (maxLoan > 2000000 && ourLoan > 0 && route.RouteIndexer.Count() > 6)
			{ DInfo("Trying to repay loan",1); INSTANCE.main.bank.canBuild=false; } // wait to repay loan*/
	local veh = AIVehicleList();
	if (INSTANCE.buildDelay > 0)	{ DInfo("Builds delayed: "+INSTANCE.buildDelay,1); INSTANCE.main.bank.canBuild=false; }
	if (!cBanker.CanBuyThat(INSTANCE.main.carrier.vehicle_cash+mintobuild))   { DInfo("Delaying build: we save money for upgrade",1); INSTANCE.main.bank.canBuild=false; }
	if (cRoute.database.len() == 2 && AIVehicleList().IsEmpty())
			{ // we have 0 vehicles force a build
			DInfo("Forcing build: We have 0 vehicle running !");
			INSTANCE.main.bank.canBuild=true;
			if (cJobs.rawJobs.IsEmpty())	{ DInfo("Hard times going on, unleashing routes"); INSTANCE.main.bank.unleash_road=true; }
			}
/*	local dgroute=0;
	foreach (route in cRoute.database)
		{
		if (route.Status == RouteStatus.WORKING)	dgroute++;
		}
	if (cRoute.database.len()==3 && dgroute == 3)
		{
		DWarn("DEBUG Disabling more than 1 route");
		bank.canBuild=false;   // FIXME : debug keep 1 route enable only
		}
		*/
//	else print("DEBUG route state : "+dgroute);
		//AIController.Break("route size="+cRoute.database.len());
	DWarn("canBuild="+INSTANCE.main.bank.canBuild+" unleash="+INSTANCE.main.bank.unleash_road+" building_main.route."+INSTANCE.main.builder.building_route+" warTreasure="+INSTANCE.main.carrier.warTreasure+" vehicle_cash="+INSTANCE.main.carrier.vehicle_cash+" RemainJobs="+cJobs.jobDoable.Count()+" vehicle_wish="+INSTANCE.main.carrier.vehicle_wishlist.Count()+" mintobuild="+mintobuild,1);
	}
