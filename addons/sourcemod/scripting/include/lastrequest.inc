#if defined _lr_included
  #endinput
#endif
#define _lr_included

#include <cstrike>

#define LR_MAX_SHORTNAME_LENGTH 32
#define LR_MAX_FULLNAME_LENGTH 64
#define LR_LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(LR_IsClientValid(%1))

/*
 * Requester is mostly the last T and opponent is the choosed CT by the T.
 * Short Name will be required for games with subgames like knife fight with different modes.
 * Note: If you return something other than Plugin_Continue, you must trigger LR_StartLastRequest
 *       Example: Soon
 */
typedef LRPreStartCB = function Action (int requester, int opponent, const char[] shortname);
typedef LRStartCB = function void (int requester, int opponent, const char[] shortname);
typedef LREndCB = function void (int winner, int loser);

/*
 * This forward will called, when someone opens the LR games list or wants to start a lr.
 * With this forward you must add your games like: "menu.AddItem(shortname, name);"
 * Name is the displayed name on the menu.

 * @param menu            Handle of the menu
 */
forward void LR_OnOpenMenu(Menu menu);

/*
 * Forward will fired when the penultimate t dies.
 *
 * @param client          Client index of the last t
 */
forward bool LR_OnLastRequestAvailable(int client);

/*
 * Register lr game.
 *
 * @param shortname        Short name of LR game
 *
 * @return                 True, if register was successful otherwise false
 */
native bool LR_RegisterGame(const char[] shortname, LRPreStartCB preStartCallback, LRStartCB startCallback, LREndCB endCallback);

/*
 * Check if the specific client is in a LR or not.
 *
 * @param client          Client index
 *
 * @return                True, if the client is in a LR, otherwise false
 */
native bool LR_IsClientInLastRequest(int client);

/*
 * Returns the client index of the opponent
 *
 * @param client          Client index
 *
 * @return                Returns the client index of the opponent, otherwise it's -1
 */
native int LR_GetClientOpponent(int client);

/*
 * Check if is LR is available.
 *
 * @return                True, if LR is available otherwise false.
 */
native bool LR_IsLastRequestAvailable();

/*
 * Stops the active LR immediately.
 */
native void LR_StopLastRequest(int winner = -1, int loser = -1);

/*
 * Firing last restart start
 * @param armor            0 - no armor, 1 - armor, 2 - armor + helm
 */
native void LR_StartLastRequest(int requester, char[] mode, char[] weapon, int health = 100, int armor = 0);

native int LR_GetMenuTime();
native int LR_GetTimeoutPunishment();

stock bool IsLastRequestAvailable()
{
	if (!LibraryExists("lastrequest"))
	{
		return SetFailState("Last Request is not loaded!");
	}
}

stock bool LR_IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
		{
			return true;
		}
	}
	return false;
}

stock void LR_StripAllWeapons(int client)
{
	for(int i = CS_SLOT_PRIMARY; i <= CS_SLOT_C4; i++)
	{
		int index = -1;
		while((index = GetPlayerWeaponSlot(client, i)) != -1)
		{
			LR_SafeRemoveWeapon(client, index);
		}
	}
}

stock bool LR_SafeRemoveWeapon(int client, int weapon)
{
	if (!IsValidEntity(weapon) || !IsValidEdict(weapon))
	{
		return false;
	}
	
	if (!HasEntProp(weapon, Prop_Send, "m_hOwnerEntity"))
	{
		return false;
	}
	
	int iOwner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	
	if (iOwner != client)
	{
		SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);
	}
	
	CS_DropWeapon(client, weapon, false);
	
	if (HasEntProp(weapon, Prop_Send, "m_hWeaponWorldModel"))
	{
		int iWorldModel = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");
		
		if (IsValidEdict(iWorldModel) && IsValidEntity(iWorldModel))
		{
			if (!AcceptEntityInput(iWorldModel, "Kill"))
			{
				return false;
			}
		}
	}
	
	if (!AcceptEntityInput(weapon, "Kill"))
	{
		return false;
	}
	
	return true;
}

stock void SetKevlarHelm(int client, int kevlar, bool helm)
{
    SetEntProp(client, Prop_Data, "m_ArmorValue", kevlar, 1);
    SetEntProp(client, Prop_Send, "m_bHasHelmet", helm);
}

public SharedPlugin __pl_lr = 
{
	name = "lastrequest",
	file = "lastrequest.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN

public __pl_lr_SetNTVOptional()
{
	MarkNativeAsOptional("LR_RegisterGame");
	MarkNativeAsOptional("LR_IsClientInLastRequest");
	MarkNativeAsOptional("LR_IsLastRequestAvailable");
	MarkNativeAsOptional("LR_SetLastRequestStatus");
	MarkNativeAsOptional("LR_StopLastRequest");
}
#endif
