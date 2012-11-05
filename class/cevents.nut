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


class cEvents extends cClass
{
	eventList = null;
	event	= null;

	constructor() {
		this.ClassName="cEvents";
		eventList = [];
		event=0;
	}
}

function cEvents::HandleEvents()
{
while (AIEventController.IsEventWaiting())
	{
	local event=AIEventController.GetNextEvent();
	local eventType=event.GetEventType();
	DInfo("New event incoming: "+eventType,2);
	switch (eventType)
		{
		case AIEvent.ET_TOWN_FOUNDED:
			event = AIEventTownFounded.Convert(event);
			local town = event.GetTownID();
			DInfo("New town found ! "+AITown.GetName(town),0);
			cProcess.AddNewProcess(town, true);
			cJobs.AddNewIndustryOrTown(town, true); // instant add, we need that info asap
		break;
		case AIEvent.ET_COMPANY_BANKRUPT:
			print("fixme event bankrupt"); //foreach (uid, dummy in cRoute.RouteIndexer)	INSTANCE.main.builder.RouteIsDamage(uid);
			// in case someone disapears, set a main.route.health check for all main.route.
		break;
		case AIEvent.ET_INDUSTRY_OPEN:
			event = AIEventIndustryOpen.Convert(event);
			local industry = event.GetIndustryID();
			DInfo("New industry "+AIIndustry.GetName(industry),0);
			cProcess.AddNewProcess(industry, false)
			cJobs.RawJob_Add(industry); // queue it to be process later

		break;
		case AIEvent.ET_INDUSTRY_CLOSE:
			event = AIEventIndustryClose.Convert(event);
			local industry = event.GetIndustryID();
			DInfo("Industry "+AIIndustry.GetName(industry)+" is closing !",0);
			cJobs.DeleteIndustry(industry); // remove any job ref
		break;
		case AIEvent.ET_COMPANY_NEW:
			event = AIEventCompanyNew.Convert(event);
			local company = AICompany.GetName(event.GetCompanyID());
			DInfo("Welcome "+company,0);
		break;
		case AIEvent.ET_ENGINE_PREVIEW:
			event = AIEventEnginePreview.Convert(event);
			if (event.AcceptPreview()) 
				{
				DInfo("New engine available for preview: " + event.GetName(),0);
				}
		print("fix me event engine_preview"); //INSTANCE.main.vehicle.CheckOneVehicleOfGroup(true);
		break;
		case AIEvent.ET_ENGINE_AVAILABLE:
			event = AIEventEngineAvailable.Convert(event);
			local engine = event.GetEngineID();
			DInfo("New engine available: " + cEngine.GetName(engine),0);
		print("fixme new engine event"); //INSTANCE.main.vehicle.CheckOneVehicleOfGroup(true);
		break;
		case AIEvent.ET_VEHICLE_CRASHED:
			local vehicle = null;
			event = AIEventVehicleCrashed.Convert(event);
			vehicle = event.GetVehicleID();
			DInfo("Vehicle "+INSTANCE.main.vehicle.VehicleGetName(vehicle)+" has crashed!!!",0);
			if (!AIVehicle.IsValidVehicle(vehicle)) break;
			local engineID=AIVehicle.GetEngineType(vehicle);
			INSTANCE.main.vehicle.vehnextprice=0; // Reset on crash in case it was the vehicle we wish upgrade
			if (engineID != null)	cEngine.RabbitUnset(engineID);
			INSTANCE.main.vehicle.VehicleSellAndDestroyRoute(vehicle); // try to see if the crash vehicle was going to remove a route
		break;
		case AIEvent.ET_VEHICLE_WAITING_IN_DEPOT:
			INSTANCE.main.vehicle.VehicleIsWaitingInDepot();
		break;
		case AIEvent.ET_VEHICLE_LOST:
			event = AIEventVehicleLost.Convert(event);
			local vehicle = event.GetVehicleID();
			print("fixme event vehicle_lost"); //DInfo(cCarrier.VehicleGetName(vehicle) + " is lost, not a good news",0);
			if (!AIVehicle.IsValidVehicle(vehicle)) return;
			//INSTANCE.main.vehicle.VehicleMaintenance_Orders(vehicle);
			//local rcheck=INSTANCE.main.vehicle.VehicleFindRouteIndex(vehicle);
			//INSTANCE.main.builder.RouteIsDamage(rcheck);
		break;
		case AIEvent.ET_VEHICLE_UNPROFITABLE:
			event = AIEventVehicleUnprofitable.Convert(event);
			local vehicle = event.GetVehicleID();
			DInfo(cCarrier.VehicleGetName(vehicle) + " is not profitable, sending it to depot",0);
			if (!AIVehicle.IsValidVehicle(vehicle)) return;
			INSTANCE.main.vehicle.VehicleMaintenance_Orders(vehicle);
			INSTANCE.main.main.builder.RouteIsDamage(INSTANCE.main.vehicle.VehicleFindRouteIndex(vehicle));
			INSTANCE.main.vehicle.VehicleSendToDepot(vehicle, DepotAction.SELL);
		break;
		case AIEvent.ET_COMPANY_IN_TROUBLE:
			event = AIEventCompanyInTrouble.Convert(event);
			local company = event.GetCompanyID();
			local action="";
			local info="";
			local isme=AICompany.IsMine(company);
			if (isme)	info="My company";
				else	info=AICompany.GetName(company);
			info+=" is in trouble. I'll take action";
			DInfo(info+action,0);
			if (isme)
				{
				local vehlist=AIVehicleList();
				vehlist.Valuate(AIVehicle.GetProfitThisYear);
				local vehsell=AIList();
				vehsell.AddList(vehlist);
				vehsell.RemoveAboveValue(0);
				vehlist.KeepAboveValue(0);
				vehlist.Valuate(AIVehicle.GetCurrentValue);
				vehlist.Sort(AIList.SORT_BY_VALUE,false);
				foreach (vehicle, profit in vehsell)
					{ // sell all non profitable vehicles
					INSTANCE.main.vehicle.VehicleSendToDepot(vehicle, DepotAction.SELL);
					}
				foreach (vehicle, value in vehlist)
					{
					do	{
						INSTANCE.main.vehicle.VehicleSendToDepot(vehicle, DepotAction.SELL);
						AIController.Sleep(150);
						INSTANCE.main.vehicle.VehicleIsWaitingInDepot();
						} while (AICompany.GetBankBalance(company) < 0 && vehlist.Count() > 2);
					}
				}
		break;
		}
	
	} // while
} // function
