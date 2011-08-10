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

function sliceString(a)
{
local t=20;
if ((a == null) || (a.len() <= 0)) return "NULL!";
if (a.len() >t) { t=a.slice(0,t-1); }
return a;
}

function getLastName(who)
{
local names = ["Castro", "Mussolini", "Lenin", "Stalin", "Batista", "Jong", "Mugabe", "Al-Bashir", "Milosevic",
	"Bonaparte", "Caesar", "Tse-Tung"];
if (who == 666) { who = AIBase.RandRange(12) };
return names[who];
}

function getFirstName(who)
{
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

function DInfo(putMsg,debugValue=0,func="unkown")
// just output AILog message depending on debug level
{
local debugState = DictatorAI.GetSetting("debug");
if (debugState > 0)	func+="-> ";
			else	func="";
if (debugValue <= debugState )
	{
	AILog.Info(func+putMsg);
	}
}

function DError(putMsg,debugValue=1,func="unkown")
// just output AILog message depending on debug level
{
local debugState = DictatorAI.GetSetting("debug");
if (debugState > 0)	func+="-> ";
			else	func="";
if (debugValue <= debugState )
	{
	AILog.Error(func+putMsg+" Error:"+AIError.GetLastErrorString());
	}
}

function DWarn(putMsg, debugValue=1,func="unkown")
// just output AILog message depending on debug level
{
local debugState = DictatorAI.GetSetting("debug");
if (debugState > 0)	func+="-> ";
			else	func="";
if (debugValue <= debugState )
	{
	AILog.Warning(func+putMsg);
	}
}

function ShowTick()
{
DInfo("ShowTick-> "+this.GetTick(),2);
}

function checkHQ()
{
if (!AIMap.IsValidTile(AICompany.GetCompanyHQ(AICompany.COMPANY_SELF)))
	{
	local townlist = AITownList();
	townlist.Valuate(AIBase.RandItem);
	DictatorAI.BuildHQ(townlist.Begin());
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
cargo_favorite=AIBase.RandRange(crglist.Count());
cargo_favorite=ListGetItem(crglist, cargo_favorite);
DInfo("We will promote "+AICargo.GetCargoLabel(cargo_favorite),0,"AIGetCargoFavorite");
}

function AIInit()
{
local myName = "Krinn Company";
local FinalName = myName;
FinalName = PickCompanyName(666);
AIController.Sleep(15);
AICompany.SetName(FinalName);
AICompany.SetPresidentGender(AICompany.GENDER_MALE);
DInfo("We're now "+FinalName,0,"AIInit");
local randomPresident = 666;
if (DictatorAI.GetSetting("PresidentName")) { randomPresident = AIBase.RandRange(12); }
local lastrand = "";
local nickrand = getFirstName(randomPresident);
lastrand = nickrand + " "+ getLastName(randomPresident);
DInfo(lastrand+" will rules the company with an iron fist",0,"AIInit");
AICompany.SetPresidentName(lastrand);
AIGetCargoFavorite();
}


