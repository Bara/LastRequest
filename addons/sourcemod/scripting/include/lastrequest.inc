#if defined _lr_included
  #endinput
#endif
#define _lr_included

#include <cstrike>
#include <sdktools>

#define LR_MAX_SHORTNAME_LENGTH 32
#define LR_MAX_FULLNAME_LENGTH 64
#define LR_LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(LR_IsClientValid(%1))
#define LR_BASE_NAME "Last Request"
#define LR_PLUGIN_NAME "Last Request - "

enum LR_End_Reason {
    Server = -3,
    Admin = -2,
    Tie = -1,
    Unknown = 0,
    Normal = 1
}

/*
 * Requester is mostly the last T and opponent is the choosed CT by the T.
 * Short Name will be required for games with subgames like knife fight with different modes.
 * Note: If you return something other than Plugin_Continue, you must trigger LR_StartLastRequest
 *       Example: Soon
 */
typedef LRPreStartCB = function Action (int requester, int opponent, const char[] shortname);
typedef LRStartCB = function void (int requester, int opponent, const char[] shortname);
typedef LREndCB = function void (LR_End_Reason reason, int winner, int loser);

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
native bool LR_RegisterGame(const char[] shortname, const char[] fullname, LRPreStartCB preStartCallback, LRStartCB startCallback, LREndCB endCallback);

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
native void LR_StopLastRequest(LR_End_Reason reason, int winner = -1, int loser = -1);

/*
 * Firing last restart start
 */
native void LR_StartLastRequest(int requester, char[] mode, char[] weapon, int health = 100, int armor = 0, bool helm = false);

native int LR_GetMenuTime();
native bool LR_IsDebugActive();
native void LR_MenuTimeout(int client);
native bool LR_RemovePlayerWeapon(int client, int weapon);

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

stock void LR_SetHealthKevlarHelm(int client, int target, int health, int kevlar, bool helm)
{
    SetEntityHealth(client, health);
    SetEntProp(client, Prop_Data, "m_ArmorValue", kevlar);
    SetEntProp(client, Prop_Send, "m_bHasHelmet", helm);

    if (target > 0)
    {
        SetEntityHealth(target, health);
        SetEntProp(target, Prop_Data, "m_ArmorValue", kevlar);
        SetEntProp(target, Prop_Send, "m_bHasHelmet", helm);
    }
}

stock int LR_GivePlayerItem(int client, const char[] classname)
{
    int iWeapon = GivePlayerItem(client, classname);
    EquipPlayerWeapon(client, iWeapon);

    RequestFrame(Frame_RefreshVM, GetClientUserId(client));
    
    return iWeapon;
}

public void Frame_RefreshVM(int userid)
{
    int client = GetClientOfUserId(userid);

    if (!LR_IsClientValid(client))
    {
        return;
    }

    if (!IsPlayerAlive(client))
    {
        return;
    }

    Event eEvent = CreateEvent("player_spawn", true);

    if (eEvent == null)
    {
        return;
    }

    eEvent.SetInt("userid", GetClientUserId(client));
    eEvent.FireToClient(client);
    eEvent.Cancel();
} 

stock bool LR_SetWeaponAmmo(int client, int weapon, int clip, int ammo = 0, bool giveWeapon = false) // TODO Make it dynamically, when someone adds a primary it doesn't work.
{
    for(int i = 0; i < GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons"); i++)
    {
        int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);

        if (IsValidEntity(weapon) && iWeapon == weapon)
        {
            if (clip > -1)
            {
                SetEntProp(iWeapon, Prop_Send, "m_iClip1", clip);
            }
            
            if (ammo > -1)
            {
                SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo);
            }

            return true;
        }
    }

    return false;
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
