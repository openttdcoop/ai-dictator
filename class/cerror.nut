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
static	isCriticalError=[0];	// maximum speed a road vehicle could do

	constructor()
		{
		this.ClassName="cError";
		}
}

function cError::IsError()
// return true if error is raise
{
	return isCriticalError[0]==1;
}

function cError::SetErrorCritical(value)
// set/unset critical flag
{
	if (value)	isCriticalError[0]=1;
		else	isCriticalError[0]=0;
}

function cError::IsCriticalError()
// Check the last error to see if the error is a critical error or temp failure
// we return false when no error or true when error
// we set CriticalError to true for a critcal error or false for a temp failure
{
	if (IsError())	return true; // tell everyone we fail until the flag is remove
	local lasterror=AIError.GetLastError();
	local errcat=AIError.GetErrorCategory();
	DInfo("Error check: "+AIError.GetLastErrorString()+" Cat: "+errcat,2);
	switch (lasterror)
		{
		case AIError.ERR_NOT_ENOUGH_CASH:
			SetErrorCritical(false);
			cBanker.RaiseFundsBigTime();
			return true;
		break;
		case AIError.ERR_NONE:
			SetErrorCritical(false);
			return false;
		break;
		case AIError.ERR_VEHICLE_IN_THE_WAY:
			SetErrorCritical(false);
			return true;
		break;
		case AIError.ERR_LOCAL_AUTHORITY_REFUSES:
			SetErrorCritical(false);
			return true;
		break;
		case AIError.ERR_ALREADY_BUILT:
			SetErrorCritical(false);
			return false; // let's fake we success in that case
		break;
		default:
			SetErrorCritical(true);
			return true; // critical set
		}
}

