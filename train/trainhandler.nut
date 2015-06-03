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

		vehicleID		= null;	// id of the train (it's vehicleID)
		numberLocos		= null;	// number of locos
		numberWagons	= null;	// number of wagons, and wagon!=loco
		length		    = null;	// length of the train
		srcStationID	= null;	// the source stationID that train is using
		dstStationID	= null;	// the destination stationID that train is using
		wagonPrice		= null;	// price to buy a new wagon for that train
		lastdepotvisit	= null;	// record last time that train was in a depot

		constructor()
			{
			vehicleID		= null;
			numberLocos		= 0;
			numberWagons	= 0;
			length		    = 0;
			srcStationID	= null;
			dstStationID	= null;
			wagonPrice		= 0;
			lastdepotvisit	= 0;
			this.ClassName  = "cTrain";
			}
	}

function cTrain::Save()
// Save the train in the database
	{
	if (this.vehicleID in cTrain.vehicledatabase)	{ return; }
	this.numberLocos = cEngineLib.VehicleGetNumberOfLocomotive(this.vehicleID);
	this.numberWagons = cEngineLib.VehicleGetNumberOfWagons(this.vehicleID);
	this.length = AIVehicle.GetLength(this.vehicleID);
	cTrain.vehicledatabase[this.vehicleID] <- this;
	DInfo("Adding " + cCarrier.GetVehicleName(this.vehicleID) + " to cTrain database", 2);
	}

function cTrain::Load(tID)
	{
	local tobj = cTrain();
	local inbase = (tID in cTrain.vehicledatabase);
	tobj.vehicleID = tID;
	if (AIVehicle.IsValidVehicle(tID))
			{
			if (inbase)	{ tobj = cTrain.vehicledatabase[tID]; }
                else	{ tobj.Save(); }
			}
	else	return -1;
	return tobj;
	}

function cTrain::TrainSetStation(vehID, stationID, isSource)
// set the station properties of a train
	{
	local train = cTrain.Load(vehID);
	if (train == -1)	return;
	if (isSource)	train.srcStationID = stationID;
			else	train.dstStationID = stationID;
	DInfo("Train " + cCarrier.GetVehicleName(vehID) + " assign to station " + cStation.GetStationName(stationID), 2);
	}

function cTrain::DeleteTrain(vehID)
// delete a vehicle from the database
	{
	local train = cTrain.Load(vehID);
	if (train == -1)	return;
	DInfo("Removing train " + cCarrier.GetVehicleName(vehID) + " from database", 2);
	if (train.srcStationID != null) cStation.UpdateVehicleCount(train.srcStationID);
	if (train.dstStationID != null)	cStation.UpdateVehicleCount(train.dstStationID);
	delete cTrain.vehicledatabase[vehID];
	}

function cTrain::TrainUpdate(vehID)
{
	local train = cTrain.Load(vehID);
	if (train == -1)	return;
	train.numberLocos = cEngineLib.VehicleGetNumberOfLocomotive(train.vehicleID);
	train.numberWagons = cEngineLib.VehicleGetNumberOfWagons(train.vehicleID);
	train.length = AIVehicle.GetLength(train.vehicleID);
	local wagon = cEngineLib.VehicleGetRandomWagon(train.vehicleID);
    train.wagonPrice = cEngine.GetPrice(AIVehicle.GetWagonEngineType(train.vehicleID, wagon));
}

function cTrain::IsFull(vehID)
// return true if train couldn't get more wagons
{
  // 	local guess_locos = cEngineLib.VehicleLackPower(vehID);
   //	if (guess_locos)	return false; // force a train that lack power to be seen as non full so it have a chance to get call for change (adding the extra engine need)
	local train = cTrain.Load(vehID);
	if (train == -1)	return;
	local station = cStation.Load(train.srcStationID);
	if (!station)	return false;
	local stationLen = station.s_Depth * 16;
	if (train.length >= stationLen)	return true; // well just make it quick if we could
	local one_more = cEngineLib.GetLength(AIVehicle.GetWagonEngineType(vehID, cEngineLib.VehicleGetRandomWagon(vehID)));
	// we look if with one more wagon the train gets too big, else a not full station size train but without enough for another wagon would return a non full status
	return ((one_more + train.length) >= stationLen);
}

function cTrain::GetWagonPrice(vehID)
// Return the price to buy a new wagon
	{
	local train = cTrain.Load(vehID);
	if (train == -1)	return 0;
	return train.wagonPrice;
	}

function cTrain::IsEmpty(vehID)
// return true if that vehicle have 0 wagons or 0 locos
	{
	local train = cTrain.Load(vehID);
	if (train == -1)	return false;
	if (train.numberLocos == 0)	{ return true; }
	if (train.numberWagons == 0)	{ return true; }
	return false;
	}

function cTrain::CanModifyTrain(vehID)
// return true if we can call that vehicle to modify it, else false
	{
	return true; //FIXME: keep or remove that
	local train = cTrain.Load(vehID);
	local now = AIDate.GetCurrentDate();
	return (now - train.lastdepotvisit > 60);
	}

function cTrain::SetDepotVisit(vehID)
// set the last time a train was in a depot
	{
	local train = cTrain.Load(vehID);
	if (train == -1)	return;
	train.lastdepotvisit = AIDate.GetCurrentDate();
	}

function cTrain::IsTrainStuckAtSignal(vehID)
{
	if (!AIVehicle.IsValidVehicle(vehID))	return false;
	if (AIVehicle.GetVehicleType(vehID) != AIVehicle.VT_RAIL)	return false;
	if (AIVehicle.GetState(vehID) != AIVehicle.VS_RUNNING)	return false;
	if (AIVehicle.GetCurrentSpeed(vehID) != 0)	return false;
	local voisin = [AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, 1)];
	local position = AIVehicle.GetLocation(vehID);
	local firenext = false;
    foreach (voisins in voisin)	if (AIRail.GetSignalType(position, position + voisins) != AIRail.SIGNALTYPE_NONE)	{ firenext = true; break; }
    if (!firenext)	foreach (voisins in voisin)	if (AIRail.GetSignalType(position + voisins, position) != AIRail.SIGNALTYPE_NONE)	{ firenext = true; break; }
    return firenext;
}


