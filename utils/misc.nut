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
local names = ["fidel", "Benito", "Vladamir", "Joseph", "Fulgencio", "Kim", "Robert", "Omar", "Slobodan",
	"Napoléon", "Julius", "Mao"];
if (who == 666) { who = AIBase.RandRange(12) };
return names[who];
}

function PickCompanyName(who)
{
local nameo = ["Last", "For the", "Militia", "Revolution", "Good", "Bad", "Evil"];
local namet = ["Hope", "People", "Corporation", "Money", "Dope", "Cry", "Shot"];
local x = 0; local y = 0;
//x = AIBase.RandRange(3);
if (who == 666)  { x = AIBase.RandRange(7); y = AIBase.RandRange(7); }
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
	AILog.Info(putMsg+" Error:"+AIError.GetLastErrorString());
	}
}

function DWarn(putMsg)
// Warning messages are always display
{
AILog.Warning("WARNING:"+putMsg);
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
	townlist.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local townid = townlist.Begin();
	local townloc = AITown.GetLocation(townid);
	local place_id = AITile.GetClosestTown(townloc);
	DictatorAI.BuildHQ(place_id);
	}
}

function AIGetCargoFavorite()
{
local crglist=AICargoList();
chemin.cargo_fav=AIBase.RandRange(crglist.Count());
DInfo("We will promote "+AICargo.GetCargoLabel(chemin.cargo_fav),0);
}


function AIInit()
{
local myName = "Krinn Company";
local FinalName = myName;
FinalName = PickCompanyName(666);
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
}


