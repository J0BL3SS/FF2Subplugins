/*
	"rage_movespeed"	                                // Ability name can use suffixes
	{
		"slot"					"0"						// Ability slot
		"duration"				"10.0"					// Ability duration
		"selfspeed"				"520.0"					// Self move speed
		"allyspeed"				"400.0"					// Ally move speed
		"allyrange"				"768.0"					// Ally range
		"enemyspeed"			"225.0"					// Enemy move speed
		"enemyrange"			"768.0"					// Enemy range
		
		"plugin_name"	        "ff2r_movespeed"
	}
	
	// Future Project - from halloween_2014
	"special_proportional_speed"		        // Ability name can't use suffixes, no multiple instances
	{
		"slot"					"0"				// Ability slot (This ability works passively)
		"enemyspeed ratio"		"0.6"			// Speed Ratio		
		"enemyrange"			"600.0"			// Enemy range
		"allyspeed ratio"		"1.25"			// Speed Ratio		
		"allyrange"				"512.0"			// Ally range (Self is Excluded)
		
		"plugin_name"	        "ff2r_movespeed"
	}
	
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#undef REQUIRE_PLUGIN
#include <tf2attributes>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME     "Freak Fortress 2 Rewrite: My Stock Subplugin"
#define PLUGIN_AUTHOR   "J0BL3SS"
#define PLUGIN_DESC     "Subplugin for applying speed on players"

#define MAJOR_REVISION  "1"
#define MINOR_REVISION  "0"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAXTF2PLAYERS   MAXPLAYERS+1
#define INACTIVE        100000000.0

float MS_SelfMoveSpeed[MAXTF2PLAYERS];

float MS_AllyMoveSpeed[MAXTF2PLAYERS];
float MS_AllyRange[MAXTF2PLAYERS];
float MS_EnemyMoveSpeed[MAXTF2PLAYERS];
float MS_EnemyRange[MAXTF2PLAYERS];
float MS_Duration[MAXTF2PLAYERS];

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
};

public void OnPluginEnd()
{
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		SDKUnhook(clientIdx, SDKHook_PreThink, MSpeed_PreThink);
	}
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names
		return;
	
	if(!StrContains(ability, "rage_movespeed", false))
	{
		Ability_MoveSpeed(clientIdx, ability, cfg);
	}
}

public void Ability_MoveSpeed(int clientIdx, const char[] ability_name, AbilityData ability)
{
	MS_SelfMoveSpeed[clientIdx] = ability.GetFloat("selfspeed", 520.0);
	
	MS_AllyMoveSpeed[clientIdx] = ability.GetFloat("allyspeed", 420.0);
	MS_AllyRange[clientIdx] = ability.GetFloat("allyrange", 0.0);
	
	MS_EnemyMoveSpeed[clientIdx] = ability.GetFloat("enemyspeed", 230.0);
	MS_EnemyRange[clientIdx] = ability.GetFloat("enemyrange", 0.0);
	
	MS_Duration[clientIdx] = ability.GetFloat("duration", 8.0) + GetGameTime();
	SDKHook(clientIdx, SDKHook_PreThink, MSpeed_PreThink);
}

public void MSpeed_PreThink(int clientIdx)
{
	if(GetGameTime() >= MS_Duration[clientIdx])
	{
		for(int target = 1; target <= MaxClients; target++)
		{
			if(IsValidClient(target))
			{
				TF2_AddCondition(target, TFCond_SpeedBuffAlly, 0.001);
			}
		}
		SDKUnhook(clientIdx, SDKHook_PreThink, MSpeed_PreThink);
	}
	
	float pos1[3], pos2[3];
	GetClientAbsOrigin(clientIdx, pos1);
	
	for(int target = 0; target <= MaxClients; target++)
	{
		if(IsValidClient(target) && IsPlayerAlive(target))
		{
			GetClientAbsOrigin(target, pos2);
			if(GetClientTeam(target) == GetClientTeam(clientIdx))
			{
				//alliedteam
				if(target != clientIdx)	// filter self
				{
					if(MS_AllyRange[clientIdx] > 0.0 && GetVectorDistance(pos1, pos2) <= MS_AllyRange[clientIdx])
					{
						SetEntPropFloat(target, Prop_Data, "m_flMaxspeed", MS_AllyMoveSpeed[clientIdx]);
					}
					else
					{
						TF2_AddCondition(target, TFCond_SpeedBuffAlly, 0.001);
					}
				}
			}
			else
			{
				//enemyteam
				if(MS_EnemyRange[clientIdx] > 0.0 && GetVectorDistance(pos1, pos2) <= MS_EnemyRange[clientIdx])
				{
					SetEntPropFloat(target, Prop_Data, "m_flMaxspeed", MS_EnemyMoveSpeed[clientIdx]);
				}
				else
				{
					TF2_AddCondition(target, TFCond_SpeedBuffAlly, 0.001);
				}
			}
		}
	}
	
	//self
	SetEntPropFloat(clientIdx, Prop_Data, "m_flMaxspeed", MS_SelfMoveSpeed[clientIdx]);
}

public void FF2R_OnBossRemoved(int clientIdx)
{
	SDKUnhook(clientIdx, SDKHook_PreThink, MSpeed_PreThink);
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