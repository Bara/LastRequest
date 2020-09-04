#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <lastrequest>
#include <emitsoundany>
#include <autoexecconfig>

#define PLUGIN_NAME "Last Request"

#include "lastrequest/globals.sp"
#include "lastrequest/api.sp"
#include "lastrequest/stocks.sp"
#include "lastrequest/menus.sp"

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("LR_RegisterGame", Native_RegisterLRGame);
    CreateNative("LR_IsLastRequestAvailable", Native_IsLastRequestAvailable);
    CreateNative("LR_IsClientInLastRequest", Native_IsClientInLastRequest);
    CreateNative("LR_GetClientOpponent", Native_GetClientOpponent);
    CreateNative("LR_StopLastRequest", Native_StopLastRequest);
    CreateNative("LR_StartLastRequest", Native_StartLastRequest);
    CreateNative("LR_GetMenuTime", Native_GetMenuTime);
    CreateNative("LR_MenuTimeout", Native_MenuTimeout);
    
    Core.OnMenu = new GlobalForward("LR_OnOpenMenu", ET_Ignore, Param_Cell);
    Core.OnLRAvailable = new GlobalForward("LR_OnLastRequestAvailable", ET_Ignore, Param_Cell);
    
    RegPluginLibrary("lastrequest");
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("core", "lastrequest");
    Config.Debug = AutoExecConfig_CreateConVar("lastrequest_debug", "1", "Show/Log debug messages?", _, true, 0.0, true, 1.0);
    Config.MenuTime = AutoExecConfig_CreateConVar("lastrequest_menu_time", "30", "Time in seconds to choose a last request");
    Config.OpenMenu = AutoExecConfig_CreateConVar("lastrequest_open_menu", "0", "Open last request menu (on player death only) for the last player?", _, true, 0.0, true, 1.0);
    Config.AvailableSounds = AutoExecConfig_CreateConVar("lastrequest_available_sounds", "0", "How many last request available to you have? 0 to disable it");
    Config.AvailablePath = AutoExecConfig_CreateConVar("lastrequet_available_path", "lastrequest/availableX.mp3", "Sounds for available last request");
    Config.StartCountdown = AutoExecConfig_CreateConVar("lastrequest_start_countdown", "3", "Countdown after accepting game until the game starts", _, true, 3.0);
    Config.CountdownPath = AutoExecConfig_CreateConVar("lastrequest_countdown_path", "lastrequest/countdownX.mp3", "Sounds for 3...2...1...Go ( Go = 0 )");
    Config.TimeoutPunishment = AutoExecConfig_CreateConVar("lastrequest_timeout_punishment", "0", "How punish the player who didn't response to the menu? (0 - Nothing, 1 - Slay, 2 - Kick)", _, true, 0.0, true, 2.0);
    Config.AdminFlag = AutoExecConfig_CreateConVar("lastrequest_admin_flag", "b", "Admin flag to cancel/stop active last requests.");
    Config.PlayerCanStop = AutoExecConfig_CreateConVar("lastrequest_player_can_stop_lr", "1", "The player, which is in a active last request, can stop the last request with the agreement of the opponent.", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    
    HookEvent("round_prestart", Event_RoundPreStart, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

    RegConsoleCmd("sm_lr", Command_LastRequest);
    RegConsoleCmd("sm_lrlist", Command_LastRequestList);
    RegConsoleCmd("sm_stoplr", Command_StopLR);
}

public void OnMapStart()
{
    delete g_smGames;
    g_smGames = new StringMap();

    Core.SetState(false, false, false, false);

    CreateTimer(3.0, Timer_CheckTeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnConfigsExecuted()
{
    PrecacheAvailableSounds();
    PrecacheCountdownSounds();
}

public void OnClientPutInServer(int client)
{
    Player[client].Reset();
}

public void OnClientDisconnect(int client)
{
    if (LR_IsClientValid(client) && Player[client].InLR)
    {
        LR_StopLastRequest(Unknown, Player[client].Target, client);
    }

    Player[client].Reset();
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (LR_IsClientValid(client) && Player[client].InLR)
    {
        LR_StopLastRequest(Normal, Player[client].Target, client);
        return;
    }
    
    CheckTeams(true);
    return;
}

public Action Timer_CheckTeams(Handle timer)
{
    if (!Core.RunningLR && !Core.CustomStart && !Core.Confirmation)
    {
        CheckTeams();
    }
    else if (Core.RunningLR || Core.CustomStart || Core.Confirmation)
    {
        if (GetTeamCountAmount(CS_TEAM_T) == 0 || GetTeamCountAmount(CS_TEAM_CT) == 0)
        {
            LR_StopLastRequest(Server);
        }
    }
}

public Action Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast)
{
    Core.SetState(false, false, false, false);

    LR_LoopClients(i)
    {
        Player[i].Reset();
    }
}

public Action Command_LastRequestList(int client, int args)
{
    if (!LR_IsClientValid(client))
    {
        return Plugin_Handled;
    }
    
    ShowLastRequestList(client);
    
    return Plugin_Continue;
}

public Action Command_LastRequest(int client, int args)
{
    if (!IsLRReady(client))
    {
        return Plugin_Handled;
    }
        
    ShowPlayerList(client);
    
    return Plugin_Continue;
}

public Action Command_StopLR(int client, int args)
{
    char sFlags[24];
    Config.AdminFlag.GetString(sFlags, sizeof(sFlags));

    if (CheckCommandAccess(client, "lr_admin", ReadFlagString(sFlags), true))
    {
        LR_StopLastRequest(Admin, client);
        return;
    }

    if (Config.PlayerCanStop.BoolValue && Player[client].InLR)
    {
        AskOpponentToStop(client);
        return;
    }
}

