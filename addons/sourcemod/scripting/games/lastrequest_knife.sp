#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <lastrequest>
#include <autoexecconfig>

#define LR_NAME "Knife Fight" // TODO: Replace this with a string buffer
#define LR_SHORT  "knifeFight"

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
    bool OldTP;

    UserMsg Fade;

    void Reset() {
        this.Normal = false;
        this.Backstab = false;
        this.LowHP = false;
        this.Drunk = false;
        this.LowGrav = false;
        this.HighSpeed = false;
        this.Drugs = false;
        this.ThirdPerson = false;
        this.OldTP = false;
    }
}

enum struct Configs {
    ConVar Normal;
    ConVar Backstab;
    ConVar LowHP;
    ConVar Drunk;
    ConVar DrunkMultiplier;
    ConVar LowGrav;
    ConVar GravValue;
    ConVar HighSpeed;
    ConVar SpeedValue;
    ConVar Drugs;
    ConVar ThirdPerson;
    ConVar EnableTP;
}

enum struct PlayerData {
    float Speed;
    float Gravity;

    void Reset() {
        this.Speed = 0.0;
        this.Gravity = 0.0;
    }
}

Modes Mode;
Configs Config;
PlayerData Player[MAXPLAYERS + 1];

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
    AutoExecConfig_SetFile("knife", "lastrequest");
    Config.Normal = AutoExecConfig_CreateConVar("knife_normal_mode_enable", "1", "Enable or disable Normal mode?", _, true, 0.0, true, 1.0);
    Config.Backstab = AutoExecConfig_CreateConVar("knife_backstab_mode_enable", "1", "Enable or disable Backstab mode?", _, true, 0.0, true, 1.0);
    Config.LowHP = AutoExecConfig_CreateConVar("knife_35hp_mode_enable", "1", "Enable or disable 35HP mode?", _, true, 0.0, true, 1.0);
    Config.Drunk = AutoExecConfig_CreateConVar("knife_drunk_mode_enable", "1", "Enable or disable Drunk mode?", _, true, 0.0, true, 1.0);
    Config.DrunkMultiplier = AutoExecConfig_CreateConVar("knife_drunk_mode_multiplier", "4.0", "The multiplier used for how drunk the player will be during the drunken boxing knife fight.", _, true, 0.0);
    Config.LowGrav = AutoExecConfig_CreateConVar("knife_lowgrav_mode_enable", "1", "Enable or disable LowGrav mode?", _, true, 0.0, true, 1.0);
    Config.GravValue = AutoExecConfig_CreateConVar("knife_lowgrav_value", "0.6", "Set gravity value for low gravity mode. Default is 0.6 and general default is 1.0", _, true, 0.1, true, 1.0);
    Config.HighSpeed = AutoExecConfig_CreateConVar("knife_highspeed_mode_enable", "1", "Enable or disable HighSpeed mode?", _, true, 0.0, true, 1.0);
    Config.SpeedValue = AutoExecConfig_CreateConVar("knife_highspeed_value", "2.2", "Set speed value for high speed mode. Default is 2.2 and general default is 1.0", _, true, 1.1);
    Config.Drugs = AutoExecConfig_CreateConVar("knife_drugs_mode_enable", "1", "Enable or disable Drugs mode?", _, true, 0.0, true, 1.0);
    Config.ThirdPerson = AutoExecConfig_CreateConVar("knife_thirdperson_mode_enable", "1", "Enable or disable ThirdPerson mode?", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    Mode.Fade = GetUserMessageId("Fade");
}

public void OnMapStart()
{
    AddFileToDownloadsTable("materials/effects/strider_pinch_dudv.vtf");
    AddFileToDownloadsTable("materials/effects/strider_pinch_dudv.vmt");
    AddFileToDownloadsTable("materials/effects/strider_pinch_dudv_dx60.vmt");
    AddFileToDownloadsTable("materials/effects/strider_bulge_dudv_dx60.vmt");
    AddFileToDownloadsTable("materials/effects/strider_pinch_dx70.vtf");
    AddFileToDownloadsTable("materials/effects/strider_pinch_normal.vtf");
}

public void OnConfigsExecuted()
{
    if (!LR_RegisterGame(LR_SHORT, LR_NAME, OnGamePreStart, OnGameStart, OnGameEnd))
    {
        SetFailState("Can't register last request: %s", LR_SHORT);
        return;
    }

    Config.EnableTP = FindConVar("sv_allow_thirdperson");
}

public void LR_OnOpenMenu(Menu menu)
{
    menu.AddItem(LR_SHORT, "Knife Fight"); // TODO: Add translation
}

public Action OnGamePreStart(int requester, int opponent, const char[] shortname)
{
    Player[requester].Reset();
    Player[opponent].Reset();

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

        DataPack pack = new DataPack();
        pack.WriteCell(GetClientUserId(client));
        pack.WriteCell(GetClientUserId(target));
        CreateTimer(1.0, Timer_SetDrunk, pack, TIMER_FLAG_NO_MAPCHANGE);
    }

    if (Mode.ThirdPerson)
    {
        Mode.OldTP = Config.EnableTP.BoolValue;
        Config.EnableTP.SetBool(true);

        SetThirdPerson(client, true);
        SetThirdPerson(target, true);
    }

    if (Mode.Drugs)
    {
        DataPack pack = new DataPack();
        pack.WriteCell(GetClientUserId(client));
        pack.WriteCell(GetClientUserId(target));
        CreateTimer(1.0, Timer_SetDrugs, pack, TIMER_FLAG_NO_MAPCHANGE);
    }

    if (Mode.HighSpeed)
    {
        Player[client].Speed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
        Player[target].Speed = GetEntPropFloat(target, Prop_Data, "m_flLaggedMovementValue");

        SetSpeed(client, true);
        SetSpeed(target, true);
    }

    if (Mode.LowGrav)
    {
        Player[client].Gravity = GetEntityGravity(client);
        Player[target].Gravity = GetEntityGravity(target);

        SetGravity(client, true);
        SetGravity(target, true);
    }
    
    GivePlayerItem(client, "weapon_knife");
    GivePlayerItem(target, "weapon_knife");
}

public void OnGameEnd(LR_End_Reason reason, int winner, int loser)
{
    if (winner > 0)
    {
        SDKUnhook(winner, SDKHook_TraceAttack, OnTraceAttack);
        SDKUnhook(winner, SDKHook_Think, OnThink);

        SetDrunk(winner, false);
        SetThirdPerson(winner, false);
    }

    if (loser > 0)
    {
        SDKUnhook(loser, SDKHook_TraceAttack, OnTraceAttack);
        SDKUnhook(loser, SDKHook_Think, OnThink);

        SetDrunk(loser, false);
        SetThirdPerson(loser, false);
    }
    
    Config.EnableTP.SetBool(Mode.OldTP);
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
        if (Mode.Backstab)
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
        else
        {
            return Plugin_Continue; // TODO: Is this okay?
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
        SetEntProp(client, Prop_Send, "m_iFOV", 110);
        SetEntProp(client, Prop_Send, "m_iDefaultFOV", 110);

        ClientCommand(client, "r_screenoverlay \"effects/strider_pinch_dudv\"");
    }
    else
    {
        SetEntProp(client, Prop_Send, "m_iFOV", 90);
        SetEntProp(client, Prop_Send, "m_iDefaultFOV", 90);

        ClientCommand(client, "r_screenoverlay \"\"");
    }
}

void SetThirdPerson(int client, bool third)
{
    if (third)
    {
        ClientCommand(client, "thirdperson");
    }
    else
    {
        ClientCommand(client, "firstperson");
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

public Action Timer_SetDrunk(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    int target = GetClientOfUserId(pack.ReadCell());
    delete pack;

    if (Mode.Drunk && LR_IsClientValid(client) && LR_IsClientInLastRequest(client) && LR_IsClientValid(target) && LR_IsClientInLastRequest(target))
    {
        float fPunch[3];
        switch (GetRandomInt(1, 160) % 4)
        {
            case 0:
            {
                fPunch[0] = Config.DrunkMultiplier.FloatValue * 5.0;
                fPunch[1] = Config.DrunkMultiplier.FloatValue * 5.0;
                fPunch[2] = Config.DrunkMultiplier.FloatValue * -5.0;
            }
            case 1:
            {
                fPunch[0] = Config.DrunkMultiplier.FloatValue * -5.0;
                fPunch[1] = Config.DrunkMultiplier.FloatValue * -5.0;
                fPunch[2] = Config.DrunkMultiplier.FloatValue * 5.0;
            }
            case 2:
            {
                fPunch[0] = Config.DrunkMultiplier.FloatValue * 5.0;
                fPunch[1] = Config.DrunkMultiplier.FloatValue * -5.0;
                fPunch[2] = Config.DrunkMultiplier.FloatValue * 5.0;
            }
            case 3:
            {
                fPunch[0] = Config.DrunkMultiplier.FloatValue * -5.0;
                fPunch[1] = Config.DrunkMultiplier.FloatValue * 5.0;
                fPunch[2] = Config.DrunkMultiplier.FloatValue * -5.0;
            }					
        }
        SetEntPropVector(client, Prop_Send, "m_aimPunchAngle", fPunch);	
        SetEntPropVector(target, Prop_Send, "m_aimPunchAngle", fPunch);

        pack = new DataPack();
        pack.WriteCell(GetClientUserId(client));
        pack.WriteCell(GetClientUserId(target));
        CreateTimer(1.0, Timer_SetDrunk, pack, TIMER_FLAG_NO_MAPCHANGE);
    }

    return Plugin_Stop;
}

public Action Timer_SetDrugs(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    int target = GetClientOfUserId(pack.ReadCell());
    delete pack;

    if (Mode.Drugs && LR_IsClientValid(client) && LR_IsClientInLastRequest(client) && LR_IsClientValid(target) && LR_IsClientInLastRequest(target))
    {
        float fAngle1[3];
        float fAngle2[3];
        GetClientEyeAngles(client, fAngle1);
        GetClientEyeAngles(target, fAngle2);
        
        fAngle1[2] = GetRandomFloat(-25.0, 25.0);
        fAngle2[2] = GetRandomFloat(-25.0, 25.0);
        
        TeleportEntity(client, NULL_VECTOR, fAngle1, NULL_VECTOR);
        TeleportEntity(target, NULL_VECTOR, fAngle2, NULL_VECTOR);
        
        int clients[3];
        clients[0] = client;
        clients[1] = target;
        
        int duration = 255;
        int holdtime = 255;
        int flags = 0x0002;
        int color[4] = { 0, 0, 0, 128 };
        color[0] = GetRandomInt(0,255);
        color[1] = GetRandomInt(0,255);
        color[2] = GetRandomInt(0,255);

        Handle message = StartMessageEx(Mode.Fade, clients, 1);
        Protobuf pb = UserMessageToProtobuf(message);
        pb.SetInt("duration", duration);
        pb.SetInt("hold_time", holdtime);
        pb.SetInt("flags", flags);
        pb.SetColor("clr", color);
        EndMessage();

        pack = new DataPack();
        pack.WriteCell(GetClientUserId(client));
        pack.WriteCell(GetClientUserId(target));
        CreateTimer(1.0, Timer_SetDrugs, pack, TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        float fAngle1[3], fAngle2[3];
        GetClientEyeAngles(client, fAngle1);
        GetClientEyeAngles(target, fAngle2);

        fAngle1[2] = 0.0;
        fAngle2[2] = 0.0;

        TeleportEntity(client, NULL_VECTOR, fAngle1, NULL_VECTOR);
        TeleportEntity(target, NULL_VECTOR, fAngle2, NULL_VECTOR);

        int iClients[3];
        iClients[0] = client;
        iClients[0] = target;

        int duration = 1536;
        int holdtime = 1536;
        int flags = (0x0001 | 0x0010);
        int color[4] = { 0, 0, 0, 0 };

        Handle message = StartMessageEx(Mode.Fade, iClients, 1);
        Protobuf pb = UserMessageToProtobuf(message);
        pb.SetInt("duration", duration);
        pb.SetInt("hold_time", holdtime);
        pb.SetInt("flags", flags);
        pb.SetColor("clr", color);
        EndMessage();
    }

    return Plugin_Stop;
}
