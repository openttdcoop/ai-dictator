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

class cPathfinder extends cClass
// Use it with cPathfinder.GetStatus(src, dst); to create and manage tasks
	{
static	database = {};
static	function GetPathfinderObject(UID)
		{
		if (UID in cPathfinder.database)	return cPathfinder.database[UID];
							else	return null;
		}

	UID			= null;	// UID of the pathfinding task
	signHandler		= null;	// the sign ID that handle this task
	pathHandler		= null;	// the pathfinder instance
	solve			= null;	// the solve array
	timer			= null;	// the time we spend on that task
	source		= null;	// the source [] to pathfind
	target		= null;	// the target [] to pathfind
	status		= null;	// 0 - working, -1 fail, 1 success pathfind, 2 success route build, 3 wait for child to finish
	stationID		= null;	// the stationID rails will be assign to
	useEntry		= null;	// the entry of the stationID will be use or not
	// if we success at pathfinding, we will try build the route, and if we fail at building the route, we will recall the pathfinder or try to rebuild it
	// we will then report failure in status
	r_source		= null;	// the original pathfind source point
	r_target		= null;	// the original pathfind target point

	constructor()
		{ // * are saved variables
		UID			= null;
		signHandler		= 0;
		pathHandler		= null;
		solve			= null;
		timer			= 0;
		source		= [];
		target		= [];
		stationID		= null;
		useEntry		= null;
		status		= 0;
		r_source		= null;
		r_target		= null;
		this.ClassName	= "cPathfinder";
		}
	}

// public

function cPathfinder::GetUID(src, tgt)
// return UID of the task
	{
	src = cPathfinder.GetSourceX(src);
	tgt = cPathfinder.GetTargetX(tgt);
	local ss = typeof(src);
	local ts = typeof(tgt);
	if (ss != "array" || ts != "array")	{ DInfo("Bad pathfinder source ("+ss+") or target ("+ts+")",1); return null; }
	if (src.len() != 2 || tgt.len() != 2)	{ DInfo("Bad pathfinder source ("+src.len()+") or target ("+tgt.len()+")",1); return null; }
	if (!AIMap.IsValidTile(src[0]) || !AIMap.IsValidTile(tgt[1]))	return null;
	return src[0]+tgt[1];
	}

function cPathfinder::GetStatus(source, target, stationID, useEntry = null)
// return the status of the task, and create it if we didn't plane it yet
	{
	source = cPathfinder.GetSourceX(source);
	target = cPathfinder.GetTargetX(target);
	local uid=cPathfinder.GetUID(source, target);
	if (uid == null)	{ DError("Invalid pathfinder task : "+source[0]+" "+source[1]+" "+target[0]+" "+target[1],1); return -1; }
	if (uid in cPathfinder.database)	{ }
						else	{ cPathfinder.CreateNewTask(source, target, useEntry, stationID); return 0; }
	local pathstatus=cPathfinder.GetPathfinderObject(uid);
	return pathstatus.status;
	}	

function cPathfinder::AdvanceAllTasks()
// Advance all tasks handle by the pathfinder, if openttd handle multi-core/cpu this would be a huge help here
	{
	foreach (task in cPathfinder.database)	cPathfinder.AdvanceTask(task.UID);
	}

function cPathfinder::GetSolve(source, target)
// return the solver instance
	{
	source = cPathfinder.GetSourceX(source);
	target = cPathfinder.GetTargetX(target);
	local UID=cPathfinder.GetUID(source, target);
	if (UID == null)	{ DError("Invalid pathfinder task : "+source[0]+" "+source[1]+" "+target[0]+" "+target[1],1); return -1; }
	local pftask=cPathfinder.GetPathfinderObject(UID);
	return pftask.solve;
	}
	
function cPathfinder::CloseTask(source, target)
// Destroy that task
	{
	source = cPathfinder.GetSourceX(source);
	target = cPathfinder.GetTargetX(target);
	local UID=cPathfinder.GetUID(source, target);
	if (UID == null)	{ DError("Invalid pathfinder task : "+source[0]+" "+source[1]+" "+target[0]+" "+target[1],1); return -1; }
	local pftask=cPathfinder.GetPathfinderObject(UID);
	if (pftask == null)	return;
	if (pftask.UID in cPathfinder.database)
		{
		delete cPathfinder.database[pftask.UID];
		AISign.RemoveSign(pftask.signHandler);
		DInfo("Pathfinder task "+pftask.UID+" closed.",1);
		}
	}

function cPathfinder::AdvanceTask(UID)
// Advance the pathfinding search
	{
	local maxTimer=300;	// maximum time put on pathfinding a path
	local maxStep=10;		// maximum time put on a try
	local _counter=0;
	local pftask=cPathfinder.GetPathfinderObject(UID);
	switch (pftask.status)
		{
		case	-1:
			DInfo("Pathfinder task "+pftask.UID+" has end : nothing more could be done, failure.",1);
		return;
		case	1:
			DInfo("Pathfinder task "+pftask.UID+" has end search: trying to build the route found.",1);
			if (pftask.useEntry == null)	cBuilder.AsyncConstructRoadROAD(pftask.source[0], pftask.target[1], pftask.stationID);	
							else	cBuilder.BuildRoadRAIL(pftask.source, pftask.target, pftask.useEntry, pftask.stationID);
		return;
		case	2:
			DInfo("Pathfinder task "+pftask.UID+" has end building the path.",1);
		return;
		case	3:
			DInfo("Pathfinder task "+pftask.UID+" is waiting its subtask result.",1);
		return;
		}
	if (pftask.status != 0)	{ DInfo("Pathfinder task "+pftask.UID+" search is over with status "+pftask.status,1); return; }
	local check=false;
	DInfo("Pathfinder is working on task "+pftask.UID);
	while (check == false && _counter < maxStep)
		{
		check = pftask.pathHandler.FindPath(maxTimer);
		_counter++; pftask.timer++;
		pftask.InfoSign("Pathfinding "+pftask.UID+"... "+pftask.timer);
		}
	if (check != null && check != false)
		{
		DInfo("Pathfinder found a path for task "+pftask.UID,1);
		pftask.status=1;
		pftask.InfoSign("Pathfinding "+pftask.UID+"... FOUND!");
		pftask.solve=check;
		return;
		}
	if (check == null || pftask.timer > maxTimer)
		{
		DInfo("Pathfinder task "+pftask.UID+" failure",1);
		pftask.InfoSign("Pathfinding "+pftask.UID+"... failure");
		pftask.status=-1;
		}
	}

// private

function cPathfinder::GetSourceX(x)
// This convert integer coord to internal usage (same as railpathfinder)
{
	if (typeof(x) == "integer")	return [x,0];
	return x;
}

function cPathfinder::GetTargetX(x)
// This convert integer coord to internal usage (same as railpathfinder)
{
	if (typeof(x) == "integer")	return [0, x];
	return x;
}

function cPathfinder::InfoSign(msg)
// Update the sign and recreate it if need
	{
	local loc=-1;
	if (AISign.IsValidSign(this.signHandler))	loc=AISign.GetLocation(this.signHandler);
	if (loc != this.target[1])	loc=-1;
	if (loc != -1)	AISign.SetName(this.signHandler, msg);
			else	this.signHandler=AISign.BuildSign(this.target[1],msg);
	}

function cPathfinder::CreateNewTask(src, tgt, entrance, station)
// Create a new pathfinding task
	{
	local pftask=cPathfinder();
	src = cPathfinder.GetSourceX(src);
	tgt = cPathfinder.GetTargetX(tgt);
	pftask.UID=cPathfinder.GetUID(src, tgt);
	pftask.source=src;
	pftask.target=tgt;
	pftask.InfoSign("Pathfinder: task #"+cPathfinder.database.len());
	pftask.useEntry=entrance;
	pftask.stationID=station;
	if (entrance == null)
		{ // road
		pftask.pathHandler= MyRoadPF();
		pftask.pathHandler.cost.bridge_per_tile = 70;
		pftask.pathHandler.cost.tunnel_per_tile = 70;
		pftask.pathHandler.cost.turn = 200;
		pftask.pathHandler.cost.max_bridge_length=30;
		pftask.pathHandler.cost.max_tunnel_length=30;
		pftask.pathHandler.cost.tile=70;
		pftask.pathHandler.cost.slope=80;
		pftask.pathHandler._cost_level_crossing = 120;
		pftask.pathHandler.InitializePath([pftask.source[0]], [pftask.target[1]]);
		}
	else	{ // rail
		pftask.pathHandler= MyRailPF();
		pftask.pathHandler.cost.bridge_per_tile = 70;
		pftask.pathHandler.cost.tunnel_per_tile = 70;
		pftask.pathHandler.cost.turn = 200;
		pftask.pathHandler.cost.max_bridge_length=30;
		pftask.pathHandler.cost.max_tunnel_length=30;
		pftask.pathHandler.cost.tile=70;
		pftask.pathHandler.cost.slope=80;
		pftask.pathHandler.InitializePath(pftask.source, pftask.target);
		}
	DInfo("New pathfinder task : "+pftask.UID,1);
	cPathfinder.database[pftask.UID] <- pftask;
	}

