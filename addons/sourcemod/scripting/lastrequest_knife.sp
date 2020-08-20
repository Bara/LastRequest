#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#include <lastrequest>

#define LR_NAME "Knife Fight"
#define PLUGIN_NAME "Last Request - " ... LR_NAME

#define LR_SHORT_KNORMAL  "knifeFight_Normal"
#define LR_SHORT_BACKSTAB "knifeFight_Backstab"

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

public void OnConfigsExecuted()
{
	if (!LR_RegisterGame(LR_SHORT_KNORMAL, OnGameStart, OnGameEnd))
	{
		SetFailState("Can't register last request: %s", LR_SHORT_KNORMAL);
	}
	
	if (!LR_RegisterGame(LR_SHORT_BACKSTAB, OnGameStart, OnGameEnd))
	{
		SetFailState("Can't register last request: %s", LR_SHORT_BACKSTAB);
	}
}

public void LR_OnOpenMenu(Menu menu)
{
	menu.AddItem(LR_SHORT_KNORMAL, "Knife Fight - Normal"); // TODO: Add translation
	menu.AddItem(LR_SHORT_BACKSTAB, "Knife Fight - Backstab"); // TODO: Add translation
}

public void OnGameStart(int client, int target, const char[] name)
{
	PrintToChatAll("Knife.OnGameStart - Client: %N, Target: %N, Game: %s", client, target, name);

	if(StrEqual(name, LR_SHORT_KNORMAL, false))
	{
		PrintToChatAll("%s", name);
		g_bKnife = true;
		g_bNormal = true;
	}
	else if(StrEqual(name, LR_SHORT_BACKSTAB, false))
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

public void OnGameEnd(int winner, int loser)
{
	if (winner != -1 && loser != -1)
	{
		PrintToChatAll("Knife.OnGameEnd - Winner: %N, Loser: %N", winner, loser);
	}

	if (winner != -1)
	{
		SDKUnhook(winner, SDKHook_TraceAttack, OnTraceAttack);
	}

	if (loser != -1)
	{
		SDKUnhook(loser, SDKHook_TraceAttack, OnTraceAttack);
	}
	
	g_bKnife = false;
	g_bNormal = false;
	g_bBackstab = false;
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	PrintToChatAll("1, Knife: %d, Normal: %d, Backstab: %d", g_bKnife, g_bNormal, g_bBackstab);

	if(!g_bKnife)
	{
		return Plugin_Continue;
	}

	PrintToChatAll("2");
	
	if(damagetype == DMG_FALL || attacker == 0)
	{
		return Plugin_Continue;
	}

	PrintToChatAll("3, ValidA: %d (%d), ValidV: %d (%d)", LR_IsClientValid(attacker), attacker, LR_IsClientValid(victim), victim);
	
	if(!LR_IsClientValid(attacker) || !LR_IsClientValid(victim))
	{
		return Plugin_Handled;
	}

	PrintToChatAll("4, InLRA: %d, InLRV: %d", LR_IsClientInLastRequest(attacker), LR_IsClientInLastRequest(victim));
	
	if(!LR_IsClientInLastRequest(attacker) || !LR_IsClientInLastRequest(victim))
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
