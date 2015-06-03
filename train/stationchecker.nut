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

/*
function cBuilder::SignalSwapper(stationID, useEntry)
	{
    local pstype = AIRail.SIGNALTYPE_NORMAL+AIRail.SIGNALTYPE_TWOWAY;
    local nstype = AIRail.SIGNALTYPE_PBS;
    local fwd = cStationRail.GetRelativeTileForward(stationID, useEntry); // one tile backward
    local bck = cStationRail.GetRelativeTileBackward(stationID, useEntry); // one tile forward
    local success=true;
	local station = cStation.Load(stationID);
	if (!station)	return false;
    local MainTrack = station.s_EntrySide[TrainSide.IN];
    local AltTrack = station.s_EntrySide[TrainSide.OUT];
    if (!useEntry)	{
					MainTrack = station.s_ExitSide[TrainSide.IN];
					AltTrack = station.s_ExitSide[TrainSide.OUT];
					}
    if (AIRail.GetSignalType(MainTrack, MainTrack+bck) == pstype)
		{
		cError.ForceAction(AIRail.RemoveSignal, MainTrack, MainTrack+bck);
		success = cError.ForceAction(AIRail.BuildSignal, MainTrack, MainTrack+bck, nstype);
		}
    if (success && AIRail.GetSignalType(AltTrack, AltTrack+fwd) == pstype)
		{
		cError.ForceAction(AIRail.RemoveSignal, AltTrack, AltTrack+fwd);
		success = cError.ForceAction(AIRail.BuildSignal, AltTrack, AltTrack+fwd, nstype);
		}
	return success;
	}
*/
