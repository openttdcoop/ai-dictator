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


// I've learned a lot from rondje's code about squirrel, thank you guys !



class cJobs
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

	roadLimited=true;	// true if max distance is limited by money
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
		roadLimited = (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 50000 && AICompany.GetLoanAmount()==0);
		}
}

function cJobs::GetUniqID()
	{
	local uID=null;
	local parentID = null;
	if (this.uniqID == null && this.sourceID != null && this.targetID != null && this.cargoID != null && this.roadType != null)
			{
			local v1=this.roadType+1;
			local v2=(this.cargoID+1)*v1*2;
			local v3=(this.targetID+1)*v2*8;
			local v4=(this.sourceID+1)*v3*32;
			parentID = (this.sourceID+1)*100+this.cargoID;
			uID = v1+v2+v3+v4;
			this.uniqID=uID;
			this.parentID=parentID;
			if (this.uniqID in database)	DWarn("JOBS -> Job "+uID+" already in database",2);
			else	{
				DInfo("JOBS -> Adding job "+uID+" ("+parentID+") to job database",2);
				database[this.uniqID] <- this;
				jobIndexer.AddItem(this.uniqID, 1);
				}
			}
	return this.uniqID;
	}

function cJobs::RefreshValue(jobID)
// refresh the datas from object
{
::AIController.Sleep(1);
local myjob = GetJobObject(jobID);
if (myjob == null) return null;
// foule, moneyGains, ranking & cargoAmount
}

function cJobs::RefreshAllValue()
// refesh datas of all objects
{
foreach (item, value in jobIndexer)	RefreshValue(item);
}

function cJobs::QuickRefesh()
// refresh datas on first 5 doable objects
	{
	local smallList=AIList();
	smallList.AddList(jobIndexer);
	smallList.KeepValue(1);
	smallList.KeepTop(5);
	foreach (item, value in smallList)	{ cJobs.RefreshValue(item); }
	return smallList;
	}

function cJobs::GetRanking(jobID)
// return the ranking for jobID
	{
	local myjob = GetJobObject(jobID);
	if (myjob == null) return 0;
	return myjob.ranking;
	}

function cJobs::GetNextJob()
// Return the next job uniqID to do, null if we have none
	{
	local smallList=QuickRefresh();
	smallList.Valuate(GetRanking);
	smallList.Sort(AIList.SORT_BY_VALUE, false);
	return smallList.Begin();
	}

function cJobs::RecheckDoable()
// rebuild our doable list
{
}

function cJobs::JobIsNotDoable()
// mark the job as not doable
	{
	local myjob=GetJobObject(this.uniqID)
	if (myjob == null) return;
	myjob.isdoable=false;
	}

function cJobs::CreateNewJob(srcID, tgtID, src_istown, cargo_id, road_type)
	{
	local newjob=cJobs();
	newjob.sourceID=srcID;
	newjob.sourceID = srcID;
	newjob.targetID = tgtID;
	newjob.source_istown = src_istown;
	newjob.target_istown = cCargo.IsCargoForTown(cargo_id);
	if (newjob.source_istown)	newjob.source_location=AITown.GetLocation(srcID);
			else		newjob.source_location=AIIndustry.GetLocation(srcID);
	if (newjob.target_istown)	newjob.target_location=AITown.GetLocation(tgtID);
			else		newjob.target_location=AIIndustry.GetLocation(tgtID);
	newjob.distance=AITile.GetDistanceManhattanToTile(newjob.source_location, newjob.target_location);
	DInfo("Distance="+newjob.distance,2);
	newjob.roadType=road_type;
	newjob.cargoID=cargo_id;
	local money = 0;
	local clean= AITile.GetBuildCost(AITile.BT_CLEAR_HOUSE);
	// local engine=root.carrier.GetVehicle TODO: fixme with ccarrier
	local engineprice=0;
	local daystransit=0;
	switch (roadType)
		{
		case	AIVehicle.VT_ROAD:
			// 2 vehicle + 2 stations + 2 depot + 4 destuction + 4 road for entry and length*road
			money+=engineprice*2;
			money+=2*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_TRUCK_STOP));
			money+=2*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_DEPOT));
			money+=4*clean;
			money+=(4+distance)*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD));
			daystransit=16;
		break;
		case	AIVehicle.VT_RAIL:
			local rtype=AIRail.GetCurrentRailType();
			// 1 vehicle + 2 stations + 2 depot + 4 destuction + 3 tracks entries and length*rail
			money+=engineprice*2;
			money+=(2+5)*(AIRail.GetBuildCost(rtype, AIRoad.BT_STATION)); // station train 5 length
			money+=2*(AIRail.GetBuildCost(rtype, AIRoad.BT_DEPOT));
			money+=4*clean;
			money+=(3+distance)*(AIRail.GetBuildCost(rtype, AIRoad.BT_TRACK));
			daystransit=4;
		break;
		case	AIVehicle.VT_WATER:
			// 2 vehicle + 2 stations + 2 depot
			money+=engineprice*2;
			money+=2*(AIMarine.GetBuildCost(AIMarine.BT_DOCK));
			money+=2*(AIMarine.GetBuildCost(AIMarine.BT_DEPOT));
			daystransit=32;
		break;
		case	AIVehicle.VT_AIR:
			// 2 vehicle + 2 airports
			money+=engineprice*2;
			money+=2*(AIAirport.GetPrice(INSTANCE.builder.GetAirportType()));
			daystransit=4;
		break;
		}
	newjob.moneyToBuild=money;
	newjob.cargoValue=AICargo.GetCargoIncome(newjob.cargoID, newjob.distance, daystransit);
	if (newjob.source_istown)	newjob.cargoAmount= AITown.GetLastMonthProduction (srcID, cargo_id);
				else	newjob.cargoAmount= AIIndustry.GetLastMonthProduction (srcID, cargo_id);
	newjob.moneyGains=newjob.cargoAmount * newjob.cargoValue;
	newjob.GetUniqID();
	}

function cJobs::GetTransportDistance(transport_type, get_min)
// Return the transport distance a transport_type could do
// get_min = true return minimum distance
// get_min = false return maximum distance
// if roadLimited is true, we limit maximum return distance, else we return the real max distance
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
				else	toret=(roadLimited) ? lim : max;
			}
		if (min < small)	small=min;
		if (lim > big)		big=lim;
		i+=2; // next iter
		}
	distanceLimits[0]=small;
	distanceLimits[1]=big;
	return toret;
	}

function cJobs::GetJobTarget(src_id, cargo_id, src_istown)
// return an AIList with all possibles destinations, values are location
	{
	local retList=AIList();
	local srcloc=null;
	local rmax=GetTransportDistance(0,false); // just to make sure min&max are init
	if (src_istown)	srcloc=AITown.GetLocation(src_id);
		else	srcloc=AIIndustry.GetLocation(src_id);
	if (cCargo.IsCargoForTown(cargo_id))
		{
		retList=AITownList();
		retList.Valuate(AITown.GetDistanceManhattanToTile, srcloc);
		retList.KeepBetweenValue(distanceLimits[0], rmax);
		retList.Valuate(AITown.GetLocation);
		}
	else	{
		retList=AIIndustryList_CargoAccepting(cargo_id);
		retList.KeepBetweenValue(distanceLimits[0], rmax);
		retList.Valuate(AIIndustry.GetLocation);
		}
	return retList;
	}

function cJobs::GetJobSourceCargoList(src_id, src_istown)
// Return a list of all cargos produce at source
	{
	local cargoList=AIList();
	if (src_istown)
		{
		cargoList.AddItem(cCargo.GetPassengerCargo(), 1);
		cargoList.AddItem(cCargo.GetMailCargo(), 1);
		}
	else	cargoList=AICargoList_IndustryProducing(src_id);
	return cargoList;
	}

function cJobs::GetTransportList(distance)
// Return a list of transport we can use
	{
	// road assign as 2, trains assign as 1 air assign as 4 boat, assign as 3
	// it's just AIVehicle.VehicleType+1
	local v_train=1;
	local v_boat =1;
	local v_air  =1;
	local v_road =1;
	if (!INSTANCE.use_train) v_train=0;
	if (!INSTANCE.use_boat) v_boat=0;
	if (!INSTANCE.use_air) v_air=0;
	if (!INSTANCE.use_road) v_road=0;
	local tweaklist=AIList();
	local road_maxdistance=GetTransportDistance(AIVehicle.VT_ROAD,false);
	local road_mindistance=GetTransportDistance(AIVehicle.VT_ROAD,true);
	local rail_maxdistance=GetTransportDistance(AIVehicle.VT_RAIL,false);
	local rail_mindistance=GetTransportDistance(AIVehicle.VT_RAIL,true);
	local air_maxdistance=GetTransportDistance(AIVehicle.VT_AIR,false);
	local air_mindistance=GetTransportDistance(AIVehicle.VT_AIR,true);
	local water_maxdistance=GetTransportDistance(AIVehicle.VT_WATER,false);
	local water_mindistance=GetTransportDistance(AIVehicle.VT_WATER,true);
	//DInfo("Distances: Truck="+road_mindistance+"/"+road_maxdistance+" Aircraft="+air_mindistance+"/"+air_maxdistance+" Train="+rail_mindistance+"/"+rail_maxdistance+" Boat="+water_mindistance+"/"+water_maxdistance,2);
	local goal=distance;
//	if (kind==AICargo.TE_MAIL || kind==AICargo.TE_PASSENGERS)
//	{
	if (goal >= road_mindistance && goal <= road_maxdistance)	{ tweaklist.AddItem(1,2*v_road); }
	if (goal >= rail_mindistance && goal <= rail_maxdistance)	{ tweaklist.AddItem(0,1*v_train); }
	if (goal >= air_mindistance && goal <= air_maxdistance)		{ tweaklist.AddItem(3,4*v_air); }
	if (goal >= water_mindistance && goal <= water_maxdistance)	{ tweaklist.AddItem(2,3*v_boat); }
//	}
//else	{ // indudstries have that effect, i won't allow something other than trucks&trains
//	if (goal >= road_mindistance && goal <= road_maxdistance)	{ tweaklist.AddItem(1,1*v_road); }
//	if (goal >= rail_mindistance && goal <= rail_maxdistance)	{ tweaklist.AddItem(2,2*v_train); }
//	}
	//DInfo("tweaklist "+tweaklist.Count());
	//foreach (ttype, value in tweaklist)	DInfo("ttype = "+ttype+" value="+value);
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
	
function cJobs::UpdateDoableJobs()
// Update the doable status of the job indexer
	{
	DInfo("JOBS -> Upating job indexer and doable list",2);
	local parentListID=AIList();
	jobDoable.Clear();
	foreach (id, value in jobIndexer)
		{
		local doable=1;
		local myjob=GetJobObject(id);
		DInfo("Dump: "+myjob.sourceID+" "+myjob.targetID+" "+myjob.distance,2);
		doable=myjob.isdoable;
		// not doable if not doable
		if (doable && myjob.isUse)	doable=false;
		// not doable if already done
		if (doable)	doable=(cBanker.CanBuyThat(myjob.moneyToBuild));
		// not doable if not enough money
		if (doable)
		// not doable if max distance is limited and lower the job distance
			{
			local curmax = GetTransportDistance(myjob.roadType, false);
			if (curmax < myjob.distance)	doable=false;
			DInfo("currmax="+curmax+" dist="+myjob.distance+" ");
			}
		if (doable)
		// not doable if any parent is already in use
			if (myjob.parentID in parentListID)	doable=false;
							else	parentListID.AddItem(myjob.parentID,1);
		if (doable)	{ jobIndexer.SetValue(id, 1); jobDoable.AddItem(id, myjob.ranking); }
			else	jobIndexer.SetValue(id, 0);
		//INSTANCE.Sleep(1);
		}
	jobDoable.Sort(AIList.SORT_BY_VALUE, false);
	DInfo("JOBS -> "+jobIndexer.Count()+" jobs known",2);
	DInfo("JOBS -> "+jobDoable.Count()+" jobs doable",2);
	//foreach (id, value in jobDoable)	{ DInfo("After update: "+id+" - "+value,2); }
	}

function cJobs::AddNewIndustry(industryID)
// Add a new industry possible jobs
	{
	local smaxLimit= roadLimited; // backup road limited
	roadLimited = false;
	local cargoList=GetJobSourceCargoList(industryID, false);
	//DInfo("Industry provide "+cargoList.Count()+" cargo",2);
	foreach (cargoid, cargodummy in cargoList)
		{
		local targetList=GetJobTarget(industryID, cargoid, false);
		//DInfo("Found "+targetList.Count()+" possible destinations",2);
		foreach (destination, locations in targetList)
			{
			distance=AIIndustry.GetDistanceManhattanToTile(industryID, locations)
			// now find possible ways to transport that
			local transportList=GetTransportList(distance);
			//DInfo("Found "+transportList.Count()+" possible transport type",2);
			foreach (transtype, dummy2 in transportList)
				{
				this.uniqID=null;
				CreateNewJob(industryID, destination, false, cargoid, transtype);
				}
			}
		}
	roadLimited=smaxLimit; // now restore it's real value
	smaxLimit = GetTransportDistance(0,false); // now re-set our real max limit
	}
