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

class cMisc
	{
	constructor()
		{
		}
	}

function cMisc::PickCompanyName(who)
{
	local nameo = ["Last", "For the", "Militia", "Revolution", "Good", "Bad", "Evil"];
	local namet = ["Hope", "People", "Corporation", "Money", "Dope", "Cry", "Shot", "War", "Battle", "Fight"];
	local x = 0; local y = 0;
	if (who == 666)  { x = AIBase.RandRange(7); y = AIBase.RandRange(10); }
		else	 { x = who; y = who; }
	return nameo[x]+" "+namet[y]+" (DictatorAI)";
}

function cMisc::SetPresident()
{
	local myName = "Krinn's Company";
	local FinalName = myName;
	FinalName = cMisc.PickCompanyName(666);
	AICompany.SetName(FinalName);
	AICompany.SetPresidentGender(AICompany.GENDER_MALE);
	DInfo("We're now "+FinalName,0);
	local randomPresident = 666;
	if (DictatorAI.GetSetting("PresidentName")) { randomPresident = AIBase.RandRange(12); }
	local lastrand = "";
	local nickrand = cMisc.getFirstName(randomPresident);
	lastrand = nickrand + " "+ cMisc.getLastName(randomPresident);
	DInfo(lastrand+" will rules the company with an iron fist",0);
	AICompany.SetPresidentName(lastrand);
}

function cMisc::getLastName(who)
{
	local names = ["Castro", "Mussolini", "Lenin", "Stalin", "Batista", "Jong", "Mugabe", "Al-Bashir", "Milosevic", "Bonaparte", "Caesar", "Tse-Tung"];
	if (who == 666) { who = AIBase.RandRange(12) };
	return names[who];
}

function cMisc::getFirstName(who)
{
	local names = ["Fidel", "Benito", "Vladamir", "Joseph", "Fulgencio", "Kim", "Robert", "Omar", "Slobodan", "Napoleon", "Julius", "Mao"];
	if (who == 666) { who = AIBase.RandRange(12) };
	return names[who];
}

function cMisc::SetBit(value, bitset)
// Set the bit in value
{
	value = value | (1 << bitset);
	return value;
}

function cMisc::ClearBit(value, bitset)
// Clear a bit in value
{
	value = value & ~(1 << bitset);
	return value;
}

function cMisc::ToggleBit(value, bitset)
// Set/unset bit in value
{
	value = value ^ (1 << bitset);
	return value;
}

function cMisc::CheckBit(value, bitset)
// return true/false if bit is set in value
{
	if (value == null || typeof(value) != "integer")  return false;
	return ((value & (1 << bitset)) != 0);
}

function cMisc::checkHQ()
// Check and build our HQ if need
{
	if (!AIMap.IsValidTile(AICompany.GetCompanyHQ(AICompany.COMPANY_SELF)))
		{
		local townlist = AITownList();
		townlist.Valuate(AIBase.RandItem);
		local tilelist = null;
		tilelist = cTileTools.GetTilesAroundTown(townlist.Begin());
		tilelist.Valuate(AIBase.RandItem);
		foreach (tile, dummy in tilelist)
			{
			if (AICompany.BuildCompanyHQ(tile))
				{
				local name = AITown.GetName(AITile.GetClosestTown(tile));
				DInfo("Built company headquarters near " + name,0);
				return;
				}
			}
		}
}

function GetCurrentGoalCallback(message, self)
{
DInfo("Received answer goal with ",2);
for (local i=0; i < message.Data.len(); i++)	DInfo(" Goal #"+i+" - "+message.Data[i],2);
local goal_to_do=AIList();
if (message.Data[3] < message.Data[2])	goal_to_do.AddItem(message.Data[1],0);
if (message.Data[6] < message.Data[5])	goal_to_do.AddItem(message.Data[4],0);
if (message.Data[9] < message.Data[8])	goal_to_do.AddItem(message.Data[7],0);
if (goal_to_do.IsEmpty())	return;
INSTANCE.SetCargoFavorite(goal_to_do.Begin());
}

function cMisc::ListToArray(list)
{
	local array = [];
	local templist = AIList();
	templist.AddList(list);
	while (templist.Count() > 0) {
		local arrayitem = [templist.Begin(), templist.GetValue(templist.Begin())];
		array.append(arrayitem);
		templist.RemoveTop(1);
	}
	return array;
}

function cMisc::ArrayToList(array)
{
	local list = AIList();
	local temparray = [];
	temparray.extend(array);
	while (temparray.len() > 0) {
		local arrayitem = temparray.pop();
		list.AddItem(arrayitem[0], arrayitem[1]);
	}
	return list;
}

function cMisc::InArray(the_array, seek_value)
// return the position of seek_value in the_array, -1 if not found
{
	for (local i = 0; i < the_array.len(); i++)	if (the_array[i] == seek_value)	return i;
	return -1;
}

function cMisc::ValidInstance(obj)
// return true if obj is an instance of something
{
	return (typeof(obj) == "instance");
}

function cMisc::SplitStars(st)
// This split the string st into an array of string, the split is at each * in the st
// This is to cut off a group name infos and grab them easy
{
	local retValue=[];
	local buff="";
	for (local i = 0; i < st.len(); i++)
		{
		local c = st.slice(i, i+1);
		if (c == "*")	{ retValue.push(buff); buff=""; }
				else	buff+=c;
		}
	if (buff != "")	retValue.push(buff); // add last one found because eol
	return retValue;
}

function cMisc::IsAIList(f)
// return true if it's an AIList
{
	if (typeof(f) != "instance")	{ return false; }
	if (f instanceof AIList)	{ return true; }
	return false;
}

function cMisc::toHexString(value)
{
	local hexchar = [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70];
	local c = value % 0x10;
	local result;
	if (value - c == 0)	result = hexchar[c].tochar();
				else	result = cMisc.toHexString((value - c) >> 4) + hexchar[c].tochar();
	return result;
}

function cMisc::toHex(value)
{
	local k = cMisc.toHexString(value);
	return "0x"+k;
}

function cMisc::Locate(tile, nosign = false)
{
	if (!AIMap.IsValidTile(tile))	{ return "invalid tile "+tile; }
	local md = AIExecMode();
	if (!nosign)	cDebug.PutSign(tile, "X");
	local z = "0x"+cMisc.toHexString(tile);
	return "tile="+tile+" "+z+" near "+AITown.GetName(AITile.GetClosestTown(tile));
}

function cMisc::MostItemInList(list, item)
// add item to list if not exist and set counter to 1, else increase counter
// return the list
{
	if (!list.HasItem(item))	{ list.AddItem(item,1); }
					else	{ local c=list.GetValue(item); c++; list.SetValue(item,c); }
	return list;
}

function cMisc::GetItemInAIList(ailist, number)
// Get the item number from an ailist
{
	if (!cMisc.IsAIList(ailist))	return null;
	local i = 0;
	foreach (item, value in ailist)
		{
		if (i == number)	return item;
		i++;
		}
	return null; // out of range
}

function cMisc::GetRandomItemFromAIList(ailist)
{
	if (!cMisc.IsAIList(ailist) || ailist.IsEmpty())	return null;
	local rnd = AIBase.RandRange(ailist.Count());
	return cMisc.GetItemInAIList(ailist, rnd);
}
