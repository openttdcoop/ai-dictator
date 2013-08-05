/* -*- Mode: C++; tab-width: 4 -*- */
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

function cBuilder::RailStationPhaseGrowing(stationObj, newStationSize, useEntry)
	{
	DInfo("--- Phase 1: grow",1);
	DInfo("Upgrading "+stationObj.s_Name+" to "+newStationSize+" platforms",1);
	cDebug.ClearSigns();
	local allfail=false;
	local topLeftPlatform=stationObj.s_Train[TrainType.PLATFORM_LEFT];
	local topRightPlatform=stationObj.s_Train[TrainType.PLATFORM_RIGHT];
	local idxRightPlatform=cStationRail.GetPlatformIndex(topRightPlatform, useEntry);
	local idxLeftPlatform=cStationRail.GetPlatformIndex(topLeftPlatform, useEntry);
	local leftTileOf=cStationRail.GetRelativeTileLeft(stationObj.s_ID, useEntry);
	local rightTileOf=cStationRail.GetRelativeTileRight(stationObj.s_ID, useEntry);
	local forwardTileOf=cStationRail.GetRelativeTileForward(stationObj.s_ID, useEntry);
	local backwardTileOf=cStationRail.GetRelativeTileBackward(stationObj.s_ID, useEntry);
	local station_depth = stationObj.s_Train[TrainType.DEPTH];
	local direction = stationObj.GetRailStationDirection();
	local station_left = null;
	local station_right = null;
	local station_right = cBuilder.GetDirection(cStationRail.GetPlatformIndex(topRightPlatform, false), cStationRail.GetPlatformIndex(topRightPlatform, true));
	local station_left=cTileTools.GetLeftRelativeFromDirection(station_right);
	station_right=cTileTools.GetRightRelativeFromDirection(station_right);
	cDebug.PutSign(station_left+idxLeftPlatform,"LS");
	cDebug.PutSign(station_right+idxRightPlatform,"RS");
	// default: main station + exit in use = best place to build a platform : left side
	local plat_main=idxLeftPlatform;
	local plat_alt=idxRightPlatform;
	local pside=station_left;
	local platopenclose=cMisc.CheckBit(stationObj.s_Platforms.GetValue(topLeftPlatform), 1);
	if (useEntry) // main station + entry in use = best place : right side
			{
			pside=station_right;
			plat_main=idxRightPlatform;
			plat_alt=idxLeftPlatform;
			platopenclose=cMisc.CheckBit(stationObj.s_Platforms.GetValue(topRightPlatform), 0);
			}
	local	success = false;
	local displace=plat_main+pside;
	local areaclean = AITileList();
	if (platopenclose)
			{
			areaclean.AddRectangle(displace,displace+(backwardTileOf*(station_depth-1)));
			local canDestroy=cTileTools.IsAreaBuildable(areaclean);
			cDebug.showLogic(areaclean); // deb
			if (canDestroy)	{ cTileTools.ClearArea(areaclean); }
			cTileTools.TerraformLevelTiles(plat_main, displace+(backwardTileOf*(station_depth-1)));
			success=INSTANCE.main.builder.CreateAndBuildTrainStation(cStationRail.GetPlatformIndex(plat_main,true)+pside, direction, stationObj.s_ID);
			cDebug.PutSign(cStationRail.GetPlatformIndex(plat_main,true)+pside,"+");
			if (success)	{ foreach (tile, dummy in areaclean)	stationObj.StationClaimTile(tile, stationObj.s_ID); }
			}
	if (!success)
			{
			cError.IsCriticalError();
			allfail=cError.IsError();
			cError.ClearError();
			pside=station_right;
			if (useEntry)	{ pside=station_left; }
			displace=plat_alt+pside;
			local areaclean=AITileList();
			areaclean.AddRectangle(displace,displace+(backwardTileOf*(station_depth-1)));
			cDebug.showLogic(areaclean);
			if (cTileTools.IsAreaBuildable(areaclean))	{ cTileTools.ClearArea(areaclean); }
			cTileTools.TerraformLevelTiles(plat_alt, displace+(backwardTileOf*(station_depth-1)));
			success=INSTANCE.main.builder.CreateAndBuildTrainStation(cStationRail.GetPlatformIndex(plat_alt,true)+pside, direction, stationObj.s_ID);
			cDebug.PutSign(cStationRail.GetPlatformIndex(plat_alt,true)+pside,"+");
			if (success)	{ foreach (tile, dummy in areaclean)	stationObj.StationClaimTile(tile, stationObj.s_ID); }
			if (!success)
					{
					cError.IsCriticalError();
					if (cError.IsError() && allfail)
							{
							// We will never be able to build one more station platform in that station so
							DInfo("Critical failure, station couldn't be upgrade anymore!",1);
							stationObj.s_MaxSize=stationObj.s_Size;
							cError.RaiseError(); // Make sure caller will be aware of that failure
							return false;
							}
					else
							{
							DInfo("Temporary failure, station couldn't be upgrade for now",1);
							return false;
							}
					}
			}
	// if we are here, we endup successfuly add a new platform to the station
	return true;
	}

function cBuilder::RailStationPhaseDefineCrossing(stationObj, useEntry)
	{
	DInfo("--- Phase2: define entry/exit point",1);
	local leftTileOf=cStationRail.GetRelativeTileLeft(stationObj.s_ID, useEntry);
	local rightTileOf=cStationRail.GetRelativeTileRight(stationObj.s_ID, useEntry);
	local forwardTileOf=cStationRail.GetRelativeTileForward(stationObj.s_ID, useEntry);
	local backwardTileOf=cStationRail.GetRelativeTileBackward(stationObj.s_ID, useEntry);
	local towncheck=AITileList();
	local testcheck=AITileList();
	local workTile = stationObj.GetRailStationFrontTile(useEntry, stationObj.GetLocation());
	towncheck.AddRectangle(workTile, workTile+rightTileOf+(5*forwardTileOf));
	testcheck.AddList(towncheck);
	local success=false;
	if (cTileTools.IsAreaBuildable(towncheck))
			{
			testcheck.AddList(towncheck);
			testcheck.Valuate(AITile.IsStationTile); // protect station here
			testcheck.KeepValue(1);
			if (testcheck.IsEmpty())
					{
					// now look if we're not going too much in a town
					local neartown=AITile.GetClosestTown(workTile);
					local s_dst=AITown.GetDistanceManhattanToTile(neartown,workTile);
					local s_end=AITown.GetDistanceManhattanToTile(neartown,workTile+(4*forwardTileOf));
					if (s_dst < 10 && s_end < 10 && s_dst > s_end) // we must be going farer inside the town
							{
							DInfo("Giving up, we're probably going inside "+AITown.GetName(neartown),1);
							success=false;
							}
					else	{ success=true; }
					}
			else	{ success=false; } // station there
			}
	else	  // not everything is removable, still we might success to cross a road
			{
			testcheck.Valuate(AIRoad.IsRoadTile);
			testcheck.KeepValue(0);
			success=(testcheck.IsEmpty());
			}
	if (success)	{ foreach (tile, dummy in towncheck)	cTileTools.DemolishTile(tile); }
            else	{ DInfo("We gave up, too much troubles",1); return false; }
	DInfo("--- Phase3: define crossing point",1);
	local direction=stationObj.GetRailStationDirection();
	local railCross, railFront, railLeft, railRight, railUpLeft, railUpRight, rail = null;
	if (direction == AIRail.RAILTRACK_NW_SE)
			{
			railFront=AIRail.RAILTRACK_NW_SE;
			railCross=AIRail.RAILTRACK_NE_SW;
			if (useEntry)	  // going NW->SE
					{
					railLeft=AIRail.RAILTRACK_SW_SE;
					railRight=AIRail.RAILTRACK_NE_SE;
					railUpLeft=AIRail.RAILTRACK_NW_SW;
					railUpRight=AIRail.RAILTRACK_NW_NE;
					}
			else	  // going SE->NW
					{
					railLeft=AIRail.RAILTRACK_NW_NE;
					railRight=AIRail.RAILTRACK_NW_SW;
					railUpLeft=AIRail.RAILTRACK_NE_SE;
					railUpRight=AIRail.RAILTRACK_SW_SE;
					}
			}
	else	  // NE_SW
			{
			railFront=AIRail.RAILTRACK_NE_SW;
			railCross=AIRail.RAILTRACK_NW_SE;
			if (useEntry)	  // going NE->SW
					{
					railLeft=AIRail.RAILTRACK_NW_SW;
					railRight=AIRail.RAILTRACK_SW_SE;
					railUpLeft=AIRail.RAILTRACK_NW_NE;
					railUpRight=AIRail.RAILTRACK_NE_SE;
					}
			else	  // going SW->NE
					{
					railLeft=AIRail.RAILTRACK_NE_SE;
					railRight=AIRail.RAILTRACK_NW_NE;
					railUpLeft=AIRail.RAILTRACK_SW_SE;
					railUpRight=AIRail.RAILTRACK_NW_SW;
					}
			}
	rail=railLeft;
	DInfo("Building crossing point ",2);
	local j=1; local temptile=null; local crossing = -1;
	local se_crossing = -1;
	local sx_crossing = -1;
	local position = stationObj.GetLocation();
	cTileTools.DemolishTile(workTile);
	if (!AITile.IsBuildable(workTile))	{ return false; } // because we must have a tile in front of the station buildable for the signal
	do  {
		temptile=workTile+(j*forwardTileOf);
		cTileTools.TerraformLevelTiles(position,temptile);
		if (cTileTools.CanUseTile(temptile,stationObj.s_ID))
				{
				cTileTools.DemolishTile(temptile);
				success=INSTANCE.main.builder.DropRailHere(rail, temptile);
				}
		else	{ return false; }
		if (success)
				{
				if (useEntry)	{ se_crossing=temptile; crossing=se_crossing; }
				else	{ sx_crossing=temptile; crossing=sx_crossing; }
				INSTANCE.main.builder.DropRailHere(rail, temptile,true); // remove the test track
				}
		j++;
		}	while (j < 5 && !success);
	if (success)
			{
			stationObj.RailStationClaimTile(crossing, useEntry);
			if (useEntry)
					{
					stationObj.s_EntrySide[TrainSide.CROSSING]= se_crossing;
					DInfo("Entry crossing is now set to : "+se_crossing,2);
					}
			else
					{
					stationObj.s_ExitSide[TrainSide.CROSSING]= sx_crossing;
					DInfo("Exit crossing is now set to : "+sx_crossing,2);
					}
			cError.ClearError();
			return true;
			}
	return false;
	}

function cBuilder::RailStationPhaseBuildEntrance(stationObj, useEntry, tmptaker, road)
	{
	DInfo("--- Phase4: build entry&exit for IN/OUT",1);
	local in_str="";
	local direction=stationObj.GetRailStationDirection();
	local railCross, railFront, railLeft, railRight, railUpLeft, railUpRight, rail = null;
	if (direction == AIRail.RAILTRACK_NW_SE)
			{
			railFront=AIRail.RAILTRACK_NW_SE;
			railCross=AIRail.RAILTRACK_NE_SW;
			if (useEntry)	  // going NW->SE
					{
					railLeft=AIRail.RAILTRACK_SW_SE;
					railRight=AIRail.RAILTRACK_NE_SE;
					railUpLeft=AIRail.RAILTRACK_NW_SW;
					railUpRight=AIRail.RAILTRACK_NW_NE;
					}
			else	  // going SE->NW
					{
					railLeft=AIRail.RAILTRACK_NW_NE;
					railRight=AIRail.RAILTRACK_NW_SW;
					railUpLeft=AIRail.RAILTRACK_NE_SE;
					railUpRight=AIRail.RAILTRACK_SW_SE;
					}
			}
	else	  // NE_SW
			{
			railFront=AIRail.RAILTRACK_NE_SW;
			railCross=AIRail.RAILTRACK_NW_SE;
			if (useEntry)	  // going NE->SW
					{
					railLeft=AIRail.RAILTRACK_NW_SW;
					railRight=AIRail.RAILTRACK_SW_SE;
					railUpLeft=AIRail.RAILTRACK_NW_NE;
					railUpRight=AIRail.RAILTRACK_NE_SE;
					}
			else	  // going SW->NE
					{
					railLeft=AIRail.RAILTRACK_NE_SE;
					railRight=AIRail.RAILTRACK_NW_NE;
					railUpLeft=AIRail.RAILTRACK_SW_SE;
					railUpRight=AIRail.RAILTRACK_NW_SW;
					}
			}
	local leftTileOf=cStationRail.GetRelativeTileLeft(stationObj.s_ID, useEntry);
	local rightTileOf=cStationRail.GetRelativeTileRight(stationObj.s_ID, useEntry);
	local forwardTileOf=cStationRail.GetRelativeTileForward(stationObj.s_ID, useEntry);
	local backwardTileOf=cStationRail.GetRelativeTileBackward(stationObj.s_ID, useEntry);
	local rail=railFront;
	local j=1;
	local fromtile=-1;
	local sigtype=AIRail.SIGNALTYPE_PBS;
	local position = stationObj.GetLocation()
					 local sigdir=0;
	local se_IN=stationObj.GetRailStationIN(true);
	local se_OUT=stationObj.GetRailStationOUT(true);
	local sx_IN=stationObj.GetRailStationIN(false);
	local sx_OUT=stationObj.GetRailStationOUT(false);
	if (useEntry)
			{
			fromtile=stationObj.s_EntrySide[TrainSide.CROSSING];
			if (tmptaker)	{ if (se_IN!=-1)	{ tmptaker=false; } }
                    else	{ if (se_OUT!=-1)	{ tmptaker=true; } }
			if (tmptaker)	{ in_str="entry IN"; }
                    else	{ in_str="entry OUT"; fromtile+=rightTileOf; }
			}
	else
			{
			fromtile = stationObj.s_ExitSide[TrainSide.CROSSING];
			if (tmptaker)	{ if (sx_IN!=-1)	{ tmptaker=false; } }
                    else	{ if (sx_OUT!=-1)	{ tmptaker=true; } }
			if (tmptaker)	{ in_str="exit IN"; }
                    else	{ in_str="exit OUT"; fromtile+=rightTileOf; }
			}
	DInfo("Building "+in_str+" point",1);
	cBuilder.StationKillDepot(stationObj.s_EntrySide[TrainSide.DEPOT]);
	cBuilder.StationKillDepot(stationObj.s_ExitSide[TrainSide.DEPOT]);
	local endconnector=fromtile;
	local success=false;
	local building_maintrack=true;
	if (!road)	{ building_maintrack=true; }
        else	{ if (road.Primary_RailLink)	{ building_maintrack=false; }}
	do  {
		local temptile=fromtile+(j*forwardTileOf);
		for (local kb = 0; kb < 6; kb++)	{ cTileTools.DemolishTile(j+(kb*forwardTileOf)); }
		cTileTools.TerraformLevelTiles(position,temptile);
		if (cTileTools.CanUseTile(temptile,stationObj.s_ID))
				{
				success=INSTANCE.main.builder.DropRailHere(rail, temptile);
				}
		else	{ cError.RaiseError(); return false; }
		if (success)	{ stationObj.RailStationClaimTile(temptile,useEntry); }
                else	{ return false; }
		if (building_maintrack) // we're building IN/OUT point for the primary track
				{
				cDebug.PutSign(temptile+(1*forwardTileOf),"R1");
				cDebug.PutSign(temptile+(2*forwardTileOf),"R2");
				cTileTools.TerraformLevelTiles(position,temptile+(3*forwardTileOf));
				if (cTileTools.CanUseTile(temptile+(1*forwardTileOf), stationObj.s_ID))
						{
						success=INSTANCE.main.builder.DropRailHere(rail, temptile+(1*forwardTileOf));
						}
				else	{ cError.RaiseError(); return false; }
				if (success) { stationObj.RailStationClaimTile(temptile+(1*forwardTileOf),useEntry); }
				if (cTileTools.CanUseTile(temptile+(2*forwardTileOf), stationObj.s_ID))
						{
						success=INSTANCE.main.builder.DropRailHere(rail, temptile+(2*forwardTileOf));
						}
				else	{ cError.RaiseError(); return false; }
				if (success) { stationObj.RailStationClaimTile(temptile+(2*forwardTileOf),useEntry); }
				}
        if (tmptaker)	{ sigdir=fromtile+((j-1)*forwardTileOf); }
                else	{ sigdir=fromtile+((j+1)*forwardTileOf); }
        DInfo("Building "+in_str+" point signal",1);
        success=AIRail.BuildSignal(temptile, sigdir, sigtype);
        if (success)
				{
				if (AIRail.IsRailDepotTile(fromtile))	{ cBuilder.StationKillDepot(fromtile); }
				if (tmptaker)
						{
						if (useEntry)
								{
								se_IN = temptile;
								stationObj.s_EntrySide[TrainSide.IN]= se_IN;
								if (building_maintrack)	{ stationObj.s_EntrySide[TrainSide.IN_LINK]= se_IN+(3*forwardTileOf); } // link
                                                   else	{ stationObj.s_EntrySide[TrainSide.IN_LINK]= se_IN+forwardTileOf; }
								if (!cTileTools.DemolishTile(stationObj.s_EntrySide[TrainSide.IN_LINK]))
                                            { cError.RaiseError(); return false;}
                                }
                        else
								{
								sx_IN = fromtile + (j*forwardTileOf);
								stationObj.s_ExitSide[TrainSide.IN]= sx_IN;
								if (building_maintrack)	{ stationObj.s_ExitSide[TrainSide.IN_LINK]= sx_IN+(3*forwardTileOf); } // link
                                                   else	{ stationObj.s_ExitSide[TrainSide.IN_LINK]= sx_IN+forwardTileOf; }
								if (!cTileTools.DemolishTile(stationObj.s_ExitSide[TrainSide.IN_LINK]))
                                            { cError.RaiseError(); return false;}
                                }
                        }
                else
						{
						if (cTileTools.CanUseTile(fromtile,stationObj.s_ID) && cBuilder.DropRailHere(railUpLeft, fromtile))
										{    // it's crossing+rightTileOf
										stationObj.RailStationClaimTile(fromtile, useEntry);
										}
                        if (useEntry)
								{
								se_OUT = temptile;
								stationObj.s_EntrySide[TrainSide.OUT]= se_OUT;
								if (building_maintrack)	{ stationObj.s_EntrySide[TrainSide.OUT_LINK]= se_OUT+(3*forwardTileOf); } // link
                                                   else	{ stationObj.s_EntrySide[TrainSide.OUT_LINK]= se_OUT+(1*forwardTileOf); }
								if (!cTileTools.DemolishTile(stationObj.s_EntrySide[TrainSide.OUT_LINK]))
                                            { cError.RaiseError(); return false;}
								cBuilder.RailConnectorSolver(fromtile+forwardTileOf, fromtile, true);
								// this build rails at crossing point connecting to 1st rail of se_OUT
								stationObj.RailStationClaimTile(fromtile+forwardTileOf, useEntry);
								}
						else
								{
								sx_OUT = temptile;
								stationObj.s_ExitSide[TrainSide.OUT]= sx_OUT;
								if (building_maintrack)	{ stationObj.s_ExitSide[TrainSide.OUT_LINK]= sx_OUT+(3*forwardTileOf); } // link
                                                else	{ stationObj.s_ExitSide[TrainSide.OUT_LINK]= sx_OUT+(1*forwardTileOf); }
                                if (!cTileTools.DemolishTile(stationObj.s_ExitSide[TrainSide.OUT_LINK]))
											{ cError.RaiseError(); return false;}
                                cBuilder.RailConnectorSolver(fromtile, fromtile+forwardTileOf ,true);
								stationObj.RailStationClaimTile(fromtile+forwardTileOf, useEntry);
								}
                        }
                }
			j++;
			}   while (j < 4 && !success);
	return success;
	}

function cBuilder::RailStationPathfindAltTrack(roadObj)
	{
	DInfo("--- Phase6: building alternate track",1);
	local srcpos, srclink, dstpos, dstlink= null;
	local pval = cRoute.RouteRailGetPathfindingLine(roadObj.UID, false);
	if (pval == -1)	{ cError.RaiseError(); return false; }
	srclink = pval[0]; srcpos = pval[1]; dstlink=pval[2], dstpos=pval[3];
	DInfo("Calling rail pathfinder: srcpos="+srcpos+" srclink="+srclink+" dstpos="+dstpos+" dstlink="+dstlink,2);
	local result=cPathfinder.GetStatus([srclink,srcpos],[dstlink,dstpos], roadObj.TargetStation.s_ID, roadObj.Target_RailEntry);
	if (result != 2)
			{
			if (result == -1)
					{
					DError("We cannot build the alternate track for that station ",1);
					if (roadObj.Source_RailEntry)	{ cStationRail.RailStationCloseEntry(roadObj.SourceStation.s_ID); }
                                            else	{ cStationRail.RailStationCloseExit(roadObj.SourceStation.s_ID); }
					if (roadObj.Target_RailEntry)	{ cStationRail.RailStationCloseEntry(roadObj.TargetStation.s_ID); }
                                            else	{ cStationRail.RailStationCloseExit(roadObj.TargetStation.s_ID); }
					cPathfinder.CloseTask([srclink,srcpos],[dstlink,dstpos]);
					cError.RaiseError();
					return false;
					}
			else	{ cError.ClearError(); return false; } // lack money, still pathfinding... just wait to retry later nothing to do
			}
	else
			{
			roadObj.Secondary_RailLink=true;
			roadObj.Route_GroupNameSave();
			cPathfinder.CloseTask([srclink,srcpos],[dstlink,dstpos]);
			cBuilder.RailConnectorSolver(dstpos, dstpos+cTileTools.GetForwardRelativeFromDirection(cBuilder.GetDirection(dstlink, dstpos)), true);
			}
	return true;
	}

function cBuilder::RailStationPhaseSignalBuilder(road)
	{
	local success=true;
	DInfo("--- Phase7: building signals",1);
	cBanker.RaiseFundsBigTime();
	local vehlist=AIList();
	vehlist.AddList(AIVehicleList_Station(road.SourceStation.s_ID)); // because station can be in use by more than 1 route
	if (!vehlist.IsEmpty())
			{
			// erf, easy solve, not really nice, but this won't prevent our work on signal (that could stuck a train else)
			foreach (vehicle, dummy in vehlist)	cCarrier.VehicleSendToDepot(vehicle,DepotAction.SIGNALUPGRADE+road.SourceStation.s_ID);
			return false;
			}
	local srcpos, dstpos = null;
	if (road.Source_RailEntry)  { srcpos=road.SourceStation.s_EntrySide[TrainSide.IN]; }
                        else	{ srcpos=road.SourceStation.s_ExitSide[TrainSide.IN]; }
	if (road.Target_RailEntry)  { dstpos=road.TargetStation.s_EntrySide[TrainSide.OUT];	}
                        else	{ dstpos=road.TargetStation.s_ExitSide[TrainSide.OUT]; }
	if (!road.SourceStation.IsRailStationPrimarySignalBuilt())
			{
			DInfo("Building signals on primary track",2);
			if (cBuilder.SignalBuilder(srcpos, dstpos))
					{
					DInfo("...done",2);
					road.SourceStation.RailStationSetPrimarySignalBuilt();
					}
			else	{ DInfo("... not all signals were built",2); success=false; }
			}
	cDebug.ClearSigns();
	if (road.Source_RailEntry)  { srcpos=road.SourceStation.s_EntrySide[TrainSide.OUT];	}
                        else	{ srcpos=road.SourceStation.s_ExitSide[TrainSide.OUT]; }
	if (road.Target_RailEntry)	{ dstpos=road.TargetStation.s_EntrySide[TrainSide.IN]; }
                        else	{ dstpos=road.TargetStation.s_ExitSide[TrainSide.IN]; }
	if (!road.TargetStation.IsRailStationSecondarySignalBuilt())
			{
			DInfo("Building signals on secondary track",2);
			if (cBuilder.SignalBuilder(dstpos, srcpos))
					{
					DInfo("...done",2);
					road.TargetStation.RailStationSetSecondarySignalBuilt();
					}
			else	{ DInfo("... not all signals were built",2); success = false; }
			}
	foreach (vehicle, dummy in vehlist)
		{
		if (cCarrier.ToDepotList.HasItem(vehicle))	{ cCarrier.ToDepotList.RemoveItem(vehicle); }
		cCarrier.TrainExitDepot(vehicle);
		}
	return success;
	}

function cBuilder::RailStationPhaseBuildDepot(stationObj, useEntry)
	{
	DInfo("--- Phase8: build depot",1);
	// build depot for it,
	// in order to build cleaner rail we build the depot where the OUT line should goes, reserving space for it
	// we may need to build entry & exit depot at the same time, so 2 runs
	local se_IN=stationObj.GetRailStationIN(true);
	local se_OUT=stationObj.GetRailStationOUT(true);
	local sx_IN=stationObj.GetRailStationIN(false);
	local sx_OUT=stationObj.GetRailStationOUT(false);
	local leftTileOf=cStationRail.GetRelativeTileLeft(stationObj.s_ID, useEntry);
	local rightTileOf=cStationRail.GetRelativeTileRight(stationObj.s_ID, useEntry);
	local forwardTileOf=cStationRail.GetRelativeTileForward(stationObj.s_ID, useEntry);
	local backwardTileOf=cStationRail.GetRelativeTileBackward(stationObj.s_ID, useEntry);
	local se_crossing=stationObj.s_EntrySide[TrainSide.CROSSING];
	local sx_crossing=stationObj.s_ExitSide[TrainSide.CROSSING];
	local entry_build = (se_IN != -1 || se_OUT != -1);
	local exit_build = (sx_IN != -1 || sx_OUT != -1);
	local tile_OUT=null;
	local depot_checker=null;
	local removedepot=false;
	local crossing = null;
	local	success=false;
	local runTarget=cStationRail.RailStationGetRunnerTarget(stationObj.s_ID);
	for (local hh=0; hh < 2; hh++)
			{
			local stationside=(hh==0); // first run we work on entry, second one on exit
			if (stationside && !entry_build)	{ continue; }
			if (!stationside && !exit_build)	{ continue; }
			if (stationside)
					{
					crossing=se_crossing;
					tile_OUT=se_IN;
					depot_checker=stationObj.s_EntrySide[TrainSide.DEPOT];
					}
			else
					{
					crossing=sx_crossing;
					tile_OUT=sx_IN;
					depot_checker=stationObj.s_ExitSide[TrainSide.DEPOT];
					}
			if (!AIRail.IsRailDepotTile(depot_checker))	{ depot_checker=-1; }
                                                else	{ continue; }
			if (depot_checker == -1)
					{
					local topLeftPlatform=stationObj.s_Train[TrainType.PLATFORM_LEFT];
					local topRightPlatform=stationObj.s_Train[TrainType.PLATFORM_RIGHT];
					local topRL=cStationRail.GetRelativeCrossingPoint(topLeftPlatform, stationside);
					local topRR=cStationRail.GetRelativeCrossingPoint(topRightPlatform, stationside);
					local depotlocations, depotfront = null;
					if (AIGameSettings.GetValue("forbid_90_deg") == 0)
							{
							depotlocations=[topRL+forwardTileOf, topRR+forwardTileOf, topRL+rightTileOf, topRL+leftTileOf, topRR+rightTileOf, topRR+leftTileOf, topRL+leftTileOf+leftTileOf, topRR+rightTileOf+rightTileOf];
							depotfront=[topRL, topRL, topRR, topRR, topRL, topRR, topRL+leftTileOf, topRR+rightTileOf];
							}
					else
							{
							depotlocations=[topRL+leftTileOf, topRR+rightTileOf, topRL+leftTileOf+leftTileOf, topRR+rightTileOf+rightTileOf];
							depotfront=[topRL, topRR, topRL+leftTileOf, topRR+rightTileOf];
							}
					DInfo("Building station depot",1);
					for (local h=0; h < depotlocations.len(); h++)
							{
							cTileTools.TerraformLevelTiles(crossing,depotlocations[h]);
							cDebug.PutSign(depotlocations[h],"d");
							if (cTileTools.CanUseTile(depotlocations[h],stationObj.s_ID))
									{
									cTileTools.DemolishTile(depotlocations[h]);
									removedepot=AIRail.BuildRailDepot(depotlocations[h], depotfront[h]);
									}
							local depot_Front=AIRail.GetRailDepotFrontTile(depotlocations[h]);
							if (AIMap.IsValidTile(depot_Front))	{ success=cBuilder.RailConnectorSolver(depotlocations[h],depot_Front,true); }
							if (success)	{ success=cStation.IsDepot(depotlocations[h]); }
							if (success)
									{
									local runTarget=cStationRail.RailStationGetRunnerTarget(stationObj.s_ID);
									if (runTarget != -1) { success= cBuilder.RoadRunner(depotlocations[h], runTarget, AIVehicle.VT_RAIL); }
									}
							if (success)
									{
									DInfo("We built depot at "+depotlocations[h],1);
									stationObj.RailStationClaimTile(depotlocations[h],stationside);
									if (stationside)	{ stationObj.s_EntrySide[TrainSide.DEPOT]= depotlocations[h]; }
									else	{ stationObj.s_ExitSide[TrainSide.DEPOT]= depotlocations[h]; }
									success=true;
									break;
									}
							else	{ if (removedepot)	{ cTileTools.DemolishTile(depotlocations[h]); } }
							}
					}
			} // for loop hh=
	return success;
	}

function cBuilder::RailStationGrow(staID, useEntry, taker)
// make the station grow and build entry/exit...
// staID: stationID
// useEntry: true to add a train to its entry, false to add it at exit
// taker: true to add a taker train, false to add a dropper train
	{
	local thatstation=cStation.Load(staID);
	if (!thatstation)	{ return false; }
	local trainEntryTaker=thatstation.s_Train[TrainType.TET];
	local trainExitTaker=thatstation.s_Train[TrainType.TXT];
	local trainEntryDropper=thatstation.s_Train[TrainType.TED];
	local trainExitDropper=thatstation.s_Train[TrainType.TXD];
	local station_depth=thatstation.s_Train[TrainType.DEPTH];
	cBuilder.SetRailType(thatstation.s_SubType); // not to forget
	local success=false;
	local canAddTrain = true;
	local closeIt=false;
	local PlatformNeedUpdate = false;
	if (useEntry)
			{
			if (taker)	{ trainEntryTaker++; }
                else	{ trainEntryDropper++; }
			}
	else
			{
			if (taker)	{ trainExitTaker++; }
                else	{ trainExitDropper++; }
			}
	local trainEntryTotal = trainEntryDropper + trainEntryTaker;
	local trainExitTotal = trainExitDropper + trainExitTaker;
	local allTaker = trainExitTaker + trainEntryTaker;
	local allDropper = trainExitDropper + trainEntryDropper;
	local needTaker = allTaker;
	local needDropper = allDropper;
	if (allDropper > 2)	{ needDropper = (allDropper >> 1) + (allDropper % 2); }
	local newStationSize = needTaker + needDropper;
	if (allDropper+allTaker == 1)	{ newStationSize = 0; } // don't grow the station until we have a real train using it
	DInfo("STATION : "+thatstation.s_Name,1);
	DInfo("allTaker="+allTaker+" allDropper="+allDropper+" needTaker="+needTaker+" needDropper="+needDropper+" newsize="+newStationSize,1);
	// find route that use the station
	local road=null;
	if (thatstation.s_Owner.IsEmpty())
			{
			DWarn("Nobody claim that station yet",1);
			}
	else
			{
			local uidowner=thatstation.s_Train[TrainType.OWNER];
			road=cRoute.Load(uidowner);
			if (!road)	{ DWarn("The route owner ID "+uidowner+" is invalid",1); }
			else	{ DWarn("Station main owner "+uidowner,1); }
			}
	if (useEntry)	{ DInfo("Working on station entry", 1); }
            else	{ DInfo("Working on station exit", 1); }
	local cangrow = (thatstation.s_Size != thatstation.s_MaxSize);
    if (cangrow)	{ DInfo("Station can be upgrade",1); }
            else	{ DInfo("Station is at its maximum size",1); }
	local cmpsize = thatstation.s_Train[TrainType.GOODPLATFORM];
	if (newStationSize > cmpsize && cangrow)	{ thatstation.RailStationPhaseUpdate(); cmpsize = thatstation.s_Train[TrainType.GOODPLATFORM]; }
	DInfo("Station have "+cmpsize+" working platforms",1);
	if (newStationSize > cmpsize)
			{
			local success = false;
			if (cangrow)
					{
					success = cBuilder.RailStationPhaseGrowing(thatstation, newStationSize, useEntry);
					if (!success)	{ cError.RaiseError(); return false; }
					thatstation.DefinePlatform();
					PlatformNeedUpdate = true;
					}
			else	{ canAddTrain=false; }
			}
	if ((useEntry && thatstation.s_EntrySide[TrainSide.CROSSING] == -1) || (!useEntry && thatstation.s_ExitSide[TrainSide.CROSSING] == -1))
			{
			if (!cBuilder.RailStationPhaseDefineCrossing(thatstation, useEntry))
					{
					if (useEntry)	{ thatstation.RailStationCloseEntry(); }
                            else	{ thatstation.RailStationCloseExit(); }
					if (!thatstation.IsRailStationEntryOpen() && !thatstation.IsRailStationExitOpen())	{ cError.RaiseError(); }
					return false;
					}
			else	{ PlatformNeedUpdate=true; }
			}
	local needIN = 0; local needOUT = 0;
	local se_IN=thatstation.GetRailStationIN(true);
	local se_OUT=thatstation.GetRailStationOUT(true);
	local sx_IN=thatstation.GetRailStationIN(false);
	local sx_OUT=thatstation.GetRailStationOUT(false);
	if (se_IN == -1 && trainEntryTaker > 0)	{ needIN++; }
	if (sx_IN == -1 && trainExitTaker > 0)	{ needIN++; }
	if (se_OUT == -1 && trainEntryDropper > 0) { needOUT++; }
	if (sx_OUT == -1 && trainExitDropper > 0) { needOUT++; }
	if ((se_IN == -1 || se_OUT == -1) && trainEntryTotal > 1)	{ needIN++; needOUT++ }
	if ((sx_IN == -1 || sx_OUT == -1) && trainExitTotal > 1)	{ needIN++; needOUT++ }
	local primary = true;
	if (!road)	{ primary = false; }
	if (needIN || needOUT > 0)
			{
			cBuilder.RailStationPhaseBuildEntrance(thatstation, useEntry, taker, road);
			se_IN=thatstation.GetRailStationIN(true);
			se_OUT=thatstation.GetRailStationOUT(true);
			sx_IN=thatstation.GetRailStationIN(false);
			sx_OUT=thatstation.GetRailStationOUT(false);
			PlatformNeedUpdate=true;
			}
	DInfo("se_IN="+se_IN+" se_OUT="+se_OUT+" sx_IN="+sx_IN+" sx_OUT="+sx_OUT+" canAddTrain="+canAddTrain,2);
	local result=true;
	if (cMisc.ValidInstance(road) && road.Secondary_RailLink == false && road.SourceStation.s_ID != thatstation.s_ID && (trainEntryTotal >1 || trainExitTotal > 1))
			{
			if (road.Target_RailEntry)	{ result = thatstation.IsRailStationEntryOpen(); }
                                else	{ result = thatstation.IsRailStationExitOpen(); }
			if (result) // don't test if we knows it's dead already
					{
					result = cBuilder.RailStationPathfindAltTrack(road);
					if (!result)	{ canAddTrain=false; }
					}
			else	{ PlatformNeedUpdate=true; } // give the destination station an update chance
			}
	if (PlatformNeedUpdate && cangrow) { thatstation.RailStationPhaseUpdate(); }
	if (cMisc.ValidInstance(road) && road.GroupID != null && road.Secondary_RailLink && (trainEntryTotal > 2 || trainExitTotal > 2) && (!road.SourceStation.IsRailStationPrimarySignalBuilt() || !road.TargetStation.IsRailStationSecondarySignalBuilt()))
			{
			// build signals
			if (!cBuilder.RailStationPhaseSignalBuilder(road))	{ canAddTrain=false; }
			}
	local r_depot = null;
	if (useEntry)	{ r_depot = AIRail.IsRailDepotTile(thatstation.s_EntrySide[TrainSide.DEPOT]); }
            else	{ r_depot = AIRail.IsRailDepotTile(thatstation.s_ExitSide[TrainSide.DEPOT]); }
	if (!r_depot)	{ cBuilder.RailStationPhaseBuildDepot(thatstation, useEntry); }
	if (newStationSize > thatstation.s_Train[TrainType.GOODPLATFORM])	{ DInfo("station refuse more trains",2); return false; }
	return canAddTrain;
	}
