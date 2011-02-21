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

function sliceString(a)
{
local t=20;
if ((a == null) || (a.len() <= 0)) return "NULL!";
if (a.len() >t) { t=a.slice(0,t-1); }
return a;
}

function getLastName(who)
{
DInfo("picking last name: "+who,1);
local names = ["Castro", "Mussolini", "Lenin", "Stalin", "Batista", "Jong", "Mugabe", "Al-Bashir", "Milosevic",
	"Bonaparte", "Caesar", "Tse-Tung"];
if (who == 666) { who = AIBase.RandRange(12) };
return names[who];
}

function getFirstName(who)
{
DInfo("picking first name: "+who,1);
local names = ["Fidel", "Benito", "Vladamir", "Joseph", "Fulgencio", "Kim", "Robert", "Omar", "Slobodan",
	"Napoleon", "Julius", "Mao"];
if (who == 666) { who = AIBase.RandRange(12) };
return names[who];
}

function PickCompanyName(who)
{
local nameo = ["Last", "For the", "Militia", "Revolution", "Good", "Bad", "Evil"];
local namet = ["Hope", "People", "Corporation", "Money", "Dope", "Cry", "Shot", "War", "Battle", "Fight"];
local x = 0; local y = 0;
if (who == 666)  { x = AIBase.RandRange(7); y = AIBase.RandRange(10); }
	else	 { x = who; y = who; }
return nameo[x]+" "+namet[y]+" (DictatorAI)"; 

}

function DInfo(putMsg,debugValue=0)
// just output AILog message depending on debug level
{
local debugState = DictatorAI.GetSetting("debug");
if (debugValue <= debugState )
	{
	AILog.Info(putMsg);
	}
}

function DError(putMsg,debugValue=1)
// just output AILog message depending on debug level
{
local debugState = DictatorAI.GetSetting("debug");
if (debugValue <= debugState )
	{
	AILog.Error(putMsg+" Error:"+AIError.GetLastErrorString());
	}
}

function DWarn(putMsg, debugValue=1)
// just output AILog message depending on debug level
{
local debugState = DictatorAI.GetSetting("debug");
if (debugValue <= debugState )
	{
	AILog.Warning(putMsg);
	}
}

function ShowTick()
{
DInfo("Live tick : "+this.GetTick(),2);
}

function checkHQ()
{
if (!AIMap.IsValidTile(AICompany.GetCompanyHQ(AICompany.COMPANY_SELF)))
	{
	local townlist = AITownList();
	townlist.Valuate(AITown.GetPopulation);
	townlist.Sort(AIList.SORT_BY_VALUE, false);
	local townid = townlist.Begin();
	local townloc = AITown.GetLocation(townid);
	local place_id = AITile.GetClosestTown(townloc);
	DictatorAI.BuildHQ(place_id);
	}
}

function ListGetItem(list, item_num)
{
local new=AIList();
new.AddList(list);
new.RemoveTop(item_num);
return new.Begin();
}

function AIGetCargoFavorite()
{
local crglist=AICargoList();
chemin.cargo_fav=AIBase.RandRange(crglist.Count());
chemin.cargo_fav=ListGetItem(crglist, chemin.cargo_fav);
DInfo("max cargo: "+crglist.Count()+" pick="+chemin.cargo_fav,1);
DInfo("We will promote "+AICargo.GetCargoLabel(chemin.cargo_fav),0);
}


function AIInit()
{
local myName = "Krinn Company";
local FinalName = myName;
FinalName = PickCompanyName(666);
AIController.Sleep(15);
AICompany.SetName(FinalName);
AICompany.SetPresidentGender(AICompany.GENDER_MALE);
DInfo("We're now "+FinalName);
local randomPresident = 666;
if (DictatorAI.GetSetting("PresidentName")) { randomPresident = AIBase.RandRange(12); }
local lastrand = "";
local nickrand = getFirstName(randomPresident);
lastrand = nickrand + " "+ getLastName(randomPresident);
DInfo(lastrand+" will rules the company with an iron fist");
AICompany.SetPresidentName(lastrand);
AIGetCargoFavorite();
checkHQ();
AIController.Sleep(20);
}


