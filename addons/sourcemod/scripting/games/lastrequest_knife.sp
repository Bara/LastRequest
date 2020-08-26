#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <lastrequest>
#include <autoexecconfig>

#define LR_NAME "Knife Fight"
#define LR_SHORT  "knifeFight"
#define PLUGIN_NAME "Last Request - " ... LR_NAME

enum struct Modes
{
    bool Normal;
    bool Backstab;
    bool LowHP;

    void Reset() {
        this.Normal = false;
        this.Backstab = false;
        this.LowHP = false;
    }
}

enum struct Configs {
    ConVar Normal;
    ConVar Backstab;
    ConVar LowHP;
}

Modes Mode;
Configs Config;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara"
};

public void OnPluginStart()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("knife", "lastrequest");
    Config.Normal = AutoExecConfig_CreateConVar("knife_enable_normal_mode", "1", "Enable or disable normal knife mode?", _, true, 0.0, true, 1.0);
    Config.Backstab = AutoExecConfig_CreateConVar("knife_enable_backstab_mode", "1", "Enable or disable backstab knife mode?", _, true, 0.0, true, 1.0);
    Config.LowHP = AutoExecConfig_CreateConVar("knife_enable_35hp_mode", "1", "Enable or disable 35hp knife mode?", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

public void OnConfigsExecuted()
{
    if (!LR_RegisterGame(LR_SHORT, LR_NAME, OnGamePreStart, OnGameStart, OnGameEnd))
    {
        SetFailState("Can't register last request: %s", LR_SHORT);
        return;
    }
}

public void LR_OnOpenMenu(Menu menu)
{
    menu.AddItem(LR_SHORT, "Knife Fight"); // TODO: Add translation
}

public Action OnGamePreStart(int requester, int opponent, const char[] shortname)
{
    Menu menu = new Menu(Menu_ModeSelection);
    menu.SetTitle("Select knife mode");

    if (Config.Normal.BoolValue)
    {
        menu.AddItem("normal", "Normal");
    }

    if (Config.Backstab.BoolValue)
    {
        menu.AddItem("backstab", "Backstab");
    }

    if (Config.LowHP.BoolValue)
    {
        menu.AddItem("35hp", "35 HP");
    }

    menu.ExitBackButton = false;
    menu.ExitButton = false;
    menu.Display(requester, LR_GetMenuTime());
}

public int Menu_ModeSelection(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12], sDisplay[24];
        menu.GetItem(param, sParam, sizeof(sParam), _, sDisplay, sizeof(sDisplay));

        Mode.Reset();

        if (StrEqual(sParam, "normal", false))
        {
            Mode.Normal = true;
        }
        else if (StrEqual(sParam, "backstab", false))
        {
            Mode.Backstab = true;
        }
        else if (StrEqual(sParam, "35hp", false))
        {
            Mode.LowHP = true;
        }

        LR_StartLastRequest(client, sDisplay, "Knife");
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Timeout)
        {
            PrintToChatAll("MenuCancel_Timeout %N", client); // TODO: Add message/translation or debug?

            if (LR_GetTimeoutPunishment() == 1)
            {
                ForcePlayerSuicide(client);
            }
            else if (LR_GetTimeoutPunishment() == 2)
            {
                KickClient(client, "You was kicked due afk during menu selection."); // TODO: Add translation
            }
        }
    }	
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public void OnGameStart(int client, int target, const char[] name)
{
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
    SDKHook(target, SDKHook_TraceAttack, OnTraceAttack);
    
    LR_StripAllWeapons(client, target);

    SetHealthKevlarHelm(client, target, 100, 0, false);

    if (Mode.LowHP)
    {
        SetHealthKevlarHelm(client, target, 35, 0, false);
    }
    
    int iKnife1 = GivePlayerItem(client, "weapon_knife");
    int iKnife2 = GivePlayerItem(target, "weapon_knife");
    
    EquipPlayerWeapon(client, iKnife1);
    EquipPlayerWeapon(target, iKnife2);
}

public void OnGameEnd(int winner, int loser)
{
    if (winner != -1)
    {
        SDKUnhook(winner, SDKHook_TraceAttack, OnTraceAttack);
    }

    if (loser != -1)
    {
        SDKUnhook(loser, SDKHook_TraceAttack, OnTraceAttack);
    }
    
    Mode.Reset();
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if (damagetype == DMG_FALL || attacker == 0)
    {
        return Plugin_Continue;
    }
    
    if (!LR_IsClientValid(attacker) || !LR_IsClientValid(victim))
    {
        return Plugin_Handled;
    }
    
    if (!LR_IsClientInLastRequest(attacker) || !LR_IsClientInLastRequest(victim))
    {
        return Plugin_Handled;
    }
    
    char sWeapon[32];
    GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
    
    if ((StrContains(sWeapon, "knife", false) != -1) || (StrContains(sWeapon, "bayonet", false) != -1))
    {
        if (Mode.Normal || Mode.LowHP)
        {
            return Plugin_Continue;
        }
        else if (Mode.Backstab)
        {
            float fAAngle[3], fVAngle[3], fBAngle[3];
            
            GetClientAbsAngles(victim, fVAngle);
            GetClientAbsAngles(attacker, fAAngle);
            MakeVectorFromPoints(fVAngle, fAAngle, fBAngle);
            
            if (fBAngle[1] > -90.0 && fBAngle[1] < 90.0)
            {
                return Plugin_Continue;
            }
        }
    }
    
    return Plugin_Handled;
}
