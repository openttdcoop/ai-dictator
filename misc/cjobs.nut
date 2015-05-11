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
static	rawJobs=AIList();		// Primary jobs list, item (if industry=industryID, if town=townID+10000), value 0=done, >0=need handling
static	deadIndustry = AIList();// List all industries that are dead and so jobs using them need to be removed


static	function GetJobObject(UID)
		{
		return UID in cJobs.database ? cJobs.database[UID] : null;
		}

	Name			= null;	// name of jobs
	SourceProcess	= null;	// source process object
	TargetProcess	= null;	// target process object
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
		SourceProcess	= null;
		TargetProcess	= null;
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

function cJobs::Load(UID)
// Load a job with some check against bad job
	{
	local obj = cJobs.GetJobObject(UID);
	if (obj == null)
			{
			DWarn("cJobs.Load function return NULL with UID="+UID,3);
			return false;
			}
	return obj;
	}

function cJobs::ReuseTownSet(townID)
// Add that town as a target town so we derank it, to avoid re-using this town too much
	{
	if (cJobs.TownAbuse.HasItem(townID))	{ cJobs.TownAbuse.SetValue(townID, cJobs.TownAbuse.GetValue(townID)+1); }
                                    else	{ cJobs.TownAbuse.AddItem(townID, 1); }
	}

function cJobs::CheckLimitedStatus()
// Check & set the limited status, at early stage we limit the distance to accept a job.
	{
	local oldmax=cJobs.distanceLimits[1];
	local testLimitChange= cJobs.GetTransportDistance(RouteType.RAIL, false, INSTANCE.main.bank.unleash_road); // get max distance a train could do
	if (oldmax != cJobs.distanceLimits[1])
			{
			DInfo("Distance limit status change to "+INSTANCE.main.bank.unleash_road,4);
			}
	}

function cJobs::Save()
// save the job
	{
	local dualrouteavoid=cJobs();
	dualrouteavoid.UID=null;
	dualrouteavoid.SourceProcess = this.TargetProcess; // swap source and target
	dualrouteavoid.TargetProcess = this.SourceProcess;
	dualrouteavoid.roadType=this.roadType;
	dualrouteavoid.cargoID=this.cargoID;
	dualrouteavoid.GetUID();
	if (dualrouteavoid.UID in database) // this remove cases where Paris->Nice(pass/bus) Nice->Paris(pass/bus)
			{
			DInfo("Job "+this.UID+" is a dual route. Dropping job",4);
			dualrouteavoid=null;
			return ;
			}
	dualrouteavoid=null;
	local jobinfo=cCargo.GetCargoLabel(this.cargoID)+"-"+cRoute.RouteTypeToString(this.roadType)+" "+this.distance+"m from ";
	jobinfo+=this.SourceProcess.Name;
	jobinfo+=" to ";
	jobinfo+=this.TargetProcess.Name;
	this.Name=jobinfo;
	if (this.UID in database)	{ DInfo("Job "+this.UID+" already in database",4); }
                        else    {
                                DInfo("Adding job #"+this.UID+" ("+parentID+") to job database: "+jobinfo,4);
                                database[this.UID] <- this;
                                cJobs.jobIndexer.AddItem(this.UID, 0);
                                }
	}

function cJobs::GetUID()
// Create a UID and parentID for a job
// Return the UID for that job
	{
	local uID=null;
	local parentID = null;
	if (this.UID == null && this.SourceProcess.ID != null && this.TargetProcess.ID != null && this.cargoID != null && this.roadType != null)
			{
			local v1=this.roadType+1;
			local v2=(this.cargoID+15);
			local v3=(this.TargetProcess.ID+100);
			if (this.TargetProcess.IsTown)	{ v3+=1000; }
			local v4=(this.SourceProcess.ID+10000);
			if (this.SourceProcess.IsTown) { v4+=4000; }
			parentID= v4+(this.cargoID+1);
			if (this.roadType == RouteType.AIR)	{ parentID = v4+(this.cargoID+100); }
			if (this.roadType == RouteType.RAIL && this.cargoID == cCargo.GetPassengerCargo())
					{ parentID = v4+(this.cargoID+100); } // let train doing passenger share the same ID as aircraft, so either aircraft or train can do it but not both
			if (this.roadType == RouteType.ROAD && this.cargoID == cCargo.GetPassengerCargo())
					{ parentID = v4+(this.cargoID+300); }
			// parentID: prevent a route done by a transport to be done by another transport
			// As paris->anywhere(v/bus)[parentID=1000] paris->anywhere(pass/train)[parentID=1000]
			// the aircraft and bus different ID means they could always be build, even a bus/aircraft is doing the job already
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
	local srcTown = this.SourceProcess.IsTown;
	local dstTown = this.TargetProcess.IsTown;
//	this.cargoAmount = this.SourceProcess.ScoreProduction;
//			this.CargoProduce.SetValue(cargoID, current);
	this.cargoAmount = this.SourceProcess.CargoProduce.GetValue(this.cargoID);
//	if (srcTown && dstTown)	{ this.cargoAmount= ((this.SourceProcess.ScoreProduction + this.TargetProcess.ScoreProduction) / 2); }
	if (srcTown && dstTown)	{ this.cargoAmount= ((this.SourceProcess.CargoProduce.GetValue(cCargo.GetPassengerCargo()) + this.TargetProcess.CargoProduce.GetValue(cCargo.GetPassengerCargo())) / 2); }
	if (this.cargoID == cCargo.GetCargoFavorite())	{ this.cargoAmount *= cCargo.GetCargoFavoriteBonus(); }
	local valuerank = this.cargoAmount * this.cargoValue;
	if (this.subsidy)
			{
			if (AIGameSettings.IsValid("subsidy_multiplier"))	{ valuerank=valuerank * AIGameSettings.GetValue("subsidy_multiplier"); }
                                                        else	{ valuerank=valuerank * 2; }
			}
	// grant a bonus to subsidy
	local stationrank = this.SourceProcess.ScoreRating * this.TargetProcess.ScoreRating;
	if (this.cargoID == cCargo.GetPassengerCargo() || this.cargoID == cCargo.GetMailCargo)
        {
        local src_drank = 0;
        local dst_drank = 0;
        if (srcTown && this.SourceProcess.UsedBy.Count() > 0)
            {
            if (this.roadType == RouteType.RAIL)   { src_drank = valuerank; }
                                            else   { src_drank = ((20 * valuerank) / 100) * this.SourceProcess.UsedBy.Count(); }
            DInfo("Downranking because "+AITown.GetName(this.SourceProcess.ID)+" is already use : Lost "+src_drank,4);
            }
        if (dstTown && this.TargetProcess.UsedBy.Count() > 0)
            {
            if (this.roadType == RouteType.RAIL)   { dst_drank = valuerank; }
											else   { dst_drank = ((20 * valuerank) / 100) * this.SourceProcess.UsedBy.Count(); }
			DInfo("Downranking because "+AITown.GetName(this.TargetProcess.ID)+" is already use : Lost "+dst_drank,4);
            }
        valuerank -= (src_drank + dst_drank);
        }
	if (stationrank < 1 || valuerank < 1)
                { this.ranking = 0; }
        else    { this.ranking = stationrank + valuerank; }
	}

function cJobs::RefreshValue(jobID, updateCost=false)
// refresh the datas from object
	{
	if (cJobs.IsInfosUpdate(jobID))	{ DInfo("JobID: "+jobID+" infos are fresh",3); return null; }
                            else	{ DInfo("JobID: "+jobID+" refreshing infos",3); }
	cJobs.jobIndexer.SetValue(jobID,AIDate.GetCurrentDate());
	if (jobID == 0 || jobID == 1)	{ return null; } // don't refresh virtual routes
	local myjob = cJobs.Load(jobID);
	if (!myjob)	{ return null; }
	local badind=false;
	// avoid handling a dead industry we didn't get the event yet
	if (!myjob.SourceProcess.IsTown && !AIIndustry.IsValidIndustry(myjob.SourceProcess.ID))
			{
			badind=true;
			cJobs.MarkIndustryDead(myjob.SourceProcess.ID);
			}
	if (!myjob.TargetProcess.IsTown && !AIIndustry.IsValidIndustry(myjob.TargetProcess.ID))
			{
			badind=true;
			cJobs.MarkIndustryDead(myjob.TargetProcess.ID);
			}
	if (badind)
			{
			DInfo("Removing bad industry from the job pool: "+myjob.UID,3);
			local deadroute=cRoute.LoadRoute(myjob.UID);
			if (!deadroute)	{ return; }
			DInfo("RefreshValue mark "+deadroute.UID+" undoable",1);
			deadroute.RouteIsNotDoable();
			return;
			}
	if (myjob.isUse)	{ return; }	// no need to refresh an already done job
	local pause = cLooper();
	// moneyGains, ranking & cargoAmount
	myjob.SourceProcess.UpdateScore();
	myjob.TargetProcess.UpdateScore();
	if (updateCost)	{ myjob.EstimateCost(); }
	myjob.RankThisJob();
	}

function cJobs::IsInfosUpdate(jobID)
// return true if jobID info is recent, false if we need to refresh it
// we also use this one as valuator
	{
	local now=AIDate.GetCurrentDate();
	local jdate=null;
	if (cJobs.jobIndexer.HasItem(jobID))	{ jdate=cJobs.jobIndexer.GetValue(jobID); }
                                    else	{ return true; } // if job is not index return infos are fresh
	return ( (now-jdate) < 7) ? true : false;
	}

function cJobs::QuickRefresh()
// refresh datas on first 5 doable top jobs
	{
	local smallList=AIList();
	cJobs.UpdateDoableJobs();
	smallList.AddList(cJobs.jobIndexer);
	local now = AIDate.GetCurrentDate();
	now = now - 30;
	smallList.RemoveList(cRoute.RouteIndexer); // remove jobs already in use
	smallList.KeepBelowValue(now);
	smallList.KeepTop(10); // refresh 10 random jobs that need a refresh
	foreach (smallID, dvalue in smallList)	{ cJobs.RefreshValue(smallID, true); }
	smallList.Clear();
	smallList.AddList(cJobs.jobDoable);
	smallList.Sort(AIList.SORT_BY_VALUE, false);
	if (INSTANCE.safeStart > 0 && smallList.IsEmpty())	{ INSTANCE.safeStart=0; } // disable it if we cannot find any jobs
	return smallList;
	}

function cJobs::GetRanking(jobID)
// return the ranking for jobID
	{
	local myjob = cJobs.Load(jobID);
	if (!myjob) { return 0; }
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
	local clean= AITile.GetBuildCost(AITile.BT_CLEAR_ROCKY);
	clean.tointeger();
	local engine=0;
	local engineprice=0;
	local daystransit=0;
	switch (this.roadType)
			{
			case	RouteType.ROAD:
				// 2 vehicle + 2 stations + 2 depot + 4 destuction + 4 road for entry and length*road
				engine=cEngine.GetEngineByCache(RouteType.ROAD, this.cargoID);
				if (engine != -1)   { engineprice=AIEngine.GetPrice(engine); }
                            else    { engineprice=100000; }
				money+=engineprice;
				money+=2*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_TRUCK_STOP));
				money+=2*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_DEPOT));
				money+=4*clean;
				money+=(4+distance)*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD));
				daystransit=16;
				break;
			case	RouteType.RAIL:
				// 1 vehicle + 2 stations + 2 depot + 4 destuction + 12 tracks entries and length*rail
				local rtype=null;
				engine=cEngine.GetEngineByCache(RouteType.RAIL, this.cargoID);
				if (engine != -1)
						{
						engineprice+=AIEngine.GetPrice(engine);
						rtype=cEngineLib.RailTypeGetFastestType(engine);
						if (rtype==-1)	{ rtype=null; }
						}
				else	{ engineprice=500000; }
				money+=engineprice;
				if (this.cargoID == cCargo.GetPassengerCargo())	money+=engineprice;
				money+=(11*clean);
				if (rtype==null)	{ money+=500000; }
                            else    {
                                    money+=((20+distance)*(AIRail.GetBuildCost(rtype, AIRail.BT_TRACK)));
                                    money+=((5)*(AIRail.GetBuildCost(rtype, AIRail.BT_STATION))); // station train 5 length
                                    money+=(2*(AIRail.GetBuildCost(rtype, AIRail.BT_DEPOT)));
                                    }
				daystransit=4;
				break;
			case	RouteType.WATER:
				// 2 vehicle + 2 stations + 2 depot
				engine = cEngine.GetEngineByCache(RouteType.WATER, this.cargoID);
				if (engine != null)	{ engineprice=AIEngine.GetPrice(engine); }
                            else	{ engineprice=500000; }
				money+=engineprice*2;
				money+=2*(AIMarine.GetBuildCost(AIMarine.BT_DOCK));
				money+=2*(AIMarine.GetBuildCost(AIMarine.BT_DEPOT));
				daystransit=32;
				break;
			case	RouteType.AIR:
				// 2 vehicle + 2 airports
				engine=cEngine.GetEngineByCache(RouteType.AIR, RouteType.AIR);
				if (engine != -1)	{ engineprice=AIEngine.GetPrice(engine); }
                            else	{ engineprice=500000; }
				money+=engineprice*2;
				money+=2*(AIAirport.GetPrice(cBuilder.GetAirportType()));
				daystransit=6;
				break;
			}
	this.moneyToBuild=money;
	this.cargoValue=AICargo.GetCargoIncome(this.cargoID, this.distance, daystransit);
	DInfo("moneyToBuild="+this.moneyToBuild+" Income: "+this.cargoValue,4);
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
	for (local i=0; i < cJobs.TRANSPORT_DISTANCE.len(); i++)
			{
			local min = cJobs.TRANSPORT_DISTANCE[i];
			local lim = cJobs.TRANSPORT_DISTANCE[i+1];
			local max = cJobs.TRANSPORT_DISTANCE[i+2];
			if (target == i)
					{
					if (get_min)	{ toret=min; }
                            else	{ toret=(limited) ? lim : max; }
					}
			if (min < small)	{ small=min; }
			if (lim > big)	{ big=lim; }
			i+=2; // next iter
			}
	cJobs.distanceLimits[0]=small;
	cJobs.distanceLimits[1]=big;
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
	local road_maxdistance=cJobs.GetTransportDistance(RouteType.ROAD,false,false);
	local road_mindistance=cJobs.GetTransportDistance(RouteType.ROAD,true,false);
	local rail_maxdistance=cJobs.GetTransportDistance(RouteType.RAIL,false,false);
	local rail_mindistance=cJobs.GetTransportDistance(RouteType.RAIL,true,false);
	local air_maxdistance=cJobs.GetTransportDistance(RouteType.AIR,false,false);
	local air_mindistance=cJobs.GetTransportDistance(RouteType.AIR,true,false);
	local water_maxdistance=cJobs.GetTransportDistance(RouteType.WATER,false,false);
	local water_mindistance=cJobs.GetTransportDistance(RouteType.WATER,true,false);
	//DInfo("Distances: Truck="+road_mindistance+"/"+road_maxdistance+" Aircraft="+air_mindistance+"/"+air_maxdistance+" Train="+rail_mindistance+"/"+rail_maxdistance+" Boat="+water_mindistance+"/"+water_maxdistance,2);
	local goal=distance;
	if (goal >= road_mindistance && goal <= road_maxdistance)	{ tweaklist.AddItem(RouteType.ROAD,2*v_road); }
	if (goal >= rail_mindistance && goal <= rail_maxdistance)	{ tweaklist.AddItem(RouteType.RAIL,1*v_train); }
	if (goal >= air_mindistance && goal <= air_maxdistance)		{ tweaklist.AddItem(RouteType.AIR,4*v_air); }
	if (goal >= water_mindistance && goal <= water_maxdistance)	{ tweaklist.AddItem(RouteType.WATER,3*v_boat); }
	tweaklist.RemoveValue(0);
	return tweaklist;
	}

function cJobs::IsTransportTypeEnable(transport_type)
// return true if that transport type is enable in the game
	{
	switch (transport_type)
			{
			case	RouteType.ROAD:
				return	(INSTANCE.use_road && INSTANCE.job_road);
			case	RouteType.AIR:
				return	(INSTANCE.use_air && INSTANCE.job_air);
			case	RouteType.RAIL:
				return	(INSTANCE.use_train && INSTANCE.job_train);
			case	RouteType.WATER:
				return	(INSTANCE.use_boat && INSTANCE.job_boat);
			}
	}

function cJobs::JobIsNotDoable(uid)
// set the undoable status for that job
	{
	local badjob=cJobs.Load(uid);
	if (!badjob) { return; }
	badjob.isdoable=false;
	cJobs.badJobs.AddItem(uid,0);
	}

function cJobs::UpdateDoableJobs()
// Update the doable status of the job indexer
	{
	cJobs.CheckLimitedStatus();
	DInfo("Analysing the task pool",0);
	local parentListID=AIList();
	INSTANCE.main.jobs.jobDoable.Clear();
	local topair=0;
	local toproad=0;
	local toprail=0;
	local topwater=0;
	cJobs.CostTopJobs[RouteType.RAIL]=0;
	cJobs.CostTopJobs[RouteType.AIR]=0;
	cJobs.CostTopJobs[RouteType.WATER]=0;
	cJobs.CostTopJobs[RouteType.ROAD]=0;
	// reset all top jobs
    local top50 = 0;
    foreach (id, value in cRoute.RouteIndexer)
		{
		if (id < 2)	{ continue; } // ignore virtual
		local j = cJobs.Load(id);
		if (!j)	{ continue; }
		parentListID.AddItem(j.parentID,0);
		}
	foreach (id, value in INSTANCE.main.jobs.jobIndexer)
		{
		if (id == 0 || id == 1)	{ continue; } // ignore virtual
		local doable=1;
		local myjob=cJobs.Load(id);
		if (!myjob)	{ continue; }
		doable = myjob.isdoable;
		// not doable if not doable
		local vehtest=null;
        if (doable) { doable = cJobs.IsTransportTypeEnable(myjob.roadType); }
		// not doable if disabled
		if (doable && myjob.ranking==0)	{ doable=false; }
		// not doable if ranking is at 0
		//if (doable && (myjob.SourceProcess.ScoreRating == 0 || myjob.TargetProcess.ScoreRating ==0))	{ doable = false; }
		// not doable if score rating is at 0
		if (doable)
			// not doable if max distance is limited and lower the job distance
				{
				local curmax = cJobs.GetTransportDistance(myjob.roadType, false, !INSTANCE.main.bank.unleash_road);
				if (curmax < myjob.distance)	{ doable=false; }
				}
		// not doable if any parent is already in use
		if (doable && parentListID.HasItem(myjob.parentID))
					{
					DInfo("Job already done by parent job ! First pass filter",4);
					doable=false;
					}
		if (doable && !myjob.SourceProcess.IsTown && !AIIndustry.IsValidIndustry(myjob.SourceProcess.ID))	{ doable=false; }
		// not doable if the industry no longer exist
		if (doable && myjob.roadType == RouteType.AIR && (myjob.SourceProcess.CargoProduce.GetValue(cCargo.GetPassengerCargo()) < 100 || myjob.TargetProcess.CargoProduce.GetValue(cCargo.GetPassengerCargo()) < 100))	{ doable=false; }
		// not doable because aircraft with poor towns don't make good jobs
		if (doable && !INSTANCE.main.bank.unleash_road && myjob.roadType == RouteType.RAIL && myjob.cargoID == cCargo.GetPassengerCargo())	{ doable=false; }
		// not doable until roads are unleash, trains aren't nice in town, so wait at least a nice big town to build them
		if (doable && myjob.SourceProcess.IsTown && DictatorAI.GetSetting("allowedjob") == 1)	{ doable=false; }
		// not doable if town jobs is not allow
		if (doable && !myjob.SourceProcess.IsTown && DictatorAI.GetSetting("allowedjob") == 2)	{ doable=false; }
		// not doable if industry jobs is not allow
		if (doable && INSTANCE.safeStart > 0 && myjob.roadType != RouteType.ROAD && cJobs.IsTransportTypeEnable(RouteType.ROAD))	{ doable = false; }
		// disable until safeStart is over
		if (doable)
				{
				switch (myjob.roadType)
						{
						case	RouteType.AIR:
							if (topair < myjob.ranking && myjob.cargoID == cCargo.GetPassengerCargo())
									{
									cJobs.CostTopJobs[myjob.roadType]=myjob.moneyToBuild;
									topair=myjob.ranking;
									}
							break;
						case	RouteType.ROAD:
							if (toproad < myjob.ranking)
									{
									cJobs.CostTopJobs[myjob.roadType]=myjob.moneyToBuild;
									toproad=myjob.ranking;
									}
							break;
						case	RouteType.WATER:
							if (topwater < myjob.ranking)
									{
									cJobs.CostTopJobs[myjob.roadType]=myjob.moneyToBuild;
									topwater=myjob.ranking;
									}
							break;
						case	RouteType.RAIL:
							if (toprail < myjob.ranking)
									{
									cJobs.CostTopJobs[myjob.roadType]=myjob.moneyToBuild;
									toprail=myjob.ranking;
									}
							break;
						}
				}
        local airValid=(doable && !INSTANCE.main.bank.unleash_road && cJobs.CostTopJobs[RouteType.AIR] > 0 && (cBanker.CanBuyThat(cJobs.CostTopJobs[RouteType.AIR]) || INSTANCE.main.carrier.warTreasure > cJobs.CostTopJobs[RouteType.AIR]) && cJobs.IsTransportTypeEnable(RouteType.AIR) && INSTANCE.safeStart == 0);
		if (airValid && myjob.roadType == RouteType.ROAD && myjob.cargoID == cCargo.GetPassengerCargo())	{ doable = false; }
		// disable because we have funds to build an aircraft job
		local train_check = true;
		if (doable)
				{
				foreach (s_juid, _ in myjob.SourceProcess.UsedBy) // check if source process is use by another train job
					{
					local tload = cJobs.Load(s_juid);
					if (!tload || tload.roadType == RouteType.RAIL)	{ train_check = false; break; }
					}
				}
		else	{ train_check = false; }
		if (train_check)
				{
				foreach (t_juid, _ in myjob.TargetProcess.UsedBy)
					{
					local tload = cJobs.Load(t_juid);
					if (!tload || tload.roadType == RouteType.RAIL)	{ doable = false; train_check = false; break; }
					}
				}
		// disable train if source or target is already use by another train job.
        local trainValid=(train_check && doable && !INSTANCE.main.bank.unleash_road && cJobs.CostTopJobs[RouteType.RAIL] > 0 && (cBanker.CanBuyThat(cJobs.CostTopJobs[RouteType.RAIL]) || INSTANCE.main.carrier.warTreasure > cJobs.CostTopJobs[RouteType.RAIL]) && cJobs.IsTransportTypeEnable(RouteType.RAIL) && INSTANCE.safeStart == 0);
        if (trainValid && myjob.roadType == RouteType.ROAD) { doable = false; }
        // disable if we can make a train instead of a road
		if (doable && !cBanker.CanBuyThat(myjob.moneyToBuild))	{ doable=false; }
		// disable as we lack money
		if (doable)	{ myjob.jobDoable.AddItem(id, myjob.ranking); top50++; }
		}
	INSTANCE.main.jobs.jobDoable.Sort(AIList.SORT_BY_VALUE, false);
	DInfo(INSTANCE.main.jobs.jobIndexer.Count()+" jobs found",2);
	DInfo(INSTANCE.main.jobs.jobDoable.Count()+" jobs doable",2);
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
			retList.KeepBetweenValue(cJobs.distanceLimits[0], rmax);
			}
	else    {
			retList=AIIndustryList_CargoAccepting(cargo_id);
			retList.Valuate(AIIndustry.GetDistanceManhattanToTile, srcloc);
			retList.KeepBetweenValue(cJobs.distanceLimits[0], rmax);
			}
	return retList;
	}

function cJobs::CreateNewJob(srcUID, dstID, cargo_id, road_type, _distance)
// Create a new Job
	{
	local newjob=cJobs();
	newjob.SourceProcess = cProcess.Load(srcUID);
	if (!newjob.SourceProcess)	{ return false; }
	if (cCargo.IsCargoForTown(cargo_id))	{ dstID=cProcess.GetUID(dstID, true); }
	newjob.TargetProcess = cProcess.Load(dstID);
	if (!newjob.TargetProcess)	{ return false; }
	// filters unwanted jobs
	if (road_type == RouteType.WATER && (!newjob.SourceProcess.WaterAccess || !newjob.TargetProcess.WaterAccess))   { return false; }
    // disable boat job without reachable access
	if (road_type == RouteType.AIR && cargo_id != cCargo.GetPassengerCargo()) { return false; }
	// only pass for aircraft, we will randomize if pass or mail later
	if (srcUID < 10000 && AIIndustry.IsBuiltOnWater(newjob.SourceProcess.ID))
        {
        if (cargo_id == cCargo.GetPassengerCargo()) { if (road_type != RouteType.AIR)  { return false; } }
                                            else    { if (road_type != RouteType.WATER)  { return false; } }
        }
    // allow passenger only for aircraft, and other cargos only for boats
	if (cargo_id == cCargo.GetPassengerCargo() && !newjob.SourceProcess.IsTown && road_type == RouteType.AIR && !AIIndustry.HasHeliport(newjob.SourceProcess.ID))	{ return; }
	// make sure the industry have an heliport we could use for aircraft (choppers), should fix FIRS Industry hotels.
	newjob.distance = _distance;
	newjob.roadType = road_type;
	newjob.cargoID = cargo_id;
	newjob.GetUID();
	newjob.Save();
	cJobs.RefreshValue(newjob.UID,true); // update ranking, cargo amount... must be call after GetUID
    return true;
	}

function cJobs::AddNewIndustryOrTown(industryID, istown)
// Add a new industry/town job: this will add all possibles jobs doable with it (transport type + all cargos)
	{
	local p_uid = cProcess.GetUID(industryID, istown);
	local p = cProcess.Load(p_uid);
	if (!p)	{ return; }
	local position=p.Location;
	local cargoList=p.CargoProduce;
	cargoList.RemoveItem(cCargo.GetMailCargo());
	// Remove the mail cargo, it's too poor for anyone except trucks, but this add more trucks/bus to town that are already too crowd.
	foreach (cargoid, amount in cargoList)
		{
		local targetList=cJobs.GetJobTarget(p.ID, cargoid, p.IsTown, p.Location); // find where we could transport it
		local pause = cLooper();
		foreach (destination, distance in targetList)
			{
			local transportList=cJobs.GetTransportList(distance);	// find possible ways to transport that
			local pause = cLooper();
			foreach (transtype, dummy2 in transportList)
				{
				cJobs.CreateNewJob(p.UID, destination, cargoid, transtype, distance);
				local pause = cLooper();
				}
			}
		}
	}

function cJobs::DeleteJob(uid)
// Remove all job references
	{
	DInfo("Removing job #"+uid+" from database",4);
	if (uid in cJobs.database)	{ delete cJobs.database[uid]; }
	if (cJobs.jobIndexer.HasItem(uid))	{ cJobs.jobIndexer.RemoveItem(uid); }
	if (cJobs.jobDoable.HasItem(uid))	{ cJobs.jobDoable.RemoveItem(uid); }
	if (cJobs.badJobs.HasItem(uid))	{ cJobs.badJobs.RemoveItem(uid); }
	}

function cJobs::DeleteIndustry()
// Remove an industry and all jobs using it
	{
	if (cJobs.deadIndustry.IsEmpty())	{ return; }
	foreach (object in cJobs.database)
		{
		foreach (industryID, _ in cJobs.deadIndustry)
			{
			if ((!object.SourceProcess.IsTown && object.SourceProcess.ID == industryID) || (!object.TargetProcess.IsTown && object.TargetProcess.ID == industryID))	{ cJobs.DeleteJob(object.UID); }
			}
		local pause = cLooper();
		}
	cJobs.deadIndustry.Clear();
	}

function cJobs::MarkIndustryDead(industry_id)
	{
	cProcess.DeleteProcess(industry_id);
	if (cJobs.rawJobs.HasItem(industry_id))	{ cJobs.RawJob_Delete(industry_id); }
                                    else	{ cJobs.deadIndustry.AddItem(industry_id,0); }
	}

function cJobs::RawJobHandling()
// Find a raw Job and add possible jobs from it to jobs database
	{
	if (cJobs.rawJobs.IsEmpty())	{ return; }
	local looper = (4 - cRoute.RouteIndexer.Count());
	if (looper < 1)	{ looper=1; }
	for (local j=0; j < looper; j++)
			{
			local p = cProcess.Load(cJobs.rawJobs.Begin());
			cJobs.AddNewIndustryOrTown(p.ID, p.IsTown);
			cJobs.RawJob_Delete(p.UID);
			if (cJobs.rawJobs.IsEmpty())	{ break; }
            }
	if (cJobs.rawJobs.IsEmpty())	{ DInfo("All raw jobs have been process",2); }
                            else	{ DInfo("rawJobs still to do: "+cJobs.rawJobs.Count(),1); }
	}

function cJobs::RawJob_Delete(pUID)
// Remove process from rawJob list
	{
	if (cJobs.rawJobs.HasItem(pUID))
			{
			DInfo("Removing industry #"+pUID+" from raw job",4); cJobs.rawJobs.RemoveItem(pUID);
			}
	}

function cJobs::RawJob_Add(pUID)
// Add a process to rawJob list
	{
	local p = cProcess.Load(pUID);
	if (!p)	{ return; }
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
		DInfo("Production of "+cCargo.GetCargoLabel(cargoid)+" : "+prod.Count(),4);
		alljob.AddList(prod);
		}
	local curr=0;
	foreach (puid, _ in alljob)
		{
		cJobs.RawJob_Add(puid);
		curr++;
		if (curr % 18 == 0)
				{
				DInfo(curr+" / "+alljob.Count(),0);
				}
		local pause = cLooper();
		}
	cJobs.rawJobs.Sort(AIList.SORT_BY_VALUE, false);
	}

function cJobs::CheckTownStatue()
// check if can add a statue to the town
	{
	if (INSTANCE.fairlevel==0)	{ return; } // no action if we play easy
	DInfo(cProcess.statueTown.Count()+" towns to build statue found.",2);
	local temp = AIList();
	temp.AddList(cProcess.statueTown);
	foreach (townID, dummy in temp)
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
		local zzz = cLooper();
		}
	}

function cJobs::GetUIDFromSubsidy(subID, onoff)
// set to onoff the state of subsidy in a job matching the subID subsidy
	{
	if (!AISubsidy.IsValidSubsidy(subID))	{ return; }
	local cargoID = AISubsidy.GetCargoType(subID);
	local sourceIsTown = (AISubsidy.GetSourceType(subID) == AISubsidy.SPT_TOWN);
	local targetIsTown = (AISubsidy.GetDestinationType(subID) == AISubsidy.SPT_TOWN);
	local sourceID = AISubsidy.GetSourceIndex(subID);
	local targetID = AISubsidy.GetDestinationIndex(subID);
	foreach (UID, _dummy in cJobs.jobDoable)
		{
		local j = cJobs.Load(UID);
		if (j.cargoID == cargoID && j.SourceProcess.IsTown == sourceIsTown && j.TargetProcess.IsTown == targetIsTown && j.SourceProcess.ID == sourceID && j.TargetProcess.ID == targetID)
				{
				j.subsidy=onoff;
				DInfo("Setting subsidy to "+onoff+" for jobs "+j.Name,1);
				return;
				}
		}
	}

function cJobs::SubsidyOn(subID)
	{
	cJobs.GetUIDFromSubsidy(subID, true);
	}

function cJobs::SubsidyOff(subID)
	{
	cJobs.GetUIDFromSubsidy(subID, false);
	}
