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


 class DictatorAI extends AIInfo 
 {
   function GetAuthor()        { return "Krinn"; }
   function GetName()          { return "DictatorAI"; }
   function GetDescription()   { return "a (should be) competitive AI."; }
   function GetVersion()       { return 150; }
   function MinVersionToLoad() { return 4; }
   function GetDate()          { return "2010-12-26"; }
   function CreateInstance()   { return "DictatorAI"; }
   function GetShortName()     { return "DCTR"; }
   function GetAPIVersion()    { return "1.0"; }
   
   function GetSettings() {

	AddSetting({name = "PresidentName",
	 description = "Use real names for the company president?",
	 easy_value = 0,
	 medium_value = 0,
	 hard_value = 0,
	 custom_value = 0,
	 flags = AICONFIG_BOOLEAN
	});

    AddSetting({name = "fairlevel",
	 description = "Alter how the AI act with others",
	 min_value = 0,
	 max_value = 2,
	 easy_value = 0,
	 medium_value = 1,
	 hard_value = 2,
	 custom_value = 2,
	 flags = 0
	});

    AddLabels("fairlevel", {_0 = "Lazy", _1 = "Opportunist", _2 = "Dictator"});

	AddSetting({
		name = "use_train",
		description = "Use trains - Not working, sorry",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
	});

	AddSetting({
		name = "use_nicetrain",
		description = "Allow AI to use trains for anything (better for economy) OR respect newGRF authors choices (better for aesthetics)",
		easy_value = 0,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
	});

	AddSetting({
		name = "use_road",
		description = "Use buses & trucks",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
	});
	AddSetting({
		name = "use_air",
		description = "Use aircrafts & choppers",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
	});
/*
	AddSetting({
		name = "use_boat",
		description = "Use boat vehicles - NOT FUNCTIONAL",
		easy_value = 0,
		medium_value = 0,
		hard_value = 0,
		custom_value = 0,
		flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
	});*/

	AddSetting({
		name = "use_terraform",
		description = "Allow terraforming, always disable in Lazy mode",
		easy_value = 0,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
	});

	AddSetting({
		name = "upgrade_townbridge",
		description = "Allow AI to also upgrade town bridges",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
	});

    	AddSetting({
	 name = "debug",
	 description = "Enable debug messages",
	 min_value = 0,
	 max_value = 2,
	 easy_value = 0,
	 medium_value = 0,
	 hard_value = 0,
	 custom_value = 0,
	 flags = AICONFIG_INGAME
	});
    AddLabels("debug", {_0 = "Disable debug", _1 = "Basic debug", _2 = "Full debug"});
   }
 }
 
 RegisterAI(DictatorAI());
