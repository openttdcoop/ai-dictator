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

