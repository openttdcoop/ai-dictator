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
class cBridge extends AIBridge
{
static	bridgedatabase = {};
static	BridgeList = AIList();	// list of bridge, item bridgeUID value=owner
static	function GetBridgeObject(bridgeUID)
		{
		return bridgeUID in cBridge.bridgedatabase ? cBridge.bridgedatabase[bridgeUID] : null;
		}

	bridgeUID		= null;	// it's our internal id ( < 0)
	bridgeID		= null;	// the bridgeID
	length		= null;	// the length of the bridge
	owner			= null;	// the companyID of the owner of the bridge
	direction		= null;	// the direction the bridge is build
	firstside		= null;	// the tile where the bridge start
	otherside		= null;	// the tile where the bridge end
	
	constructor()
		{
		bridgeUID=null;
		bridgeID=null;
		length=0;
		owner=AICompany.COMPANY_INVALID;
		direction=AIRail.RAILTRACK_INVALID;
		firstside=-1;
		otherside=-1;
		}
}

function cBridge::IsValidTile(tile)
// validate a bridge tile
	{
	if (!AIMap.IsValidTile(tile))	return false;
	if (!AIBridge.IsBridgeTile(tile))	return false;
	return true;
	}

function cBridge::GetBridgeUID(tile)
// Return the bridge UID (our internal ID) from that tile
	{
	local validstart=cBridge.IsValidTile(tile);
	local validend=cBridge.IsValidTile(tile);
	if (!validstart && !validend)
		{ DError("This is not a bridge",2,"cBridge::GetBridgeUID"); return null; }
	print("::getbridgeuid too big ? "+tile+" "+AIBridge.GetOtherBridgeEnd(tile));
	return 0-( (tile+1)*(AIBridge.GetOtherBridgeEnd(tile)+1) );
	}

function cBridge::Save()
// Save the bridge in the database
	{
	print("::save");
	this.bridgeUID=cBridge.GetBridgeUID(this.firstside);
	if (bridgeUID==null)	return; // no bridge found
	local validstart=cBridge.IsValidTile(this.firstside);
	print("::save is in data? "+this.bridgeUID+" "+(this.bridgeUID in cBridge.bridgedatabase));
	print("::save validstart="+validstart);
	if (validstart)	this.otherside=AIBridge.GetOtherBridgeEnd(this.firstside);
			else	this.firstside=AIBridge.GetOtherBridgeEnd(this.otherside);
	if (this.bridgeUID in cBridge.bridgedatabase)	{ print("::save already in data???"); return; }
	print("::save didn't find it in data");
	this.length=AIMap.DistanceManhattan(this.firstside, this.otherside) +1;
	local dir=cBuilder.GetDirection(this.firstside, this.otherside);
	if (dir == 0 || dir == 1)	this.direction = AIRail.RAILTRACK_NW_SE;
					else	this.direction = AIRail.RAILTRACK_NE_SW;
	this.owner=AICompany.ResolveCompanyID(AITile.GetOwner(this.firstside));
	this.bridgeID=AIBridge.GetBridgeID(this.firstside);
	cBridge.bridgedatabase[this.bridgeUID] <- this;
	cBridge.BridgeList.AddItem(this.bridgeUID,this.owner);
	DInfo("Adding "+AIBridge.GetName(this.bridgeID)+" to cBridge database",2,"cBridge::Save");
	DInfo("List of known bridges : "+(cBridge.bridgedatabase.len()),1,"cBridge::Save");
	}

function cBridge::Load(bUID)
// Load a bridge object, and detect if we have an UID or a tile gave
	{
	local cobj=cBridge();
	print("::load bUID="+bUID);
	if (AIMap.IsValidTile(bUID))
		{
		print("::load valid tile");
		cobj.bridgeUID=cBridge.GetBridgeUID(bUID);
		print("::load getbridgeUID return "+cobj.bridgeUID);
		if (cobj.bridgeUID!=null)	cobj.firstside=bUID;
		print("::load firstside="+cobj.firstside);
		bUID=cobj.bridgeUID;
		}
	else	cobj.bridgeUID=bUID;
	print("::load is in database? "+bUID+" "+(bUID in cBridge.bridgedatabase));
	if (bUID in cBridge.bridgedatabase)	{ print("::load found in data"); cobj=cBridge.GetBridgeObject(bUID);/* cBridge.CheckBridge(bUID);*/ }
						else	cobj.Save(); // we will not save a null bridgeUID
	return cobj;
	}

function cBridge::GetLength(bUID)
// return the length of a bridge
	{
	local bobj=cBridge.Load(bUID);
	return bobj.length;
	}

function cBridge::CheckBridge(bUID)
// Check if the bridge need an update of its infos
	{
	local cobj=cBridge.Load(bUID);
	local validstart=cBridge.IsValidTile(cobj.firstside);
	local validend=cBridge.IsValidTile(cobj.otherside);
	if (!validstart || !validend)
		{
		DInfo("Bridge infos aren't valid anymore, bridge has moved ?",2,"cBridge::CheckBridge");
		cBridge.DeleteBridge(bUID);
		cobj.Save(); // try to save it again, the Save function will seek who is valid and who's not
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
	return cobj.direction;
	}

function cBridge::GetOwner(bUID)
// return the owner of the bridge
	{
	local cobj=cBridge.Load(bUID);
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
	print(":: getbridgeid "+bUID+" cobj="+cobj.bridgeUID+" bridgeid="+cobj.bridgeID);
	return cobj.bridgeID;
	}

function cBridge::GetMaxSpeed(bUID)
// return the max speed of a bridge
	{
	print(":: getmaxspeed");
	return AIBridge.GetMaxSpeed(cBridge.GetBridgeID(bUID));
	}

function cBridge::IsBridgeTile(tile)
// return AIBridge.IsBridgeTile answer, but record the bridge if need
	{
	if (AIBridge.IsBridgeTile(tile))
		{
		//print("hack isBridgeTile enter");
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
	if (AIBridge.IsBridgeTile(cobj.firstside) && AITile.HasTransportType(cobj.firstside, AITile.TRANSPORT_ROAD))	return true;
	return false;
	}

function cBridge::IsRailBridge(bUID)
// return true if that bridge is a rail bridge
	{
	local cobj=cBridge.Load(bUID);
	if (AIBridge.IsBridgeTile(cobj.firstside) && AITile.HasTransportType(cobj.firstside, AITile.TRANSPORT_RAIL))	return true;
	return false;
	}
