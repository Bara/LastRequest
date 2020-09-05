#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <lastrequest>
#include <autoexecconfig>

#define LR_NAME "Gun Toss" // TODO: Replace this with a string buffer
#define LR_SHORT  "guntoss"

enum struct General
{
    ConVar Enable;
    ConVar Debug;
    ConVar Knife;
    ConVar Unit;
    ConVar Interval;

    char Weapon[32];

    bool Active;

    void Reset() {
        this.Weapon[0] = '\0';

        this.Active = false;
    }
}

enum struct PlayerData {
    int Weapon;

    float Start[3];
    float End[3];
    float FinalEnd[3];

    float Distance;

    bool Dropped;

    void Reset() {
        this.Weapon = -1;

        this.Start = NULL_VECTOR;
        this.End = NULL_VECTOR;
        this.FinalEnd = NULL_VECTOR;

        this.Distance = 0.0;

        this.Dropped = false;
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
    AutoExecConfig_SetFile("guntoss", "lastrequest");
    Core.Enable = AutoExecConfig_CreateConVar("guntoss_enable", "1", "Enable or disable gun toss?", _, true, 0.0, true, 1.0);
    Core.Knife = AutoExecConfig_CreateConVar("guntoss_give_knife", "1", "Give players a knife too?", _, true, 0.0, true, 1.0);
    Core.Unit = AutoExecConfig_CreateConVar("guntoss_unit", "0", "Show throwed distance in 0 - Units, 1 - Meters, 2 - Feet", _, true, 0.0, true, 2.0);
    Core.Interval = AutoExecConfig_CreateConVar("guntoss_interval", "5", "Check interval after weapon drop. (Default: 3)", _, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    
    AddCommandListener(Command_Drop, "drop");
}

public void OnConfigsExecuted()
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/lastrequest/guntoss_weapons.ini");

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
            SetFailState("[Gun Toss] No weapons found!");
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
        menu.AddItem(LR_SHORT, "Gun Toss"); // TODO: Add translation
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

    int iWeapon = LR_GivePlayerItem(client, Core.Weapon);
    Player[client].Weapon = EntIndexToEntRef(iWeapon);

    LR_GivePlayerItem(target, Core.Weapon);
    Player[target].Weapon = EntIndexToEntRef(iWeapon);

    Core.Active = true;

    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public Action Command_Drop(int client, const char[] command, int args)
{
    if (!Core.Active && !LR_IsClientInLastRequest(client))
    {
        return Plugin_Continue;
    }

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    if (weapon != EntRefToEntIndex(Player[client].Weapon))
    {
        return Plugin_Continue;
    }

    GetClientAbsOrigin(client, Player[client].Start);
    Player[client].Dropped = true;

    CreateTimer(Core.Interval.FloatValue, Timer_CheckPosition, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon)
{
    if (Core.Active && LR_IsClientInLastRequest(client) && Player[client].Dropped)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Timer_CheckPosition(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!LR_IsClientValid(client))
    {
        LR_StopLastRequest(Server);
        return Plugin_Stop;
    }

    int iWeapon = EntRefToEntIndex(Player[client].Weapon);

    if (!IsValidEntity(iWeapon))
    {
        LR_StopLastRequest(Server);
        return Plugin_Stop;
    }

    GetEntPropVector(iWeapon, Prop_Send, "m_vecOrigin", Player[client].FinalEnd);

    if (!IsNullVector(Player[client].End) && GetVectorDistance(Player[client].End, Player[client].FinalEnd) > 3.0)
    {
        Player[client].Distance = GetVectorDistance(Player[client].End, Player[client].FinalEnd);

        LR_LoopClients(i)
        {
            char sDistance[18];

            if (Core.Unit.IntValue == 0)
            {
                Format(sDistance, sizeof(sDistance), "%.2f units", Player[client].Distance);
            }
            else if (Core.Unit.IntValue == 1)
            {
                Format(sDistance, sizeof(sDistance), "%.2f meters", Player[client].Distance * 0.01905);
            }
            else if (Core.Unit.IntValue == 2)
            {
                Format(sDistance, sizeof(sDistance), "%.2f feets", (Player[client].Distance * 0.01905) * 3.2808399);
            }

            PrintToChat(i, "%N throwed a distance of %s!", client, sDistance);
        }

        CheckPlayers(client);

        return Plugin_Stop;
    }

    GetEntPropVector(iWeapon, Prop_Send, "m_vecOrigin", Player[client].End);

    return Plugin_Continue;
}

void CheckPlayers(int client)
{
    int target = LR_GetClientOpponent(client);

    if (!LR_IsClientValid(target))
    {
        LR_StopLastRequest(Unknown, client, target);
    }

    if (Player[target].Distance <= 0.0)
    {
        return;
    }

    if (Player[client].Distance > Player[target].Distance)
    {
        LR_StopLastRequest(Normal, client, target);
    }
    else if (Player[target].Distance > Player[client].Distance)
    {
        LR_StopLastRequest(Normal, target, client);
    }
    else
    {
        LR_StopLastRequest(Tie);
    }
}

public void OnGameEnd(LR_End_Reason reason, int winner, int loser)
{
    Core.Reset();
    
    if (winner > 0)
    {
        Player[winner].Reset();
    }

    if (loser > 0)
    {
        Player[loser].Reset();
    }
}
