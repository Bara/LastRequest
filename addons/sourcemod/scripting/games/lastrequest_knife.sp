#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <lastrequest>
#include <autoexecconfig>

#define LR_NAME "Knife Fight" // TODO: Replace this with a string buffer
#define LR_SHORT  "knifeFight"
#define PLUGIN_NAME "Last Request - " ... LR_NAME

enum struct Modes
{
    bool Normal;
    bool Backstab;
    bool LowHP;
    bool Drunk; // TODO: Need Test
    bool LowGrav; // TODO Need Test
    bool HighSpeed; // TODO Need Test
    bool Drugs; // TODO Need Test
    bool ThirdPerson; // TODO Need Test

    void Reset() {
        this.Normal = false;
        this.Backstab = false;
        this.LowHP = false;
        this.Drunk = false;
        this.LowGrav = false;
        this.HighSpeed = false;
        this.Drugs = false;
        this.ThirdPerson = false;
    }
}

enum struct Configs {
    ConVar Normal;
    ConVar Backstab;
    ConVar LowHP;
    ConVar Drunk;
    ConVar LowGrav;
    ConVar GravValue;
    ConVar HighSpeed;
    ConVar SpeedValue;
    ConVar Drugs;
    ConVar ThirdPerson;
}

enum struct PlayerData {
    float Speed;
    float Gravity;
}

Modes Mode;
Configs Config;
PlayerData Player[MAXPLAYERS + 1];

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
    Config.Normal = AutoExecConfig_CreateConVar("knife_normal_mode_enable", "1", "Enable or disable Normal mode?", _, true, 0.0, true, 1.0);
    Config.Backstab = AutoExecConfig_CreateConVar("knife_backstab_mode_enable", "1", "Enable or disable Backstab mode?", _, true, 0.0, true, 1.0);
    Config.LowHP = AutoExecConfig_CreateConVar("knife_35hp_mode_enable", "1", "Enable or disable 35HP mode?", _, true, 0.0, true, 1.0);
    Config.Drunk = AutoExecConfig_CreateConVar("knife_drunk_mode_enable", "1", "Enable or disable Drunk mode?", _, true, 0.0, true, 1.0);
    Config.LowGrav = AutoExecConfig_CreateConVar("knife_lowgrav_mode_enable", "1", "Enable or disable LowGrav mode?", _, true, 0.0, true, 1.0);
    Config.GravValue = AutoExecConfig_CreateConVar("knife_lowgrav_value", "0.6", "Set gravity value for low gravity mode. Default is 0.6 and general default is 1.0", _, true, 0.1, true, 1.0);
    Config.HighSpeed = AutoExecConfig_CreateConVar("knife_highspeed_mode_enable", "1", "Enable or disable HighSpeed mode?", _, true, 0.0, true, 1.0);
    Config.GravValue = AutoExecConfig_CreateConVar("knife_highspeed_value", "2.2", "Set speed value for high speed mode. Default is 2.2 and general default is 1.0", _, true, 1.1);
    Config.Drugs = AutoExecConfig_CreateConVar("knife_drugs_mode_enable", "1", "Enable or disable Drugs mode?", _, true, 0.0, true, 1.0);
    Config.ThirdPerson = AutoExecConfig_CreateConVar("knife_thirdperson_mode_enable", "1", "Enable or disable ThirdPerson mode?", _, true, 0.0, true, 1.0);
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
    Player[requester].Speed = 0.0;
    Player[opponent].Gravity = 0.0;

    Menu menu = new Menu(Menu_ModeSelection);
    menu.SetTitle("Select knife mode"); // TODO: Add translation

    if (Config.Normal.BoolValue)
    {
        menu.AddItem("normal", "Normal"); // TODO: Add translation
    }

    if (Config.Backstab.BoolValue)
    {
        menu.AddItem("backstab", "Backstab"); // TODO: Add translation
    }

    if (Config.LowHP.BoolValue)
    {
        menu.AddItem("35hp", "35 HP"); // TODO: Add translation
    }

    if (Config.Drunk.BoolValue)
    {
        menu.AddItem("drunk", "Drunk"); // TODO: Add translation
    }

    if (Config.LowGrav.BoolValue)
    {
        menu.AddItem("lowgrav", "LowGrav"); // TODO: Add translation
    }

    if (Config.HighSpeed.BoolValue)
    {
        menu.AddItem("highspeed", "HighSpeed"); // TODO: Add translation
    }

    if (Config.Drugs.BoolValue)
    {
        menu.AddItem("drugs", "Drugs"); // TODO: Add translation
    }

    if (Config.ThirdPerson.BoolValue)
    {
        menu.AddItem("thirdperson", "ThirdPerson"); // TODO: Add translation
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
        else if (StrEqual(sParam, "drunk", false))
        {
            Mode.Drunk = true;
        }
        else if (StrEqual(sParam, "lowgrav", false))
        {
            Mode.LowGrav = true;
        }
        else if (StrEqual(sParam, "highspeed", false))
        {
            Mode.HighSpeed = true;
        }
        else if (StrEqual(sParam, "drugs", false))
        {
            Mode.Drugs = true;
        }
        else if (StrEqual(sParam, "thirdperson", false))
        {
            Mode.ThirdPerson = true;
        }

        if (!Mode.LowHP)
        {
            LR_StartLastRequest(client, sDisplay, "Knife"); // TODO: Add translation
        }
        else
        {
            LR_StartLastRequest(client, sDisplay, "Knife", 35); // TODO: Add translation
        }
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
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
    SDKHook(target, SDKHook_TraceAttack, OnTraceAttack);
    SDKHook(client, SDKHook_Think, OnThink);
    SDKHook(target, SDKHook_Think, OnThink);

    if (Mode.Drunk)
    {
        SetDrunk(client, true);
        SetDrunk(target, true);
    }

    if (Mode.ThirdPerson)
    {
        SetThirdPerson(client, true);
        SetThirdPerson(target, true);
    }

    if (Mode.Drugs)
    {
        SetDrugs(client, true);
        SetDrugs(target, true);
    }

    if (Mode.HighSpeed)
    {
        Player[client].Speed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
        Player[target].Speed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");

        SetSpeed(client, true);
        SetSpeed(target, true);
    }

    if (Mode.LowGrav)
    {
        Player[client].Gravity = GetEntityGravity(client);
        Player[target].Gravity = GetEntityGravity(client);

        SetGravity(client, true);
        SetGravity(target, true);
    }
    
    int iKnife1 = GivePlayerItem(client, "weapon_knife");
    int iKnife2 = GivePlayerItem(target, "weapon_knife");
    
    EquipPlayerWeapon(client, iKnife1);
    EquipPlayerWeapon(target, iKnife2);
}

public void OnGameEnd(LR_End_Reason reason, int winner, int loser)
{
    if (winner != -1)
    {
        SDKUnhook(winner, SDKHook_TraceAttack, OnTraceAttack);
        SDKUnhook(winner, SDKHook_Think, OnThink);

        SetDrunk(winner, false);
        SetThirdPerson(winner, false);
        SetDrugs(winner, false);
    }

    if (loser != -1)
    {
        SDKUnhook(loser, SDKHook_TraceAttack, OnTraceAttack);
        SDKUnhook(loser, SDKHook_Think, OnThink);

        SetDrunk(loser, false);
        SetThirdPerson(loser, false);
        SetDrugs(loser, false);
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

public void OnThink(int client)
{
    if (!LR_IsClientInLastRequest(client))
    {
        return;
    }

    if (Mode.Drunk)
    {
        SetDrunk(client, true);
    }

    if (Mode.ThirdPerson)
    {
        SetThirdPerson(client, true);
    }

    if (Mode.Drugs)
    {
        SetDrugs(client, true);
    }

    if (Mode.HighSpeed)
    {
        SetSpeed(client, true);
    }

    if (Mode.LowGrav)
    {
        SetGravity(client, true);
    }
}

void SetDrunk(int client, bool drunk)
{
    if (drunk)
    {
        SetEntProp(client, Prop_Send, "m_iFOV", 105);
        SetEntProp(client, Prop_Send, "m_iDefaultFOV", 105);

        ClientCommand(client, "r_screenoverlay \"effects/strider_pinch_dudv\"");
    }
    else
    {
        SetEntProp(client, Prop_Send, "m_iFOV", 90);
        SetEntProp(client, Prop_Send, "m_iDefaultFOV", 90);
    }
}

void SetThirdPerson(int client, bool third)
{
    if (third)
    {
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);

        SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
        SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
        SetEntProp(client, Prop_Send, "m_iFOV", 120);
        SetEntProp(client, Prop_Send, "m_iDefaultFOV", 120);
    }
    else
    {
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 1);

        SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
        SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
        SetEntProp(client, Prop_Send, "m_iFOV", 90);
        SetEntProp(client, Prop_Send, "m_iDefaultFOV", 90);
    }
}

void SetDrugs(int client, bool drugs)
{
    if (drugs)
    {
        ServerCommand("sm_drug #%d 1", GetClientUserId(client));
    }
    else
    {
        ServerCommand("sm_drug #%d 0", GetClientUserId(client));
    }
}

void SetSpeed(int client, bool speed)
{
    if (speed)
    {
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", Config.SpeedValue.FloatValue);
    }
    else
    {
        if (Player[client].Speed < 0.1)
        {
            SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
        }
        else
        {
            SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", Player[client].Speed);
        }
    }
}


void SetGravity(int client, bool gravity)
{
    if (gravity)
    {
        SetEntityGravity(client, Config.GravValue.FloatValue);
    }
    else
    {
        if (Player[client].Gravity < 0.1)
        {
            SetEntityGravity(client, 1.0);
        }
        else
        {
            SetEntityGravity(client, Player[client].Gravity);
        }
    }
}
