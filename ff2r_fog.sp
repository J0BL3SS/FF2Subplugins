/*
 *	It is not recomended to use both of these abilities together, or with multiple bosses with these abilities
 */

/*
	"rage_fog_fx"		// Ability name can use suffixes
	{	
		"slot"			"0"
			
		//colors
		"color1"		"255 255 255"		// RGB colors
		"color2"		"255 255 255"		// RGB colors
		
		// fog properties
		"blend"			"0" 				// blend
		"fog start"		"64.0"				// fog start distance
		"fog end"		"384.0"				// fog end distance
		"fog density"	"1.0"				// fog density
		
		// effect properties
		"effect type"	"0"					// fog effect: 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
		"effect range"	"9999.0"			// rage distance
		"duration"		"5.0"				// fog duration
		
		"plugin_name"	"ff2r_fog"
	}
	
	"fog_fx"			// Ability name can't use suffixes
	{	
		"slot"			"0"
			
		//colors
		"color1"		"255 255 255"		// RGB colors
		"color2"		"255 255 255"		// RGB colors
		
		// fog properties
		"blend"			"0" 				// blend
		"fog start"		"64.0"				// fog start distance
		"fog end"		"384.0"				// fog end distance
		"fog density"	"1.0"				// fog density
		
		// effect properties
		"effect type"	"0"					// fog effect: 0: Everyone, 1: Only Self, 2:Team, 3: Enemy Team, 4: Everyone besides self
		"plugin_name"	"ff2r_fog"
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

#define PLUGIN_NAME 	"Freak Fortress 2 Rewrite: Fog Effects"
#define PLUGIN_AUTHOR 	"J0BL3SS"
#define PLUGIN_DESC 	"Every town has an elm street"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"0"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAXTF2PLAYERS	MAXPLAYERS+1

int FOG_EntityIndex = -1;
bool IsFogActive = false;
float FOG_Duration[MAXTF2PLAYERS];
int FOG_Effect[MAXTF2PLAYERS];
char FOG_AbilityName[MAXTF2PLAYERS][128];
bool IsUnderFogEffect[MAXTF2PLAYERS];

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

// re-apply fog
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int UserIdx = GetEventInt(event, "userid");
	int clientIdx = GetClientOfUserId(UserIdx);
	
	if(!IsValidClient(clientIdx))
		return;
		
	ApplyFogToPlayers(clientIdx);
	
	BossData boss = FF2R_GetBossData(clientIdx);
	if(boss)
		FF2R_OnBossCreated(clientIdx, boss, false);
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{	
	int clientIdx = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(clientIdx))
		return;
	
	if(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return;	// Make sure it is not deadringer
	
	BossData boss = FF2R_GetBossData(clientIdx);
	if(boss)
		FF2R_OnBossRemoved(clientIdx);
	
	if(IsUnderFogEffect[clientIdx])
	{
		SetVariantString("");
		AcceptEntityInput(clientIdx, "SetFogController");
	}

}

public void OnClientPutInServer(int clientIdx)
{
	if(IsValidClient(clientIdx))
		ApplyFogToPlayers(clientIdx);
}

public void ApplyFogToPlayers(int clientIdx)
{
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsValidClient(target))
		{	
			BossData cfg = FF2R_GetBossData(target);
			if(cfg)
			{
				if(IsFogActive)
				{
					if(FogEffectType(target, clientIdx))
					{
						SetVariantString("ElmStreet");
						AcceptEntityInput(clientIdx, "SetFogController");
					}
				}
			}
		}
	}
}

public void OnPluginEnd()
{		
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		IsUnderFogEffect[clientIdx] = false;
		
		if(IsValidClient(clientIdx))
			SDKUnhook(clientIdx, SDKHook_PreThink, Fog_PreThink);
	}
	
	KillFog(FOG_EntityIndex);
	FOG_EntityIndex = -1;
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
	AbilityData ability = cfg.GetAbility("fog_fx");
	if(!ability.IsMyPlugin())	// Incase of duplicated ability names
		return;
		
	if(!IsValidClient(clientIdx))
		return;
	
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsValidClient(target))
		{	
			Activate_Fog(clientIdx, "fog_fx", ability);
		}
	}
}

public void FF2R_OnBossRemoved(int clientIdx)
{	  
	SDKUnhook(clientIdx, SDKHook_PreThink, Fog_PreThink);
	KillFog(FOG_EntityIndex);
	FOG_EntityIndex = -1;
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names in boss config
		return;
	
	if(!cfg.GetBool("enabled", true))	// hidden/internal bool for abilities
		return;
	
	if(!StrContains(ability, "rage_fog_fx", false))	// We want to use subffixes
	{
		Activate_Fog(clientIdx, ability, cfg);
	}
}

public void Activate_Fog(int clientIdx, const char[] ability_name, AbilityData ability)
{
	Format(FOG_AbilityName[clientIdx], 128, ability_name);
	char colors[3][16]; float distance;
	
	ability.GetString("blend", colors[0], 16);
	ability.GetString("color1", colors[1], 16);
	ability.GetString("color2", colors[2], 16);
	FOG_Effect[clientIdx] = ability.GetInt("effect type", 0);
	
	FOG_EntityIndex = CreateFog(colors[0], colors[1], colors[2],
	ability.GetFloat("fog start", 64.0), ability.GetFloat("fog end", 384.0), ability.GetFloat("fog density", 1.0));
	
	if(!StrContains(ability_name, "rage_fog_fx", false))	// add time and proper range if its normal fog
	{
		distance = ability.GetFloat("effect range");
		FOG_Duration[clientIdx] = ability.GetFloat("duration", 8.0) + GetGameTime();
		SDKHook(clientIdx, SDKHook_PreThink, Fog_PreThink);
	}
	else if(!StrContains(ability_name, "fog_fx", false)) // it's passive ability so add effect in mapwide & no duration
	{
		distance = 9999.0;
	}
	
	float pos1[3], pos2[3];
	GetClientAbsOrigin(clientIdx, pos1);
	
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsValidClient(target))
		{
			GetClientAbsOrigin(target, pos2);
			if(GetVectorDistance(pos1, pos2) <= distance)
			
			if(FogEffectType(clientIdx, target))
			{
				SetVariantString("ElmStreet");
				AcceptEntityInput(target, "SetFogController");
				IsUnderFogEffect[target] = true;
			}
		}
	}
}

public void Fog_PreThink(int clientIdx)
{
	if(GetGameTime() >= FOG_Duration[clientIdx])
	{
		KillFog(FOG_EntityIndex);
		FOG_EntityIndex = -1;
		SDKUnhook(clientIdx, SDKHook_PreThink, Fog_PreThink);
	}
}

stock int CreateFog(char[] fogblend, char[] fogcolor1, char[] fogcolor2, float fogstart = 64.0, float fogend = 384.0, float fogdensity = 1.0)
{
	int iFog = CreateEntityByName("env_fog_controller");
	if(IsValidEntity(iFog)) 
	{
		DispatchKeyValue(iFog, "targetname", "ElmStreet");
		DispatchKeyValue(iFog, "fogenable", "1");
		DispatchKeyValue(iFog, "spawnflags", "1");
		DispatchKeyValue(iFog, "fogblend", fogblend);
		DispatchKeyValue(iFog, "fogcolor", fogcolor1);
		DispatchKeyValue(iFog, "fogcolor2", fogcolor2);
		DispatchKeyValueFloat(iFog, "fogstart", fogstart);
		DispatchKeyValueFloat(iFog, "fogend", fogend);
		DispatchKeyValueFloat(iFog, "fogmaxdensity", fogdensity);
		DispatchSpawn(iFog);
		AcceptEntityInput(iFog, "TurnOn");
		IsFogActive = true;		
	}
	return iFog;
}

stock void KillFog(int iEnt)
{
	if(IsValidEdict(iEnt) && iEnt > MaxClients)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SetVariantString("");
				AcceptEntityInput(i, "SetFogController");
			}
		}
		AcceptEntityInput(iEnt, "Kill");
		iEnt = -1;
		IsFogActive = false;
	}
}

stock bool FogEffectType(int clientIdx, int target)
{
	switch(FOG_Effect[clientIdx])
	{
		case 1: // if target is boss,
		{
			if(clientIdx == target)		
				return true;
			else return false;
		}
		case 2: // if target's team same team as boss's team
		{
			if(GetClientTeam(target) == GetClientTeam(clientIdx)) 
				return true;
			else return false;
		}
		case 3: // if target's team is not same team as boss's team
		{
			if(GetClientTeam(target) != GetClientTeam(clientIdx)) 
				return true;
			else return false;
		}
		case 4: // if target is not boss
		{
			if(clientIdx != target) 
				return true;
			else return false;
		}
		default: // effect everyone
		{
			return true;	
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