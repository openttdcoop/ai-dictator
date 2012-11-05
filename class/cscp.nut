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

import("Library.SCPLib", "SCPLib", 45);
require("version.nut");

class cSCP extends cClass
	{
	SCPInstance= null;
	SCPTile = null;
	goal_callback = null;
	
	constructor()
		{
		this.ClassName="cSCP";
		}
	}

function cSCP::Init()
{
	this.SCPInstance=SCPLib(SELF_SHORTNAME, SELF_VERSION, null);
	this.SCPInstance.SCPLogging_Error(true);
	this.SCPInstance.SCPLogging_Info(false);
	this.SCPTile = SCPInstance.SCPGetCommunicationTile();
	this.AddCommandSet();
}

function cSCP::WaitReady()
{
	DInfo("Waiting SCP to get ready.",2);
	for (local j=0; j < 10; j++)
		{
		if (!this.SCPInstance.CanSpeakWith())	{ AIController.Sleep(1); this.SCPInstance.Check(); }
								else	return;
		}
	//this.GetCurrentGoal();
}

function cSCP::IsAllow()
{
	return (AIController.GetSetting("allow_scp") == 1);
}

function cSCP::Check()
{
	return SCPInstance.Check();
}

function cSCP::AddCommandSet()
{
	SCPInstance.AddCommand("CurrentGoal", "NoCarGoal", this, cSCP.GetCurrentGoalCallback);
	//SCPInstance.AddCommand("GSSetting", "NoCarGoal", this, cSCP.ReceivedGSSettingCommand);
	SCPInstance.AddCommand("GoalCompleted", "NoCarGoal", this, cSCP.GoalComplete);

}

function cSCP::GoalComplete(message, self)
{
	DInfo("Goal complete for "+AICargo.GetCargoLabel(message.Data[0])+" "+message.Data[0],0,"cSCP::GoalComplete");
	this.GetCurrentGoal();
}

function cSCP::GetCurrentGoal()
{
print("get current goal");
	SCPInstance.QueryServer("CurrentGoal", "NoCarGoal", AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
}

function cSCP::GetCurrentGoalCallback(message, self)
{
	if (goal_callback != null)	goal_callback(message,self);
	DWarn("GetCurrentGoalCallback is not set");
}

function cSCP::SetCurrentGoalCallback(ngoal)
{
	this.goal_callback = ngoal;
}

/*
function cSCP::GetCurrentGoalCallback(message, self)
{
print("Received answer goal with ");
for (local i=0; i < message.Data.len(); i++)	print(" Goal #"+i+" - "+message.Data[i]);
local goal_to_do=AIList();
if (message.Data[3] < message.Data[2])	goal_to_do.AddItem(message.Data[1],0);
if (message.Data[6] < message.Data[5])	goal_to_do.AddItem(message.Data[4],0);
if (message.Data[9] < message.Data[8])	goal_to_do.AddItem(message.Data[7],0);
if (goal_to_do.IsEmpty())	return;
INSTANCE.SetCargoFavorite(goal_to_do.Begin());
}
*/