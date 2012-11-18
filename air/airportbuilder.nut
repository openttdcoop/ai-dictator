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

function cBuilder::AirportNeedUpgrade(stationid)
// this upgrade an existing airport to a newer one
{
	// better check criticals stuff before stopping our traffic and find we're going to fail
	local station=cStation.Load(stationid);
	local firstroute = false;
	if (station != false)	{ firstroute = cRoute.Load(station.s_Owner.Begin()); }
	if (!firstroute || !station)	{ DInfo("Found an airport attach to no route ! Giving up.",1); return false }
	local townrating=0;
	local noiselevel=0;
	local townid=-1;
	local start=false;
	if (firstroute.SourceStation.s_ID == stationid)	{ start=true; townid=firstroute.SourceProcess.ID; }
								else	{ start=false; townid=firstroute.TargetProcess.ID; }
	local now=AIDate.GetCurrentDate();
	if (station.s_DateLastUpgrade != null && now - station.s_DateLastUpgrade < 120) // wait 40 days before each trys
		{
		DInfo("We try to upgrade that airport not so long ago, giving up",1);
		return false;
		}
	station.s_DateLastUpgrade=now;
	if (!cBanker.CanBuyThat(station.s_MoneyUpgrade))
		{
		DInfo("We still lack money to upgrade the airport. Will retry later with "+station.s_MoneyUpgrade+" credits",1);
		station.s_MoneyUpgrade = station.s_MoneyUpgrade / 2; // we decrease it, in case we overestimate the cost
		return false;
		}
	local airporttype=INSTANCE.main.builder.GetAirportType();
	townrating=AITown.GetRating(townid,AICompany.COMPANY_SELF);
	noiselevel=AITown.GetAllowedNoise(townid);
	local ourloc=0;
	local ournoise=AIAirport.GetNoiseLevelIncrease(station.s_Location,airporttype);
	DInfo("Town rating = "+townrating+" noiselevel="+noiselevel,2);
	cTileTools.SeduceTown(townid);
	townrating=AITown.GetRating(townid, AICompany.COMPANY_SELF);
	if (townrating < AITown.TOWN_RATING_GOOD)
		{ DInfo("Cannot upgrade airport, too dangerous with our current rating with this town.",1); station.s_DateLastUpgrade+=70; return false; }
	local cost=AIAirport.GetPrice(airporttype)*cBanker.GetInflationRate();
	cost+=1000; // i'm not sure how much i need to destroy old airport
	INSTANCE.main.bank.RaiseFundsBy(cost);
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < cost)
		{ DInfo("Cannot upgrade airport, need "+cost+" money for success.",1); INSTANCE.main.carrier.vehnextprice=cost; return false; }
	DInfo("Trying to upgrade airport #"+stationid+" "+station.s_Name,0);
	// find traffic that use that airport & reroute it
	// prior to reroute aircraft, make sure they have a route to go
	foreach (ownID, dummy in station.s_Owner)
		{
		local dummyObj=cRoute.Load(ownID);
		if (!dummyObj)	continue;
		INSTANCE.main.carrier.VehicleBuildOrders(dummyObj.GroupID,true);
		}
	INSTANCE.main.carrier.AirNetworkOrdersHandler(); // or maybe it's one from our network that need orders
	local counter=0;
	local maxcount=600;
	local result=false;
	INSTANCE.main.carrier.VehicleHandleTrafficAtStation(station.s_ID, true);
	// time to pray a bit for success, we could invalidate a working route here
	do	{
		local test=AITestMode();
		result=AIAirport.RemoveAirport(station.s_Location);
		test=null;
		INSTANCE.main.carrier.VehicleHandleTrafficAtStation(station.s_ID,true);
		counter++;
		if (!result) 
			{
			AIController.Sleep(10);
			INSTANCE.main.carrier.VehicleIsWaitingInDepot(true); // try remove aircraft from airport
			}
		} while (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 1000 && !result && counter < maxcount);	
	if (!result)	{
				INSTANCE.main.carrier.VehicleHandleTrafficAtStation(station.s_ID,false);
				return false;
				}

	result=INSTANCE.main.builder.BuildAirStation(start, firstroute.UID);
	if (result == -1)	return false;
	DInfo("Airport was upgrade successfuly !",1);
//INSTANCE.main.carrier.VehicleHandleTrafficAtStation(AIStation.GetStationID(result), false);
	INSTANCE.main.carrier.vehnextprice=0; // We might have put a little havock while upgrading, reset this one
	station.s_DateLastUpgrade=null;
}

function cBuilder::GetAirportType()
// return an airport type to build or null
{
local AirType=null;
if (AIAirport.IsValidAirportType(AIAirport.AT_SMALL))	{ AirType=AIAirport.AT_SMALL; }
if (AIAirport.IsValidAirportType(AIAirport.AT_LARGE))	{ AirType=AIAirport.AT_LARGE; }
if (AIAirport.IsValidAirportType(AIAirport.AT_METROPOLITAN))	{ AirType=AIAirport.AT_METROPOLITAN; }
if (AIAirport.IsValidAirportType(AIAirport.AT_INTERNATIONAL))	{ AirType=AIAirport.AT_INTERNATIONAL; }
if (AIAirport.IsValidAirportType(AIAirport.AT_INTERCON))	{ AirType=AIAirport.AT_INTERCON; }
return AirType;
}

function cBuilder::AirportMaker(tile, airporttype)
// Build an airport at tilebase
{
	local essai=false;
	if (!cTileTools.SeduceTown(AITile.GetClosestTown(tile)))
		{
		DInfo("Town doesn't like us...",1);
		cTileTools.terraformCost.AddItem(999995,1); // tell rating is poor
		}
	DInfo("Cost to build an airport = "+AIAirport.GetPrice(airporttype)*cBanker.GetInflationRate(),2);
	INSTANCE.main.bank.RaiseFundsBy(AIAirport.GetPrice(airporttype)*cBanker.GetInflationRate());
	essai=AIAirport.BuildAirport(tile, airporttype, AIStation.STATION_NEW);
	if (essai)	DInfo("-> Built an airport at "+tile,1);
		else	DError("Cannot build an airport at "+tile,1);
	return essai;	
}

function cBuilder::BuildAirStation(start, routeID=null)
// Create an airport for our route at start/destination
// return airport stationID on success
{
	local road=false;
	if (routeID==null)	road=INSTANCE.main.route;
			else		road=cRoute.Load(routeID);
	if (road == false)	return -1;
	local townname="none";
	local helipadonly=false;
	// Pickup the airport we can build
	local airporttype=cBuilder.GetAirportType();
	local air_x=AIAirport.GetAirportWidth(airporttype);
	local air_y=AIAirport.GetAirportHeight(airporttype);
	local rad=AIAirport.GetAirportCoverageRadius(airporttype);
	local cargoID=cCargo.GetPassengerCargo();
	local ignoreList=AIList();
	local oldAirport = null;
	local newAirport = null;
	local oldAirport_Remove=false;
	local airportUpgrade=false;
	local oldAirport_Noise=0;
	local tilelist=AITileList();
	local success=false;
	local allfail=true;
	local newStation=-1;
	local townnoise=0;
	local heliloc=null;
	local needTime=false;
	local needMoney=0;
	local solverlist=AITileList();
	local townID=null;
	if (start)
		{
		if (road.SourceProcess.IsTown)
			{
			tilelist= cTileTools.GetTilesAroundTown(road.SourceProcess.ID);
			helipadonly=false;
			townname=road.SourceProcess.Name;
			townnoise=AITown.GetAllowedNoise(road.SourceProcess.ID);
			oldAirport = (typeof(road.SourceStation) == "instance") ? road.SourceStation : null;
			townID=road.SourceProcess.ID;
			}
		else	{
			// no coverage need, we know exactly where we go
			helipadonly=true;
			heliloc=road.SourceProcess.Location;
			}
		}
	else	{
		if (road.TargetProcess.IsTown)
			{
			tilelist= cTileTools.GetTilesAroundTown(road.TargetProcess.ID);
			townname= road.TargetProcess.Name;
			townnoise=AITown.GetAllowedNoise(road.TargetProcess.ID);
			helipadonly=false;
			oldAirport = (typeof(road.TargetStation) == "instance") ? road.TargetStation : null;
			townID=road.TargetProcess.ID;
			}
		else	return -1;
			// we should never have a platform as destination station !!!
		}
	if (oldAirport != null)
		{
		airportUpgrade=true;
		oldAirport_Width=AIAirport.GetAirportWidth(oldAirport.s_SubType);
		oldAirport_Height=AIAirport.GetAirportHeight(oldAirport.s_SubType);
		ignoreList=cTileTools.FindStationTiles(oldAirport.s_Location);
		oldAirport_Noise=AIAirport.GetNoiseLevelIncrease(oldAirport.s_Location, oldAirport.s_SubType);
		cDebug.showLogic(ignoreList);
		DInfo("Found an old airport in town : we will upgrade it",1);
		if (!AIAirport.IsValidAirportType(oldAirport.s_SubType))	DWarn("Old airport type is no more buildable, this is highly dangerous !!!",0);
		}
	if (!helipadonly)
		{
		DInfo("Looking for a place to build an airport at "+townname,0);
		tilelist.Valuate(cTileTools.IsBuildable);
		tilelist.RemoveValue(0);
		local worktilelist=AIList();
		worktilelist.AddList(tilelist);
		worktilelist.Valuate(AIAirport.GetNoiseLevelIncrease,airporttype);
		worktilelist.RemoveAboveValue((townnoise + oldAirport_Noise));
		DInfo("Town "+townname+" noise level="+townnoise+" oldairportnoise="+oldAirport_Noise,2);
		if (worktilelist.IsEmpty())
				{
				DInfo("Town "+townname+" can only get a noise level of "+townnoise+" Giving up.",0);
				INSTANCE.main.builder.CriticalError=true;
				return -1;
				}
		worktilelist.Clear();
		foreach (tile, dummy in tilelist)
			{
			local newTile=cTileTools.IsBuildableRectangle(tile, air_x, air_y, ignoreList);
			if (newTile != -1)	worktilelist.AddItem(newTile,666);
			}
		tilelist.Clear();
		tilelist.AddList(worktilelist);
		tilelist.Valuate(AIAirport.GetNearestTown, airporttype);
	//	tilelist.Valuate(AITile.IsWithinTownInfluence,townID);
	//	tilelist.KeepValue(1);
	//	tilelist.Valuate(AITile.GetTownAuthority);
	// this is boring how openttd handle town authority and rating !!!
		tilelist.KeepValue(townID);
		tilelist.Valuate(cTileTools.IsTilesBlackList);
		tilelist.KeepValue(0);
		if (tilelist.IsEmpty())	
				{
				DInfo("There's no buildable space at "+townname+" where i could put an airport of "+air_x+"x"+air_y,0);
				INSTANCE.main.builder.CriticalError=true;
				return -1;
				}
		tilelist.Valuate(AITile.GetCargoAcceptance, cargoID, air_x, air_y, rad);
		tilelist.RemoveBelowValue(8);
		tilelist.Sort(AIList.SORT_BY_VALUE, false);
		solverlist.AddList(tilelist);
		tilelist.Valuate(AITile.IsWaterTile);
		tilelist.RemoveValue(1);
		tilelist.Valuate(AITile.GetCargoAcceptance, cargoID, air_x, air_y, rad);
		tilelist.RemoveBelowValue(8);
		foreach (tile, dummy in tilelist)
			{
			cDebug.PutSign(tile,".");
			local newTile=-1;
			if (cTileTools.IsAreaFlat(tile, air_x, air_y))	newTile=tile;
			if (newTile != -1)
				{
				DInfo("Found a flat area to try at "+newTile,1);
				cDebug.PutSign(newTile,"*");
				for (local tt=0; tt < 5; tt++)
					{
					if (airportUpgrade && !oldAirport_Remove)
						{
						oldAirport_Remove=AIAirport.RemoveAirport(oldAirport.s_Location);
						DInfo("Removing old airport : "+oldAirport.s_Name,1);
						if (oldAirport_Remove)	{ break; }
						}
					INSTANCE.Sleep(5);
					}
				if (airportUpgrade && !oldAirport_Remove)	{ needTime=true; break; }
				success=cBuilder.AirportMaker(newTile, airporttype);
				if (success)	{ newStation=newTile; break; }
						else	if (cTileTools.terraformCost.HasItem(999995))
								{
								cTileTools.terraformCost.RemoveItem(999995);
								needTime=true;
								break;
								}
				local pause = cLooper();
				}
			}
		if (!success && !needTime)
			{
			// Switch back to simple list of tile, solver work less hard to find a solve
			DInfo("Analyzing the surrounding of "+townname,0);
			local solver=cBuilder.AirportBestPlace_EvaluateHill(solverlist, air_x, air_y);
			if (solver.len() == 0)	{ DWarn("Nothing to do, we can't find any solve to build the airport",1); }
						else	{
							for (local tt=0; tt < 5; tt++)
								{
								if (airportUpgrade && !oldAirport_Remove)
									{
									oldAirport_Remove=AIAirport.RemoveAirport(oldAirport.s_Location);
									DInfo("Removing old airport : "+oldAirport.s_Name,1);
									if (oldAirport_Remove)	break;
									}
								INSTANCE.Sleep(5);
								}
							if (airportUpgrade && !oldAirport_Remove)	{ needTime=true; }
							if (!needTime)
								{
								newStation=cBuilder.AirportBestPlace_BuildFromSolve(solver, air_x, air_y, airporttype);
								if (cTileTools.terraformCost.HasItem(999999))
									{
									needMoney=cTileTools.terraformCost.GetValue(999999);
									cTileTools.terraformCost.RemoveItem(999999);
									}
								}
							}
			}
		}
	success= (newStation != -1 && !needTime);
	if (helipadonly)	success=true;
	if (needMoney > 0 && oldAirport != null)
		{
		oldAirport.s_MoneyUpgrade = needMoney;
		INSTANCE.main.carrier.vehnextprice += needMoney; // try to reserve the money for next upgrade try
		}
	if (!success)
		{
		DWarn("Failure to build an airport at "+townname,0);
		if (oldAirport_Remove)
			{
			DInfo("Trying to restore previous airport, feeling lucky ?",0);
			success=cBuilder.AirportMaker(oldAirport.s_Location, oldAirport.s_Type);
			if (success)	return oldAirport.s_ID;
					else	{
						foreach (ownerUID, _ in oldAirport.s_Owner)
							{
							OldAirport.OwnerReleaseStation(ownerUID);
							local deadowner=cRoute.Load(ownerUID);
							if (deadowner != false)	{ DInfo("BuildAirStation mark "+deadowner.UID+" undoable",1); deadowner.RouteIsNotDoable(); }
							}
						// and get ride of the old (now dead) station
						cStation.DeleteStation(oldAirport.s_ID);
						return -1;
						}
			}
		}
	if (success)
		{
		if (!helipadonly)
			{
			DInfo("Airport #"+AIStation.GetStationID(newStation)+"-"+AIStation.GetName(AIStation.GetStationID(newStation))+" built at "+townname,0);
			if (start)
				{
				road.SourceStation = AIStation.GetStationID(newStation);
				newStation = road.CreateNewStation(start);
				road.SourceStation = newStation;
				}
			else	{
				road.TargetStation = AIStation.GetStationID(newStation);
				newStation = road.CreateNewStation(start);
				road.TargetStation = newStation;
				}
			if (oldAirport_Remove)
				{
				foreach (ownerUID, dummy in oldAirport.s_Owner)
						{
						oldAirport.OwnerReleaseStation(ownerUID);
						local oldOwner = cRoute.Load(ownerUID);
						if (!oldOwner)	continue;
						local srcValid = (typeof(oldOwner.SourceStation) == "instance");
						local dstValid = (typeof(oldOwner.TargetStation) == "instance");
						if (srcValid && oldOwner.SourceStation.s_ID == oldAirport.s_ID)	oldOwner.SourceStation = newStation;
						if (dstValid && oldOwner.TargetStation.s_ID == oldAirport.s_ID)	oldOwner.TargetStation = newStation;
						oldOwner.RouteUpdateVehicle();
						local pause = cLooper();
						}
				cStation.DeleteStation(oldAirport.s_ID);
				cCarrier.VehicleHandleTrafficAtStation(newStation.s_ID, false); // rebuild orders
				}
			return newStation.s_ID;
			}
		else	{
			road.SourceStation = AIStation.GetStationID(heliloc);
			road.VehicleType = RouteType.CHOPPER;
			road.SourceStation = road.CreateNewStation(start);
			road.SourceStation.s_Depot = -1;
			road.SourceStation.s_Location = heliloc;
			return road.SourceStation.s_ID;
			}
		}
	if (!needTime && !needMoney)	INSTANCE.main.builder.CriticalError=true;
	return -1;
}

function cBuilder::AirportBestPlace_EvaluateHill(workTileList, width, height)
// This search all tiles from a list of tiles where we can build an airport and record all solves found with their costs to build them
// This is real time consumming as we will run multi-times the TerraformSolver to flatten land
// workTileList : a list of tiles we would like an airport built
// width : width of an airport
// height: height of an airport
{
local allsolve=[];
//foreach (tile, dummy in workTileList)	if (cTileTools.IsTilesBlackList(tile))	workTileList.RemoveItem(tile);
// remove bad tile locations
if (workTileList.IsEmpty())	return [];
local randomTile=AITileList();
randomTile.AddList(workTileList);
randomTile.Sort(AIList.SORT_BY_VALUE, false);
cDebug.showLogic(randomTile);
cDebug.ClearSigns();
randomTile.KeepTop(6);
foreach (tile, dummy in randomTile)	randomTile.SetValue(tile, tile+AIMap.GetTileIndex(width-1, height-1));
workTileList.Clear();
workTileList.AddList(randomTile);
cDebug.showLogic(workTileList);
cDebug.ClearSigns();
local templist=AITileList();
local solveIndex=0;
foreach (tileFrom, tileTo in workTileList)
	{
	templist.Clear();
	templist.AddRectangle(tileFrom, tileTo);
cDebug.showLogic(templist);
cDebug.PutSign(tileFrom,"F"); cDebug.PutSign(tileTo,"T");
	local solve=cTileTools.TerraformHeightSolver(templist);
cDebug.ClearSigns();
	solve.RemoveValue(0); // discard no solve
	local bf, bt, bs, bp=null;
	bp=99999999999999;
	foreach (solution, prize in solve)
		{
		/*allsolve.push(tileFrom);
		allsolve.push(tileTo);
		allsolve.push(solution);
		allsolve.push(prize);*/
		if (abs(prize) < abs(bp)) { bf=tileFrom; bt=tileTo; bp=prize; bs=solution; } // find cheapest one
		solveIndex++;
		}
	if (!solve.IsEmpty())
		{
		allsolve.push(bf); // this way we only keep cheapest one out of all solves found for that area
		allsolve.push(bt); // so the area will have only 1 solution
		allsolve.push(bs);
		allsolve.push(bp);
		}
	}
cDebug.ClearSigns();
DInfo("Total solves found: "+solveIndex,1);
return allsolve;
}

function cBuilder::AirportBestPlace_BuildFromSolve(allsolve, width, height, airporttype)
// This function try each solve found from AirportBestPlace_EvaluateHill to flatten area and build an airport
// Time consumming, and worst, money eater !
// solve = an array of solve, should have been made by AirportBestPlace_EvaluateHill
// width : width of an airport
// height: height of an airport
// airportype: the type of airport to build
{
local bestSolve=AIList();
local radius=AIAirport.GetAirportCoverageRadius(airporttype);
local solveIndex=0;
local cargoID=cCargo.GetPassengerCargo();
for (local i=0; i < allsolve.len(); i++)
	{
	local tileFrom, tileTo, solution, realprize =null;
	tileFrom=allsolve[i+0];
	tileTo=allsolve[i+1];
	solution=allsolve[i+2];
	realprize=allsolve[i+3];
	local cargovalue=AITile.GetCargoProduction(tileFrom, cargoID, width, height, radius);
	bestSolve.AddItem(solveIndex,(10000000000-(abs(realprize)*8))+(cargovalue));
	i+=3;
	solveIndex++;
	}
bestSolve.Sort(AIList.SORT_BY_VALUE, false);
foreach (index, prize in bestSolve)
	{
	local tileFrom, tileTo, solution, realprize, updown=null;
	tileFrom=allsolve[4*index+0];
	tileTo=allsolve[4*index+1];
	solution=allsolve[4*index+2];
	realprize=allsolve[4*index+3];
	updown=(realprize < 0);
	local templist=AITileList();
	templist.AddRectangle(tileFrom, tileTo);
	cDebug.PutSign(tileFrom,"?");
	if (!cBanker.CanBuyThat(abs(realprize)))
		{
		DInfo("Skipping that solve. We won't have enough money to succeed",1);
		cTileTools.terraformCost.AddItem(999999,abs(prize));
		INSTANCE.main.builder.CriticalError=false; // make sure we tell it's just temporary
		return -1; // no need to continue, list is range from cheaper to higher prize, if you can't buy cheaper already...
		}
	else	{
		cBanker.RaiseFundsBigTime();
		local money=cTileTools.TerraformDoAction(templist, solution, updown, false);
		if (money != -1)
			{
			DInfo("Trying to build an airport at "+tileFrom,1);
			local success=INSTANCE.main.builder.AirportMaker(tileFrom, airporttype);
			if (success)	return tileFrom;
					else	if (cTileTools.terraformCost.HasItem(999995))
							{
							cTileTools.terraformCost.RemoveItem(999995);
							return -1;
							}
			}
		DInfo("Blacklisting tile "+tileFrom,2);
		cTileTools.BlackListTile(tileFrom, -100);
		}
	}
return -1;
}

function cBuilder::AirportAcceptBigPlanes(airportID)
// return true if we can accept big aircraft
// airportID : the airport station ID
{
	if (airportID == null)	return false;
	local airport = cStation.Load(airportID);
	if (!airport)	return false;
	if (airport.s_SubType == AIAirport.AT_SMALL)	return false;
	return true;
}
