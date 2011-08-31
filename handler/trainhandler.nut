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
class cTrain
// that class handle train, not the train engine, but the vehicle made with train engine + wagon engines
{
static	vehicledatabase = {};
static	function GetTrainObject(vehicleID)
		{
		return vehicleID in cTrain.vehicledatabase ? cTrain.vehicledatabase[vehicleID] : null;
		}

	vehicleID		= null;	// id of the train (it's vehicleID)
	numberLocos		= null;	// number of locos
	numberWagons	= null;	// number of wagons, and wagon!=loco
	length		= null;	// length of the train
	srcStationID	= null;	// the source stationID that train is using
	dstStationID	= null;	// the destination stationID that train is using
	src_useEntry	= null;	// source station is use by its entry=true, exit=false;
	dst_useEntry	= null;	// destination station is use by its entry=true, exit=false;
	full			= null; 	// set to true if train cannot have more wagons attach to it
	
	constructor()
		{
		vehicleID		= null;
		numberLocos		= 0;
		numberWagons	= 0;
		length		= 0;
		srcStationID	= null;
		dstStationID	= null;
		src_useEntry	= null;
		dst_useEntry	= null;
		full			= false;
		}
}

function cTrain::Save()
// Save the train in the database
	{
	if (AIVehicle.GetVehicleType(this.vehicleID)!=AIVehicle.VT_RAIL)	{ DError("Only supporting train",2,"cTrain::Save"); return; }
	if (this.vehicleID in cTrain.vehicledatabase)	return;
	cTrain.vehicledatabase[this.vehicleID] <- this;
	DInfo("Adding "+AIVehicle.GetName(this.vehicleID)+" to cTrain database",2,"cTrain::Save");
	}

function cTrain::Load(tID)
	{
	local tobj=cTrain();
	local inbase=(tID in cTrain.vehicledatase);
	tobj.vehicleID=tID;
	if (AIVehicle.IsValidVehicle(tID))
		{
		if (inbase)	tobj=cTrain.GetTrainObject(tID);
			else	tobj.Save();
		}
	else	{ cTrain.DeleteVehicle(tID); DInfo("Removing an invalid vehicle "+tID+" from cTrain database",2,"cTrain::Load"); }
	return tobj;
	}

function cTrain::Update(vehID)
// Update a train infos for length, locos, wagons
	{
	local train=cTrain.Load(vehID);
	DInfo("Updating vehicle properties for "+AIVehicle.GetName(vehID),2,"cTrain::Update");
	train.numberWagons=cCarrier.GetNumberOfWagons(vehID);
	train.numberLocos=cCarrier.GetNumberOfLocos(vehID);
	train.length=AIVehicle.GetLength(vehID);
	}

function cTrain::SetStation(vehID, stationID, isSource, useEntry)
// set the station proprieties of a train
	{
	local train=cTrain.Load(vehID);
	if (isSource)
		{
		train.src_useEntry=useEntry;
		train.srcStationID=stationID;
		}
	else	{
		train.dst_useEntry=useEntry;
		train.dstStationID=stationID;
		}
	}

function cTrain::DeleteVehicle(vehID)
// delete a vehicle from the database
	{
	if (vehID in cTrain.vehicledatase)	delete cTrain.vehicledatase[vehID];
	}

function cTrain::IsFull(vehID)
// return the cTrain.full value
	{
	local train=cTrain.Load(vehID);
	return train.IsFull;
	}

function cTrain::SetFull(vehID, fullv)
// set the isFull value of a train
	{
	local train=cTrain.Load(vehID);
	train.full=fullv;
	}
