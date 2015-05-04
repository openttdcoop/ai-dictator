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

function cBanker::SetMinimumCashToBuild()
{
	local minc = (AICompany.GetLoanInterval() * 4 * cBanker.GetInflationRate()).tointeger();
	INSTANCE.main.bank.mincash = minc;
}

function cBanker::RaiseFundsTo(money)
// Raise money to that level if possible, if we have already the amount do nothing, else raise to max we could reach
{
    money = money.tointeger();
	local curr = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	if (curr >= 2147483647 || curr >= money)	return true;
	local toloan = AICompany.GetLoanAmount() + money;
	local success = AICompany.SetMinimumLoanAmount(toloan);
	if (!success)
				{ // can't get what we need, raising to what we could do so
				DInfo("Cannot raise money to "+money+". Raising money to max we can",2);
				toloan = AICompany.GetMaxLoanAmount();
				success = AICompany.SetMinimumLoanAmount(toloan);
				}
	return success;
}

function cBanker::RaiseFundsBigTime()
// Raise our cash with big money, called when i'm going to spent a lot
{
	local loan_max = AICompany.GetMaxLoanAmount();
	// if we have more than what we can loan, just don't loan to not waste our cash in loan penalties
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > loan_max)	return true;
	local m = loan_max - AICompany.GetLoanAmount();
	return cBanker.GetMoney(m);
}

function cBanker::CanBuyThat(money)
// return true if we can spend money
{
	local loan = AICompany.GetMaxLoanAmount()-AICompany.GetLoanAmount();
	local cash = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	if (cash >= money)	return true;
	if (cash + loan < cash)	return true; // overflow
	if (cash + loan >= money)	return true;
	return false;
}

function cBanker::GetMoney(money)
// Try get money amount
{
	local curr = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	if (curr >= money || curr >= 2147483647)	return true;
	local needed = money + curr;
	if (needed < curr)	return true;
	return (cBanker.RaiseFundsTo(needed));
}

function cBanker::PayLoan()
{
	local loan = AICompany.GetLoanAmount();
	if (loan == 0)	return;
	local money = 0 - (AICompany.GetBankBalance(AICompany.COMPANY_SELF) - loan) + AICompany.GetLoanInterval();
	loan = min(AICompany.GetMaxLoanAmount(), max(0, money));
	DInfo("Changing loan to "+loan,2);
	return AICompany.SetMinimumLoanAmount(money);
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
