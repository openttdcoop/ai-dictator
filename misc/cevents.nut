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
			// in case someone disapears, nothing, we will catch problems for sure
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
			cJobs.MarkIndustryDead(industry); // remove any job ref
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
			cCarrier.CheckOneVehicleOfGroup(true);
		break;
		case AIEvent.ET_ENGINE_AVAILABLE:
			event = AIEventEngineAvailable.Convert(event);
			local engine = event.GetEngineID();
			DInfo("New engine available: " + cEngine.GetEngineName(engine),0);
			cCarrier.CheckOneVehicleOfGroup(true);
		break;
		case AIEvent.ET_VEHICLE_CRASHED:
			local vehicle = null;
			event = AIEventVehicleCrashed.Convert(event);
			vehicle = event.GetVehicleID();
			DInfo("Vehicle "+cCarrier.GetVehicleName(vehicle)+" has crashed!!!",0);
		break;
		case AIEvent.ET_VEHICLE_WAITING_IN_DEPOT:
			cCarrier.VehicleIsWaitingInDepot();
		break;
		case AIEvent.ET_VEHICLE_LOST:
			event = AIEventVehicleLost.Convert(event);
			local vehicle = event.GetVehicleID();
			if (!AIVehicle.IsValidVehicle(vehicle)) break;
			DInfo(cCarrier.GetVehicleName(vehicle) + " is lost, not a good news",0);
			cCarrier.VehicleMaintenance_Orders(vehicle);
			local rcheck = cCarrier.VehicleFindRouteIndex(vehicle);
			cBuilder.RouteIsDamage(rcheck);
		break;
		case AIEvent.ET_VEHICLE_UNPROFITABLE:
			event = AIEventVehicleUnprofitable.Convert(event);
			local vehicle = event.GetVehicleID();
			if (!AIVehicle.IsValidVehicle(vehicle)) break;
			DInfo(cCarrier.GetVehicleName(vehicle) + " is not profitable, sending it to depot",0);
			cBuilder.RouteIsDamage(cCarrier.VehicleFindRouteIndex(vehicle));
			cRoute.CheckRouteProfit(cCarrier.VehicleFindRouteIndex(vehicle));
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
                vehlist.KeepAboveValue(0);
				foreach (vehicle, profit in vehlist)
					{ // sell all non profitable vehicles
					cCarrier.VehicleSendToDepot(vehicle, DepotAction.SELL);
					}
				if (!vehlist.IsEmpty()) { INSTANCE.buildDelay = 6; }
				}
		break;
		case	AIEvent.ET_SUBSIDY_OFFER_EXPIRED:
			local action = AIEventSubsidyOfferExpired.Convert(event);
			cJobs.SubsidyOff(action.GetSubsidyID());
		break;
		case	AIEvent.ET_SUBSIDY_AWARDED:
			local action = AIEventSubsidyAwarded.Convert(event);
			cJobs.SubsidyOff(action.GetSubsidyID());
		break;
		case	AIEvent.ET_SUBSIDY_EXPIRED:
			local action = AIEventSubsidyExpired.Convert(event);
			cJobs.SubsidyOff(action.GetSubsidyID());
		break;
		case	AIEvent.ET_SUBSIDY_OFFER:
			local action = AIEventSubsidyOffer.Convert(event);
			cJobs.SubsidyOn(action.GetSubsidyID());
		break;
		}

	} // while
} // function

