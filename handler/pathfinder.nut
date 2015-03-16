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

class cPathfinder extends cClass
	// Use it with cPathfinder.GetStatus function to create and manage tasks
	// Return state is -1= error, 2=success, so while -1 or 2 keep querying GetStatus
	{
		static	database = {};
		static	function GetPathfinderObject(UID)
			{
			if (UID in cPathfinder.database)	{ return cPathfinder.database[UID]; }
										else	{ return null; }
			}

		UID			= null;	// UID of the pathfinding task
		signHandler	= null;	// the sign ID that handle this task
		pathHandler	= null;	// the pathfinder instance
		solve		= null;	// the solve array
		timer		= null;	// the time we spend on that task
		source		= null;	// the source [] to pathfind
		target		= null;	// the target [] to pathfind
		status		= null;	// 0 - working, -1 fail, 1 success pathfind, 2 success route build, 3 wait for child to finish
		stationID	= null;	// the stationID rails will be assign to
		useEntry	= null;	// the entry of the stationID will be use or not
		// if we success at pathfinding, we will try build the route, and if we fail at building the route, we will recall the pathfinder or try to rebuild it
		// we will then report failure in status
		child		= null;	// the array list of child, first element is parent UID (or its own UID if it have no parent)
		autofail	= null; // a function that test a condition and return true if condition is met, false when condition is no more met
		autofail_arg= null; // parameters to pass to autofail function
		road_build	= null;	// a function to call to build road paths
		rail_build	= null;	// a function to call to build rail paths

		constructor()
			{
			UID			    = null;
			signHandler		= 0;
			pathHandler		= null;
			solve			= null;
			timer			= 0;
			source		    = [];
			target	    	= [];
			stationID		= null;
			useEntry		= null;
			status		    = 0;
			child			= [this.UID];
			autofail		= cPathfinder.StationExist;
			autofail_arg	= [this.stationID];
			this.ClassName	= "cPathfinder";
			this.road_build	= cBuilder.BuildPath_ROAD;
			this.rail_build = cBuilder.BuildPath_RAIL;
			}
	}

function cPathfinder::CheckPathCondition()
{
	if (this.useEntry == null)
				{
				if (!AIRoad.IsRoadTile(this.source[0]))	return false;
				if (!AIRoad.IsRoadTile(this.target[1]))	return false;
				}
		else	{
				if (!AIRail.IsRailTile(this.source[1]))	return false; // must be rail
				if (!AIRail.IsRailTile(this.target[1]))	return false;

				// must be clear or something we own (like a rail...)
 				if (!AITile.IsBuildable(this.source[0]) && AITile.GetOwner(this.source[0]) != AICompany.COMPANY_SELF)	return false;
				if (!AITile.IsBuildable(this.target[0]) && AITile.GetOwner(this.target[0]) != AICompany.COMPANY_SELF)	return false;
				}
	return true;
}

function cPathfinder::GetUID(src, tgt)
// return UID of the task
	{
	src = cPathfinder.GetSourceX(src);
	tgt = cPathfinder.GetTargetX(tgt);
	local ss = typeof(src);
	local ts = typeof(tgt);
	if (ss != "array" || ts != "array")	{ DInfo("Bad pathfinder source ("+ss+") or target ("+ts+")",1); return null; }
	if (src.len() != 2 || tgt.len() != 2)	{ DInfo("Bad pathfinder source ("+src.len()+") or target ("+tgt.len()+")",1); return null; }
	if (!AIMap.IsValidTile(src[0]) || !AIMap.IsValidTile(tgt[1]))	{ return null; }
	return src[0]+tgt[1];
	}

function cPathfinder::ThreeTileCheck(tile, tile_forward, func, value)
{
	local zone = AIList();
	zone.AddItem(tile, 0);
	zone.AddItem(tile + tile_forward, 1);
	zone.AddItem(tile - tile_forward, 2);
	zone.Valuate(func);
	zone.KeepValue(value);
	if (zone.Count() == 3)	return true;
	return false;
}

function cPathfinder::BuildShortPoints(source, target)
{
	local start = source[1];
	local end = target[1];
	local RT = (AIRail.IsRailTile(start) && AIRail.IsRailTile(end));
	if (!RT)	{ return -1; }
	RT = AIRail.GetRailType(start);
//	local mid = AIMap.GetTileIndex( (AIMap.GetTileX(start) + AIMap.GetTileX(end)) / 2, (AIMap.GetTileY(start) + AIMap.GetTileY(end)) / 2);
	local direction = cBuilder.GetDirection(start, end);
    local track = cTrack.GetRailFromDirection(direction);
    local startdir = cBuilder.GetDirection(source[1], source[0]); // to see if both are going toward same direction
    local enddir = cBuilder.GetDirection(target[1], target[0]);
    local s_x = AIMap.GetTileX(start);
    local s_y = AIMap.GetTileY(start);
    local e_x = AIMap.GetTileX(end);
    local e_y = AIMap.GetTileY(end);
    local mid = AIMap.GetTileIndex( (s_x + e_x) / 2, (s_y + e_y) / 2); // mid position default, between half of both points
    AISign.BuildSign(mid,"S");
	local m_x = 0;
    local m_y = 0;
    switch (direction)
		{
		case	DIR_SE:
		case		DIR_NW:
				print("SE/NW case");
/*				if (s_x > e_x)	{ m_x = e_x; m_y = (s_y + e_y) / 2; }
						else	{ m_x = s_x; m_y = (s_y + e_y) / 2; }*/
				m_x = s_x;
				if (startdir == DIR_NE || startdir == DIR_SW)
					{
					if (m_x > e_x)	m_x += AIMap.GetTileIndex(-1, 0);
							else	m_x += AIMap.GetTileIndex(1, 0);
					}
				m_y = (s_y + e_y) / 2;
				//if (startdir == enddir) { print("shorten point"); m_x = e_x; m_y = (s_y + e_y * 2) / 3; }
				// closer to start
				break;
/*		case	DIR_NW:
				if (s_x > e_x)	{ m_x = e_x; m_y = s_y; }
						else	{ m_x = s_x; m_y = e_y; }
				break;*/
        case	DIR_NE:
		case		DIR_SW:
				print("NE/SW case");
				//if (s_y > e_y)	{ m_x = e_x; m_y = s_y; }  //852*188g 852*215d
					//	else	{ m_x = s_x; m_y = e_y; }
				m_x = (s_x + e_x) / 2;
				m_y = s_y;
				if (startdir == DIR_NW || startdir == DIR_SE)
					{
					if (m_y > e_y)	m_y += AIMap.GetTileIndex(0, -1);
							else	m_y += AIMap.GetTileIndex(0, 1);
					}
				//if (startdir == enddir)	{ print("shorten point"); m_x = (s_x + e_x * 2) / 3; m_y = e_y; }
				break;
/*		case	DIR_SW:
				if (s_x > e_x)	{ m_x = s_x; m_y = e_y; }
						else	{ m_x = e_x; m_y = s_y; }
				break;*/
		}
	mid = AIMap.GetTileIndex(m_x, m_y);
    print("distancemax = "+AIMap.DistanceMax(start, end));
    print("s_x="+s_x+" s_y="+s_y+" e_x="+e_x+" e_y="+e_y+" startdir="+cBuilder.DirectionToString(startdir)+" enddir="+cBuilder.DirectionToString(enddir));
    print("DIR_NE="+DIR_NE+" DIR_SE="+DIR_SE+" DIR_NW="+DIR_NW+" DIR_SW="+DIR_SW+" direction="+cBuilder.DirectionToString(direction));
	AISign.BuildSign(mid, "M");

	local fwd = cTileTools.GetForwardRelativeFromDirection(direction);
    local seek_area = AITileList();
    seek_area.AddRectangle(mid + AIMap.GetTileIndex(5, 5), mid - AIMap.GetTileIndex(5,5));
    seek_area.Valuate(cPathfinder.ThreeTileCheck, fwd, AITile.IsBuildable, 1);
    seek_area.KeepValue(1);
    print("buildable options="+seek_area.Count());
	if (seek_area.IsEmpty())	return -1; // no place to build
    seek_area.Valuate(cPathfinder.ThreeTileCheck, fwd, AITile.GetSlope, AITile.SLOPE_FLAT);
    local need_terraform = false;
    foreach (tiles, flat in seek_area)
		{
		if (AITile.IsWaterTile(tiles))
				{
				need_terraform = true;
				break;
				}
		if (flat != 1)	{ need_terraform = true; break; }
		}
	if (!INSTANCE.terraform && need_terraform)	return -1;
	seek_area.Valuate(AIMap.DistanceManhattan, mid);
	seek_area.Sort(AIList.SORT_BY_VALUE, true);
	local mainTile = null;
	local bckTile = null;
    local fwdTile = null;
	foreach (tile, distance in seek_area)
		{
		if (need_terraform)	{ cBanker.RaiseFundsBigTime(); cTileTools.TerraformLevelTiles(tile + fwd, tile - fwd); }
		if (cPathfinder.ThreeTileCheck(tile, fwd, AITile.GetSlope, AITile.SLOPE_FLAT) && cPathfinder.ThreeTileCheck(tile, fwd, AITile.IsBuildable, 1))
				{ mainTile = tile; break; }
		}
	print("mainTile ="+mainTile);
	if (mainTile == null)	return -1;
	cTrack.DropRailHere(track, mainTile);
    bckTile = mainTile - fwd;
    fwdTile = mainTile + fwd;
    local newpath = [];
    newpath.push(source);
    newpath.push([bckTile, mainTile]);
    newpath.push([fwdTile, mainTile]);
    newpath.push(target);
    cDebug.ClearSigns();
	return newpath;
}

function cPathfinder::CheckPathfinderTaskIsRunning(condition)
	{
	if (typeof condition != "array")	{ DError("conditions must be an array with args to pass to your own autofail test function"); return false; }
	foreach (obj in cPathfinder.database)
		{
		if (obj.autofail(condition))	return true;
		}
	return false;
	}

function cPathfinder::GetStatus(source, target, stationID, useEntry = null)
// return the status of the task, and create it if we didn't plane it yet
	{
	local uid=cPathfinder.GetUID(source, target);
	if (uid == null)	{ DError("Invalid pathfinder task : "+source[0]+" / "+source[1]+" / "+target[0]+" / "+target[1],1); return -1; }
	if (uid in cPathfinder.database)	{ }
                                else	{ cPathfinder.CreateNewTask(source, target, useEntry, stationID, true); return 0; }
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
	local UID=cPathfinder.GetUID(source, target);
	if (UID == null)	{ DError("Invalid pathfinder task : "+source[0]+" / "+source[1]+" / "+target[0]+" / "+target[1],1); return -1; }
	local pftask=cPathfinder.GetPathfinderObject(UID);
	return pftask.solve;
	}

function cPathfinder::CloseTaskAndChildren(id)
{
	local task = cPathfinder.GetPathfinderObject(id);
	if (task == null)	return;
	for (local i = 1; i < task.child.len(); i++)
		{
		cPathfinder.CloseTaskAndChildren(task.child[i]);
		}
	if (task.UID in cPathfinder.database)
		{
		delete cPathfinder.database[task.UID];
		AISign.RemoveSign(task.signHandler);
		DInfo("Pathfinder task "+task.UID+" closed.",1);
		}
}

function cPathfinder::CloseTask(source, target)
// Destroy that task and its children
{
	local UID = cPathfinder.GetUID(source, target);
	if (UID == null)	return;
	local root_id = cPathfinder.GetRootTask(UID);
	if (root_id == null)	return;
	cPathfinder.CloseTaskAndChildren(root_id);
}

function cPathfinder::GetRootTask(uid)
// it return the uid of the root task
{
    while (true)
		{
		local ptask = cPathfinder.GetPathfinderObject(uid);
		if (ptask == null)	return -1;
		if (ptask.child[0] == null)	return ptask.UID;
							else	uid = ptask.child[0];
		}
}

function cPathfinder::PropagateChange(id)
{
	local task = cPathfinder.GetPathfinderObject(id);
	if (task == null)	return -1;
	local root_id = cPathfinder.GetRootTask(id);
	if (root_id == -1)	return -1;
	local anerror =false;
	local allsuccess = true;
	for (local i = 1; i < task.child.len(); i++)
		{
		local fils = cPathfinder.GetPathfinderObject(task.child[i]);
		if (fils == null || fils.status == -1)	{ anerror = true; break; }
		if (fils.status != 2)	allsuccess = false;
		print(task.UID+" child "+fils.UID+" status "+fils.status);
		}
	if (anerror)	{
					if (root_id == task.UID)	{ task.status = -1; return -1; }
					local root = cPathfinder.GetPathfinderObject(root_id);
					if (root == null)	return -1;
					root.status = -1;
					return -1;
					}
	if (allsuccess)	{
					task.status = 2;
					if (task.child[0] != null)	cPathfinder.PropagateChange(task.child[0]); // see if its parent now end too
					}
}

function cPathfinder::AdvanceTask(UID)
// Advance the pathfinding search
{
	local maxTimer=300;	// maximum time put on pathfinding a path
	local maxStep=5;		// maximum time put on a try
	local _counter=0;
	local pftask=cPathfinder.GetPathfinderObject(UID);
	if (pftask == null)	return;
	local tlist = "Parent:";
	for (local k = 0; k < pftask.child.len(); k++)
			{
			if (k == 0)
				{
				if (pftask.child[0] == null)	{ tlist += "ROOT "; }
										else	{ tlist += pftask.child[0]+" "; }
				continue;
				}
			if (k == 1)	tlist += "Children: ";
			local fils = cPathfinder.GetPathfinderObject(pftask.child[k]);
			if (fils == null)	return;
			tlist += pftask.child[k]+":"+fils.status+"  ";
			}
	switch (pftask.status)
			{
			case	-1:
				DInfo("Pathfinder task "+pftask.UID+" has end : nothing more could be done, failure. "+tlist,1);
				local root = cPathfinder.GetRootTask(pftask.UID);
				if (root == -1)	return;
				// give it a last chance to handle the failure
				pftask = cPathfinder.GetPathfinderObject(root);
				if (pftask == null)	return;
				pftask.status = -1; // we set root task to failure
				local result;
				if (pftask.useEntry == null)	{ result = pftask.road_build(pftask.source[0], pftask.target[1], pftask.stationID); }
                                        else	{ result = pftask.rail_build(pftask.source, pftask.target, pftask.useEntry, pftask.stationID); }
				cPathfinder.CloseTask(pftask.source, pftask.target);
				return;
			case	1:
				if (!cBanker.CanBuyThat(30000))	{ return; }
				cBanker.RaiseFundsBy(30000);
				DInfo("Pathfinder task "+pftask.UID+" has end search: trying to build the route found.",1);
				local result = 0;
				if (pftask.useEntry == null)	{ result = pftask.road_build(pftask.source[0], pftask.target[1], pftask.stationID); }
                                        else	{ result = pftask.rail_build(pftask.source, pftask.target, pftask.useEntry, pftask.stationID); }
				if (result == -1)	return; // don't let it propagate success if we lack money to endup all builds
				if (result == 0)	pftask.status = 2;
				if (result == -2)	pftask.status = -1;
				cPathfinder.PropagateChange(pftask.UID);
				return;
			case	2:
				DInfo("Pathfinder task "+pftask.UID+" has end task. "+tlist,1);
				if (pftask.child[0] == null) // we're end and we are root task
					{
					local result = 0;
					// recalling function to handle the work is finish
					if (pftask.useEntry == null)	{ result = pftask.road_build(pftask.source[0], pftask.target[1], pftask.stationID); }
											else	{ result = pftask.rail_build(pftask.source, pftask.target, pftask.useEntry, pftask.stationID); }
					// even if we succeed, if the function tell us we fail, set us as fail
					if (result == -2 && pftask.status != -1)	{ pftask.status = -1; }
					}
				return;
			case	3:
				DInfo("Pathfinder task "+pftask.UID+" is waiting subtask result. "+tlist,1);
				return;
			}
	local check = false;
	DInfo("Pathfinder is working on task "+pftask.UID);
	while (check == false && _counter < maxStep)
			{
			check = pftask.pathHandler.FindPath(maxTimer);
			_counter++; pftask.timer++;
			pftask.InfoSign("Pathfinding "+pftask.UID+"... "+pftask.timer);
			}
	if (check != null && check != false)
			{
			DInfo("Pathfinder found a path for task "+pftask.UID+" @"+pftask.timer,1);
			pftask.status = 1;
			pftask.InfoSign("Pathfinding "+pftask.UID+"... FOUND!");
			pftask.solve = check;
			return;
			}
	if (check == null || pftask.timer > maxTimer || !pftask.CheckPathCondition())
			{
			DInfo("Pathfinder task "+pftask.UID+" failure",1);
			pftask.InfoSign("Pathfinding "+pftask.UID+"... failure");
			pftask.status = -1;
			}
	if (!pftask.autofail(pftask.autofail_arg))
			{
			DInfo("Pathfinder is autoclosing task "+pftask.UID,1);
			cPathfinder.CloseTask(pftask.source[0], pftask.target[1]);
			}
}

// private

function cPathfinder::StationExist(arg)
{
	if (stationID == null)	return false;
	return AIStation.IsValidStation(stationID);
}

function cPathfinder::GetSourceX(x)
// This convert integer coord to internal usage (same as railpathfinder)
	{
	if (typeof(x) == "integer")	{ return [x,0]; }
	return x;
	}

function cPathfinder::GetTargetX(x)
// This convert integer coord to internal usage (same as railpathfinder)
	{
	if (typeof(x) == "integer")	{ return [0, x]; }
	return x;
	}

function cPathfinder::InfoSign(msg)
// Update the sign and recreate it if need
	{
	local loc=-1;
	if (AISign.IsValidSign(this.signHandler))	{ loc=AISign.GetLocation(this.signHandler); }
	if (loc != this.target[1])	{ loc=-1; }
	if (loc != -1)	{ AISign.SetName(this.signHandler, msg); }
            else	{ this.signHandler=AISign.BuildSign(this.target[1],msg); }
	}

function cPathfinder::CreateNewTask(src, tgt, entrance, station, split = false)
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
			{
			// road
			pftask.pathHandler= MyRoadPF();
			pftask.pathHandler.cost.bridge_per_tile = 90;
			pftask.pathHandler.cost.tunnel_per_tile = 90;
			pftask.pathHandler.cost.turn = 200;
			pftask.pathHandler.cost.max_bridge_length=30;
			pftask.pathHandler.cost.max_tunnel_length=30;
			pftask.pathHandler.cost.tile=70;
			pftask.pathHandler.cost.slope=120;
			pftask.pathHandler._cost_level_crossing = 120;
			pftask.pathHandler.InitializePath([pftask.source[0]], [pftask.target[1]]);
			}
	else	  // rail
			{
            pftask.pathHandler= MyRailPF();
//			pftask.pathHandler.cost.bridge_per_tile = 50;//70
//			pftask.pathHandler.cost.tunnel_per_tile = 50;//70
//			pftask.pathHandler.cost.turn = 80;//200
			pftask.pathHandler.cost.max_bridge_length=30;
			pftask.pathHandler.cost.max_tunnel_length=30;
			pftask.pathHandler.cost.tile=100;
			pftask.pathHandler.cost.slope=110;//80
			pftask.pathHandler.cost.coast = 140;
			pftask.pathHandler.cost.diagonal_tile=100;
			pftask.pathHandler.InitializePath([pftask.source], [pftask.target]);
			}
	DInfo("New pathfinder task : "+pftask.UID,1);
	cPathfinder.database[pftask.UID] <- pftask;
	if (split && entrance != null)	cPathfinder.AddSubTask(pftask.UID);
	}

function cPathfinder::AddSubTask(mainUID)
{
	print("add subtask");
	local point = null;
	local s1 = null;
	local s2 = null;
	local s3 = null;
	local s4 = null;
	local roottask = cPathfinder.GetPathfinderObject(mainUID);
	if (roottask == null)   return;
	local distance = AITile.GetDistanceManhattanToTile(roottask.source[1], roottask.target[1]);
	print("distance = "+distance)
	if (distance <= 40)	return; // no split, distance is short
	point = cPathfinder.BuildShortPoints(roottask.source, roottask.target);
	if (point == -1)	return;
	s1 = [point[0], point[1]];
	s4 = [point[2], point[3]];
	if (distance > 80)
		{
		point = cPathfinder.BuildShortPoints(s1[0], s1[1]);
		print("point="+point);
		if (point != -1)
			{
			print("point non nul");
			s1 = [point[0], point[1]];
			s2 = [point[2], point[3]];
			}
		}
	if (distance > 80)
		{
		point = cPathfinder.BuildShortPoints(s4[0], s4[1]);
		if (point != -1)
			{
			s3 = [point[0], point[1]];
			s4 = [point[2], point[3]];
			}
		}
	if (s1 != null)	cPathfinder.CreateSubTask(mainUID, s1[0], s1[1]);
	if (s2 != null)	cPathfinder.CreateSubTask(mainUID, s2[0], s2[1]);
	if (s3 != null)	cPathfinder.CreateSubTask(mainUID, s3[0], s3[1]);
	if (s4 != null)	cPathfinder.CreateSubTask(mainUID, s4[0], s4[1]);
}

function cPathfinder::CreateSubTask(mainUID, newSource, newTarget)
// Create a subtask of mainUID task
{
	local parentTask = cPathfinder.GetPathfinderObject(mainUID);
	if (parentTask == null)	return -1;
	local filsUID = cPathfinder.GetUID(newSource, newTarget);
	local fils = null;
	if (filsUID == mainUID)
		{
        fils = cPathfinder.GetPathfinderObject(filsUID);
        if (fils == null)	return -1;
        parentTask = cPathfinder.GetPathfinderObject(fils.child[0]);
        if (parentTask == null)	return -1;
        AISign.RemoveSign(fils.signHandler);
		delete cPathfinder.database[filsUID];
		DInfo("Re-running subtask "+filsUID,1);
		}
	local subTask = cPathfinder.CreateNewTask(newSource, newTarget, parentTask.useEntry, parentTask.stationID, false);
	fils = cPathfinder.GetPathfinderObject(cPathfinder.GetUID(newSource, newTarget));
	if (filsUID != mainUID)	parentTask.child.push(fils.UID);
	parentTask.status = 3;
	fils.child[0] = parentTask.UID;
	DInfo("Pathfinder add subtask "+fils.UID+" to "+parentTask.UID,1);
}
