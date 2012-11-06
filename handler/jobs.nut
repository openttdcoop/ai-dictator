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

function cJobs::Load(UID)
// Load a job with some check against bad job
{
	local obj = cJobs.GetJobObject(UID);
	if (obj == null)
		{
		DWarn("cJobs.Load function return NULL",1);
		return false;
		}
	return obj;
}

function cJobs::TargetTownSet(townID)
// Add that town as a target town so we derank it, to avoid re-using this town too much
	{
	if (cJobs.targetTown.HasItem(townID))	cJobs.targetTown.SetValue(townID, cJobs.targetTown.GetValue(townID)+1);
							else	cJobs.targetTown.AddItem(townID, 1);
	}

function cJobs::CheckLimitedStatus()
// Check & set the limited status, at early stage we limit the distance to accept a job.
	{
	local oldmax=distanceLimits[1];
	local testLimitChange= GetTransportDistance(AIVehicle.VT_RAIL, false, INSTANCE.main.bank.unleash_road); // get max distance a train could do
	if (oldmax != distanceLimits[1])
	DInfo("Distance limit status change to "+INSTANCE.main.bank.unleash_road,2);
	}

function cJobs::Save()
// save the job
	{
	local dualrouteavoid=cJobs();
	dualrouteavoid.UID=null;
	dualrouteavoid.sourceObject = this.targetObject; // swap source and target
	dualrouteavoid.targetObject = this.sourceObject;
	dualrouteavoid.roadType=this.roadType;
	dualrouteavoid.cargoID=this.cargoID;
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
	jobinfo+=" to ";
	jobinfo+=this.targetObject.Name;
	this.Name=jobinfo;
	if (this.UID in database)	DInfo("Job "+this.UID+" already in database",2);
		else	{
			DInfo("Adding job #"+this.UID+" ("+parentID+") to job database: "+jobinfo,2);
			database[this.UID] <- this;
			cJobs.jobIndexer.AddItem(this.UID, 0);
			if (this.sourceObject.IsTown)	cJobs.UIDTown.AddItem(this.UID, this.sourceObject.ID);
							else	cJobs.UIDIndustry.AddItem(this.UID, this.sourceObject.ID);
			if (this.targetObject.IsTown)	cJobs.UIDTown.AddItem(this.UID, this.targetObject.ID);
							else	cJobs.UIDIndustry.AddItem(this.UID, this.targetObject.ID);
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
	local valuerank = this.sourceObject.ScoreProduction * this.cargoValue;
	if (this.subsidy)
		{
		if (AIGameSettings.IsValid("subsidy_multiplier"))	valuerank=valuerank * AIGameSettings.GetValue("subsidy_multiplier");
										else	valuerank=valuerank * 2;
		}
	// grant a bonus to subsidy
	local srcTown = this.sourceObject.IsTown;
	local dstTown = this.targetObject.IsTown;
	local stationrank = this.sourceObject.ScoreRating;
	// use rating of the source: industry or town
	if (dstTown)	stationrank = this.targetObject.ScoreRating;
	// use the rating of target if its a town
	if (srcTown && dstTown)
		{
		if (this.sourceObject.ScoreRating < this.targetObject.ScoreRating)	stationrank = this.targetObject.ScoreRating;
														stationrank = this.sourceObject.ScoreRating;
		}
	// take the poorest rank out of the two towns
	if (dstTown && cJobs.targetTown.HasItem(this.targetObject.ID) && (this.roadType==AIVehicle.VT_AIR || this.roadType==AIVehicle.VT_ROAD) && (this.cargoID == cCargo.GetPassengerCargo() || this.cargoID == cCargo.GetMailCargo()))
		// passenger or mail transport by road or aircraft to that target already
		{
		local drank= ( (10 * valuerank) / 100) * cJobs.targetTown.GetValue(this.targetObject.ID);
		DInfo("Downranking because target town is already handle : Lost "+drank,2);
		valuerank -= drank; // add 10% penalty for each time we have use that town as target, to avoid reuse a town too much
		}
	if (stationrank < 1)	
		{
		if (INSTANCE.fairlevel > 0)	stationrank=1;
						else	stationrank=0; // at this fairlevel, the job will simply be 0 and not done
		}
	if (valuerank < 1)	valuerank=1;
	this.ranking = stationrank * valuerank;
	}

function cJobs::RefreshValue(jobID, updateCost=false)
// refresh the datas from object
	{
	if (cJobs.IsInfosUpdate(jobID))	{ DInfo("JobID: "+jobID+" infos are fresh",2); return null; }
						else	{ DInfo("JobID: "+jobID+" refreshing infos",2); }
	cJobs.jobIndexer.SetValue(jobID,AIDate.GetCurrentDate());
	if (jobID == 0 || jobID == 1)	return null; // don't refresh virtual routes
	local myjob = cJobs.Load(jobID);
	if (!myjob)	return null;
	local badind=false;
	// avoid handling a dead industry we didn't get the event yet
	if (!myjob.sourceObject.IsTown && !AIIndustry.IsValidIndustry(myjob.sourceObject.ID))
		{
		badind=true;
		cJobs.DeleteIndustry(myjob.sourceID,false);
		}
	if (!myjob.targetObject.IsTown && !AIIndustry.IsValidIndustry(myjob.targetObject.ID))
		{
		badind=true;
		cJobs.DeleteIndustry(myjob.targetID,false);
		}
	if (badind)
		{
		DInfo("Removing bad industry from the job pool: "+myjob.UID,0);
		local deadroute=cRoute.GetRouteObject(myjob.UID);
		if (deadroute != null)	deadroute.RouteIsNotDoable();
		return;
		}
	if (myjob.isUse)	return;	// no need to refresh an already done job
	::AIController.Sleep(1);
	// moneyGains, ranking & cargoAmount
	myjob.sourceObject.UpdateScore();
	if (myjob.sourceObject.IsTown)
		{
		myjob.cargoAmount=myjob.sourceObject.CargoProduce.GetValue(myjob.cargoID);
		if (myjob.targetObject.IsTown)
			{
			myjob.targetObject.UpdateScore();
			local average=myjob.targetObject.CargoProduce.GetValue(myjob.cargoID);
			if (average < 60 || myjob.cargoAmount < 60)
					{ // poor towns makes poor routes, this will add another malus because of that poor town
					if (average < myjob.cargoAmount)	myjob.cargoAmount=average;
					}
				else	myjob.cargoAmount=(myjob.cargoAmount+average) / 2 ; // average towns pop, help find best route
			}
		}
	else	{ // industry
		myjob.cargoAmount=myjob.sourceObject.CargoProduce.GetValue(myjob.cargoID);
		}
	if (updateCost)	myjob.EstimateCost();
	if (myjob.cargoAmount < 1)	myjob.ranking = 0;
					else	myjob.RankThisJob();
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
	INSTANCE.main.jobs.UpdateDoableJobs();
	smallList.AddList(cJobs.jobIndexer);
	smallList.Valuate(cJobs.IsInfosUpdate);
	smallList.KeepValue(0); // keep only ones that need refresh
	smallList.Valuate(AIBase.RandItem);
	smallList.KeepTop(5); // refresh 5 random jobs that need a refresh
	foreach (smallID, dvalue in smallList)	{ INSTANCE.main.jobs.RefreshValue(smallID, true); }
	smallList.Clear();
	smallList.AddList(cJobs.jobDoable);
	smallList.Sort(AIList.SORT_BY_VALUE,false);
	smallList.KeepTop(5); // Keep 5 top rank job doable
	if (INSTANCE.safeStart > 0 && smallList.IsEmpty())	INSTANCE.safeStart=0; // disable it if we cannot find any jobs
	return smallList;
	}

function cJobs::GetRanking(jobID)
// return the ranking for jobID
	{
	local myjob = cJobs.Load(jobID);
	if (!myjob) return 0;
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
			if (engine==-1)	engine=INSTANCE.main.carrier.ChooseRoadVeh(this.cargoID);
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
			if (engine==-1)	engine=INSTANCE.main.carrier.ChooseRailEngine(null,this.cargoID, true);
			if (engine==-1)	{ engineprice=500000000; 	INSTANCE.use_train=false; }
						else	{
							/*engineprice+=cEngine.GetPrice(engine.Begin());
							engineprice+=2*cEngine.GetPrice(engine.GetValue(engine.Begin()));
							rtype=cmain.vehicle.GetRailTypeNeedForEngine(engine.Begin());*/
							engineprice+=cEngine.GetPrice(engine);
							rtype=cCarrier.GetRailTypeNeedForEngine(engine);
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
		case	AIVehicle.VT_WATER: //TODO: fixme boat
			// 2 vehicle + 2 stations + 2 depot
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
			if (engine==-1)	engine=INSTANCE.main.carrier.ChooseAircraft(this.cargoID, this.distance, AircraftType.EFFICIENT);
			if (engine != null)	engineprice=cEngine.GetPrice(engine);
						else	engineprice=500000000;
			money+=engineprice*2;
			money+=2*(AIAirport.GetPrice(INSTANCE.main.builder.GetAirportType()));
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
	local badjob=cJobs.Load(uid);
	if (!badjob) return;
	badjob.isdoable=false;
	cJobs.badJobs.AddItem(uid,0);
	}

function cJobs::UpdateDoableJobs()
// Update the doable status of the job indexer
	{
	INSTANCE.main.jobs.CheckLimitedStatus();
	DInfo("Analysing the task pool",0);
	local parentListID=AIList();
	INSTANCE.main.jobs.jobDoable.Clear();
	local topair=0;
	local toproad=0;
	local toprail=0;
	local topwater=0;
	cJobs.CostTopJobs[AIVehicle.VT_RAIL]=0;
	cJobs.CostTopJobs[AIVehicle.VT_AIR]=0;
	cJobs.CostTopJobs[AIVehicle.VT_WATER]=0;
	cJobs.CostTopJobs[AIVehicle.VT_ROAD]=0;
	// reset all top jobs
	foreach (id, value in INSTANCE.main.jobs.jobIndexer)
		{
		if (id == 0 || id == 1)	continue; // ignore virtual
		local doable=1;
		local myjob=cJobs.Load(id);
		if (!myjob)	continue;
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
			local curmax = INSTANCE.main.jobs.GetTransportDistance(myjob.roadType, false, !INSTANCE.main.bank.unleash_road);
			if (curmax < myjob.distance)	{ doable=false; }
			}
		// not doable if any parent is already in use
		if (doable)
			if (parentListID.HasItem(myjob.parentID))
				{
				DInfo("Job already done by parent job ! First pass filter",2);
				doable=false;
				}
		if (doable && !myjob.sourceObject.IsTown && !AIIndustry.IsValidIndustry(myjob.sourceObject.ID))	doable=false;
		// not doable if the industry no longer exist
		if (doable && myjob.sourceObject.IsTown && DictatorAI.GetSetting("allowedjob") == 1)	doable=false;
		// not doable if town jobs is not allow
		if (doable && !myjob.sourceObject.IsTown && DictatorAI.GetSetting("allowedjob") == 2)	doable=false;
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
	foreach (jobID, rank in INSTANCE.main.jobs.jobDoable)
		{	// even some have already been filtered out in the previous loop, some still have pass the check succesfuly
			// but it should cost us less cycle to filter the remaining ones here instead of filter all of them before the loop
		local myjob=cJobs.Load(jobID);
		if (!myjob)	continue;
		local airValid=(cJobs.CostTopJobs[AIVehicle.VT_AIR] > 0 && (cBanker.CanBuyThat(cJobs.CostTopJobs[AIVehicle.VT_AIR]) || INSTANCE.main.carrier.warTreasure > cJobs.CostTopJobs[AIVehicle.VT_AIR]) && INSTANCE.use_air);
		local trainValid=(cJobs.CostTopJobs[AIVehicle.VT_RAIL] > 0 && (cBanker.CanBuyThat(cJobs.CostTopJobs[AIVehicle.VT_RAIL]) || INSTANCE.main.carrier.warTreasure > cJobs.CostTopJobs[AIVehicle.VT_RAIL]) && INSTANCE.use_train);
		if (myjob.roadType == AIVehicle.VT_ROAD && (airValid || trainValid))	cJobs.jobDoable.RemoveItem(jobID);
			// disable because we have funds to build an aircraft or a rail job

		if (parentListID.HasItem(myjob.parentID))
			{
			DInfo("Job already done by parent job ! Second pass filter",2);
			cJobs.jobDoable.RemoveItem(jobID);
			}
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
		retList.KeepBetweenValue(distanceLimits[0], rmax);
		}
	else	{
		retList=AIIndustryList_CargoAccepting(cargo_id);
		retList.Valuate(AIIndustry.GetDistanceManhattanToTile, srcloc);
		retList.KeepBetweenValue(distanceLimits[0], rmax);
		}
	return retList;
	}

function cJobs::CreateNewJob(srcUID, dstID, cargo_id, road_type, _distance)
// Create a new Job
	{
	local newjob=cJobs();
	newjob.sourceObject = cProcess.Load(srcUID);
	if (!newjob.sourceObject)	return;
	if (cCargo.IsCargoForTown(cargo_id))	dstID=cProcess.GetUID(dstID, true);
	newjob.targetObject = cProcess.Load(dstID);
	if (!newjob.targetObject)	return;
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
	}

function cJobs::DeleteIndustry(industry_id)
// Remove an industry and all jobs using it
{

/*	foreach (object in cJobs.database)
		{
		if ((!object.sourceObject.IsTown && object.sourceObject.ID == industry_id) || (!object.targetObject.IsTown && object.targetObject.ID == industry_id))	cJobs.DeleteJob(object.UID);
		AIController.Sleep(1);
		}*/
	local mapping = AIList();
	mapping.AddList(cJobs.UIDIndustry);
	mapping.KeepValue(industry_id);
	foreach (UID, _ in mapping)	cJobs.DeleteJob(UID);
	cJobs.RawJob_Delete(industry_id);
	cProcess.DeleteProcess(industry_id);
}

function cJobs::RawJobHandling()
// Find a raw Job and add possible jobs from it to jobs database
	{
	if (cJobs.rawJobs.IsEmpty())	return;
	local looper = (10 - cRoute.RouteIndexer.Count());
	if (looper < 1)	looper=1;
	for (local j=0; j < looper; j++)
		{
		local p = cProcess.Load(cJobs.rawJobs.Begin());
		cJobs.AddNewIndustryOrTown(p.ID, p.IsTown);
		cJobs.RawJob_Delete(p.UID);
		if (cJobs.rawJobs.IsEmpty())	break
		}
	if (cJobs.rawJobs.IsEmpty())	DInfo("All raw jobs have been process",1);
					else	DInfo("rawJobs still to do: "+cJobs.rawJobs.Count());

	}

function cJobs::RawJob_Delete(pUID)
// Remove process from rawJob list
	{
	if (cJobs.rawJobs.HasItem(pUID))	
		{
		DInfo("Removing industry #"+pUID+" from raw job",2); cJobs.rawJobs.RemoveItem(pUID);
		}
	}

function cJobs::RawJob_Add(pUID)
// Add a process to rawJob list
	{
	local p = cProcess.Load(pUID);
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
foreach (puid, _ in alljob)
	{
	cJobs.RawJob_Add(puid);
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

function cJobs::GetUIDFromSubsidy(subID, onoff)
{
	local sourceMapping = AIList();
	local targetMapping = AIList();
	local cargoID = AISubsidy.GetCargoType(subID);
	local sourceIsTown = (AISubsidy.GetSourceType(subID) == AISubsidy.SPT_TOWN);
	local targetIsTown = (AISubsidy.GetDestinationType(subID) == AISubsidy.SPT_TOWN);
	local sourceID = AISubsidy.GetSourceIndex(subID);
	local targetID = AISubsidy.GetDestinationIndex(subID);
	if (sourceIsTown)	sourceMapping.AddList(cJobs.UIDTown);
				sourceMapping.AddList(cJobs.UIDIndustry);
	if (targetIsTown)	targetMapping.AddList(cJobs.UIDTown);
				targetMapping.AddList(cJobs.UIDIndustry);
	sourceMapping.KeepValue(sourceID);
	targetMapping.KeepValue(targetID);
	if (sourceMapping.IsEmpty() || targetMapping.IsEmpty())	return; // cannot match
	// ok now let's see if any jobs have both of them
	foreach (sUID, dummy in sourceMapping)
		{
		foreach (tUID, _dummy in targetMapping)
			{
			if (sUID == tUID); // if both UID are the same, that job use the source and target we want
				{
				local task=cJobs.Load(sUID);
				if (!task)	continue;
					else	if (task.cargoID == cargoID)	{
											task.subsidy=onoff;
											DInfo("Setting subsidy to "+onoff+" for jobs "+task.Name,1);
											break;
											}
				}
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
