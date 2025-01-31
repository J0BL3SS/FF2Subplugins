/*
	"rage_hinttext"				// Ability name can use suffixes
	{
		"slot"			"0"								// Ability Slot
		"message"		"Go Get Them Maggot!"			// Hinttext Message
		"plugin_name"	"ff2r_subplugin_template"		// this subplugin name
	}
	
	"rage_change_boss_name"		// Ability name can use suffixes
	{
		"slot"			"-1"							// Ability Slot
		"new name"		"My Boss V2.0"					// New boss name
		"plugin_name"	"ff2r_subplugin_template"		// this subplugin name
	}
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME 		"Freak Fortress 2 Rewrite: My Stock Subplugin"
#define PLUGIN_AUTHOR 		"J0BL3SS"
#define PLUGIN_DESC 		"It's a template ff2r subplugin"

#define MAJOR_REVISION 		"1"
#define MINOR_REVISION 		"0"
#define STABLE_REVISION 	"1"
#define PLUGIN_VERSION 		MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAXTF2PLAYERS		MAXPLAYERS+1

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
};

public void OnPluginStart()
{
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		if(IsClientInGame(clientIdx))
		{
			OnClientPutInServer(clientIdx);
			
			BossData cfg = FF2R_GetBossData(clientIdx);	// Get boss config (known as boss index) from player
			if(cfg)
			{
				FF2R_OnBossCreated(clientIdx, cfg, false);	// If boss is valid, Hook the abilities because this subplugin is most likely late-loaded
			}
		}
	}
	
	
}

public void OnClientPutInServer(int clientIdx)
{
	// Check and apply effects if boss abilities that can effect players are active
}

public void OnPluginEnd()
{
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		// Clear everything from players, because FF2:R either disabled/unloaded or this subplugin unloaded
	}
}

public void FF2R_OnBossRemoved(int clientIdx)
{
	/*
	* When the boss removed, <Leave the Game | Command Toggle>
	* 
	* Unhook and clear ability effects from the player(s)
	*
	*/
		 
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
	/*
	* When the boss created, hook the abilities etc. <New Round (Arena) | Command Toggle>
	*
	* We no longer use RoundStart Event to hook abilities because bosses can be created trough 
	* manually by command in other gamemodes other than Arena or create bosses mid-round.
	*
	*/
	
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	/*
	* When boss respawned <Player Death>
	* 
	* Re-Hook/Reset boss(es) abilities and clear/apply ability effects for the player(s)
	* Player will be remain boss when respawned.	
	*
	*/
	
	int clientIdx = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(clientIdx))
		return;
	
	BossData boss = FF2R_GetBossData(clientIdx);
	if(boss)
	{
		// Respawned player is a boss
	}
	else
	{
		// Respawned player is not a boss
	}
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{	
	/*
	* When boss died <Player Death>
	* 
	* Clear ability effects from the player(s)
	* Player will be remain boss when respawned.
	* Make Unhooking boss(es) abilities under FF2R_OnBossRemoved()
	*
	*/
	
	int clientIdx = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(clientIdx))
		return;
	
	int attackerIdx = GetClientOfUserId(event.GetInt("attacker"));	// Not necessarily needed if abilities are not effecting players
	if(!IsValidClient(attackerIdx))
		PrintToConsole(clientIdx, "You have probably died to environmental damage");
	
	if(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return;	// Make sure it is not deadringer
	
	BossData boss = FF2R_GetBossData(clientIdx);
	if(boss)
	{
		// Died player is a boss
	}
	else
	{
		// Died player is not a boss
	}
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	/*
	* When boss use their abilities
	* 
	* Your classic stuff, when boss use his rage abilities
	*
	*/
	
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names with different plugins in boss config
		return;
		
	if(!cfg.GetBool("enabled", true))	// hidden/internal bool for abilities
		return;
		
	if(!StrContains(ability, "rage_hinttext", false))	// We want to use subffixes
	{
		Rage_HintText(clientIdx, cfg);
	}
	
	if(!StrContains(ability, "rage_change_boss_name", false))	// We want to use subffixes
	{
		Rage_Change_Name(clientIdx, cfg);
	}
}

void Rage_HintText(int clientIdx, AbilityData ability)
{
	static char buffer[128];
	ability.GetString("message", buffer, sizeof(buffer));	// We use ConfigMap to Get string from "message" argument from ability
		
	if(buffer[0] != '\0') {
		PrintHintText(clientIdx, buffer);
	}
	else {
		PrintHintText(clientIdx, "fill up your \"message\" argument lol");
	}
}

void Rage_Change_Name(int clientIdx, AbilityData ability)
{
	static char buffer[128];
	ability.GetString("new name", buffer, sizeof(buffer));	// We use ConfigMap to Get string from "new name" argument from ability
		
	if(buffer[0] != '\0') {
		FF2R_GetBossData(clientIdx).SetString("name", buffer);	// We use ConfigMap to Set string, editing boss's name directly
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