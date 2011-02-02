 class DictatorAI extends AIInfo 
 {
   function GetAuthor()        { return "Brumi"; }
   function GetName()          { return "DictatorAI"; }
   function GetDescription()   { return "a (should be) competitive AI."; }
   function GetVersion()       { return 12; }
   function MinVersionToLoad() { return 1; }
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
	 flags = AICONFIG_INGAME | AICONFIG_BOOLEAN
	});

    AddSetting({name = "fairlevel",
	 description = "Alter how the AI act with others",
	 min_value = 0,
	 max_value = 2,
	 easy_value = 0,
	 medium_value = 1,
	 hard_value = 2,
	 custom_value = 2,
	 flags = AICONFIG_INGAME
	});

    AddLabels("fairlevel", {_0 = "Crazy", _1 = "Opportunist", _2 = "Dictator"});

	AddSetting({
		name = "use_train",
		description = "Use trains",
		easy_value = 1,
		medium_value = 1,
		hard_value = 1,
		custom_value = 1,
		flags = AICONFIG_BOOLEAN | AICONFIG_INGAME
	});
	AddSetting({
		name = "use_road",
		description = "Use road vehicles",
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
	AddSetting({
		name = "use_boat",
		description = "Use boat vehicles",
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
	 easy_value = 2,
	 medium_value = 2,
	 hard_value = 2,
	 custom_value = 2,
	 flags = AICONFIG_INGAME
	});
    AddLabels("debug", {_0 = "Disable debug", _1 = "Basic debug", _2 = "Full debug"});
   }
 }
 
 RegisterAI(DictatorAI());
