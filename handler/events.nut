class cEvents
{
	root = null;
	todepotlist = null;
	eventList = null;
	event	= null;

	constructor(that) {
		root = that;
		todepotlist = AIList();
		eventList = [];
		event=0;
	}
}

function cEvents::GetEvents()
// Get the event, we will handle it when we can
{
while (AIEventController.IsEventWaiting())
	{
	local newevent=AIEventController.GetNextEvent();
	root.eventManager.AddEvent(newevent);
	}
DInfo("Event queue: "+eventList.len(),1);
}

function cEvents::AddEvent(newevent)
{
local evlist=[];
evlist.push(newevent); // so new event is first
foreach (i, dummy in eventList) // now add our eventList to its queue
	{
	evlist.push(dummy);
	}
eventList=evlist; // now we got all events, fresher at first pos, older at end
}

function cEvents::HandleEvents()
{
while (AIEventController.IsEventWaiting())
{
local event=AIEventController.GetNextEvent();
local eventType=event.GetEventType();
// TODO: watch out for eventType=even[0].GetEventType()
DInfo("New event incoming: "+eventType,2);
switch (eventType)
	{
	case AIEvent.AI_ET_INDUSTRY_OPEN:
		event = AIEventIndustryOpen.Convert(event);
		local industry = event.GetIndustryID();
		root.chemin.RouteCreateIndustry(industry);
	break;
	case AIEvent.AI_ET_INDUSTRY_CLOSE:
		//event = AIEventIndustryClose.Convert(event);
		//local industry = event.GetIndustryID();
		// For now i don't handle industry closing, cChemin::RouteArrayPurge is handling it already
		// May change because RouteArrayPurge only handle starting industry not ending ones.
	break;
	case AIEvent.AI_ET_COMPANY_NEW:
		event = AIEventCompanyNew.Convert(event);
		local company = AICompany.GetName(event.GetCompanyID());
		DInfo("Welcome "+company,0);
		if ("SimpleAI" in company)
			{
			DInfo("I love "+company+"! DictatorAI is a fork of SimpleAI.",0);
			}
	break;
	case AIEvent.AI_ET_ENGINE_PREVIEW:
		event = AIEventEnginePreview.Convert(event);
		if (event.AcceptPreview()) DInfo("New engine available for preview: " + event.GetName(),0);
	break;
	case AIEvent.AI_ET_ENGINE_AVAILABLE:
		event = AIEventEngineAvailable.Convert(event);
		local engine = event.GetEngineID();
		DInfo("New engine available: " + AIEngine.GetName(engine),0);
	break;
	case AIEvent.AI_ET_VEHICLE_CRASHED:
		local vehicle = null;
		event = AIEventVehicleCrashed.Convert(event);
		vehicle = event.GetVehicleID();
		DInfo("One of my vehicle has crashed.",0);
		if (!AIVehicle.IsValidVehicle(vehicle)) break;
		DInfo("Vehicle state: " + AIVehicle.GetState(vehicle),1);
		if (AIVehicle.GetState(vehicle) != AIVehicle.VS_CRASHED) break;
		local group = AIVehicle.GetGroupID(vehicle);
		local routeidx = root.carrier.VehicleFindRouteIndex(vehicle);
		local homedepot = root.builder.GetDepotID(routeidx,true);
		local newveh=null;
		root.bank.RaiseFundsBigTime();
		if (!root.carrier.vehsaveactive)	newveh=AIVehicle.CloneVehicle(homedepot, vehicle, true);
			else	{ DInfo("Cannot cloned any vehicle while we're in save vehicle mode. Say goodbye to that vehicle, sorry",0); break; }

		if (AIVehicle.IsValidVehicle(newveh))
			{
			AIVehicle.StartStopVehicle(newveh);
			DInfo("Cloned the crashed vehicle.",0);
			}
	break;
	case AIEvent.AI_ET_VEHICLE_WAITING_IN_DEPOT:
		root.carrier.VehicleIsWaitingInDepot();
	break;
	case AIEvent.AI_ET_VEHICLE_LOST:
		event = AIEventVehicleLost.Convert(event);
		local vehicle = event.GetVehicleID();
		DInfo(AIVehicle.GetName(vehicle) + " is lost, I don't know what to do with that ! Sending it to depot");
		root.carrier.VehicleToDepotAndSell(vehicle);
	break;
	case AIEvent.AI_ET_VEHICLE_UNPROFITABLE:
		event = AIEventVehicleUnprofitable.Convert(event);
		local vehicle = event.GetVehicleID();
		DInfo(AIVehicle.GetName(vehicle) + " is not profitable, sending it to depot");
		root.carrier.VehicleToDepotAndSell(vehicle);
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
		switch (root.fairlevel)
			{
			case	0:
				if (isme)	action="I'm sure someone will give me some money";
						action="Oh no, it's so sad !";
			break;
			case	1:
				if (isme)	action="I will call Bernard Madoff for more hints.";
					else	action="Sell those actions now !";
			break;
			case	2:
				if (isme)	action="Fools rebels, you will never win !";
						action="They have refuse to put my son as director, now pay !";
			break;
			}
		DInfo(info+action);
		if (isme)
			{
			local vehlist=AIVehicleList();
			vehlist.Valuate(AIVehicle.GetProfitThisYear);
			local vehsell=AIAbstractList();
			vehsell.AddList(vehlist);
			vehsell.RemoveAboveValue(0);
			vehlist.KeepAboveValue(0);
			vehlist.Valuate(AIVehicle.GetCurrentValue);
			vehlist.Sort(AIList.SORT_BY_VALUE,false);
			foreach (vehicle, profit in vehsell)
				{ // sell all non profitable vehicles
				root.carrier.VehicleToDepotAndSell(vehicle);
				}
			foreach (vehicle, value in vehlist)
				{
				do	{
					root.carrier.VehicleToDepotAndSell(vehicle);
					AIController.Sleep(400);
					} while (AICompany.GetBankBalance(company) < 0 && vehlist.Count() > 2);
				}
			}
	break;
	default :
		DInfo("Discarding event "+eventType,2);
	}

} // while
} // function

/*AI_ET_INVALID = 0,
  AI_ET_TEST,
  AI_ET_SUBSIDY_OFFER,
  AI_ET_SUBSIDY_OFFER_EXPIRED,
  AI_ET_SUBSIDY_AWARDED,
  AI_ET_SUBSIDY_EXPIRED,
  AI_ET_ENGINE_PREVIEW,
  AI_ET_COMPANY_NEW,
  AI_ET_COMPANY_IN_TROUBLE,
  AI_ET_COMPANY_ASK_MERGER,
  AI_ET_COMPANY_MERGER,
  AI_ET_COMPANY_BANKRUPT,
  AI_ET_VEHICLE_CRASHED,
  AI_ET_VEHICLE_LOST,
  AI_ET_VEHICLE_WAITING_IN_DEPOT,
  AI_ET_VEHICLE_UNPROFITABLE,
  AI_ET_INDUSTRY_OPEN,
  AI_ET_INDUSTRY_CLOSE,
  AI_ET_ENGINE_AVAILABLE,
  AI_ET_STATION_FIRST_VEHICLE,
  AI_ET_DISASTER_ZEPPELINER_CRASHED,
  AI_ET_DISASTER_ZEPPELINER_CLEARED 
*/
/*
		switch (eventtype) {
			case AIEvent.AI_ET_SUBSIDY_AWARDED:
				event = AIEventSubsidyAwarded.Convert(event);
				local sub = event.GetSubsidyID();
				if (AICompany.IsMine(AISubsidy.GetAwardedTo(sub))) {
					local srcname = null, dstname = null;
					if (AISubsidy.GetSourceType(sub) == AISubsidy.SPT_TOWN) {
						srcname = AITown.GetName(AISubsidy.GetSourceIndex(sub));
					} else {
						srcname = AIIndustry.GetName(AISubsidy.GetSourceIndex(sub));
					}
					if (AISubsidy.GetDestinationType(sub) == AISubsidy.SPT_TOWN) {
						dstname = AITown.GetName(AISubsidy.GetDestinationIndex(sub));
					} else {
						dstname = AIIndustry.GetName(AISubsidy.GetDestinationIndex(sub));
					}
					
					local crgname = AICargo.GetCargoLabel(AISubsidy.GetCargoType(sub));
					AILog.Info("I got the subsidy: " + crgname + " from " + srcname + " to " + dstname);
				}
			break;

			case AIEvent.AI_ET_COMPANY_IN_TROUBLE:
				event = AIEventCompanyInTrouble.Convert(event);
				local company = event.GetCompanyID();
				if (AICompany.IsMine(company)) AILog.Error("I'm in trouble, I don't know what to do!");
			break;


			case AIEvent.AI_ET_INDUSTRY_OPEN:
				event = AIEventIndustryOpen.Convert(event);
				local industry = event.GetIndustryID();
				AILog.Info("New industry: " + AIIndustry.GetName(industry));
				workClass.Create(industry);
			break;

			case AIEvent.AI_ET_INDUSTRY_CLOSE:
				event = AIEventIndustryClose.Convert(event);
				local industry = event.GetIndustryID();
				if (!AIIndustry.IsValidIndustry(industry)) break;
				AILog.Info("Closing industry: " + AIIndustry.GetName(industry));
				// TODO: Handle it. 
			break;
		}
	}
}

function cManager::CheckRoutes() {
	foreach (idx, route in root.routes) {
		switch (route.vehtype) {
			case AIVehicle.VT_ROAD:
				local vehicles = AIVehicleList_Group(route.group);

				// Empty route 
				if (vehicles.Count() == 0) {
					AILog.Info("Removing empty route: " + AIStation.GetName(route.stasrc) + " - " + AIStation.GetName(route.stadst));
					route.vehtype = null;
					root.groups.RemoveItem(route.group);
					AIGroup.DeleteGroup(route.group);
					root.serviced.RemoveItem(route.src * 256 + route.crg);
					cBuilder.DeleteRoadStation(route.stasrc);
					cBuilder.DeleteRoadStation(route.stadst);
					break;
				}

				// Adding vehicles 
				if ((vehicles.Count() < route.maxvehicles) && (AIStation.GetCargoWaiting(route.stasrc, route.crg) > 150)) {
					vehicles.Valuate(AIVehicle.GetProfitThisYear);
					if (vehicles.GetValue(vehicles.Begin()) <= 0) break;
					vehicles.Valuate(AIVehicle.GetAge);
					vehicles.Sort(AIAbstractList.SORT_BY_VALUE, true);
					if (vehicles.GetValue(vehicles.Begin()) > 90) {
						local engine = cBuilder.ChooseRoadVeh(route.crg);
						if (engine == null) break;
						if (cBanker.GetMaxBankBalance() > (AICompany.GetLoanInterval() + AIEngine.GetPrice(engine))) {
							if (cManager.AddVehicle(route, vehicles.Begin(), engine, null)) {
								AILog.Info("Added road vehicle to route: " + AIStation.GetName(route.stasrc) + " - " + AIStation.GetName(route.stadst));
							}
						}
					}
				}

				// Replacing old vehicles 
				vehicles.Valuate(AIVehicle.GetAgeLeft);
				vehicles.KeepBelowValue(0);
				foreach (vehicle, dummy in vehicles) {
					if (todepotlist.HasItem(vehicle)) continue;
					local engine = cBuilder.ChooseRoadVeh(route.crg);
					if (engine == null) continue;
					if (cBanker.GetMaxBankBalance() > (AICompany.GetLoanInterval() + AIEngine.GetPrice(engine))) {
						AILog.Info(AIVehicle.GetName(vehicle) + " is getting old, sending it to the depot...");
						if (!AIVehicle.SendVehicleToDepot(vehicle)) {
							AIVehicle.ReverseVehicle(vehicle);
							AIController.Sleep(75);
							if (!AIVehicle.SendVehicleToDepot(vehicle)) break;
						}
						todepotlist.AddItem(vehicle, 2);
					}
				}

				// Checking vehicles in depot 
				vehicles = AIVehicleList_Group(route.group);
				vehicles.Valuate(AIVehicle.IsStoppedInDepot);
				vehicles.KeepValue(1);
				foreach (vehicle, dummy in vehicles) {
					if (AIVehicle.GetProfitThisYear(vehicle) != 0 || AIVehicle.GetProfitLastYear(vehicle) != 0 || AIVehicle.GetAge(vehicle) < 60) continue;
					if (todepotlist.HasItem(vehicle)) {
						todepotlist.RemoveItem(vehicle);
						AIVehicle.StartStopVehicle(vehicle);
					} else {
						AILog.Warning("Sold " + AIVehicle.GetName(vehicle) + ", as it has been sitting in the depot for ages.");
						AIVehicle.SellVehicle(vehicle);
					}
				}

			break;
			case AIVehicle.VT_RAIL:
				local vehicles = AIVehicleList_Group(route.group);

				// Empty route 
				if (vehicles.Count() == 0) {
					AILog.Info("Removing empty route: " + AIStation.GetName(route.stasrc) + " - " + AIStation.GetName(route.stadst));
					route.vehtype = null;
					root.groups.RemoveItem(route.group);
					AIGroup.DeleteGroup(route.group);
					root.serviced.RemoveItem(route.src * 256 + route.crg);
					local builder = cBuilder(root);
					builder.DeleteRailStation(route.stasrc);
					builder.DeleteRailStation(route.stadst);
					builder = null;
					break;
				}

				// Electrifying rails 
				if ((AIRail.TrainHasPowerOnRail(route.railtype, AIRail.GetCurrentRailType())) && (route.railtype != AIRail.GetCurrentRailType())) {
					if (cBanker.GetMaxBankBalance() > (30000 * cBanker.GetInflationRate() / 100)) {
							if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < (30000 * cBanker.GetInflationRate() / 100)) {
								cBanker.SetMinimumBankBalance(30000 * cBanker.GetInflationRate() / 100);
							}
							AILog.Info("Electrifying rail line: " + AIStation.GetName(route.stasrc) + " - " + AIStation.GetName(route.stadst));
							local builder = cBuilder(root);
							route.railtype = AIRail.GetCurrentRailType();
							builder.ElectrifyRail(AIStation.GetLocation(route.stasrc));
							builder = null;
					}
				}

				// Adding trains 
				if (vehicles.Count() == 1 && route.maxvehicles == 2) {
					if (AIVehicle.GetProfitThisYear(vehicles.Begin()) <= 0) break;
					if (AIStation.GetCargoWaiting(route.stasrc, route.crg) > 150) {
						local railtype = AIRail.GetCurrentRailType();
						AIRail.SetCurrentRailType(route.railtype);
						local wagon = cBuilder.ChooseWagon(route.crg);
						if (wagon == null) {
							AIRail.SetCurrentRailType(railtype);
							return false;
						}
						local engine = cBuilder.ChooseTrainEngine();
						if (engine == null) {
							AIRail.SetCurrentRailType(railtype);
							return false;
						}
						if (cBanker.GetMaxBankBalance() > (AICompany.GetLoanInterval() + AIEngine.GetPrice(engine) + 4 * AIEngine.GetPrice(wagon))) {
							if (cManager.AddVehicle(route, vehicles.Begin(), engine, wagon)) {
								AILog.Info("Added train to route: " + AIStation.GetName(route.stasrc) + " - " + AIStation.GetName(route.stadst));
							}
						}
						AIRail.SetCurrentRailType(railtype);
					}
				}

				// Replacing old vehicles 
				vehicles.Valuate(AIVehicle.GetAgeLeft);
				vehicles.KeepBelowValue(0);
				foreach (vehicle, dummy in vehicles) {
					if (todepotlist.HasItem(vehicle)) continue;
					local railtype = AIRail.GetCurrentRailType();
					AIRail.SetCurrentRailType(route.railtype);
					local engine = cBuilder.ChooseTrainEngine();
					local wagon = cBuilder.ChooseWagon(route.crg);
					AIRail.SetCurrentRailType(railtype);
					if (engine == null || wagon == null) continue;
					if (cBanker.GetMaxBankBalance() > (AICompany.GetLoanInterval() + AIEngine.GetPrice(engine) + 5*AIEngine.GetPrice(wagon))) {
						AILog.Info(AIVehicle.GetName(vehicle) + " is getting old, sending it to the depot...");
						if (!AIVehicle.SendVehicleToDepot(vehicle)) {
							AIVehicle.ReverseVehicle(vehicle);
							AIController.Sleep(75);
							if (!AIVehicle.SendVehicleToDepot(vehicle)) break;
						}
						todepotlist.AddItem(vehicle, 2);
					}
				}

				// Lengthening short trains 
				vehicles = AIVehicleList_Group(route.group);
				local platform = cBuilder.GetRailStationPlatformLength(route.stasrc);
				foreach (train, dummy in vehicles) {
					if (todepotlist.HasItem(train)) continue;
					if (AIVehicle.GetLength(train) < platform * 16) {
						local railtype = AIRail.GetCurrentRailType();
						AIRail.SetCurrentRailType(route.railtype);
						local wagon = cBuilder.ChooseWagon(route.crg);
						if (wagon == null) break;
						if (cBanker.GetMaxBankBalance() > (AICompany.GetLoanInterval() + 5*AIEngine.GetPrice(wagon))) {
							AILog.Info(AIVehicle.GetName(train) + " is short, sending it to the depot to attach more wagons...");
							if (!AIVehicle.SendVehicleToDepot(train)) {
								AIVehicle.ReverseVehicle(train);
								AIController.Sleep(75);
								if (!AIVehicle.SendVehicleToDepot(train)) break;
							}
							todepotlist.AddItem(train, 3);
						}
						AIRail.SetCurrentRailType(railtype);
					}
				}

				// Checking vehicles in depot 
				vehicles = AIVehicleList_Group(route.group);
				vehicles.Valuate(AIVehicle.IsStoppedInDepot);
				vehicles.KeepValue(1);
				foreach (vehicle, dummy in vehicles) {
					if (AIVehicle.GetProfitThisYear(vehicle) != 0 || AIVehicle.GetProfitLastYear(vehicle) != 0 || AIVehicle.GetAge(vehicle) < 60) continue;
					if (todepotlist.HasItem(vehicle)) {
						todepotlist.RemoveItem(vehicle);
						AIVehicle.StartStopVehicle(vehicle);
					} else {
						AILog.Warning("Sold " + AIVehicle.GetName(vehicle) + ", as it has been sitting in the depot for ages.");
						AIVehicle.SellWagonChain(vehicle, 0);
					}
				}

			break;
		}
	}
	cManager.CheckDefaultGroup();
}

function cManager::AddVehicle(route, mainvehicle, engine, wagon)
{
	local builder = cBuilder(root);
	builder.crg = route.crg;
	builder.stasrc = route.stasrc;
	builder.stadst = route.stadst;
	builder.group = route.group;
	builder.homedepot = route.homedepot;
	if (route.vehtype == AIVehicle.VT_RAIL)	{
		local trains = AIVehicleList();
		trains.Valuate(AIVehicle.GetVehicleType);
		trains.KeepValue(AIVehicle.VT_RAIL);
		if (trains.Count() + 1 > AIGameSettings.GetValue("vehicle.max_trains")) return false;
		local length = cBuilder.GetRailStationPlatformLength(builder.stasrc) * 2 - 2;
		if (builder.BuildAndStartTrains(1, length, engine, wagon, mainvehicle)) {
			builder = null;
			return true;
		} else {
			builder = null;
			return false;
		}
	} else {
		local roadvehicles = AIVehicleList();
		roadvehicles.Valuate(AIVehicle.GetVehicleType);
		roadvehicles.KeepValue(AIVehicle.VT_ROAD);
		if (roadvehicles.Count() + 1 > AIGameSettings.GetValue("vehicle.max_roadveh")) return false;
		if (builder.BuildAndStartVehicles(engine, 1, mainvehicle)) {
			builder = null;
			return true;
		} else {
			builder = null;
			return false;
		}
	}
}

function cManager::ReplaceVehicle(vehicle)
{
	local group = AIVehicle.GetGroupID(vehicle);
	local route = root.routes[root.groups.GetValue(group)];
	local engine = null;
	local wagon = null;
	local railtype = AIRail.GetCurrentRailType();
	if (AIVehicle.GetVehicleType(vehicle) == AIVehicle.VT_RAIL) {
		AIRail.SetCurrentRailType(route.railtype);
		engine = cBuilder.ChooseTrainEngine();
		wagon = cBuilder.ChooseWagon(route.crg);
	} else {
		engine = cBuilder.ChooseRoadVeh(route.crg);
	}
	local vehicles = AIVehicleList_Group(group);
	local ordervehicle = null;
	foreach (nextveh, dummy in vehicles) {
		ordervehicle = nextveh;
		if (nextveh != vehicle)	break;
	}
	if (ordervehicle == vehicle) ordervehicle = null;
	if (AIVehicle.GetVehicleType(vehicle) == AIVehicle.VT_RAIL) {
		if (engine != null && wagon != null && (cBanker.GetMaxBankBalance() > AIEngine.GetPrice(engine) + 5*AIEngine.GetPrice(wagon))) {
			AIVehicle.SellWagonChain(vehicle, 0);
			cManager.AddVehicle(route, ordervehicle, engine, wagon);
		} else {
			AIVehicle.StartStopVehicle(vehicle);
		}
		AIRail.SetCurrentRailType(railtype);
	} else {
		if (engine != null && (cBanker.GetMaxBankBalance() > AIEngine.GetPrice(engine))) {
			AIVehicle.SellVehicle(vehicle);
			cManager.AddVehicle(route, ordervehicle, engine, null);
		} else {
			AIVehicle.StartStopVehicle(vehicle);
		}
	}
	todepotlist.RemoveItem(vehicle);
}

function cManager::CheckDefaultGroup()
{
	local vehicles = AIVehicleList_DefaultGroup(AIVehicle.VT_ROAD);
	vehicles.Valuate(AIVehicle.IsStoppedInDepot);
	vehicles.KeepValue(1);
	foreach (vehicle, dummy in vehicles) {
		if (AIVehicle.GetProfitThisYear(vehicle) != 0 || AIVehicle.GetProfitLastYear(vehicle) != 0 || AIVehicle.GetAge(vehicle) < 60) continue;
		if (todepotlist.HasItem(vehicle)) {
			todepotlist.RemoveItem(vehicle);
			AIVehicle.StartStopVehicle(vehicle);
		} else {
			AILog.Warning("Sold " + AIVehicle.GetName(vehicle) + ", as it has been sitting in the depot for ages.");
			AIVehicle.SellVehicle(vehicle);
		}
	}
	vehicles = AIVehicleList_DefaultGroup(AIVehicle.VT_RAIL);
	vehicles.Valuate(AIVehicle.IsStoppedInDepot);
	vehicles.KeepValue(1);
	foreach (vehicle, dummy in vehicles) {
		if (AIVehicle.GetProfitThisYear(vehicle) != 0 || AIVehicle.GetProfitLastYear(vehicle) != 0 || AIVehicle.GetAge(vehicle) < 60) continue;
		if (todepotlist.HasItem(vehicle)) {
			todepotlist.RemoveItem(vehicle);
			AIVehicle.StartStopVehicle(vehicle);
		} else {
			AILog.Warning("Sold " + AIVehicle.GetName(vehicle) + ", as it has been sitting in the depot for ages.");
			AIVehicle.SellWagonChain(vehicle, 0);
		}
	}
}
*/
