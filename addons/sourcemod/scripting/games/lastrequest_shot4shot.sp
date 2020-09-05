#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <lastrequest>
#include <autoexecconfig>

#define LR_NAME "Shot 4 Shot" // TODO: Replace this with a string buffer
#define LR_SHORT  "shot4shot"

enum struct General
{
    ConVar Enable;
    ConVar Debug;
    ConVar Knife;
    ConVar Drop;

    char Weapon[32];

    bool Active;

    void Reset() {
        this.Weapon[0] = '\0';

        this.Active = false;
    }
}

enum struct PlayerData {
    int Weapon;

    void Reset() {
        this.Weapon = -1;
    }
}

General Core;
PlayerData Player[MAXPLAYERS + 1];

StringMap g_smWeapons = null;

public Plugin myinfo =
{
    name = LR_PLUGIN_NAME ... LR_NAME,
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara"
};

public void OnPluginStart()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("shot4shot", "lastrequest");
    Core.Enable = AutoExecConfig_CreateConVar("shot4shot_enable", "1", "Enable or disable shot 4 shot?", _, true, 0.0, true, 1.0);
    Core.Knife = AutoExecConfig_CreateConVar("shot4shot_give_knife", "1", "Give players a knife too?", _, true, 0.0, true, 1.0);
    Core.Drop = AutoExecConfig_CreateConVar("shot4shot_block_drop", "1", "Block weapon drop during active shot4shot?",_, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    HookEvent("weapon_fire", Event_WeaponFire);
}

public void OnConfigsExecuted()
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/lastrequest/shot4shot_weapons.ini");

    if (!FileExists(sFile))
    {
        SetFailState("Can not found the following file: \"%s\"", sFile);
        return;
    }

    KeyValues kvConfig = new KeyValues("Weapons");

    if (!kvConfig.ImportFromFile(sFile))
    {
        SetFailState("Can not read from the following file: \"%s\"", sFile);
        return;
    }

    Core.Debug = FindConVar("lastrequest_debug");

    delete g_smWeapons;
    g_smWeapons = new StringMap();

    if (kvConfig.GotoFirstSubKey(false))
    {
        char sClass[32];
        char sName[64];

        int iCount = 0;

        do
        {
            kvConfig.GetSectionName(sClass, sizeof(sClass));
            kvConfig.GetString(NULL_STRING, sName, sizeof(sName));

            if (strlen(sClass) > 1 && strlen(sName) > 1)
            {
                if (Core.Debug.BoolValue)
                {
                    LogMessage("Adding %s (Class: %s) to weapon stringmap.", sName, sClass);
                }

                g_smWeapons.SetString(sClass, sName, true);
                iCount++;
            }
        }
        while (kvConfig.GotoNextKey(false));

        if (iCount == 0)
        {
            SetFailState("[Shot 4 Shot] No weapons found!");
            return;
        }
    }

    delete kvConfig;

    if (!LR_RegisterGame(LR_SHORT, LR_NAME, OnGamePreStart, OnGameStart, OnGameEnd))
    {
        SetFailState("Can't register last request: %s", LR_SHORT);
        return;
    }
}

public void LR_OnOpenMenu(Menu menu)
{
    if (Core.Enable.BoolValue)
    {
        menu.AddItem(LR_SHORT, "Shot 4 Shot"); // TODO: Add translation
    }
}

public Action OnGamePreStart(int requester, int opponent, const char[] shortname)
{
    Menu menu = new Menu(Menu_WeaponSelection);
    menu.SetTitle("Select weapon"); // TODO: Add translation

    if (Core.Enable.BoolValue)
    {
        StringMapSnapshot snap = g_smWeapons.Snapshot();

        char sName[32], sClass[32];

        for (int i = 0; i < snap.Length; i++)
        {
            snap.GetKey(i, sClass, sizeof(sClass));
            g_smWeapons.GetString(sClass, sName, sizeof(sName));
            menu.AddItem(sClass, sName);
        }

        delete snap;
    }

    menu.ExitBackButton = false;
    menu.ExitButton = false;
    menu.Display(requester, LR_GetMenuTime());
}

public int Menu_WeaponSelection(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sClass[32], sDisplay[32];
        menu.GetItem(param, sClass, sizeof(sClass), _, sDisplay, sizeof(sDisplay));

        strcopy(Core.Weapon, sizeof(General::Weapon), sClass);

        LR_StartLastRequest(client, "Normal", sDisplay); // TODO: Add translation
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Timeout)
        {
            LR_MenuTimeout(client);
        }
    }	
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public void OnGameStart(int client, int target, const char[] name)
{
    if (Core.Knife.BoolValue)
    {
        GivePlayerItem(client, "weapon_knife");
        GivePlayerItem(target, "weapon_knife");
    }

    Core.Active = true;

    int iRandom = GetRandomInt(0, 1);

    int iWeapon = LR_GivePlayerItem(client, Core.Weapon);
    LR_SetWeaponAmmo(client, iWeapon, iRandom ? 1 : 0);
    Player[client].Weapon = EntIndexToEntRef(iWeapon);

    iWeapon = LR_GivePlayerItem(target, Core.Weapon);
    LR_SetWeaponAmmo(target, iWeapon, iRandom ? 0 : 1);
    Player[target].Weapon = EntIndexToEntRef(iWeapon);

    SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
    SDKHook(target, SDKHook_WeaponDrop, OnWeaponDrop);
}

public Action OnWeaponDrop(int client, int weapon)
{
    if (!Core.Active)
    {
        return Plugin_Continue;
    }

    if (!LR_IsClientInLastRequest(client))
    {
        return Plugin_Continue;
    }

    int iWeapon = EntRefToEntIndex(Player[client].Weapon);

    if (weapon == iWeapon)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    if (!Core.Active)
    {
        return;
    }
    
    if (Core.Debug.BoolValue)
    {
        PrintToChatAll("Event_WeaponFire 1");
    }
    
    if (strlen(Core.Weapon) < 2)
    {
        return;
    }

    if (Core.Debug.BoolValue)
    {
        PrintToChatAll("Event_WeaponFire 2");
    }
    

    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!LR_IsClientValid(client))
    {
        return;
    }

    if (Core.Debug.BoolValue)
    {
        PrintToChatAll("Event_WeaponFire 3");
    }
    

    if (!LR_IsClientInLastRequest(client))
    {
        return;
    }

    if (Core.Debug.BoolValue)
    {
        PrintToChatAll("Event_WeaponFire 4");
    }
    

    char sWeapon[32];
    event.GetString("weapon", sWeapon, sizeof(sWeapon));

    if (StrContains(Core.Weapon, sWeapon, false) != -1)
    {
        if (Core.Debug.BoolValue)
        {
            PrintToChatAll("Event_WeaponFire 5");
        }
    
        RequestFrame(Frame_SetAmmo, GetClientUserId(LR_GetClientOpponent(client)));
    }
}

public void Frame_SetAmmo(int userid)
{
    int iTarget = GetClientOfUserId(userid);

    if (LR_IsClientValid(iTarget) && IsPlayerAlive(iTarget))
    {
        if (Core.Debug.BoolValue)
        {
            PrintToChatAll("%N ammo set to 1", iTarget);
        }

        LR_SetWeaponAmmo(iTarget, EntRefToEntIndex(Player[iTarget].Weapon), 1);
    }
}

public void OnGameEnd(LR_End_Reason reason, int winner, int loser)
{
    Core.Reset();
    
    if (winner > 0)
    {
        SDKHook(winner, SDKHook_WeaponDrop, OnWeaponDrop);
        Player[winner].Reset();
    }

    if (loser > 0)
    {
        SDKHook(loser, SDKHook_WeaponDrop, OnWeaponDrop);
        Player[loser].Reset();
    }
}
