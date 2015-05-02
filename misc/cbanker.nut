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

class cBanker extends cClass
	{
	canBuild        = null;		// true if we can build new route
	unleash_road    = null;	// true to build big road, false for small size
	mincash         = null;
	basePrice       = null;		// it's just a base price cost to remove a rock tile

	constructor()
		{
		unleash_road    = false;
		canBuild        = true;
		mincash         = 10000;
		basePrice       = 0;
		this.ClassName  = "cBanker";
		}
	}


function cBanker::GetLoanValue(money)
// return amount to loan to have enough money
{
	local i=0;
	local loanStep=AICompany.GetLoanInterval();
	while (money > 0) { i++; money-=loanStep; }
	i--;
	return (i*loanStep);
}

function cBanker::RaiseFundsTo(money)
// Raise money to that level if possible, if we have already the amount do nothing, else raise to max we could reach
{
	local toloan = (AICompany.GetLoanAmount() + money).tointeger();
	money = money.tointeger();
	local curr=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	local success=true;
	if (curr > money)	success=true;
				else	success=AICompany.SetMinimumLoanAmount(toloan);
	if (!success)	{ // can't get what we need, raising to what we could do so
				DInfo("Cannot raise money to "+money+". Raising money to max we can",2);
				toloan = AICompany.GetMaxLoanAmount();
				success = AICompany.SetMinimumLoanAmount(toloan);
				}
	return success;
}

function cBanker::RaiseFundsBigTime()
// Raise our cash with big money, called when i'm going to spent a lot
{
	local max=(AICompany.GetMaxLoanAmount()).tointeger()-AICompany.GetLoanAmount();
	// if we have more than what we can loan, just don't loan to not waste our cash in loan penalty, it should be enough
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > AICompany.GetMaxLoanAmount())	return true;
	return cBanker.RaiseFundsBy(max);
}

function cBanker::CanBuyThat(money)
// return true if we can spend money
{
	local loan=AICompany.GetMaxLoanAmount()-AICompany.GetLoanAmount();
	local cash=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	if (cash >= money)	return true;
	if (cash + loan < cash)	return true; // overflow
	if (cash + loan >= money)	return true;
	return false;
}

function cBanker::GetMaxMoneyAmount()
// return the max amount of cash we could raise
{
	local loan=AICompany.GetMaxLoanAmount()-AICompany.GetLoanAmount();
	local cash=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	if (cash+loan < cash)	return cash; //overflow
	return cash+loan;
}

function cBanker::SaveMoney()
// lower loan max to save money
{
	local weare=AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
	local balance=AICompany.GetBankBalance(weare);
	DInfo("Saving our money",1);
	local canrepay=cBanker.GetLoanValue(balance);
	local newLoan=AICompany.GetLoanAmount()-canrepay;
	if (newLoan <=0) newLoan=0;
	AICompany.SetMinimumLoanAmount(newLoan);
}

function cBanker::RaiseFundsBy(money)
// Raise account by money amount.
{
	local curr = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	if (curr < 0) curr=0;
	local needed = money + curr;
	return (cBanker.RaiseFundsTo(needed));
}

function cBanker::PayLoan()
{
	local money = 0 - (AICompany.GetBankBalance(AICompany.COMPANY_SELF) - AICompany.GetLoanAmount()) + AICompany.GetLoanInterval();
	if (money > 0)	{	if (AICompany.SetMinimumLoanAmount(money)) return true; else return false; }
			else	{	if (AICompany.SetMinimumLoanAmount(0)) return true; else return false;	}
}

function cBanker::CashFlow()
{
	cBanker.PayLoan();
    cBanker.SetMinimumCashToBuild();
}

function cBanker::GetInflationRate()
{
	return (AICompany.GetMaxLoanAmount() / AIGameSettings.GetValue("difficulty.max_loan").tofloat());
}

function cBanker::SetMinimumCashToBuild()
{
	local minc = (AICompany.GetLoanInterval() * 4 * cBanker.GetInflationRate()).tointeger();
	INSTANCE.main.bank.mincash = minc;
}