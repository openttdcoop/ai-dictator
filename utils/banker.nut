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

class cBanker
	{
	root = null;
	canBuild= null;		// true if we can build new route
	unleash_road = null;	// true to build big road, false for small size
	mincash=null;
	busyRoute=null;		// true if we are still busy handling a route, we need false to build new route
	basePrice=null;		// it's just a base price cost to remove a rock tile
	
	constructor(that)
		{
		root=that;
		unleash_road=false;
		canBuild=true;
		mincash=10000;
		busyRoute=false;
		basePrice=0;
		}
	}

function cBanker::Update()
{
local ourLoan=AICompany.GetLoanAmount();
local maxLoan=AICompany.GetMaxLoanAmount();
local cash=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
local goodcash=root.bank.mincash*cBanker.GetInflationRate();
if (goodcash < root.bank.mincash) goodcash=root.bank.mincash;
if (ourLoan==0 && cash>=root.bank.mincash)	{ root.bank.unleash_road=true; }
	else	{ root.bank.unleash_road=false; }
if (cash < goodcash)	{ root.bank.canBuild=false; }
if (maxLoan > 2000000 && ourLoan > 0)	{ DInfo("Trying to repay loan",2); root.bank.canBuild=false; } // wait to repay loan
if (ourLoan < maxLoan+(4*AICompany.GetLoanInterval()))	{ root.bank.canBuild=true; }
local veh=AIVehicleList();
if (root.bank.busyRoute)	root.bank.canBuild=false;
if (root.builddelay)	root.bank.canBuild=false;
if (root.chemin.map_group_to_route.Count() == 0)	root.bank.canBuild=true; // we have 0 route force a build
if (root.bank.canBuild) DInfo("Construction is now allowed",1);
DInfo("canBuild="+root.bank.canBuild+" busyRoute="+root.bank.busyRoute+" goodcash="+goodcash+" unleash="+root.bank.unleash_road+" nowroute="+root.chemin.nowRoute,2);
}

function cBanker::GetConstructionsCosts(idx)
// return estimate costs to try build that route
{
local road=root.chemin.RListGetItem(idx);
local money=0;
local clean=AITile.GetBuildCost(AITile.BT_CLEAR_HOUSE);
local engine=root.carrier.GetVehicle(idx);
local engineprice=0;
if (engine != -1)	engineprice=AIEngine.GetPrice(engine);
switch (road.ROUTE.kind)
	{
	case	AIVehicle.VT_ROAD:
		// 2 vehicle + 2 stations + 2 depot + 4 destuction + 4 road for entry and length*road
		money+=engineprice*2;
		money+=2*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_TRUCK_STOP));
		money+=2*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_DEPOT));
		money+=4*clean;
		money+=(4+road.ROUTE.length)*(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD));
	break;
	case	AIVehicle.VT_RAIL:
		local rtype=AIRail.GetCurrentRailType();
		// 1 vehicle + 2 stations + 2 depot + 4 destuction + 3 tracks entries and length*rail
		money+=engineprice*2;
		money+=(2+5)*(AIRail.GetBuildCost(rtype, AIRoad.BT_STATION)); // station train 5 length
		money+=2*(AIRail.GetBuildCost(rtype, AIRoad.BT_DEPOT));
		money+=4*clean;
		money+=(3+road.ROUTE.length)*(AIRail.GetBuildCost(rtype, AIRoad.BT_TRACK));
	break;
	case	AIVehicle.VT_WATER:
		// 2 vehicle + 2 stations + 2 depot
		money+=engineprice*2;
		money+=2*(AIMarine.GetBuildCost(AIMarine.BT_DOCK));
		money+=2*(AIMarine.GetBuildCost(AIMarine.BT_DEPOT));
	break;
	case	AIVehicle.VT_AIR:
		// 2 vehicle + 2 airports
		money+=engineprice*2;
		money+=2*(AIAirport.GetPrice(root.builder.GetAirportType()));
	break;
	}
DInfo("Estimated costs to build route "+idx+" : "+money,2);
return money;
}

function cBanker::GetLoanValue(money)
{
local i=0;
local loanStep=AICompany.GetLoanInterval();
while (money > 0) { i++; money-=loanStep; }
return (i*loanStep);	
}

function cBanker::RaiseFundsTo(money)
{
local toloan = AICompany.GetLoanAmount() + money;
local curr=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
local success=true;
if (curr > money) success=true;
	else	success=AICompany.SetMinimumLoanAmount(toloan);
return success;
}

function cBanker::RaiseFundsBigTime()
// Raise our cash with big money, called when i'm going to spent a lot
{
local tomax=5000000;
local max=tomax;
if (AICompany.GetMaxLoanAmount() < tomax)	max=(AICompany.GetMaxLoanAmount()*80/100);
root.bank.RaiseFundsTo(AICompany.GetBankBalance(AICompany.COMPANY_SELF)+max);
}

function cBanker::CanBuyThat(money)
// return true if we can spend money
{
local loan=AICompany.GetMaxLoanAmount()-AICompany.GetLoanAmount();
local cash=AICompany.GetBankBalance(AICompany.COMPANY_SELF)+loan;
if (cash >= money)	return true;
	else	return false;
}

function cBanker::SaveMoney()
// lower loan max to save money
{
local canrepay=cBanker.GetLoanValue(AICompany.GetBankBalance(AICompany.COMPANY_SELF));
local newLoan=AICompany.GetLoanAmount()-canrepay;
if (newLoan <=0) newLoan=0;
AICompany.SetMinimumLoanAmount(newLoan);
}

function cBanker::RaiseFundsBy(money)
{
	local curr = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	if (curr < 0) curr=0;
	local needed = money + curr;
	if (cBanker.RaiseFundsTo(money)) return true; else return false;
}

function cBanker::PayLoan()
{
	local money = 0 - (AICompany.GetBankBalance(AICompany.COMPANY_SELF) - AICompany.GetLoanAmount()) + AICompany.GetLoanInterval();
	if (money > 0) {
		if (AICompany.SetMinimumLoanAmount(money)) return true; else return false;
	} else {
		if (AICompany.SetMinimumLoanAmount(0)) return true; else return false;
	}
}

function cBanker::CashFlow()
{
root.bank.PayLoan();
local goodcash=root.bank.mincash;
if (goodcash < root.bank.mincash) goodcash=root.bank.mincash;
root.bank.RaiseFundsTo(goodcash);
root.bank.Update();
}

function cBanker::GetInflationRate()
{
	return (AICompany.GetMaxLoanAmount() / AIGameSettings.GetValue("difficulty.max_loan") );
}
