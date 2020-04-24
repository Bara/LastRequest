#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#include <lastrequest>

#define LR_NAME "Knife Fight"
#define PLUGIN_NAME "Last Request - " ... LR_NAME

#define KNORMAL  LR_NAME ... " - Normal"
#define BACKSTAB LR_NAME ... " - Backstab"

bool g_bKnife = false;
bool g_bNormal = false;
bool g_bBackstab = false;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = "github.com/Bara"
};

public void OnAllPluginsLoaded()
{
	if (LR_RegisterGame(KNORMAL, "KnifeNormal"))
	{
		SetFailState("Can't register last request: %s", KNORMAL);
	}
	
	if (LR_RegisterGame(BACKSTAB, "KnifeAntiBackstab"))
	{
		SetFailState("Can't register last request: %s", BACKSTAB);
	}
}

public void LR_OnLastRequestChoosen(int client, int target, const char[] name)
{
	if(StrEqual(name, KNORMAL, false))
	{
		PrintToChatAll("%s", name);
		g_bKnife = true;
		g_bNormal = true;
	}
	else if(StrEqual(name, BACKSTAB, false))
	{
		PrintToChatAll("%s", name);
		g_bKnife = true;
		g_bBackstab = true;
	}
	
	if(g_bKnife)
	{
		SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
		SDKHook(target, SDKHook_TraceAttack, OnTraceAttack);
	}
	
	LR_StripAllWeapons(client);
	LR_StripAllWeapons(target);
	
	int iKnife1 = GivePlayerItem(client, "weapon_knife");
	int iKnife2 = GivePlayerItem(target, "weapon_knife");
	
	EquipPlayerWeapon(client, iKnife1);
	EquipPlayerWeapon(target, iKnife2);
}

public void LR_OnLastRequestEnd(int client, int target)
{
	SDKUnhook(client, SDKHook_TraceAttack, OnTraceAttack);
	SDKUnhook(target, SDKHook_TraceAttack, OnTraceAttack);
	
	g_bKnife = false;
	g_bNormal = false;
	g_bBackstab = false;
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if(!g_bKnife)
	{
		return Plugin_Continue;
	}
	
	if(damagetype == DMG_FALL || damagetype == DMG_GENERIC || attacker == 0)
	{
		return Plugin_Continue;
	}
	
	if(LR_IsClientValid(attacker) && LR_IsClientValid(victim) && !LR_IsClientInLastRequest(attacker) || !LR_IsClientInLastRequest(victim))
	{
		return Plugin_Handled;
	}
	
	char sWeapon[32];
	GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
	
	if ((StrContains(sWeapon, "knife", false) != -1) || (StrContains(sWeapon, "bayonet", false) != -1))
	{
		if(g_bNormal)
		{
			return Plugin_Continue;
		}
		else if(g_bBackstab)
		{
			float fAAngle[3], fVAngle[3], fBAngle[3];
			
			GetClientAbsAngles(victim, fVAngle);
			GetClientAbsAngles(attacker, fAAngle);
			MakeVectorFromPoints(fVAngle, fAAngle, fBAngle);
			
			if(fBAngle[1] > -90.0 && fBAngle[1] < 90.0)
			{
				return Plugin_Continue;
			}
			else
			{
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Handled;
}
