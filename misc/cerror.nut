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

class cError extends cClass
{
static	isCriticalError=[0];	// hold error flag

	constructor()
		{
		this.ClassName="cError";
		}
}

function cError::IsError()
// return true if error is raise
{
	return cError.isCriticalError[0]==1;
}

function cError::ClearError()
// force unset the error flag
{
	cError.SetErrorCritical(false);
}

function cError::RaiseError()
// force the error flag set
{
	cError.SetErrorCritical(true);
}

function cError::SetErrorCritical(value)
// set/unset critical flag
{
	if (value)	cError.isCriticalError[0]=1;
		else	cError.isCriticalError[0]=0;
}

function cError::IsCriticalError()
// Check the last error to see if the error is a critical error or temp failure
// we return false when no error or true when error
// we set CriticalError to true for a critcal error or false for a temp failure
{
	local lasterror=AIError.GetLastError();
	local errcat=AIError.GetErrorCategory();
	DInfo("Error check: "+AIError.GetLastErrorString()+" Cat: "+errcat+" flag: "+cError.IsError(),2);
	if (cError.IsError())	return true; // return failure as long as flag is set
	switch (lasterror)
		{
		case AIError.ERR_NOT_ENOUGH_CASH:
			cError.SetErrorCritical(false);
			cBanker.RaiseFundsBigTime();
			return true;
		break;
		case AIError.ERR_NONE:
			cError.SetErrorCritical(false);
			return false;
		break;
		case AIError.ERR_VEHICLE_IN_THE_WAY:
			cError.SetErrorCritical(false);
			return true;
		break;
		case AIError.ERR_LOCAL_AUTHORITY_REFUSES:
			cError.SetErrorCritical(false);
			return true;
		break;
		case AIError.ERR_ALREADY_BUILT:
			cError.SetErrorCritical(false);
			return false; // let's fake we success in that case
		break;
		default:
			cError.SetErrorCritical(true);
			return true; // critical set
		}
}

function cError::ForceAction(...)
/** @brief Loop until the action result is not block by a vehicle. Don't use it with functions that change arguments content
 *
 * @param ... The first param is the action, others are actions parameters (7 params only as YexoCallFunction limit)
 *
 */
{
	local action = null;
	local action_param = [];
	if (vargc < 1 || vargc > 8)	return;
	local output="";
	local tile = -1;
	for (local i = 0; i < vargc; i++)
		{
		if (i ==0)	{ action =vargv[i]; }
			else	{
					action_param.push(vargv[i]);
					if (i == 1)	{ tile = action_param[0]; } // assuming function use tile as first param
					output += " "+vargv[i];
					}
		}
	local result = -1;
	local error = -666;
	local count = 100;
	local move = false;
	while (error != AIError.ERR_NONE && count > 0)
		{
		count--;
		result = cTileTools.YexoCallFunction(action, action_param);
		error = AIError.GetLastError();
		if (error != AIError.ERR_VEHICLE_IN_THE_WAY)	{ return result; }
		DWarn("ForceAction delayed : tile="+tile+" params="+output+" @"+cMisc.Locate(tile),1);
		if (tile != null && AIMap.IsValidTile(tile))
				{
				local veh = AIVehicleList();
				veh.Valuate(AIVehicle.GetLocation);
				veh.KeepValue(tile);
				foreach (v, _ in veh)	{
										local kind = DepotAction.WAITING+30;
										if (cEngineLib.IsDepotTile(tile))	{ kind = DepotAction.SELL; cCarrier.VehicleIsWaitingInDepot(); }
										cCarrier.VehicleSendToDepot(v, kind);
										AIController.Sleep(74); // give it a day to move
										}
				}
		AIController.Sleep(30);
		}
	return result;
}
