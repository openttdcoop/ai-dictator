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

require("misc/version.nut");

 class DictatorAI extends AIInfo
 {
   function GetAuthor()        { return "Krinn"; }
   function GetName()          { return "DictatorAI"; }
   function GetDescription()   { return "a (should be) competitive AI."; }
   function GetVersion()       { return SELF_VERSION; }
   function MinVersionToLoad() { return 1; }
   function GetDate()          { return "2010-12-26"; }
   function CreateInstance()   { return "DictatorAI"; }
   function GetShortName()     { return "DCTR"; }
   function GetAPIVersion()    { return "1.3"; }
   function GetURL()		 { return "http://www.tt-forums.net/viewtopic.php?f=65&t=52982"; }

   function GetSettings() {

	AddSetting({name = "PresidentName",
	 description = "Use real names for the company president?",
	 easy_value = 0,
	 medium_value = 0,
	 hard_value = 0,
	 custom_value = 0,
	 flags = CONFIG_BOOLEAN
	});

    AddSetting({name = "fairlevel",
	 description = "Alter how the AI act with others",
	 min_value = 0,
	 max_value = 2,
	 easy_value = 0,
	 medium_value = 1,
	 hard_value = 2,
	 custom_value = 2,
	 flags = CONFIG_NONE
	});

    AddLabels("fairlevel", {_0 = "Lazy", _1 = "Opportunist", _2 = "Dictator"});

    AddSetting({name = "allowedjob",
	 description = "What tasks the AI can handle",
	 min_value = 0,
	 max_value = 2,
	 easy_value = 1,
	 medium_value = 0,
	 hard_value = 0,
	 custom_value = 0,
	 flags = CONFIG_INGAME
	});

    AddLabels("allowedjob", {_0 = "Industry & Town", _1 = "Only Industry", _2 = "Only Town"});

	AddSetting({
		name = "use_road",
		description = "Use buses & trucks",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});

	AddSetting({
		name = "station_balance",
		description = "Detect traffic jam: on - better fairplay and aesthetic / off - better for economy",
		easy_value = 1,
		medium_value = 1,
		hard_value = 0,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});

	AddSetting({
		name = "keep_road",
		description = "Remove roads: on - better economy and aesthetic / off - better for opponents (some AIs may bug)",
		easy_value = 0,
		medium_value = 0,
		hard_value = 1,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});

	AddSetting({
		name = "use_train",
		description = "Use trains",
		easy_value = 0,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});

	AddSetting({
		name = "use_nicetrain",
		description = "Respect newGRF flag: on - better for aesthetic / off - better for economy",
		easy_value = 1,
		medium_value = 1,
		hard_value = 0,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});

	AddSetting({
		name = "use_air",
		description = "Use aircrafts & choppers",
		easy_value = 0,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});

	AddSetting({
		name = "use_boat",
		description = "Use boats",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
	});

	AddSetting({
		name = "use_terraform",
		description = "Allow terraforming: always disable in Lazy mode",
		easy_value = 0,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});

	AddSetting({
		name = "upgrade_townbridge",
		description = "Upgrade towns bridges: on - better for aesthetics & opponents / off - better for economy",
		easy_value = 1,
		medium_value = 1,
		hard_value = 0,
		custom_value = 0,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});

	AddSetting({
		name = "allow_scp",
		description = "Allow DictatorAI to play with GoalScript using SCP",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME
	});

    	AddSetting({
	 name = "debug",
	 description = "Enable debug messages",
	 min_value = 0,
	 max_value = 4,
	 easy_value = 0,
	 medium_value = 0,
	 hard_value = 0,
	 custom_value = 0,
	 flags = CONFIG_INGAME | CONFIG_DEVELOPER
	});
    //AddLabels("debug", {_0 = "Disable debug", _1 = "Basic", _2 = "Medium", _3 = "Noisy"});

	AddSetting({
		name = "debug_sign",
		description = "Enable debug signs",
		easy_value = 0,
		medium_value = 0,
		hard_value = 0,
		custom_value = 0,
		flags = CONFIG_BOOLEAN | CONFIG_INGAME | CONFIG_DEVELOPER
	});


   }
 }

 RegisterAI(DictatorAI());
