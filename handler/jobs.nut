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

function cJobs::TargetTownSet(townID)
// Add that town as a target town so we derank it, to avoid re-using this town too much
	{
	if (cJobs.targetTown.HasItem(townID))	cJobs.targetTown.SetValue(townID, cJobs.targetTown.GetValue(townID)+1);
							else	cJobs.targetTown.AddItem(townID, 1);
	}

function cJobs::CheckLimitedStatus()
// Check & set the limited status
	{
	local oldmax=distanceLimits[1];
	local testLimitChange= GetTransportDistance(AIVehicle.VT_RAIL, false, INSTANCE.bank.unleash_road); // get max distance a train could do
	if (oldmax != distanceLimits[1])
	DInfo("Distance limit status change to "+INSTANCE.bank.unleash_road,2);
	}

function cJobs::Save()
// save the job
	{
	local dualrouteavoid=cJobs();
	dualrouteavoid.UID=null;
	dualrouteavoid.sourceObject = this.targetObject; // swap source and target
	dualrouteavoid.targetObject = this.sourceObject;
//	dualrouteavoid.sourceID=this.targetObject.ID;
//	dualrouteavoid.targetID=this.sourceObject.ID;
	dualrouteavoid.roadType=this.roadType;
	dualrouteavoid.cargoID=this.cargoID;
//	dualrouteavoid.source_istown=this.targetObject.IsTown;
//	dualrouteavoid.target_istown=this.sourceObject.IsTown;
	dualrouteavoid.GetUID();
	if (dualrouteavoid.UID in database) // this remove cases where Paris->Nice(pass/bus) Nice->Paris(pass/bus)
		{
		DInfo("Job "+this.UID+" is a dual route. Dropping job",2);
		dualrouteavoid=null;
		return ;
		}
	dualrouteavoid=null;
	local jobinfo=cCargo.GetCargoLabel(this.cargoID)+"-"+cRoute.RouteTypeToString(this.roadType)+" "+this.distance+"m from ";
	jobinfo+=this.sourceObject.Name;
//	if (this.sourceObject.IsTown)	jobinfo+=AITown.GetName(this.sourceID);
//				else	jobinfo+=AIIndustry.GetName(this.sourceID);
	jobinfo+=" to ";
//	if (this.target_istown)	jobinfo+=AITown.GetName(this.targetID);
//				else	jobinfo+=AIIndustry.GetName(this.targetID);
	jobinfo+=this.targetObject.Name;
	if (this.UID in database)	DInfo("Job "+this.UID+" already in database",2);
		else	{
			DInfo("Adding job #"+this.UID+" ("+parentID+") to job database: "+jobinfo,2);
			database[this.UID] <- this;
			jobIndexer.AddItem(this.UID, 0);
			}
	}

function cJobs::GetUID()
// Create a UID and parentID for a job
// Return the UID for that job
	{
	local uID=null;
	local parentID = null;
	if (this.UID == null && this.sourceObject.ID != null && this.targetObject.ID != null && this.cargoID != null && this.roadType != null)
			{
			local v1=this.roadType+1;
			local v2=(this.cargoID+10);
			local v3=(this.targetObject.ID+100);
			if (this.targetObject.IsTown)	v3+=1000;
			local v4=(this.sourceObject.ID+10000);
			if (this.sourceObject.IsTown) v4+=4000;
			parentID= v4+(this.cargoID+1);
			if (this.roadType == AIVehicle.VT_AIR)	parentID = v4+(this.cargoID+100);
			if (this.roadType == AIVehicle.VT_ROAD && this.cargoID == cCargo.GetPassengerCargo())
				{ parentID = v4+(this.cargoID+300); }
			// parentID: prevent a route done by a transport to be done by another transport
			// As paris->anywhere(v/bus)[parentID=1000] paris->anywhere(pass/train)[parentID=1000]
			// the aircraft different ID means aircraft could always be build, even a bus is doing the job already
			uID = (v3*v4)+(v1*v2);
			this.UID=uID;
			this.parentID=parentID;
		//DInfo("JOBS -> "+uID+" src="+this.sourceID+" tgt="+this.targetID+" crg="+this.cargoID+" rt="+this.roadType);
			}
	return this.UID;
	}

function cJobs::RankThisJob()
// rank the current job
	{
	local valuerank=0;
	local stationrank=0;
	local cargorank=this.cargoValue;
	if (INSTANCE.cargo_favorite==this.cargoID)	cargorank=((20*cargoValue)/100)+cargoValue;// 20% bonus fav cargo
	valuerank= cargorank * cargoAmount;
	if (this.source_istown)
		{
		stationrank= (100- this.foule);
		if (INSTANCE.fairlevel == 2)	stationrank=100; // no malus for level 2
		}
	else	switch (INSTANCE.fairlevel)
			{	
			case	0:
				stationrank= (100 - (this.foule *100));	// give up when 1 station is present
			break;
			case	1:
				stationrank= (100- (this.foule *50));	// give up when 2 stations are there
			break;
			case	2:
				stationrank= (100- (this.foule *25));	// give up after 4 stations
			break;
			}
	local mail=cCargo.GetMailCargo();
	local pass=cCargo.GetPassengerCargo();
	if (this.target_istown && (this.roadType==AIVehicle.VT_AIR || this.roadType==AIVehicle.VT_ROAD) && (this.cargoID == pass || this.cargoID == mail) && cJobs.targetTown.HasItem(this.targetID))
		// passenger or mail by road or aircraft
		{
		local drank= ( (10*valuerank) / 100) * cJobs.targetTown.GetValue(this.targetID);
		DInfo("Downranking because target town is already handle : loose "+drank,2);
		valuerank-= drank; // add 10% penalty for each station we find
		if (valuerank < 1)	valuerank=1;
		}
	if (stationrank <=0 && INSTANCE.fairlevel > 0)	stationrank=1;
	// even crowd, one small chance to get pickup with 1&2 fairlevel, fairlevel 0 will never do that job
	this.ranking = stationrank * valuerank;
	}

function cJobs::RefreshValue(jobID, updateCost=false)
// refresh the datas from object
	{
return; // TODO: fixme
	if (cJobs.IsInfosUpdate(jobID))	{ DInfo("JobID: "+jobID+" infos are fresh",2); return null; }
						else	{ DInfo("JobID: "+jobID+" refreshing infos",2); }
	cJobs.jobIndexer.SetValue(jobID,AIDate.GetCurrentDate());
	if (jobID == 0 || jobID == 1)	return null; // don't refresh virtual routes
	local myjob = cJobs.GetJobObject(jobID);
	if (myjob == null) return null;
	local badind=false;
	if (!myjob.source_istown && !AIIndustry.IsValidIndustry(myjob.sourceID))
		{
		badind=true;
		cJobs.RawJobDelete(myjob.sourceID,false);
		}
	if (!myjob.target_istown && !AIIndustry.IsValidIndustry(myjob.targetID))
		{
		badind=true;
		cJobs.RawJobDelete(myjob.targetID,false);
		}

	if (badind) //TODO: handle called from route
		{
		DInfo("Removing bad industry from the job pool: "+myjob.UID,0);
		local deadroute=cRoute.GetRouteObject(myjob.UID);
		if (deadroute != null)	deadroute.RouteIsNotDoable();
		}
	if (myjob.isUse)	return;	// no need to refresh an already done job
	::AIController.Sleep(1);
	// foule, moneyGains, ranking & cargoAmount
	if (myjob.source_istown)
		{
		myjob.cargoAmount=AITown.GetLastMonthProduction(myjob.sourceID, myjob.cargoID);
		myjob.foule=AITown.GetLastMonthSupplied(myjob.sourceID, myjob.cargoID);
		if (myjob.target_istown)
			{
			local average=AITown.GetLastMonthProduction(myjob.targetID, myjob.cargoID);
			if (average < 60 || myjob.cargoAmount < 60) // poor towns makes poor routes
					{
					if (average < myjob.cargoAmount)	myjob.cargoAmount=average;
					}
					else	myjob.cargoAmount=(myjob.cargoAmount+average) / 2 ; // average towns pop, help find best route
			myjob.foule+=AITown.GetLastMonthSupplied(myjob.targetID, myjob.cargoID);
			}
		}
	else	{ // industry
		myjob.cargoAmount=AIIndustry.GetLastMonthProduction(myjob.sourceID, myjob.cargoID);
		myjob.foule=cRoute.GetAmountOfCompetitorStationAround(myjob.sourceID);
		}
	if (updateCost)	myjob.EstimateCost();
	myjob.RankThisJob();
	::AIController.Sleep(1);
	}

function cJobs::IsInfosUpdate(jobID)
// return true if jobID info is recent, false if we need to refresh it
// we also use this one as valuator
	{
	local now=AIDate.GetCurrentDate();
	local jdate=null;
	if (cJobs.jobIndexer.HasItem(jobID))	jdate=cJobs.jobIndexer.GetValue(jobID);
							else	return true; // if job is not index return infos are fresh
	return ( (now-jdate) < 240) ? true : false;
	}

function cJobs::RefreshAllValue()
// refesh datas of all jobs objects
	{
	DInfo("Collecting jobs infos, will take time...",0);
	local curr=0;
	local needRefresh=AIList();
	needRefresh.AddList(cJobs.jobIndexer);
	needRefresh.Valuate(cJobs.IsInfosUpdate);
	needRefresh.KeepValue(0); // only keep ones that need refresh
	DInfo("Need refresh: "+needRefresh.Count()+"/"+cJobs.jobIndexer.Count(),1);
	foreach (item, jdate in needRefresh)
		{
		cJobs.RefreshValue(item);
		curr++;
		if (curr % 15 == 0)
			{
			DInfo(curr+" / "+cJobs.needRefresh.Count(),0);
			INSTANCE.Sleep(1);
			}
		}
	return true;
	}

function cJobs::QuickRefresh()
// refresh datas on first 5 doable top jobs
	{
	local smallList=AIList();
	INSTANCE.jobs.UpdateDoableJobs();
	smallList.AddList(cJobs.jobIndexer);
	smallList.Valuate(cJobs.IsInfosUpdate);
	smallList.KeepValue(0); // keep only ones that need refresh
	smallList.Valuate(AIBase.RandItem);
	//smallList.Sort(AIList.SORT_BY_VALUE,true);
	smallList.KeepTop(5);
	foreach (smallID, dvalue in smallList)	{ INSTANCE.jobs.RefreshValue(smallID, true); }
	smallList.Clear();
	smallList.AddList(cJobs.jobDoable);
	/*foreach (item, value in smallList)
		{ // now remove jobs that we cannot build because of money need for that
		local j=cJobs.GetJobObject(item);
		if (!cBanker.CanBuyThat(j.moneyToBuild))	 { smallList.RemoveItem(item); }
		}*/
	smallList.Sort(AIList.SORT_BY_VALUE,false);
	smallList.KeepTop(5);
	if (INSTANCE.safeStart > 0 && smallList.IsEmpty())	INSTANCE.safeStart=0; // disable it if we cannot find any jobs
	foreach (uid, value in smallList)	INSTANCE.builder.DumpJobs(uid);
	return smallList;
	}

function cJobs::GetRanking(jobID)
// return the ranking for jobID
	{
	local myjob = cJobs.GetJobObject(jobID);
	if (myjob == null) return 0;
	return myjob.ranking;
	}

function cJobs::GetNextJob()
// Return the next job UID to do, -1 if we have none to do
	{
	local smallList=QuickRefresh();
	if (smallList.IsEmpty())	{ DInfo("Can't find any good jobs to do",1); return -1; }
					else	{ DInfo("Doable jobs: "+smallList.Count(),1); }
	return smallList.Begin();
	}

function cJobs::EstimateCost()
// Estimate the cost to build a job
	{
	local money = 0;
	local clean= AITile.GetBuildCost(AITile.BT_CLEAR_ROCKY)*cBanker.GetInflationRate();
	local engine=0;
	local engineprice=0;
	local daystransit=0;
	switch (this.roadType)
		{
		case	AIVehicle.VT_ROAD:
			// 2 vehicle + 2 stations + 2 depot + 4 destuction + 4 road for entry and length*road
			engine=cEngine.GetEngineByCache(RouteType.ROAD, this.cargoID);
			if (engine==-1)	engine=INSTANCE.main.vehicle.ChooseRoadVeh(this.cargoID);
			if (engine != null)	engineprice=cEngine.GetPrice(engine);
						else	{ engineprice=500000000; INSTANCE.use_road=false; }
			money+=engineprice;
			money+=2*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_TRUCK_STOP))*cBanker.GetInflationRate();
			money+=2*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_DEPOT))*cBanker.GetInflationRate();
			money+=4*clean;
			money+=(4+distance)*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD))*cBanker.GetInflationRate();
			daystransit=16;
		break;
		case	AIVehicle.VT_RAIL:
			// 1 vehicle + 2 stations + 2 depot + 4 destuction + 12 tracks entries and length*rail
			local rtype=null;
			engine=cEngine.GetEngineByCache(RouteType.RAIL, this.cargoID);
			if (engine==-1)	engine=INSTANCE.main.vehicle.ChooseRailEngine(null,this.cargoID, true);
			if (engine==-1)	{ engineprice=500000000; 	INSTANCE.use_train=false; }
						else	{
							/*engineprice+=cEngine.GetPrice(engine.Begin());
							engineprice+=2*cEngine.GetPrice(engine.GetValue(engine.Begin()));
							rtype=cmain.vehicle.GetRailTypeNeedForEngine(engine.Begin());*/
							engineprice+=cEngine.GetPrice(engine);
							rtype=cmain.vehicle.GetRailTypeNeedForEngine(engine);
							if (rtype==-1)	rtype=null;
							}
			money+=engineprice;
			money+=(8*clean);
			if (rtype==null)	money+=500000000;
					else	{
						money+=((20+distance)*(AIRail.GetBuildCost(rtype, AIRail.BT_TRACK)))*cBanker.GetInflationRate();
						money+=((2+5)*(AIRail.GetBuildCost(rtype, AIRail.BT_STATION)))*cBanker.GetInflationRate(); // station train 5 length
						money+=(2*(AIRail.GetBuildCost(rtype, AIRail.BT_DEPOT)))*cBanker.GetInflationRate();
						}
			daystransit=4;
		break;
		case	AIVehicle.VT_WATER: //TODO: finish it
			// 2 vehicle + 2 stations + 2 depot
//			engine=cEngine.GetEngineByCache(RouteType.ROAD, this.cargoID);
			engine=null;
			if (engine != null)	engineprice=cEngine.GetPrice(engine);
						else	{ engineprice=500000000; INSTANCE.use_air=false; }
			money+=engineprice*2;
			money+=2*(AIMarine.GetBuildCost(AIMarine.BT_DOCK))*cBanker.GetInflationRate();
			money+=2*(AIMarine.GetBuildCost(AIMarine.BT_DEPOT))*cBanker.GetInflationRate();
			daystransit=32;
		break;
		case	AIVehicle.VT_AIR:
			// 2 vehicle + 2 airports
			engine=cEngine.GetEngineByCache(RouteType.AIR, RouteType.AIR);
			if (engine==-1)	engine=INSTANCE.main.vehicle.ChooseAircraft(this.cargoID, this.distance, AircraftType.EFFICIENT);
			if (engine != null)	engineprice=cEngine.GetPrice(engine);
						else	engineprice=500000000;
			money+=engineprice*2;
			money+=2*(AIAirport.GetPrice(INSTANCE.builder.GetAirportType()));
			daystransit=6;
		break;
		}
	this.moneyToBuild=money;
	this.cargoValue=AICargo.GetCargoIncome(this.cargoID, this.distance, daystransit);
	DInfo("moneyToBuild="+this.moneyToBuild+" Income: "+this.cargoValue,2);
	}

function cJobs::GetTransportDistance(transport_type, get_min, limited)
// Return the transport distance a transport_type could do
// get_min = true return minimum distance
// get_min = false return maximum distance
	{
	local small=1000;
	local big=0;
	local target=transport_type * 3;
	local toret=0;
	for (local i=0; i < TRANSPORT_DISTANCE.len(); i++)
		{
		local min=TRANSPORT_DISTANCE[i];
		local lim=TRANSPORT_DISTANCE[i+1];
		local max=TRANSPORT_DISTANCE[i+2];
		if (target == i)
			{
			if (get_min)	toret=min;
					else	toret=(limited) ? lim : max;
			}
		if (min < small)	small=min;
		if (lim > big)	big=lim;
		i+=2; // next iter
		}
	distanceLimits[0]=small;
	distanceLimits[1]=big;
	return toret;
	}

function cJobs::GetTransportList(distance)
// Return a list of transport we can use
	{
	// road assign as 2, trains assign as 1, air assign as 4, boat assign as 3
	// it's just AIVehicle.VehicleType+1
	local v_train=1;
	local v_boat =1;
	local v_air  =1;
	local v_road =1;
	local tweaklist=AIList();
	local road_maxdistance=cJobs.GetTransportDistance(AIVehicle.VT_ROAD,false,false);
	local road_mindistance=cJobs.GetTransportDistance(AIVehicle.VT_ROAD,true,false);
	local rail_maxdistance=cJobs.GetTransportDistance(AIVehicle.VT_RAIL,false,false);
	local rail_mindistance=cJobs.GetTransportDistance(AIVehicle.VT_RAIL,true,false);
	local air_maxdistance=cJobs.GetTransportDistance(AIVehicle.VT_AIR,false,false);
	local air_mindistance=cJobs.GetTransportDistance(AIVehicle.VT_AIR,true,false);
	local water_maxdistance=cJobs.GetTransportDistance(AIVehicle.VT_WATER,false,false);
	local water_mindistance=cJobs.GetTransportDistance(AIVehicle.VT_WATER,true,false);
	//DInfo("Distances: Truck="+road_mindistance+"/"+road_maxdistance+" Aircraft="+air_mindistance+"/"+air_maxdistance+" Train="+rail_mindistance+"/"+rail_maxdistance+" Boat="+water_mindistance+"/"+water_maxdistance,2);
	local goal=distance;
	if (goal >= road_mindistance && goal <= road_maxdistance)	{ tweaklist.AddItem(1,2*v_road); }
	if (goal >= rail_mindistance && goal <= rail_maxdistance)	{ tweaklist.AddItem(0,1*v_train); }
	if (goal >= air_mindistance && goal <= air_maxdistance)		{ tweaklist.AddItem(3,4*v_air); }
	//if (goal >= water_mindistance && goal <= water_maxdistance)	{ tweaklist.AddItem(2,3*v_boat); } TODO: fixme boat
	tweaklist.RemoveValue(0);
	return tweaklist;
	}

function cJobs::IsTransportTypeEnable(transport_type)
// return true if that transport type is enable in the game
	{
	switch (transport_type)
		{
		case	AIVehicle.VT_ROAD:
		return	(INSTANCE.use_road);
		case	AIVehicle.VT_AIR:
		return	(INSTANCE.use_air);
		case	AIVehicle.VT_RAIL:
		return	(INSTANCE.use_train);
		case	AIVehicle.VT_WATER:
		return	(INSTANCE.use_boat);
		}
	}
	
function cJobs::JobIsNotDoable(uid)
// set the undoable status for that job
	{
	local badjob=cJobs.GetJobObject(uid);
	if (badjob == null) return;
	badjob.isdoable=false;
	cJobs.badJobs.AddItem(uid,0);
	}

function cJobs::UpdateDoableJobs()
// Update the doable status of the job indexer
	{
	INSTANCE.jobs.CheckLimitedStatus();
	DInfo("Analysing the task pool",0);
	local parentListID=AIList();
	INSTANCE.jobs.jobDoable.Clear();
	local topair=0;
	local toproad=0;
	local toprail=0;
	local topwater=0;
	cJobs.CostTopJobs[AIVehicle.VT_RAIL]=0;
	cJobs.CostTopJobs[AIVehicle.VT_AIR]=0;
	cJobs.CostTopJobs[AIVehicle.VT_WATER]=0;
	cJobs.CostTopJobs[AIVehicle.VT_ROAD]=0;
	// reset all top jobs
	foreach (id, value in INSTANCE.jobs.jobIndexer)
		{
		if (id == 0 || id == 1)	continue;
		local doable=1;
		local myjob=cJobs.GetJobObject(id);
		doable=myjob.isdoable;
		// not doable if not doable
		local vehtest=null;
		switch (myjob.roadType)
			{
			case	AIVehicle.VT_AIR:
				if (!INSTANCE.use_air)	doable=false;
			break;
			case	AIVehicle.VT_ROAD:
				if (!INSTANCE.use_road)	doable=false;
			break;
			case	AIVehicle.VT_WATER:
				if (!INSTANCE.use_boat)	doable=false;
			break;
			case	AIVehicle.VT_RAIL:
				if (!INSTANCE.use_train)	doable=false;
			break;
			}
		// not doable if disabled
		if (myjob.isUse)	{ doable=false; parentListID.AddItem(myjob.parentID,1); }
		// not doable if already done, also record the parentID to block similar jobs
		if (doable && myjob.ranking==0)	{ doable=false; }
		// not doable if ranking is at 0
		if (doable)
		// not doable if max distance is limited and lower the job distance
			{
			local curmax = INSTANCE.jobs.GetTransportDistance(myjob.roadType, false, !INSTANCE.bank.unleash_road);
			if (curmax < myjob.distance)	{ doable=false; }
			}
		// not doable if any parent is already in use
		if (doable)
			if (parentListID.HasItem(myjob.parentID))
				{
				DInfo("Job already done by parent job ! First pass filter",2);
				doable=false;
				//cJobs.jobIndexer.RemoveItem(id);
				//cJobs.DeleteJob(id)
				//continue;
				}
		if (doable && !myjob.source_istown)
			if (!AIIndustry.IsValidIndustry(myjob.sourceID))	doable=false;
		// not doable if the industry no longer exist
		if (doable && myjob.source_istown && DictatorAI.GetSetting("allowedjob") == 1)	doable=false;
		// not doable if town jobs is not allow
		if (doable && !myjob.source_istown && DictatorAI.GetSetting("allowedjob") == 2)	doable=false;
		// not doable if industry jobs is not allow
		if (doable)	{
				switch (myjob.roadType)
					{
					case	AIVehicle.VT_AIR:
						if (topair < myjob.ranking && myjob.cargoID == cCargo.GetPassengerCargo())
							{
							cJobs.CostTopJobs[myjob.roadType]=myjob.moneyToBuild;
							topair=myjob.ranking;
							}
					break;
					case	AIVehicle.VT_ROAD:
						if (toproad < myjob.ranking)
							{
							cJobs.CostTopJobs[myjob.roadType]=myjob.moneyToBuild;
							toproad=myjob.ranking;
							}
					break;
					case	AIVehicle.VT_WATER:
						if (topwater < myjob.ranking)
							{
							cJobs.CostTopJobs[myjob.roadType]=myjob.moneyToBuild;
							topwater=myjob.ranking;
							}
					break;
						case	AIVehicle.VT_RAIL:
						if (toprail < myjob.ranking)
							{
							cJobs.CostTopJobs[myjob.roadType]=myjob.moneyToBuild;
							toprail=myjob.ranking;
							}
					break;
					}
				}
		if (doable && !cBanker.CanBuyThat(myjob.moneyToBuild))	{ doable=false; }
		// disable as we lack money
		if (doable)	myjob.jobDoable.AddItem(id, myjob.ranking);
		}
	foreach (jobID, rank in INSTANCE.jobs.jobDoable)
		{	// even some have already been filtered out in the previous loop, some still have pass the check succesfuly
			// but it should cost us less cycle to filter the remaining ones here instead of filter all of them before the loop
		local myjob=cJobs.GetJobObject(jobID);
		local airValid=(cJobs.CostTopJobs[AIVehicle.VT_AIR] > 0 && (cBanker.CanBuyThat(cJobs.CostTopJobs[AIVehicle.VT_AIR]) || INSTANCE.main.vehicle.warTreasure > cJobs.CostTopJobs[AIVehicle.VT_AIR]) && INSTANCE.use_air);
		local trainValid=(cJobs.CostTopJobs[AIVehicle.VT_RAIL] > 0 && (cBanker.CanBuyThat(cJobs.CostTopJobs[AIVehicle.VT_RAIL]) || INSTANCE.main.vehicle.warTreasure > cJobs.CostTopJobs[AIVehicle.VT_RAIL]) && INSTANCE.use_train);
		if (myjob.roadType == AIVehicle.VT_ROAD && (airValid || trainValid))	cJobs.jobDoable.RemoveItem(jobID);
			// disable because we have funds to build an aircraft or a rail job

		if (parentListID.HasItem(myjob.parentID))
			{
			DInfo("Job already done by parent job ! Second pass filter",2);
			cJobs.jobDoable.RemoveItem(jobID);
			//cJobs.jobIndexer.RemoveItem(jobID);
			//cJobs.DeleteJob(jobID);
			}
		}
	INSTANCE.jobs.jobDoable.Sort(AIList.SORT_BY_VALUE, false);
	DInfo(INSTANCE.jobs.jobIndexer.Count()+" jobs found",2);
	DInfo(INSTANCE.jobs.jobDoable.Count()+" jobs doable",2);
	}

function cJobs::GetJobTarget(src_id, cargo_id, src_istown, srcloc)
// return an AIList with all possibles destinations, return values are manhattan distance from srcloc
	{
	local retList=AIList();
	local rmax=cJobs.GetTransportDistance(0,false,false); // just to make sure min&max are init
	if (cCargo.IsCargoForTown(cargo_id))
		{
		retList=AITownList();
		retList.Valuate(AITown.GetPopulation);
		retList.Sort(AIList.SORT_BY_VALUE,false);
		retList.Valuate(AITown.GetDistanceManhattanToTile, srcloc);
		retList.KeepBetweenValue(distanceLimits[0], rmax);
		//retList.Valuate(AITown.GetLocation);
		}
	else	{
		retList=AIIndustryList_CargoAccepting(cargo_id);
		retList.Valuate(AIIndustry.GetDistanceManhattanToTile, srcloc);
		retList.KeepBetweenValue(distanceLimits[0], rmax);
	//	retList.Valuate(AIIndustry.GetLocation);
		}
	return retList;
	}

function cJobs::CreateNewJob(srcUID, dstID, cargo_id, road_type, _distance)
// Create a new Job
	{
	local newjob=cJobs();
	newjob.sourceObject = cProcess.Load(srcUID);
	if (cCargo.IsCargoForTown(cargo_id))	dstID=cProcess.GetUID(dstID, true);
	newjob.targetObject = cProcess.Load(dstID);
//	newjob.sourceID = srcID;
//	newjob.targetID = tgtID;
//	newjob.source_istown = src_istown;
	// filters unwanted jobs
	if (road_type==AIVehicle.VT_WATER)	return;
	// disable any boat jobs
	if (road_type == AIVehicle.VT_AIR && cargo_id != cCargo.GetPassengerCargo()) return;
	// only pass for aircraft, we will randomize if pass or mail later
	if (!newjob.sourceObject.IsTown && AIIndustry.IsBuiltOnWater(newjob.sourceObject.ID) && road_type != AIVehicle.VT_AIR && road_type != AIVehicle.VT_WATER) return;
	// only aircraft & boat to do platforms

	newjob.distance = _distance;
	newjob.roadType = road_type;
	newjob.cargoID = cargo_id;
	newjob.GetUID();
	newjob.Save();
	INSTANCE.main.jobs.RefreshValue(newjob.UID,true); // update ranking, cargo amount, foule values, must be call after GetUID
	}

function cJobs::AddNewIndustryOrTown(industryID, istown)
// Add a new industry/town job: this will add all possibles jobs doable with it (transport type + all cargos)
	{
	local p_uid = cProcess.GetUID(industryID, istown);
	local p = cProcess.Load(p_uid);
	if (!p)	return;
	local position=p.Location;
	local cargoList=p.CargoProduce;
	cargoList.RemoveItem(cCargo.GetMailCargo());
	// Remove the mail cargo, it's too poor for anyone except trucks, but this add more trucks/bus to town that are already too crowd.
	foreach (cargoid, amount in cargoList)
		{
		local targetList=cJobs.GetJobTarget(p.ID, cargoid, p.IsTown, p.Location); // find where we could transport it
		foreach (destination, distance in targetList)
			{
			local transportList=GetTransportList(distance);	// find possible ways to transport that
			foreach (transtype, dummy2 in transportList)
				{
				this.UID=null;
				cJobs.CreateNewJob(p.UID, destination, cargoid, transtype, distance);
				::AIController.Sleep(1);
				}
			}
		::AIController.Sleep(1);
		}
	}

function cJobs::DeleteJob(uid)
// Remove all job references
	{
	DInfo("Removing job #"+uid+" from database",2);
	if (uid in cJobs.database)	delete cJobs.database[uid];
	if (cJobs.jobIndexer.HasItem(uid))	cJobs.jobIndexer.RemoveItem(uid);
	if (cJobs.jobDoable.HasItem(uid))	cJobs.jobDoable.RemoveItem(uid);
	if (cJobs.badJobs.HasItem(uid))	cJobs.badJobs.RemoveItem(uid);
	cJobs.RawJob_Delete(uid);
	cProcess.DeleteProcess(uid);
	}

function cJobs::RawJobHandling()
// Find a raw Job and add possible jobs from it to jobs database
	{
	if (cJobs.rawJobs.IsEmpty())	return;
	local p = cProcess.Load(cJobs.rawJobs.Begin());
	cJobs.AddNewIndustryOrTown(p.ID, p.IsTown);
	cJobs.RawJob_Delete(p.UID);
	if (cJobs.rawJobs.IsEmpty())	DInfo("All raw jobs have been process",1);
					else	DInfo("rawJobs still to do: "+cJobs.rawJobs.Count());
	}

function cJobs::RawJob_Delete(UID)
// Remove process from rawJob list
	{
	if (cJobs.rawJobs.HasItem(UID))	cJobs.rawJobs.RemoveItem(UID);
	}

function cJobs::RawJob_Add(UID)
// Add a process to rawJob list
	{
	local p = cProcess.Load(UID);
	if (!p)	return;
	cJobs.rawJobs.AddItem(p.UID, p.Score);
	}

function cJobs::PopulateJobs()
// Find towns and industries and add any jobs we could do with them
{
local cargoList=AICargoList();
local alljob=AIList();
DInfo("Finding all industries & towns jobs...",0);
foreach (cargoid, _ in cargoList)
	{
	local prod=cProcess.GetProcessList_ProducingCargo(cargoid);
	DInfo("Production of "+cCargo.GetCargoLabel(cargoid)+" : "+prod.Count(),1);
	alljob.AddList(prod);
	}
local curr=0;
foreach (uid, _ in alljob)
	{
	cJobs.RawJob_Add(uid);
	curr++;
	if (curr % 18 == 0)
		{
		DInfo(curr+" / "+alljob.Count(),0);
		INSTANCE.Sleep(1);
		}
	}
cJobs.rawJobs.Sort(AIList.SORT_BY_VALUE, false);
}

function cJobs::CheckTownStatue()
// check if can add a statue to the town
	{
	if (INSTANCE.fairlevel==0)	return; // no action if we play easy
	DInfo(cProcess.statueTown.Count()+" towns to build statue found.",1);
	foreach (townID, dummy in cProcess.statueTown)
		{
		if (AITown.IsActionAvailable(townID, AITown.TOWN_ACTION_BUILD_STATUE))
			{
			if (AITown.HasStatue(townID))	{ cProcess.statueTown.RemoveItem(townID);	continue; }
			AITown.PerformTownAction(townID, AITown.TOWN_ACTION_BUILD_STATUE);
			if (AITown.HasStatue(townID))
				{
				DInfo("Built a statue at "+AITown.GetName(townID),0);
				cProcess.statueTown.RemoveItem(townID);
				}
			}
		INSTANCE.Sleep(1);
		}
	}
