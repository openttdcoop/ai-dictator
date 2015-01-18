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

class cTrain extends cClass
	// that class handle train, not the train engine, but the vehicle made with train engine + wagon engines
	{
		static	vehicledatabase = {};
		function GetTrainObject(vehicleID)
			{
			return vehicleID in cTrain.vehicledatabase ? cTrain.vehicledatabase[vehicleID] : null;
			}

		vehicleID		= null;	// id of the train (it's vehicleID)
		numberLocos		= null;	// number of locos
		numberWagons	= null;	// number of wagons, and wagon!=loco
		length		    = null;	// length of the train
		srcStationID	= null;	// the source stationID that train is using
		dstStationID	= null;	// the destination stationID that train is using
		src_useEntry	= null;	// source station is use by its entry=true, exit=false;
		dst_useEntry	= null;	// destination station is use by its entry=true, exit=false;
		stationbit		= null;	// bit0 source station, bit1=destination station :: set to 1 train load or 0 train unload at station
		wagonPrice		= null;	// price to buy a new wagon for that train
		lastdepotvisit	= null;	// record last time that train was in a depot
		extraengine		= null;	// true if we have two engines

		constructor()
			{
			vehicleID		= null;
			numberLocos		= 0;
			numberWagons	= 0;
			length		    = 0;
			srcStationID	= null;
			dstStationID	= null;
			src_useEntry	= null;
			dst_useEntry	= null;
			stationbit		= 0;
			wagonPrice		= 0;
			lastdepotvisit	= 0;
			extraengine		= false;
			this.ClassName  = "cTrain";
			}
	}

function cTrain::Save()
// Save the train in the database
	{
	if (AIVehicle.GetVehicleType(this.vehicleID)!=AIVehicle.VT_RAIL)	{ DError("Only supporting train",2); return; }
	if (this.vehicleID in cTrain.vehicledatabase)	{ return; }
	cTrain.vehicledatabase[this.vehicleID] <- this;
	DInfo("Adding "+cCarrier.GetVehicleName(this.vehicleID)+" to cTrain database",2);
	}

function cTrain::Load(tID)
	{
	local tobj=cTrain();
	local inbase=(tID in cTrain.vehicledatabase);
	tobj.vehicleID=tID;
	if (AIVehicle.IsValidVehicle(tID))
			{
			if (inbase)	{ tobj=cTrain.GetTrainObject(tID); }
                else	{ tobj.Save(); }
			}
	else	{ cTrain.DeleteVehicle(tID); }
	return tobj;
	}

function cTrain::TrainSetStation(vehID, stationID, isSource, useEntry, taker)
// set the station properties of a train
	{
	local train=cTrain.Load(vehID);
	if (isSource)
			{
			train.src_useEntry=useEntry;
			train.srcStationID=stationID;
			if (taker)	{ train.stationbit=cMisc.SetBit(train.stationbit, 0); }
			}
	else
			{
			train.dst_useEntry=useEntry;
			train.dstStationID=stationID;
			if (taker)	{ train.stationbit=cMisc.SetBit(train.stationbit, 1); }
			}
	DInfo("Train "+cCarrier.GetVehicleName(vehID)+" assign to station "+cStation.GetStationName(stationID),2);
	}

function cTrain::DeleteVehicle(vehID)
// delete a vehicle from the database
	{
	if (vehID in cTrain.vehicledatabase)
			{
			local atrain=null;
			if (AIVehicle.IsValidVehicle(vehID))	{ atrain=cTrain.Load(vehID); } // if invalid cTrain.Load call DeleteVehicle ->infinite loop
                                            else	{ atrain=cTrain(); atrain.vehicleID=vehID; }
			DInfo("Removing train "+cCarrier.GetVehicleName(vehID)+" from database",2);
			local taker = cMisc.CheckBit(atrain.stationbit, 0);
			if (atrain.srcStationID != null)	{ cStationRail.StationRemoveTrain(taker, atrain.src_useEntry, atrain.srcStationID); }
			taker = cMisc.CheckBit(atrain.stationbit, 1);
			if (atrain.dstStationID != null)	{ cStationRail.StationRemoveTrain(taker, atrain.dst_useEntry, atrain.dstStationID); }
			delete cTrain.vehicledatabase[vehID];
			}
	}

function cTrain::IsFull(vehID)
// return true if train couldn't get more wagons
{
	local train = cTrain.Load(vehID);
	local station = cStation.Load(train.srcStationID);
	if (!station)	return false;
	local stationLen = station.s_Train[TrainType.DEPTH]*16;
	local veh_len = AIVehicle.GetLength(vehID);
	return (veh_len >= stationLen);
}

function cTrain::SetWagonPrice(vehID, wprice)
// Set the price for a wagon
	{
	local train=cTrain.Load(vehID);
	train.wagonPrice=wprice;
	}

function cTrain::GetWagonPrice(vehID)
// Return the price to buy a new wagon
	{
	local train=cTrain.Load(vehID);
	return train.wagonPrice;
	}

function cTrain::IsEmpty(vehID)
// return true if that vehicle have 0 wagons or 0 locos
	{
	local train=cTrain.Load(vehID);
	if (train.numberLocos==0)	{ return true; }
	if (train.numberWagons==0)	{ return true; }
	return false;
	}

function cTrain::CanModifyTrain(vehID)
// return true if we can call that vehicle to modify it, else false
	{
	local train=cTrain.Load(vehID);
	local now=AIDate.GetCurrentDate();
	return (now-train.lastdepotvisit>60);
	}

function cTrain::SetDepotVisit(vehID)
// set the last time a train was in a depot
	{
	local train=cTrain.Load(vehID);
	train.lastdepotvisit=AIDate.GetCurrentDate();
	}

