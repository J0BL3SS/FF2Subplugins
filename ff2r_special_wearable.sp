/*
	"rage_apply_wearables"		// Ability name can use suffixes
	{
		"slot"					"0"			// Ability slot
		"clear wearables"		"true"		// Clear current wearables
		
		"wearables"				// Up to 20 wearables
		{
			"wearable1"
			{
				"index"			"486"		// Cosmetic index
				"show"			"true"		// Show wearable
				"attributes"	""			// Attributes
				"level"			"99"		// Level
				"quality"		"2"			// Quality
				"rank"			"5"			// Strange rank
			}
			"wearable2"
			{
				"index"			"942"		// Cosmetic index
				"show"			"true"		// Show wearable
				"attributes"	""			// Attributes
				"level"			"99"		// Level
				"quality"		"2"			// Quality
				"rank"			"5"			// Strange rank
			}
		}
		
		"plugin_name"			"ff2r_special_wearable"
	}
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#undef REQUIRE_PLUGIN
#tryinclude <tf2utils>
#tryinclude <tf_custom_attributes>

#include "freak_fortress_2/formula_parser.sp"

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME 	"Freak Fortress 2 Rewrite: Special Wearable"
#define PLUGIN_AUTHOR 	"J0BL3SS"
#define PLUGIN_DESC 	"Applying On Boss Wearable"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"0"
#define STABLE_REVISION "1"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAXTF2PLAYERS	MAXPLAYERS+1

Handle SDKEquipWearable;
int PlayersAlive[4];
bool SpecTeam;
ConVar CvarFriendlyFire;

#define TF2U_LIBRARY	"nosoop_tf2utils"
#define TCA_LIBRARY		"tf2custattr"

#if defined __nosoop_tf2_utils_included
bool TF2ULoaded;
#endif

#if defined __tf_custom_attributes_included
bool TCALoaded;
#endif

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	#if defined __nosoop_tf2_utils_included
	MarkNativeAsOptional("TF2Util_GetPlayerWearableCount");
	MarkNativeAsOptional("TF2Util_GetPlayerWearable");
	MarkNativeAsOptional("TF2Util_GetPlayerMaxHealthBoost");
	MarkNativeAsOptional("TF2Util_EquipPlayerWearable");
	#endif
	
	#if defined __tf_custom_attributes_included
	MarkNativeAsOptional("TF2CustAttr_SetString");
	#endif
	return APLRes_Success;
}

public void OnPluginStart()
{
	CvarFriendlyFire = FindConVar("mp_friendlyfire");
	
	#if defined __nosoop_tf2_utils_included
	TF2ULoaded = LibraryExists(TF2U_LIBRARY);
	#endif
	
	GameData gamedata = new GameData("sm-tf2.games");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(gamedata.GetOffset("RemoveWearable") - 1);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	SDKEquipWearable = EndPrepSDKCall();
	if(!SDKEquipWearable)
		LogError("[Gamedata] Could not find RemoveWearable");
	
	delete gamedata;
}


public void OnLibraryAdded(const char[] name)
{
	#if defined __nosoop_tf2_utils_included
	if(!TF2ULoaded && StrEqual(name, TF2U_LIBRARY))
		TF2ULoaded = true;
	#endif
	
	#if defined __tf_custom_attributes_included
	if(!TCALoaded && StrEqual(name, TCA_LIBRARY))
		TCALoaded = true;
	#endif
}

public void OnLibraryRemoved(const char[] name)
{
	#if defined __nosoop_tf2_utils_included
	if(TF2ULoaded && StrEqual(name, TF2U_LIBRARY))
		TF2ULoaded = false;
	#endif
	
	#if defined __tf_custom_attributes_included
	if(TCALoaded && StrEqual(name, TCA_LIBRARY))
		TCALoaded = false;
	#endif
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	//Just your classic stuff, when boss raged:
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names with different plugins in boss config
		return;
		
	if(!cfg.GetBool("enabled", true))	// hidden/internal bool for abilities
		return;
	
	if(!StrContains(ability, "rage_apply_wearables", false))	// We want to use subffixes
	{
		ApplyWearables(clientIdx, ability, cfg);
	}
}

public void ApplyWearables(int clientIdx, const char[] ability_name, AbilityData ability)
{	
	if(ability.GetBool("clear wearables", true))
		TF2_RemoveCosmetics(clientIdx);
		
	ConfigData wearables = ability.GetSection("wearables");
	
	for(int i = 1; i <= 20; i++)
	{
		char buffer[12];
		Format(buffer, sizeof(buffer), "wearable%i", i);
		ConfigData wearable = wearables.GetSection(buffer);
		NewWeapon(clientIdx, wearable, ability_name);
	}
}

void NewWeapon(int client, ConfigData cfg, const char[] ability)
{
	static char classname[36], attributes[2048];
	if(!cfg.GetString("classname", classname, sizeof(classname)))
		if(!cfg.GetString("name", classname, sizeof(classname)))
			classname = "tf_wearable";
	
	cfg.GetString("attributes", attributes, sizeof(attributes));
	bool wearable = StrContains(classname, "tf_weap") != 0;
	
	if(!wearable)
	{
		int slot = cfg.GetInt("weapon slot", -99);
		if(slot == -99)
			slot = TF2_GetClassnameSlot(classname);
		
		if(slot >= 0 && slot < 6)
			TF2_RemoveWeaponSlot(client, slot);
	}
	
	int index = cfg.GetInt("index");
	int level = cfg.GetInt("level", -1);
	int quality = cfg.GetInt("quality", 5);
	
	int kills = cfg.GetInt("rank", -99);
	if(kills == -99 && level == -1)
		kills = GetURandomInt() % 21;
	
	if(kills >= 0)
		kills = wearable ? GetKillsOfCosmeticRank(kills, index) : GetKillsOfWeaponRank(kills, index);
	
	if(level < 0 || level > 127)
		level = 101;
	
	static char buffers[40][256];
	
	int count = ExplodeString(attributes, " ; ", buffers, sizeof(buffers), sizeof(buffers));
	
	if(count % 2)
		count--;
	
	int alive = GetTotalPlayersAlive(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client));
	int attribs;
	int entity = -1;
	if(wearable)
	{
		entity = CreateEntityByName(classname);
		if(entity != -1)
		{
			SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", index);
			SetEntProp(entity, Prop_Send, "m_bInitialized", true);
			SetEntProp(entity, Prop_Send, "m_iEntityQuality", quality);
			SetEntProp(entity, Prop_Send, "m_iEntityLevel", level);
			
			DispatchSpawn(entity);
		}
		/*
		else
		{
			FF2R_GetBossData(client).GetString("filename", buffers[0], sizeof(buffers[]));
			LogError("[Boss] Invalid classname '%s' for '%s' in '%s'", classname, buffers[0], ability);
		}*/
	}
	
	if(entity != -1)
	{
		if(wearable)
		{
			EquipPlayerWearable(client, entity);
		}
		else
		{
			EquipPlayerWeapon(client, entity);
		}
		
		for(; attribs < count; attribs += 2)
		{
			int attrib = StringToInt(buffers[attribs]);
			if(attrib)
			{
				TF2Attrib_SetByDefIndex(entity, attrib, ParseFormula(buffers[attribs+1], alive));
			}
			else
			{
				FF2R_GetBossData(client).Get("filename", attributes, sizeof(attributes));
				LogError("[Boss] Bad weapon attribute passed for '%s' on '%s': %s ; %s in '%s'", attributes, classname, buffers[attribs], buffers[attribs+1], ability);
			}
		}
		
		#if defined __tf_custom_attributes_included
		if(TCALoaded)
		{
			ConfigData custom = cfg.GetSection("custom");
			if(custom)
				ApplyCustomAttributes(entity, custom);
		}
		#endif
		
		if(kills >= 0)
		{
			TF2Attrib_SetByDefIndex(entity, 214, view_as<float>(kills));
			if(wearable)
				TF2Attrib_SetByDefIndex(entity, 454, view_as<float>(64));
		}
		
		if(cfg.GetBool("show", true))
		{
			if(cfg.GetString("worldmodel", buffers[0], sizeof(buffers[])))
			{
				index = StringToInt(buffers[0]);
				if(!index)
					index = PrecacheModel(buffers[0]);
				
				SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", index);
				for(level = 0; level < 4; level++)
				{
					SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", index, _, level);
				}
			}
				
			GetEntityNetClass(entity, attributes, sizeof(attributes));
			int offset = FindSendPropInfo(attributes, "m_iItemIDHigh");
			
			SetEntData(entity, offset - 8, 0);	// m_iItemID
			SetEntData(entity, offset - 4, 0);	// m_iItemID
			SetEntData(entity, offset, 0);		// m_iItemIDHigh
			SetEntData(entity, offset + 4, 0);	// m_iItemIDLow
			
			SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", true);
		}
		else
		{
			SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
			SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
		}
		
		level = cfg.GetInt("alpha", 255);
		index = cfg.GetInt("red", 255);
		kills = cfg.GetInt("green", 255);
		count = cfg.GetInt("blue", 255);
		
		if(level != 255 || index != 255 || kills != 255 || count != 255)
		{
			SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
			SetEntityRenderColor(entity, index, kills, count, level);
		}
		
		SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		
		if(!wearable)
		{
			if(cfg.GetBool("force switch"))
			{
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", entity);
			}
			else
			{
				FakeClientCommand(client, "use %s", classname);
			}
		}
	}
}

public void FF2R_OnAliveChanged(const int alive[4], const int total[4])
{
	for(int i; i < 4; i++)
	{
		PlayersAlive[i] = alive[i];
	}
	
	SpecTeam = (total[TFTeam_Unassigned] || total[TFTeam_Spectator]);
}

int GetTotalPlayersAlive(int team = -1)
{
	int amount;
	for(int i = SpecTeam ? 0 : 2; i < sizeof(PlayersAlive); i++)
	{
		if(i != team)
			amount += PlayersAlive[i];
	}
	
	return amount;
}

void EquipPlayerWearable(int client, int entity)
{
	#if defined __nosoop_tf2_utils_included
	if(TF2ULoaded)
	{
		TF2Util_EquipPlayerWearable(client, entity);
	}
	else
	#endif
	{
		SDKCall_EquipWearable(client, entity);
	}
}

void SDKCall_EquipWearable(int client, int entity)
{
	if(SDKEquipWearable)
	{
		SDKCall(SDKEquipWearable, client, entity);
	}
	else
	{
		RemoveEntity(entity);
	}
}

int TF2_GetClassnameSlot(const char[] classname, bool econ = false)
{
	if(StrEqual(classname, "player"))
	{
		return -1;
	}
	else if(StrEqual(classname, "tf_weapon_scattergun") ||
	   StrEqual(classname, "tf_weapon_handgun_scout_primary") ||
	   StrEqual(classname, "tf_weapon_soda_popper") ||
	   StrEqual(classname, "tf_weapon_pep_brawler_blaster") ||
	  !StrContains(classname, "tf_weapon_rocketlauncher") ||
	   StrEqual(classname, "tf_weapon_particle_cannon") ||
	   StrEqual(classname, "tf_weapon_flamethrower") ||
	   StrEqual(classname, "tf_weapon_grenadelauncher") ||
	   StrEqual(classname, "tf_weapon_cannon") ||
	   StrEqual(classname, "tf_weapon_minigun") ||
	   StrEqual(classname, "tf_weapon_shotgun_primary") ||
	   StrEqual(classname, "tf_weapon_sentry_revenge") ||
	   StrEqual(classname, "tf_weapon_drg_pomson") ||
	   StrEqual(classname, "tf_weapon_shotgun_building_rescue") ||
	   StrEqual(classname, "tf_weapon_syringegun_medic") ||
	   StrEqual(classname, "tf_weapon_crossbow") ||
	  !StrContains(classname, "tf_weapon_sniperrifle") ||
	   StrEqual(classname, "tf_weapon_compound_bow"))
	{
		return TFWeaponSlot_Primary;
	}
	else if(!StrContains(classname, "tf_weapon_pistol") ||
	  !StrContains(classname, "tf_weapon_lunchbox") ||
	  !StrContains(classname, "tf_weapon_jar") ||
	   StrEqual(classname, "tf_weapon_handgun_scout_secondary") ||
	   StrEqual(classname, "tf_weapon_cleaver") ||
	  !StrContains(classname, "tf_weapon_shotgun") ||
	   StrEqual(classname, "tf_weapon_buff_item") ||
	   StrEqual(classname, "tf_weapon_raygun") ||
	  !StrContains(classname, "tf_weapon_flaregun") ||
	  !StrContains(classname, "tf_weapon_rocketpack") ||
	  !StrContains(classname, "tf_weapon_pipebomblauncher") ||
	   StrEqual(classname, "tf_weapon_laser_pointer") ||
	   StrEqual(classname, "tf_weapon_mechanical_arm") ||
	   StrEqual(classname, "tf_weapon_medigun") ||
	   StrEqual(classname, "tf_weapon_smg") ||
	   StrEqual(classname, "tf_weapon_charged_smg"))
	{
		return TFWeaponSlot_Secondary;
	}
	else if(!StrContains(classname, "tf_weapon_r"))	// Revolver
	{
		return econ ? TFWeaponSlot_Secondary : TFWeaponSlot_Primary;
	}
	else if(StrEqual(classname, "tf_weapon_sa"))	// Sapper
	{
		return econ ? TFWeaponSlot_Building : TFWeaponSlot_Secondary;
	}
	else if(!StrContains(classname, "tf_weapon_i") || !StrContains(classname, "tf_weapon_pda_engineer_d"))	// Invis & Destory PDA
	{
		return econ ? TFWeaponSlot_Item1 : TFWeaponSlot_Building;
	}
	else if(!StrContains(classname, "tf_weapon_p"))	// Disguise Kit & Build PDA
	{
		return econ ? TFWeaponSlot_PDA : TFWeaponSlot_Grenade;
	}
	else if(!StrContains(classname, "tf_weapon_bu"))	// Builder Box
	{
		return econ ? TFWeaponSlot_Building : TFWeaponSlot_PDA;
	}
	else if(!StrContains(classname, "tf_weapon_sp"))	 // Spellbook
	{
		return TFWeaponSlot_Item1;
	}
	return TFWeaponSlot_Melee;
}

int GetKillsOfWeaponRank(int rank = -1, int index = 0)
{
	switch(rank)
	{
		case 0:
		{
			return GetRandomInt(0, 9);
		}
		case 1:
		{
			return GetRandomInt(10, 24);
		}
		case 2:
		{
			return GetRandomInt(25, 44);
		}
		case 3:
		{
			return GetRandomInt(45, 69);
		}
		case 4:
		{
			return GetRandomInt(70, 99);
		}
		case 5:
		{
			return GetRandomInt(100, 134);
		}
		case 6:
		{
			return GetRandomInt(135, 174);
		}
		case 7:
		{
			return GetRandomInt(175, 224);
		}
		case 8:
		{
			return GetRandomInt(225, 274);
		}
		case 9:
		{
			return GetRandomInt(275, 349);
		}
		case 10:
		{
			return GetRandomInt(350, 499);
		}
		case 11:
		{
			if(index == 656)	// Holiday Punch
			{
				return GetRandomInt(500, 748);
			}
			else
			{
				return GetRandomInt(500, 749);
			}
		}
		case 12:
		{
			if(index == 656)	// Holiday Punch
			{
				return 749;
			}
			else
			{
				return GetRandomInt(750, 998);
			}
		}
		case 13:
		{
			if(index == 656)	// Holiday Punch
			{
				return GetRandomInt(750, 999);
			}
			else
			{
				return 999;
			}
		}
		case 14:
		{
			return GetRandomInt(1000, 1499);
		}
		case 15:
		{
			return GetRandomInt(1500, 2499);
		}
		case 16:
		{
			return GetRandomInt(2500, 4999);
		}
		case 17:
		{
			return GetRandomInt(5000, 7499);
		}
		case 18:
		{
			if(index == 656)	// Holiday Punch
			{
				return GetRandomInt(7500, 7922);
			}
			else
			{
				return GetRandomInt(7500, 7615);
			}
		}
		case 19:
		{
			if(index == 656)	// Holiday Punch
			{
				return GetRandomInt(7923, 8499);
			}
			else
			{
				return GetRandomInt(7616, 8499);
			}
		}
		case 20:
		{
			return GetRandomInt(8500, 9999);
		}
		default:
		{
			return GetRandomInt(0, 9999);
		}
	}
}

#if defined __tf_custom_attributes_included
void ApplyCustomAttributes(int entity, ConfigData cfg)
{
	StringMapSnapshot snap = cfg.Snapshot();
	
	int entries = snap.Length;
	for(int i; i < entries; i++)
	{
		int length = snap.KeyBufferSize(i) + 1;
		
		char[] key = new char[length];
		snap.GetKey(i, key, length);
		
		static PackVal attribute;	
		cfg.GetArray(key, attribute, sizeof(attribute));
		if(attribute.tag == KeyValType_Value)
			TF2CustAttr_SetString(entity, key, attribute.data);
	}
	
	delete snap;
}
#endif

int GetKillsOfCosmeticRank(int rank = -1, int index = 0)
{
	switch(rank)
	{
		case 0:
		{
			if(index == 133 || index == 444 || index == 655)	// Gunboats, Mantreads, or Spirit of Giving
			{
				return 0;
			}
			else
			{
				return GetRandomInt(0, 14);
			}
		}
		case 1:
		{
			if(index == 133 || index == 444 || index == 655)	// Gunboats, Mantreads, or Spirit of Giving
			{
				return GetRandomInt(1, 2);
			}
			else
			{
				return GetRandomInt(15, 29);
			}
		}
		case 2:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(3, 4);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(3, 6);
			}
			else
			{
				return GetRandomInt(30, 49);
			}
		}
		case 3:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(5, 6);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(7, 11);
			}
			else
			{
				return GetRandomInt(50, 74);
			}
		}
		case 4:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(7, 9);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(12, 19);
			}
			else
			{
				return GetRandomInt(75, 99);
			}
		}
		case 5:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(10, 13);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(20, 27);
			}
			else
			{
				return  GetRandomInt(100, 134);
			}
		}
		case 6:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(14, 17);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(28, 36);
			}
			else
			{
				return GetRandomInt(135, 174);
			}
		}
		case 7:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(18, 22);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(37, 46);
			}
			else
			{
				return GetRandomInt(175, 249);
			}
		}
		case 8:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(23, 27);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(47, 56);
			}
			else
			{
				return GetRandomInt(250, 374);
			}
		}
		case 9:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(28, 34);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(57, 67);
			}
			else
			{
				return GetRandomInt(375, 499);
			}
		}
		case 10:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(35, 49);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(68, 78);
			}
			else
			{
				return GetRandomInt(500, 724);
			}
		}
		case 11:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(50, 74);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(79, 90);
			}
			else
			{
				return GetRandomInt(725, 999);
			}
		}
		case 12:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(75, 98);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(91, 103);
			}
			else
			{
				return GetRandomInt(1000, 1499);
			}
		}
		case 13:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return 99;
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(104, 119);
			}
			else
			{
				return GetRandomInt(1500, 1999);
			}
		}
		case 14:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(100, 149);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(120, 137);
			}
			else
			{
				return GetRandomInt(2000, 2749);
			}
		}
		case 15:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(150, 249);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(138, 157);
			}
			else
			{
				return GetRandomInt(2750, 3999);
			}
		}
		case 16:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(250, 499);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(158, 178);
			}
			else
			{
				return GetRandomInt(4000, 5499);
			}
		}
		case 17:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(500, 749);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(179, 209);
			}
			else
			{
				return GetRandomInt(5500, 7499);
			}
		}
		case 18:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(750, 783);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(210, 249);
			}
			else
			{
				return GetRandomInt(7500, 9999);
			}
		}
		case 19:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(784, 849);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(250, 299);
			}
			else
			{
				return GetRandomInt(10000, 14999);
			}
		}
		case 20:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(850, 999);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(300, 399);
			}
			else
			{
				return GetRandomInt(15000, 19999);
			}
		}
		default:
		{
			if(index == 133 || index == 444)	// Gunboats or Mantreads
			{
				return GetRandomInt(0, 999);
			}
			else if(index == 655)	// Spirit of Giving
			{
				return GetRandomInt(0, 399);
			}
			else
			{
				return GetRandomInt(0, 19999);
			}
		}
	}
}

stock void TF2_RemoveCosmetics(int clientIdx)
{
	int edict = MaxClients + 1;
	while((edict = FindEntityByClassname(edict, "tf_wearable")) != -1)
	{
		char netclass[32];
		if (GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFWearable"))
		{
			if(GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == clientIdx && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
			{
				AcceptEntityInput(edict, "Kill");
			}
		}
	}
}

stock bool IsValidClient(int clientIdx, bool replaycheck=true)
{
	if(clientIdx <= 0 || clientIdx > MaxClients)
		return false;

	if(!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
		return false;

	if(GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
		return false;

	return true;
}