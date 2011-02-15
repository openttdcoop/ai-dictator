class cBanker
	{
	root = null;
	canBuild= null;		// true if we can build new route
	unleash_road = null;	// true to build big road, false for small size
	mincash=null;
	busyRoute=null;		// true if we are still busy handling a route, we need false to build new route
	
	constructor(that)
		{
		root=that;
		unleash_road=false;
		canBuild=true;
		mincash=70000;
		busyRoute=false;
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
if (ourLoan < maxLoan)	{ root.bank.canBuild=true; }
local veh=AIVehicleList();
if (root.bank.busyRoute)	root.bank.canBuild=false;
if (root.builddelay)	root.bank.canBuild=false;
//if (!root.bank.canBuild && veh.IsEmpty()) // we have no vehicles
//	{ root.bank.canBuild=true; }
if (root.bank.canBuild) DInfo("Construction is now allowed",1);
DInfo("canBuild="+root.bank.canBuild+" busyRoute="+root.bank.busyRoute+" goodcash="+goodcash+" unleash="+root.bank.unleash_road,2);
}

function cBanker::GetLoanValue(money)
{
local i=0;
local loanStep=AICompany.GetLoanInterval();
while (money > 0) { i++; money-=loanStep; }
return (i*loanStep);	
}

/*function cBanker::DoLoan(money)
{
local stillneed=money-AICompany.GetBankBalance(AICompany.COMPANY_SELF);
if (stillneed < 0) return true;
local maxget=AICompany.GetMaxLoanAmount();
stillneed=root.bank.GetLoanValue(stillneed);
if (stillneed > maxget) stillneed=maxget;
local essai=AICompany.SetLoanAmount(stillneed);
if (essai)	return true;
	else	DError("Loan failure : "+stillneed+" - ",2);
}*/

/*function cBanker::RaiseFunds(money)
{
DInfo("Bank was ask to raise money upto "+money,2);
local cash=AICompany.GetBankBalance(AICompany.COMPANY_SELF)
if (cash > money) return true;
if ((cash+AICompany.GetMaxLoanAmount()) < money) money=cash+AICompany.GetMaxLoanAmount();
return root.bank.DoLoan(money);
}*/
/*
function cBanker::RaiseFundsTo(money)
// raise our cash to money value -> cash=money
{
return root.bank.RaiseFunds(money);
}

function cBanker::RaiseFundsBy(money)
// raise our cash by money value -> cash=cash+money
{
DInfo("BANK: ask "+money+" more",2);
local toraise=money-AICompany.GetBankBalance(AICompany.COMPANY_SELF);
if (toraise > 0) return true;
return root.bank.RaiseFunds(toraise); 
}
*/

function cBanker::RaiseFundsTo(money)
{
local toloan = AICompany.GetLoanAmount() + money;
local curr=AICompany.GetBankBalance(AICompany.COMPANY_SELF);
local success=true;
if (curr > money) success=true;
	else	success=AICompany.SetMinimumLoanAmount(toloan);
//DInfo("Funds query: Cash was="+curr+" need="+money+" after="+AICompany.GetBankBalance(AICompany.COMPANY_SELF)+" success="+success,2);
return success;
}

function cBanker::RaiseFundsBigTime()
// Raise our cash with big money, called when i'm going to spent a lot
{
local tomax=5000000;
local max=tomax;
if (AICompany.GetMaxLoanAmount() < tomax)	max=AICompany.GetMaxLoanAmount();
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
/*
function cBanker::LowerLoan()
{
//if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > AICompany.GetLoanAmount())
local newLoan=AICompany.GetLoanAmount();
do	{
	newLoan-=root.bank.GetLoanValue(AICompany.GetBankBalance(AICompany.COMPANY_SELF));
	newLoan-=AICompany.GetLoanInterval();
	if (newLoan < 0) newLoan=0;
	} while (newLoan!=0 && AICompany.SetLoanAmount(newLoan));
DInfo("Lowering loan, now "+AICompany.GetLoanAmount(),1);
}*/

function cBanker::SaveMoney()
// lower loan max to save money
{
local canrepay=cBanker.GetLoanValue(AICompany.GetBankBalance(AICompany.COMPANY_SELF));
//local newLoan=( AICompany.GetBankBalance(AICompany.COMPANY_SELF) / AICompany.GetLoanInterval() ) * AICompany.GetLoanInterval();
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
//root.bank.LowerLoan();
root.bank.PayLoan();
//local goodcash=root.bank.mincash*cBanker.GetInflationRate();
local goodcash=root.bank.mincash;
if (goodcash < root.bank.mincash) goodcash=root.bank.mincash;
//DInfo("goodcach?"+goodcash+" inflation: "+cBanker.GetInflationRate(),2);
//DInfo("FFS bank! get some credits!!! goodcash="+goodcash,2);
root.bank.RaiseFundsTo(goodcash);
root.bank.Update();
}

function cBanker::GetInflationRate()
{
	return (AICompany.GetMaxLoanAmount() / AIGameSettings.GetValue("difficulty.max_loan") );
}
