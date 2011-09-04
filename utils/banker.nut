/* -*- Mode: C++; tab-width: 6 -*- */ 
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
	canBuild= null;		// true if we can build new route
	unleash_road = null;	// true to build big road, false for small size
	mincash=null;
	busyRoute=null;		// true if we are still busy handling a route, we need false to build new route
	basePrice=null;		// it's just a base price cost to remove a rock tile
	
	constructor()
		{
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
local goodcash=INSTANCE.bank.mincash*cBanker.GetInflationRate();
if (goodcash < INSTANCE.bank.mincash) goodcash=INSTANCE.bank.mincash;
if (ourLoan==0 && cash>=INSTANCE.bank.mincash)
		{ INSTANCE.bank.unleash_road=true; }
	else	{ INSTANCE.bank.unleash_road=false; }
if (cash < goodcash)	{ INSTANCE.bank.canBuild=false; }
if (maxLoan > 2000000 && ourLoan > 0 && cRoute.RouteIndexer.Count() > 6)	{ DInfo("Trying to repay loan",2); INSTANCE.bank.canBuild=false; } // wait to repay loan
if (ourLoan +(2*AICompany.GetLoanInterval()) < maxLoan)	{ INSTANCE.bank.canBuild=true; }
local veh=AIVehicleList();
if (INSTANCE.bank.busyRoute)	INSTANCE.bank.canBuild=false;
//if (INSTANCE.builddelay)	INSTANCE.bank.canBuild=false;
if (INSTANCE.carrier.vehnextprice >0)	INSTANCE.bank.canBuild=false;
local veh=AIVehicleList();
if (veh.IsEmpty())	INSTANCE.bank.canBuild=true; // we have 0 vehicles force a build
if (INSTANCE.bank.canBuild) DWarn("Construction is now allowed",1);
DInfo("canBuild="+INSTANCE.bank.canBuild+" unleash="+INSTANCE.bank.unleash_road+" building_route="+INSTANCE.builder.building_route+" warTreasure="+INSTANCE.carrier.warTreasure,1,"cBanker::Update");
}

function cBanker::GetLoanValue(money)
{
local i=0;
local loanStep=AICompany.GetLoanInterval();
while (money > 0) { i++; money-=loanStep; }
i--;
return (i*loanStep);	
}

function cBanker::RaiseFundsTo(money)
{
local toloan = AICompany.GetLoanAmount() + money;
local curr=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
local success=true;
if (curr > money) success=true;
		else	success=AICompany.SetMinimumLoanAmount(toloan);
if (!success)	{ // can't get what we need, raising to what we could do so
			DInfo("Cannot raise money to "+money+". Raising money to max we can",2,"cBanker::RaiseFundsTo");
			toloan=AICompany.GetMaxLoanAmount();
			success=AICompany.SetMinimumLoanAmount(toloan);
			}
return success;
}

function cBanker::RaiseFundsBigTime()
// Raise our cash with big money, called when i'm going to spent a lot
{
local max=(AICompany.GetMaxLoanAmount()*80/100)-AICompany.GetLoanAmount();
INSTANCE.bank.RaiseFundsTo(AICompany.GetBankBalance(AICompany.COMPANY_SELF)+max);
}

function cBanker::CanBuyThat(money)
// return true if we can spend money
{
local loan=AICompany.GetMaxLoanAmount()-AICompany.GetLoanAmount();
local cash=AICompany.GetBankBalance(AICompany.COMPANY_SELF)+loan;
if (cash >= money)	return true;
			else	return false;
}

function cBanker::GetMaxMoneyAmount()
// return the max amount of cash we could raise
{
local loan=AICompany.GetMaxLoanAmount()-AICompany.GetLoanAmount();
local cash=AICompany.GetBankBalance(AICompany.COMPANY_SELF)+loan;
return cash;
}

function cBanker::SaveMoney()
// lower loan max to save money
{
local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
local balance=AICompany.GetBankBalance(weare);
DInfo("Saving our money",0,"cBanker::SaveMoney");
local canrepay=cBanker.GetLoanValue(balance);
local newLoan=AICompany.GetLoanAmount()-canrepay;
if (newLoan <=0) newLoan=0;
AICompany.SetMinimumLoanAmount(newLoan);
}

function cBanker::RaiseFundsBy(money)
{
	local curr = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	if (curr < 0) curr=0;
	local needed = money + curr;
	return (cBanker.RaiseFundsTo(money));
}

function cBanker::PayLoan()
{
	local money = 0 - (AICompany.GetBankBalance(AICompany.COMPANY_SELF) - AICompany.GetLoanAmount()) + AICompany.GetLoanInterval();
	if (money > 0)
		{
		if (AICompany.SetMinimumLoanAmount(money)) return true; else return false;
		}
	else	{
		if (AICompany.SetMinimumLoanAmount(0)) return true; else return false;
		}
}

function cBanker::CashFlow()
{
INSTANCE.bank.PayLoan();
local goodcash=INSTANCE.bank.mincash;
if (goodcash < INSTANCE.bank.mincash) goodcash=INSTANCE.bank.mincash;
INSTANCE.bank.RaiseFundsTo(goodcash);
INSTANCE.bank.Update();
}

function cBanker::GetInflationRate()
{
	return (AICompany.GetMaxLoanAmount() / AIGameSettings.GetValue("difficulty.max_loan") );
}
