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

class cBridge extends AIBridge
	{
		static	bridgedatabase = {};
		static	BridgeList = AIList();		// list of bridge, item bridgeUID value=owner
		static	function GetBridgeObject(bridgeUID)
			{
			return bridgeUID in cBridge.bridgedatabase ? cBridge.bridgedatabase[bridgeUID] : null;
			}

		bridgeUID	= null;	// it's our internal id ( < 0)
		bridgeID	= null;	// the bridgeID
		length		= null;	// the length of the bridge
		owner		= null;	// the companyID of the owner of the bridge
		direction	= null;	// the direction the bridge is build
		firstside	= null;	// the tile where the bridge start
		otherside	= null;	// the tile where the bridge end

		constructor()
			{
			bridgeUID   = null;
			bridgeID    = null;
			length      = 0;
			owner       = AICompany.COMPANY_INVALID;
			direction   = AIRail.RAILTRACK_INVALID;
			firstside   = -1;
			otherside   = -1;
			}
	}

function cBridge::IsValidTile(tile)
// validate a bridge tile
	{
	if (!AIMap.IsValidTile(tile))	{ return false; }
	if (!AIBridge.IsBridgeTile(tile))	{ return false; }
	return true;
	}

function cBridge::GetBridgeUID(tile)
// Return the bridge UID (our internal ID) from that tile
	{
	local validstart=cBridge.IsValidTile(tile);
	if (!validstart)	{ INSTANCE.DError("This is not a bridge at "+cMisc.Locate(tile),2); return null; }
	return 0-( (tile+1)*(AIBridge.GetOtherBridgeEnd(tile)+1) );
	}

function cBridge::Save()
// Save the bridge in the database
	{
	this.bridgeUID=cBridge.GetBridgeUID(this.firstside);
	if (bridgeUID==null)	{ return; } // no bridge found
	this.otherside=AIBridge.GetOtherBridgeEnd(this.firstside);
	if (this.bridgeUID in cBridge.bridgedatabase)	{ return; }
	this.length=AIMap.DistanceManhattan(this.firstside, this.otherside) +1;
	local dir=cBuilder.GetDirection(this.firstside, this.otherside);
	if (dir == 0 || dir == 1)	{ this.direction = AIRail.RAILTRACK_NW_SE; }
	else	{ this.direction = AIRail.RAILTRACK_NE_SW; }
	this.owner=AICompany.ResolveCompanyID(AITile.GetOwner(this.firstside));
	this.bridgeID=AIBridge.GetBridgeID(this.firstside);
	cBridge.bridgedatabase[this.bridgeUID] <- this;
	cBridge.BridgeList.AddItem(this.bridgeUID,this.owner);
	INSTANCE.DInfo("Adding "+AIBridge.GetName(this.bridgeID)+" at "+this.firstside+" to cBridge database",2);
	INSTANCE.DInfo("List of known bridges : "+(cBridge.bridgedatabase.len()),1);
	}

function cBridge::Load(bUID)
// Load a bridge object, and detect if we have an UID or a tile gave
	{
	local cobj=cBridge();
	if (AIMap.IsValidTile(bUID))
			{
       print("bridgeload "+bUID);
			cobj.bridgeUID=cBridge.GetBridgeUID(bUID);
			if (cobj.bridgeUID!=null)	{ cobj.firstside=bUID; }
                                else	{ return null; }
			bUID=cobj.bridgeUID;
			}
	else	{ cobj.bridgeUID=bUID; }
	if (bUID in cBridge.bridgedatabase)	{ cobj=cBridge.GetBridgeObject(bUID); cobj.CheckBridge(); }
	return null;
	}

function cBridge::GetLength(bUID)
// return the length of a bridge
	{
	local bobj=cBridge.Load(bUID);
	if (bobj == null) return 0;
	return bobj.length;
	}

function cBridge::CheckBridge()
// Check if the bridge need an update of its infos
	{
	local validstart=cBridge.IsValidTile(this.firstside);
	local validend=cBridge.IsValidTile(this.otherside);
	if (!validstart || !validend)
			{
			INSTANCE.DInfo("Bridge infos aren't valid anymore",2);
			cBridge.DeleteBridge(this.bridgeUID);
			}
	}

function cBridge::DeleteBridge(bUID)
// delete a bridge UID (not the bridge structure itself)
	{
	if (bUID in cBridge.bridgedatabase)
			{
			delete cBridge.bridgedatabase[bUID];
			BridgeList.RemoveItem(bUID);
			}
	}

function cBridge::GetDirection(bUID)
// return the direction the bridge is
	{
	local cobj=cBridge.Load(bUID);
    if (cobj == null)   return null;
	return cobj.direction;
	}

function cBridge::GetLocation(bUID)
// return the firstside (location) of the bridge
	{
	local cobj=cBridge.Load(bUID);
	if (cobj == null) return null;
	return cobj.firstside;
	}

function cBridge::GetOwner(bUID)
// return the owner of the bridge
	{
	local cobj=cBridge.Load(bUID);
	if (cobj == null)   return AICompany.COMPANY_INVALID;
	return cobj.owner;
	}

function cBridge::GetOurBridgeList()
// return the list of bridge that we own
	{
	local allBridge=AIList();
	allBridge.AddList(cBridge.BridgeList);
	allBridge.KeepValue(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
	return allBridge;
	}

function cBridge::GetBridgeID(bUID)
// return the bridgeID
	{
	local cobj=cBridge.Load(bUID);
    if (cobj == null) return null;
	return cobj.bridgeID;
	}

function cBridge::GetMaxSpeed(bUID)
// return the max speed of a bridge
	{
	local bID=cBridge.GetBridgeID(bUID);
	if (bID != null)	{ return AIBridge.GetMaxSpeed(bID); }
	return 0;
	}

function cBridge::IsBridgeTile(tile)
// return AIBridge.IsBridgeTile answer, but record the bridge if need
	{
	if (AIBridge.IsBridgeTile(tile))
			{
			local cobj=cBridge();
			cobj.firstside=tile;
			cobj.bridgeUID=cBridge.GetBridgeUID(tile);
			cobj.Save();
			return true;
			}
	return false;
	}

function cBridge::IsRoadBridge(tile)
// return true if that bridge is a road bridge
	{
	local cobj=cBridge.Load(tile);
	if (cobj == null)	{ return false; }
	if (cBridge.IsBridgeTile(cobj.firstside) && AITile.HasTransportType(cobj.firstside, AITile.TRANSPORT_ROAD))	{ return true; }
	return false;
	}

function cBridge::IsRailBridge(bUID)
// return true if that bridge is a rail bridge
	{
	local cobj=cBridge.Load(bUID);
	if (cobj == null)	{ return false; }
	if (cBridge.IsBridgeTile(cobj.firstside) && AITile.HasTransportType(cobj.firstside, AITile.TRANSPORT_RAIL))	{ return true; }
	return false;
	}

function cBridge::GetCheapBridgeID(btype, length, needresult=true)
// return a bridge ID to build a bridge of that size and type at needed speed
	{
	local needSpeed = cEngineLib.RailTypeGetSpeed(cEngineLib.RailTypeGetFastestType());
	if (btype == AIVehicle.VT_ROAD)	{ needSpeed=INSTANCE.main.carrier.speed_MaxRoad; }
	if (needSpeed == 0)
			{
			local vehlist=cEngineLib.GetEngineList(btype);
			vehlist.Valuate(AIEngine.GetMaxSpeed);
			vehlist.KeepAboveValue(1); // remove 0 speed engines
			vehlist.Sort(AIList.SORT_BY_VALUE, false);
			if (!vehlist.IsEmpty()) { needSpeed=vehlist.GetValue(vehlist.Begin()); }
			}
	local blist=AIBridgeList_Length(length);
	blist.Valuate(AIBridge.GetMaxSpeed);
	blist.KeepAboveValue((needSpeed -1));
	blist.Sort(AIList.SORT_BY_VALUE, true); // slowest first as this are all bridges faster than our train speed anyway
	if (blist.IsEmpty() && needresult)	{ blist=AIBridgeList_Length(length); blist.Valuate(AIBridge.GetMaxSpeed); blist.Sort(AIList.SORT_BY_VALUE, false); }
	if (blist.IsEmpty())	{ return -1; }
                    else	{ return blist.Begin(); }
	}