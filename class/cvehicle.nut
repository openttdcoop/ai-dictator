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

class cCarrier extends cClass
{
static	AirportTypeLimit=[6, 10, 2, 16, 30, 5, 6, 60, 8]; // limit per airport type
static	IDX_HELPER = 512;			// use to create an uniq ID (also use to set handicap value)
static	AIR_NET_CONNECTOR=2500;		// town is add to air network when it reach that value population
static	ToDepotList=AIList();		// list vehicle going to depot, value=DepotAction for trains we also add wagons need
static	vehicle_database={};		// database for vehicles
static	VirtualAirRoute=[];		// the air network destinations list
static 	OldVehicle=1095;			// age left we consider a vehicle is old
static	MaintenancePool=[];		// list of vehicles that need maintenance
static	function GetVehicleObject(vehicleID)
		{
		return vehicleID in cCarrier.vehicle_database ? cCarrier.vehicle_database[vehicleID] : null;
		}

	rail_max		=null;	// maximum trains vehicle a station can handle
	road_max		=null;	// maximum a road station can upgarde (max: 6)
	road_upgrade	=null;	// maximum vehicle a road station can support before upgarde itself
	air_max		=null;	// maximum aircraft a station can handle
	airnet_max		=null;	// maximum aircraft on a network
	airnet_count	=null;	// current number of aircrafts running the network
	water_max		=null;	// maximum ships a station can handle
	road_max_onroute	=null;	// maximum road vehicle on a route
	train_length	=null;	// maximum length for train/rail station
	vehnextprice	=null;	// we just use that to upgrade vehicle
	do_profit		=null;	// Record each vehicle profits
	warTreasure		=null;	// total current value of nearly all our road vehicle
	highcostAircraft	=null;	// the highest cost for an aircraft we need
	highcostTrain	=null;	// the highest cost for a train
	speed_MaxTrain	=null;	// maximum speed a train could do
	speed_MaxRoad	=null;	// maximum speed a road vehicle could do
	running_vehicle	=null;	// number of vehicle per type we own

	constructor()
		{
		this.ClassName="cCarrier";
		rail_max		= 0;
		road_max		= 0;
		road_upgrade	= 0;
		air_max		= 0;
		airnet_max		= 0;
		airnet_count	= 0;
		water_max		= 0;
		road_max_onroute	= 0;
		train_length	= 0;
		vehnextprice	= 0;
		do_profit		= AIList();
		warTreasure		= 0;
		highcostAircraft	= 0;
		highcostTrain	= 0;
		speed_MaxTrain	= 0;
		speed_MaxRoad	= 0;
		running_vehicle	= [0,0,0,0];
		}
}

function cCarrier::GetVehicleName(veh)
// return a vehicle string with the vehicle infos
{
	if (!AIVehicle.IsValidVehicle(veh))	return "<Invalid vehicle> #"+veh;
	local toret="#"+veh+" "+AIVehicle.GetName(veh)+"("+cEngine.GetName(AIVehicle.GetEngineType(veh))+")";
	return toret;
}

function cCarrier::GetVehicleCount(vehtype)
// return number of vehicle we own
// return 0 on error
{
	return INSTANCE.main.carrier.running_vehicle[vehtype];
}

function cCarrier::VehicleCountUpdate()
// update the vehicle counter for vehtype
{
	local allvehlist=AIVehicleList();
	allvehlist.Valuate(AIVehicle.GetVehicleType);
	local ro=0, tr=0, sh=0, ai=0;
	foreach (veh, vtype in allvehlist)
		{
		switch (vtype)
			{
			case AIVehicle.VT_RAIL:
				tr++;
			break;
			case AIVehicle.VT_ROAD:
				ro++;
			break;
			case AIVehicle.VT_WATER:
				sh++;
			break;
			case AIVehicle.VT_AIR:
				ai++;
			break;
			}
		}
	running_vehicle[AIVehicle.VT_RAIL]=tr;
	running_vehicle[AIVehicle.VT_ROAD]=ro;
	running_vehicle[AIVehicle.VT_WATER]=sh;
	running_vehicle[AIVehicle.VT_AIR]=ai;
}


