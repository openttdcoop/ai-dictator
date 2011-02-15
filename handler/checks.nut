// this file handle events we check 1 time per month
// all operations here a cBuilder even the file itself do handling work
// operations here are time earter

function cBuilder::CheckAirportUpgrade()
{
root.chemin.VirtualAirNetworkUpdate();
DInfo("Checking if any airport need to be upgrade...",2);
local newairporttype=root.builder.GetAirportType();
for (local i=0; i < root.chemin.RListGetSize(); i++)
	{
	local road=root.chemin.RListGetItem(i);
	if (road.ROUTE.kind!=AIVehicle.VT_AIR)	continue;
	if (!road.ROUTE.isServed) continue;
	local stationtype=0;
	local src=root.chemin.GListGetItem(road.ROUTE.src_station);
	local dst=root.chemin.GListGetItem(road.ROUTE.dst_station);
	local upgrade=false;
	if (src.STATION.type < newairporttype)
		{
		DInfo("stationt type="+src.STATION.type+" newairporttype="+newairporttype,2);
		root.builder.AirportNeedUpgrade(i,true);
		upgrade=true;
		}
	if (dst.STATION.type < newairporttype)
		{
		DInfo("stationt type="+src.STATION.type+" newairporttype="+newairporttype,2);
		root.builder.AirportNeedUpgrade(i,false);
		upgrade=true;
		}
	if (upgrade) break;
	}
}

function cBuilder::MonthlyChecks()
{
local month=AIDate.GetMonth(AIDate.GetCurrentDate());
if (root.OneMonth!=month)	{ root.OneMonth=month; root.SixMonth++;}
		else	return false;
DInfo("Montly checks run...",1);
root.builder.CheckAirportUpgrade();
if (root.SixMonth == 6)	root.builder.HalfYearChecks();
}

function cBuilder::HalfYearChecks()
{
root.SixMonth=0;
root.TwelveMonth++;
DInfo("Half year checks run...",1);
if (root.TwelveMonth == 2)	root.builder.YearlyChecks();
root.builddelay=false;
}

function cBuilder::YearlyChecks()
{
root.TwelveMonth=0;
DInfo("Yearly checks run...",1);
for (local j=0; j < root.chemin.RListGetSize(); j++)
	{
	local road=root.chemin.RListGetItem(j);
	if (!road.ROUTE.isServed) continue;
	if (road.ROUTE.kind != AIVehicle.VT_ROAD)	continue;
	local test=root.builder.CheckRoadHealth(j);
	DInfo("Health check return "+test,1);
	}
}

function cBuilder::AirportStationsBalancing()
// Look at airport for busy loading and if busy & some waiting force the aircraft to move on
{
local airID=AIStationList(AIStation.STATION_AIRPORT);
foreach (i, dummy in airID)
	{
	local vehlist=root.carrier.VehicleListBusyAtStation(i);
	local count=vehlist.Count();
	//DInfo("Airport "+AIStation.GetName(i)+" is busy with "+vehlist.Count(),2);
	if (vehlist.Count() < 2)	continue;
	local passcargo=root.carrier.GetPassengerCargo(); // i don't care mail
	local cargowaiting=AIStation.GetCargoWaiting(i,passcargo);
	if (cargowaiting > 100)
		{
		DInfo("Airport "+AIStation.GetName(i)+" is busy but can handle it : "+cargowaiting,2); 
		continue;
		}
	foreach (i, dummy in vehlist)
		{
		local percent=root.carrier.VehicleGetLoadingPercent(i);
		//DInfo("Vehicle "+i+" load="+percent,2);
		if (percent > 4 && percent < 90)
			{ // we have a vehicle with more than 20% cargo in it
			root.carrier.VehicleOrderSkipCurrent(i);
			DInfo("Forcing vehicle "+AIVehicle.GetName(i)+" to get out of the station with "+i+"% load",1);
			break;
			}
		}
	}
}

function cBuilder::QuickTasks()
// functions list here should be only function with a vital thing to do
{
root.builder.AirportStationsBalancing();
}
