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
		bridgeID	= null;	// the bridgeID ; its type
		length		= null;	// the length of the bridge
		owner		= null;	// the companyID of the owner of the bridge
		direction	= null;	// the direction the bridge is build
		firstside	= null;	// the tile where the bridge start
		otherside	= null;	// the tile where the bridge end
		roadtype	= null; // the bridge rail/road type use

		constructor()
			{
			bridgeUID   = null;
			bridgeID    = null;
			length      = 0;
			owner       = AICompany.COMPANY_INVALID;
			direction   = AIRail.RAILTRACK_INVALID;
			firstside   = -1;
			otherside   = -1;
			roadtype	= -1;
			}
	}

function cBridge::GetBridgeUID(tile)
// Return the bridge UID (our internal ID) from that tile
// -1 on error
	{
	if (tile == null)	return -1;
	if (!AIMap.IsValidTile(tile))	return -1;
	if (!::AIBridge.IsBridgeTile(tile))
			{
			if (tile in cBridge.bridgedatabase)	cBridge.DeleteBridge(tile);
			return -1;
			}
	local other_side = ::AIBridge.GetOtherBridgeEnd(tile);
    if (tile in cBridge.bridgedatabase)	return tile;
    if (other_side in cBridge.bridgedatabase)	return other_side;
	local t_brg = cBridge();
	t_brg.firstside = tile;
	t_brg.otherside = other_side;
	t_brg.bridgeUID = tile;
	t_brg.Save();
	return t_brg.bridgeUID;
	}

function cBridge::Save()
// Save the bridge in the database
	{
	if (this.bridgeUID in cBridge.bridgedatabase)	return;
	print("saving bridgeUID "+this.bridgeUID);
	this.length = AIMap.DistanceManhattan(this.firstside, this.otherside) + 1;
	local dir = cDirection.GetDirection(this.firstside, this.otherside);
	if (dir == 0 || dir == 1)	{ this.direction = AIRail.RAILTRACK_NW_SE; }
						else	{ this.direction = AIRail.RAILTRACK_NE_SW; }
	this.owner = AICompany.ResolveCompanyID(AITile.GetOwner(this.firstside));
	this.bridgeID = ::AIBridge.GetBridgeID(this.firstside);
	// seek out the type of bridge
    if (AIRoad.HasRoadType(this.firstside, AIRoad.ROADTYPE_TRAM))	this.roadtype = AIRoad.ROADTYPE_TRAM;
		else	if (AIRoad.HasRoadType(this.firstside, AIRoad.ROADTYPE_ROAD))	this.roadtype = AIRoad.ROADTYPE_ROAD;
			else	this.roadtype = AIRail.IsRailTile(this.firstside) ? AIRail.GetRailType(tile) : -1;
	if (this.roadtype == -1)    { INSTANCE.DInfo("Cannot get type of bridge at " + cMisc.Locate(this.firstside)); return; }
	cBridge.bridgedatabase[this.bridgeUID] <- this;
	cBridge.BridgeList.AddItem(this.bridgeUID, this.owner);
	}

function cBridge::UpgradeBridge(tile, newmodele)
// upgrade the bridge at tile for the new bridge type
// return false on error
{
	local bridge = cBridge.Load(tile);
    if (bridge == null)	return false;
    local VT_TYPE = AIVehicle.VT_ROAD;
    if (cBridge.IsRoadBridge(tile))	{ AIRoad.SetCurrentRoadType(bridge.roadtype); }
							else	{ VT_TYPE = AIVehicle.VT_RAIL; AIRail.SetCurrentRailType(bridge.railtype); }
	local res = ::AIBridge.BuildBridge(VT_TYPE, newmodele, bridge.firstside, bridge.otherside);
	if (res)	{ cBridge.DeleteBridge(tile); bridge.Save(); }
	return res;
}

function cBridge::Load(bUID)
// Load a bridge object
// null on error
	{
	local _id = cBridge.GetBridgeUID(bUID);
	if (_id == -1)	return null;
	local cobj = cBridge.GetBridgeObject(_id);
	return cobj == null ? null : cobj;
	}

function cBridge::GetLength(bUID)
// return the length of a bridge
	{
	local bobj = cBridge.Load(bUID);
	if (bobj == null) return 0;
	return bobj.length;
	}

function cBridge::DeleteBridge(bUID)
// delete a bridge UID (not the bridge structure itself)
	{
	if (bUID in cBridge.bridgedatabase)
			{
			INSTANCE.DInfo("Deleting bridge " + bUID, 2);
			delete cBridge.bridgedatabase[bUID];
			cBridge.BridgeList.RemoveItem(bUID);
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
	local cobj = cBridge.Load(bUID);
	if (cobj == null) return null;
	return cobj.firstside;
	}

function cBridge::GetOwner(bUID)
// return the owner of the bridge
	{
	local cobj = cBridge.Load(bUID);
	if (cobj == null)   return AICompany.COMPANY_INVALID;
	return cobj.owner;
	}

function cBridge::GetOurBridgeList()
// return the list of bridge that we own
	{
	local allBridge = AIList();
	allBridge.AddList(cBridge.BridgeList);
	allBridge.KeepValue(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
	return allBridge;
	}

function cBridge::GetBridgeID(bUID)
// return the bridgeID
	{
	local cobj = cBridge.Load(bUID);
    if (cobj == null) return null;
	return cobj.bridgeID;
	}

function cBridge::GetMaxSpeed(bUID)
// return the max speed of a bridge
	{
	local bID = cBridge.GetBridgeID(bUID);
	if (bID != null)	{ return AIBridge.GetMaxSpeed(bID); }
	return 0;
	}

function cBridge::IsBridgeTile(tile)
// return AIBridge.IsBridgeTile answer, but record the bridge if need
	{
	local cobj = cBridge.Load(tile);
	if (cobj == null)	return false;
	return true;
	}

function cBridge::IsRoadBridge(tile)
// return true if that bridge is a road bridge
	{
	local cobj = cBridge.Load(tile);
	if (cobj == null)	{ return false; }
	if (AITile.HasTransportType(cobj.firstside, AITile.TRANSPORT_ROAD))	{ return true; }
	return false;
	}

function cBridge::IsRailBridge(bUID)
// return true if that bridge is a rail bridge
	{
	local cobj = cBridge.Load(bUID);
	if (cobj == null)	{ return false; }
	if (AITile.HasTransportType(cobj.firstside, AITile.TRANSPORT_RAIL))	{ return true; }
	return false;
	}

function cBridge::GetCheapBridgeID(btype, length, needresult=true)
// return a bridge ID to build a bridge of that size and type at needed speed
	{
	local needSpeed = cEngineLib.RailTypeGetSpeed(cEngineLib.RailTypeGetFastestType());
	if (btype == AIVehicle.VT_ROAD)	{ needSpeed = INSTANCE.main.carrier.speed_MaxRoad; }
	if (needSpeed == 0)
			{
			local vehlist=cEngineLib.GetEngineList(btype);
			vehlist.Valuate(AIEngine.GetMaxSpeed);
			vehlist.KeepAboveValue(1); // remove 0 speed engines
			vehlist.Sort(AIList.SORT_BY_VALUE, false);
			if (!vehlist.IsEmpty()) { needSpeed=vehlist.GetValue(vehlist.Begin()); }
			}
	local blist = AIBridgeList_Length(length);
	blist.Valuate(AIBridge.GetMaxSpeed);
	blist.KeepAboveValue((needSpeed -1));
	blist.Sort(AIList.SORT_BY_VALUE, true); // slowest first as this are all bridges faster than our train speed anyway
	if (blist.IsEmpty() && needresult)	{ blist=AIBridgeList_Length(length); blist.Valuate(AIBridge.GetMaxSpeed); blist.Sort(AIList.SORT_BY_VALUE, false); }
	if (blist.IsEmpty())	{ return -1; }
                    else	{ return blist.Begin(); }
	}
