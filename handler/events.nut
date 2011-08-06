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


class cEvents
{
	eventList = null;
	event	= null;

	constructor() {
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
/*		case AIEvent.AI_ET_TOWN_FOUNDED:
			event = AIEventTownFounded(event);
			local town = event.GetTownID();
			INSTANCE.jobs.AddNewIndustryOrTown(industry, true);
		break;
*/
		case AIEvent.AI_ET_COMPANY_BANKRUPT:
			foreach (uid, dummy in cRoute.RouteIndexer)	INSTANCE.builder.RouteIsDamage(uid);
			// in case someone disapears, set a route health check for all routes
		break;
		case AIEvent.AI_ET_INDUSTRY_OPEN:
			event = AIEventIndustryOpen.Convert(event);
			local industry = event.GetIndustryID();
			//INSTANCE.jobs.AddNewIndustryOrTown(industry, false);
			cJobs.RawJobAdd(industry,false);
			DInfo("New industry "+AIIndustry.GetName(industry),0);
		break;
		case AIEvent.AI_ET_INDUSTRY_CLOSE:
			event = AIEventIndustryClose.Convert(event);
			local industry = event.GetIndustryID();
			DInfo("Industry "+AIIndustry.GetName(industry)+" is closing !",0);
			cJobs.RawJobDelete(industry, false)
		break;
		case AIEvent.AI_ET_COMPANY_NEW:
			event = AIEventCompanyNew.Convert(event);
			local company = AICompany.GetName(event.GetCompanyID());
			DInfo("Welcome "+company,0);
		break;
		case AIEvent.AI_ET_ENGINE_PREVIEW:
			event = AIEventEnginePreview.Convert(event);
			if (event.AcceptPreview()) 
				{
				DInfo("New engine available for preview: " + event.GetName(),0);
				INSTANCE.carrier.TopEngineList.Clear(); // reset top vehicle list
				}
		break;
		case AIEvent.AI_ET_ENGINE_AVAILABLE:
			event = AIEventEngineAvailable.Convert(event);
			local engine = event.GetEngineID();
			DInfo("New engine available: " + AIEngine.GetName(engine),0);
			INSTANCE.carrier.TopEngineList.Clear(); // reset top vehicle list
		break;
		case AIEvent.AI_ET_VEHICLE_CRASHED:
			local vehicle = null;
			event = AIEventVehicleCrashed.Convert(event);
			vehicle = event.GetVehicleID();
			DInfo("Vehicle "+INSTANCE.carrier.VehicleGetFormatString(vehicle)+" has crashed. I suspect everyone ! Some heads will fall !!!",0);
			if (!AIVehicle.IsValidVehicle(vehicle)) break;
			DInfo("Vehicle state: " + AIVehicle.GetState(vehicle),1);
			INSTANCE.carrier.vehnextprice=0; // Reset on crash in case it was the vehicle we wish upgrade
		break;
		case AIEvent.AI_ET_VEHICLE_WAITING_IN_DEPOT:
			INSTANCE.carrier.VehicleIsWaitingInDepot();
		break;
		case AIEvent.AI_ET_VEHICLE_LOST:
			event = AIEventVehicleLost.Convert(event);
			local vehicle = event.GetVehicleID();
			DInfo(AIVehicle.GetName(vehicle) + " is lost, I don't know what to do with that ! Sending it to depot");
			INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
		break;
		case AIEvent.AI_ET_VEHICLE_UNPROFITABLE:
			event = AIEventVehicleUnprofitable.Convert(event);
			local vehicle = event.GetVehicleID();
			DInfo(AIVehicle.GetName(vehicle) + " is not profitable, sending it to depot");
			INSTANCE.builder.RouteIsDamage(INSTANCE.carrier.VehicleFindRouteIndex(vehicle));
			INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
		break;
		case AIEvent.AI_ET_COMPANY_IN_TROUBLE:
			event = AIEventCompanyInTrouble.Convert(event);
			local company = event.GetCompanyID();
			local action="";
			local info="";
			local isme=AICompany.IsMine(company);
			if (isme)	info="My company";
				else	info=AICompany.GetName(company);
			info+=" is in trouble. ";
			switch (INSTANCE.fairlevel)
				{
				case	0:
					if (isme)	action="I'm sure someone will give me some money";
						else	action="Oh no, it's so sad !";
				break;
				case	1:
					if (isme)	action="I will call Bernard Madoff for more hints.";
						else	action="Sell his actions now !";
				break;
				case	2:
					if (isme)	action="Fools rebels, you will never win !";
						else	action="They have refuse to put my son as director, now pay !";
				break;
				}
			DInfo(info+action);
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
					INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
					}
				foreach (vehicle, value in vehlist)
					{
					do	{
						INSTANCE.carrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
						AIController.Sleep(150);
						INSTANCE.carrier.VehicleIsWaitingInDepot();
						} while (AICompany.GetBankBalance(company) < 0 && vehlist.Count() > 2);
					}
				}
		break;
		}
	
	} // while
} // function

