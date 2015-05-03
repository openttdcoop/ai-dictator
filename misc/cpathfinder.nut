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
		status		= null;	// 0 - working, -1 fail pathfind, -2 fail building, 1 success pathfind, 2 success build
		stationID	= null;	// the stationID rails will be assign to
		PrimaryLane = null; // true if we build main lane, false if we build alt lane
		useEntry	= null;	// the entry of the stationID will be use or not
		// if we success at pathfinding, we will try build the route, and if we fail at building the route, we will recall the pathfinder or try to rebuild it
		// we will then report failure in status
		child		= null;	// the array list of child, first element is parent UID (or its own UID if it have no parent)
		autofail	= null; // a function that test a condition and return true if condition is met, the "this" context is the task object
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
			PrimaryLane		= null;
			useEntry		= null;
			status		    = 0;
			child			= [null];
			autofail		= cPathfinder.StationExist;
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
 				if (!AITile.IsBuildable(this.source[0]) && !AICompany.IsMine(AITile.GetOwner(this.source[0])))	return false;
				if (!AITile.IsBuildable(this.target[0]) && !AICompany.IsMine(AITile.GetOwner(this.target[0])))	return false;
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

function cPathfinder::FiveTileCheck(tile, tile_forward, func, value)
{
	local zone = AIList();
	zone.AddItem(tile, 0);
	zone.AddItem(tile + tile_forward, 1);
	zone.AddItem(tile + tile_forward + tile_forward, 1);
	zone.AddItem(tile - tile_forward, 2);
	zone.AddItem(tile - tile_forward - tile_forward, 2);
	zone.Valuate(func);
	zone.KeepValue(value);
	if (zone.Count() == 5)	return true;
	return false;
}

function cPathfinder::NextToTrackBonus(tile, trackplace, direction)
// gives a value to the tile position, farer from the trackplace, bigger the value
// but also, lower the value if the tile is on the good side of the track : endup with lowest value, best tile to use
{
	local r = AIMap.DistanceSquare(tile, trackplace);
	local tr_x = AIMap.GetTileX(trackplace);
	local tr_y = AIMap.GetTileY(trackplace);
	local ti_x = AIMap.GetTileX(tile);
	local ti_y = AIMap.GetTileY(tile);
	local b = 80; // a big malus from being on the wrong side
	switch (direction)
			{
			case	DIR_SE:
				if (tr_x < ti_x)	b = -10;
				break;
			case	DIR_NW:
				if (tr_x > ti_x)	b = -10;
				break;
			case	DIR_NE:
				if (tr_y < ti_y)	b = -10;
				break;
			case	DIR_SW:
				if (tr_y > ti_y)	b = -10;
				break;
			}
	r += b;
	return r;
}

function cPathfinder::BuildShortPoints(source, target, close_source)
// Build a rail in between source/target distance, next to another rail if possible
{
	local start = source[1];
	local end = target[1];
	local RT = (AIRail.IsRailTile(start) && AIRail.IsRailTile(end));
	if (!RT)	{ return -1; }
	RT = AIRail.GetRailType(start);
	local direction = cDirection.GetDirection(start, end);
    local track = cTrack.GetRailFromDirection(direction);
    local startdir = cDirection.GetDirection(source[1], source[0]);
    local s_x = AIMap.GetTileX(start);
    local s_y = AIMap.GetTileY(start);
    local e_x = AIMap.GetTileX(end);
    local e_y = AIMap.GetTileY(end);
    local mid = AIMap.GetTileIndex( (s_x + e_x) / 2, (s_y + e_y) / 2); // mid position default, between half of both points
	local m_x = AIMap.GetTileX(mid);
    local m_y = AIMap.GetTileY(mid);
    local correct = mid;
    AISign.BuildSign(mid, "M");
    if (close_source)
		switch (startdir)
			{
			case	DIR_SE:
				if (m_y < s_y)	m_y = s_y;
				break;
			case	DIR_NW:
				if (m_y > s_y)	m_y = s_y;
				break;
			case	DIR_NE:
				if (m_x > s_x)	m_x = s_x;
				break;
			case	DIR_SW:
				if (m_x < s_x)	m_x = s_x;
				break;
			}
	correct = AIMap.GetTileIndex(m_x, m_y);
	AISign.BuildSign(correct, "C");
	if (AIMap.DistanceManhattan(correct, start) > 9) mid = correct; // use correct point if it doesn't fall to close start point only
	local fwd = cDirection.GetForwardRelativeFromDirection(direction);
    local seek_area = AITileList();
    seek_area.AddRectangle(mid + AIMap.GetTileIndex(5, 5), mid - AIMap.GetTileIndex(5,5));
	local any_rail = null;
	foreach (tile, _ in seek_area)
		{ // lookout if we can find a rail we own
		if (AIRail.IsRailTile(tile) && AICompany.IsMine(AITile.GetOwner(tile)))
			{
			any_rail = tile;
			break;
			}
		}
    seek_area.Valuate(cPathfinder.FiveTileCheck, fwd, AITile.IsBuildable, 1);
    seek_area.KeepValue(1);
	if (seek_area.IsEmpty())	return -1; // no place to build
    seek_area.Valuate(cPathfinder.FiveTileCheck, fwd, AITile.GetSlope, AITile.SLOPE_FLAT);
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
	if (any_rail != null)	seek_area.Valuate(cPathfinder.NextToTrackBonus, any_rail, direction);
					else	seek_area.Valuate(AIMap.DistanceManhattan, mid);
	seek_area.Sort(AIList.SORT_BY_VALUE, true);
	local mainTile = null;
	local bckTile = null;
    local fwdTile = null;
	foreach (tile, distance in seek_area)
		{
		if (need_terraform)	{ cTerraform.TerraformLevelTiles(tile + fwd + fwd, tile - fwd - fwd); }
		if (cPathfinder.FiveTileCheck(tile, fwd, AITile.GetSlope, AITile.SLOPE_FLAT) && cPathfinder.FiveTileCheck(tile, fwd, AITile.IsBuildable, 1))
				{ mainTile = tile; break; }
		}
	if (mainTile == null)	return -1;
	cTrack.DropRailHere(track, mainTile);
    bckTile = mainTile - fwd;
    fwdTile = mainTile + fwd;
    local newpath = [];
    newpath.push(source);
    newpath.push([bckTile, mainTile]);
    newpath.push([fwdTile, mainTile]);
    newpath.push(target);
	return newpath;
}

function cPathfinder::CheckPathfinderTaskIsRunning(stations)
	{
	if (typeof stations != "array")	{ DError("stations must be an array with source stationID and target stationID"); return false; }
	foreach (obj in cPathfinder.database)
		{
		if (obj.stationID == stations[0] || obj.stationID == stations[1])	return true;
		}
	return false;
	}

function cPathfinder::GetStatus(source, target, stationID, primarylane, useEntry)
// return the status of the task, and create it if we didn't plane it yet
	{
	local uid = cPathfinder.GetUID(source, target);
	if (uid == null)	{ DError("Invalid pathfinder task : "+source[0]+" / "+source[1]+" / "+target[0]+" / "+target[1],1); return -1; }
	if (uid in cPathfinder.database)	{ }
                                else	{ cPathfinder.CreateNewTask(source, target, stationID, primarylane, useEntry, true); return 0; }
	local pathstatus = cPathfinder.GetPathfinderObject(uid);
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
	local UID = cPathfinder.GetUID(source, target);
	if (UID == null)	{ DError("Invalid pathfinder task : "+source[0]+" / "+source[1]+" / "+target[0]+" / "+target[1],1); return -1; }
	local pftask = cPathfinder.GetPathfinderObject(UID);
	if (!pftask)	{ DError("Invalid pathfinder task : "+source[0]+" / "+source[1]+" / "+target[0]+" / "+target[1],1); return -1; }
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
// Destroy that task and its parent and children
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

function cPathfinder::PropagateChangeToParent(id)
{
	local task = cPathfinder.GetPathfinderObject(id);
	if (task == null || task.child[0] == null)	return;
	local ptask = cPathfinder.GetPathfinderObject(task.child[0]);
	if (ptask == null)	return;
	local state = task.status;
    if (state != -2 && ptask.status == state)	return;
	for (local i = 1; i < ptask.child.len(); i++)
		{
		local ptask_child = cPathfinder.GetPathfinderObject(ptask.child[i]);
		if (ptask_child == null)	return;
		if (ptask_child.status == -2)	state = -2; // viral failure
        if (state == -2)	ptask_child.status = -2;
		if (ptask_child.status != state)	return;
		}
    ptask.status = state;
    DInfo("task #"+ptask.UID+" status change to "+ptask.status,2);
    // tell its own parent about the change
    if (ptask.child[0] != null)	cPathfinder.PropagateChangeToParent(ptask.child[0]);
}

function cPathfinder::AdvanceTask(UID)
// Advance the pathfinding search
{
	local maxTimer = 300;	// maximum time put on pathfinding a path, but it change with distance
	local maxStep = 5;		// maximum time put on a try
	local _counter = 0;
	local pftask = cPathfinder.GetPathfinderObject(UID);
	if (pftask == null)	return;
	maxTimer = (AIMap.DistanceManhattan(pftask.source[0], pftask.target[1]) * 4).tointeger();
	if (maxTimer > 300)	maxTimer = 300;
	local tlist = " Parent:";
	for (local k = 0; k < pftask.child.len(); k++)
			{
			if (k == 0)
				{
				if (pftask.child[0] == null)	{ tlist += "ROOT"; }
										else	{ tlist += pftask.child[0]; }
				continue;
				}
			if (k == 1)	tlist += "Child: ";
			local fils = cPathfinder.GetPathfinderObject(pftask.child[k]);
			if (fils == null)	return;
			tlist += pftask.child[k]+"("+fils.status+") ";
			}
	DInfo("Pathfinder task #"+UID+"("+pftask.status+") @"+maxTimer+tlist,0);
	local spacer = "        ";
	DInfo(spacer+" from "+cMisc.Locate(pftask.source[0])+spacer+cMisc.Locate(pftask.source[1]),1);
	DInfo(spacer+"  to  "+cMisc.Locate(pftask.target[0])+spacer+cMisc.Locate(pftask.target[1]),1);
	if (!pftask.autofail())
		{
		DInfo(spacer+"Pathfinder is autoclosing task "+pftask.UID,1);
		cPathfinder.CloseTask(pftask.source[0], pftask.target[1]);
		}
	if (pftask.status == 0 && pftask.child.len() > 1)	{ DInfo(spacer+"is waiting children to finish",1); return; }
	local root_id = cPathfinder.GetRootTask(UID);
	local root_task = null;
	if (root_id != -1)	root_task = cPathfinder.GetPathfinderObject(root_id);
	if (root_task == null)	{ cPathfinder.CloseTaskAndChildren(UID); return; }
	switch (pftask.status)
			{
			case	-1:
				DInfo(spacer+" "+pftask.UID+" fail to pathfind",1);
				if (pftask.UID == root_id)	{ DInfo(spacer+" ROOT task is dead...",1); pftask.status = -2; return; }
				// kill all child from root task
				for (local i = 1; i < root_task.child.len(); i++)	cPathfinder.CloseTaskAndChildren(root_task.child[i]);
				root_task.child = [null];
				root_task.status = 0;
				return;
			case	-2:
				DInfo(spacer+"nothing more could be done, failure",1);
                if (root_task.UID != pftask.UID)	{ cPathfinder.PropagateChangeToParent(pftask.UID); return; }
				// give it a last chance to handle the failure
				if (pftask.useEntry == null)	pftask.road_build(pftask.source[0], pftask.target[1], pftask.stationID, pftask.PrimaryLane);
                                        else	pftask.rail_build(pftask.source, pftask.target, pftask.stationID, pftask.PrimaryLane, pftask.useEntry);
				//cPathfinder.CloseTask(pftask.source, pftask.target);
				return;
			case	-3:
				cPathfinder.CloseTask(pftask.source, pftask.target);
				return;
			case	1:
				if (!cBanker.CanBuyThat(10000))	 return;
				cBanker.RaiseFundsBy(30000);
				DInfo(spacer+pftask.UID+" has end search",1);
				// only start building if root task is ok to build
				if (root_task.status != 1)	return;
                // but don't build anything if you have a child yourself
				if (pftask.child.len() > 1)	return;
   				DInfo(spacer+pftask.UID+" is building the path",1);
				local result = 0;
				if (pftask.useEntry == null)	{ result = pftask.road_build(pftask.source[0], pftask.target[1], pftask.stationID, pftask.PrimaryLane); }
                                        else	{ result = pftask.rail_build(pftask.source, pftask.target, pftask.stationID, pftask.PrimaryLane, pftask.useEntry); }
				if (result == -1)	return; // retry later
				if (result == 0)	pftask.status = 2;
				if (result == -2)	pftask.status = -2;
				cPathfinder.PropagateChangeToParent(pftask.UID);
				return;
			case	2:
				DInfo(spacer+pftask.UID+" has end building",1);
				// Only root task can run this
                if (root_task.UID != pftask.UID)	return;
				// recalling function to handle the work is finish
				local result = 0;
				if (pftask.useEntry == null)	{ result = pftask.road_build(pftask.source[0], pftask.target[1], pftask.stationID, pftask.PrimaryLane); }
										else	{ result = pftask.rail_build(pftask.source, pftask.target, pftask.stationID, pftask.PrimaryLane, pftask.useEntry); }
				// even if we succeed, if the function tell us we fail, set us as fail
				//cPathfinder.CloseTask(pftask.source, pftask.target);
				return;
			}
	local check = false;
	DInfo(spacer+"is searching a path @"+pftask.timer);
	if (!pftask.CheckPathCondition())
		{
		if (pftask.UID == root_id)	pftask.status = -2;
							else	pftask.status = -1;
		return;
		}
	while (check == false && _counter < maxStep)
			{
			check = pftask.pathHandler.FindPath(maxTimer);
			_counter++; pftask.timer++;
			pftask.InfoSign("Pathfinding "+pftask.UID+"... "+pftask.timer);
			}
	if (check != null && check != false)
			{
			DInfo(spacer+"found a path @"+pftask.timer,1);
			pftask.status = 1;
			pftask.InfoSign("Pathfinding "+pftask.UID+"... FOUND!");
			pftask.solve = check;
			cPathfinder.PropagateChangeToParent(UID);
			return;
			}
	if (check == null || pftask.timer > maxTimer)
			{
			DInfo(spacer+"task failure : timer="+pftask.timer+" maxTimer="+maxTimer,1);
			pftask.InfoSign("Pathfinding "+pftask.UID+"... failure");
			pftask.status = -1;
			}
}

// private

function cPathfinder::StationExist()
{
	if (this.stationID == null)	return false;
	return AIStation.IsValidStation(this.stationID);
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

function cPathfinder::CreateNewTask(src, tgt, station, primarylane, entrance, split = false)
// Create a new pathfinding task
	{
	local pftask = cPathfinder();
	src = cPathfinder.GetSourceX(src);
	tgt = cPathfinder.GetTargetX(tgt);
	pftask.UID = cPathfinder.GetUID(src, tgt);
	pftask.source = src;
	pftask.target = tgt;
	pftask.InfoSign("Pathfinder: task #"+cPathfinder.database.len());
	pftask.useEntry = entrance;
	pftask.PrimaryLane = primarylane;
	pftask.stationID = station;
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
			// we change the callback function when primarylane is false for road function
			if (!primarylane)	pftask.road_build = cBuilder.BuildRoadROAD;
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
	point = cPathfinder.BuildShortPoints(roottask.source, roottask.target, true);
	if (point == -1)	return;
	s1 = [point[0], point[1]];
	s4 = [point[2], point[3]];
	if (distance > 80)
		{
		point = cPathfinder.BuildShortPoints(s1[0], s1[1], true);
		if (point != -1)
			{
			s1 = [point[0], point[1]];
			s2 = [point[2], point[3]];
			}
		}
	if (distance > 80)
		{
		point = cPathfinder.BuildShortPoints(s4[0], s4[1], false);
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
	if (filsUID == mainUID || filsUID in cPathfinder.database)
		{
		DWarn("Trying to re-run same subtask again : "+filsUID,1);
		parentTask.status = -2;
		return;
		}
	local subTask = cPathfinder.CreateNewTask(newSource, newTarget, parentTask.stationID, parentTask.PrimaryLane, parentTask.useEntry, false);
	fils = cPathfinder.GetPathfinderObject(cPathfinder.GetUID(newSource, newTarget));
	if (filsUID != mainUID)	parentTask.child.push(fils.UID);
	parentTask.status = 0;
	fils.child[0] = parentTask.UID;
	// Now make sure root task is also reset to 0
	local root_task = cPathfinder.GetPathfinderObject(cPathfinder.GetRootTask(mainUID));
	if (root_task == null)	{ DError("Cannot find root task of "+UID,2); }
	root_task.status = 0;
	DInfo("Pathfinder add subtask "+fils.UID+" to "+parentTask.UID,1);
}
