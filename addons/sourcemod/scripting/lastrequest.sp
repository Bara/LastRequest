#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <emitsoundany>

#pragma newdecls required

#include <lastrequest>

#define PLUGIN_NAME "Last Request"

enum struct Variables {
    bool IsAvailable;
    bool CustomStart;
    bool Confirmation;
    bool RunningLR;
}

enum struct Configs {
    ConVar MenuTime;
    ConVar OpenMenu;
    ConVar AvailableSounds;
    ConVar AvailablePath;
    ConVar StartCountdown;
    ConVar CountdownPath;
    ConVar TimeoutPunishment;
    ConVar AdminFlag;
    ConVar PlayerCanStop;
    ConVar Debug;
}

enum struct Forwards {
    GlobalForward OnMenu;
    GlobalForward OnLRAvailable;
}

enum struct Games
{
    char Name[LR_MAX_SHORTNAME_LENGTH];
    char FullName[LR_MAX_FULLNAME_LENGTH];
    Handle plugin;
    Function PreStartCB;
    Function StartCB;
    Function EndCB;
}

enum struct PlayerData
{
    bool InLR;
    int Target;
    Games Game;

    void Reset()
    {
        this.InLR = false;
        this.Target = -1;
    }
}

StringMap g_smGames = null;

Variables Core;
Configs Config;
Forwards Forward;

PlayerData g_iPlayer[MAXPLAYERS + 1];

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
    CreateNative("LR_GetTimeoutPunishment", Native_GetTimeoutPunishment);
    
    Forward.OnMenu = new GlobalForward("LR_OnOpenMenu", ET_Ignore, Param_Cell);
    Forward.OnLRAvailable = new GlobalForward("LR_OnLastRequestAvailable", ET_Ignore, Param_Cell);
    
    RegPluginLibrary("lastrequest");
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    Config.Debug = CreateConVar("lastrequest_debug", "1", "Show/Log debug messages?", _, true, 0.0, true, 1.0);
    Config.MenuTime = CreateConVar("lastrequest_menu_time", "30", "Time in seconds to choose a last request");
    Config.OpenMenu = CreateConVar("lastrequest_open_menu", "1", "Open last request menu (on player death only) for the last player?", _, true, 0.0, true, 1.0);
    Config.AvailableSounds = CreateConVar("lastrequest_available_sounds", "3", "How many last request available to you have? 0 to disable it");
    Config.AvailablePath = CreateConVar("lastrequet_available_path", "lastrequest/availableX.mp3", "Sounds for available last request");
    Config.StartCountdown = CreateConVar("lastrequest_start_countdown", "3", "Countdown after accepting game until the game starts", _, true, 3.0);
    Config.CountdownPath = CreateConVar("lastrequest_countdown_path", "lastrequest/countdownX.mp3", "Sounds for 3...2...1...Go ( Go = 0 )");
    Config.TimeoutPunishment = CreateConVar("lastrequest_timeout_punishment", "0", "How punish the player who didn't response to the menu? (0 - Nothing, 1 - Slay, 2 - Kick)", _, true, 0.0, true, 2.0);
    Config.AdminFlag = CreateConVar("lastrequest_admin_flag", "b", "Admin flag to cancel/stop active last requests.");
    Config.PlayerCanStop = CreateConVar("lastrequest_player_can_stop_lr", "1", "The player, which is in a active last request, can stop the last request with the agreement of the opponent.", _, true, 0.0, true, 1.0);
    
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

    Core.RunningLR = false;
    Core.IsAvailable = false;
    Core.CustomStart = false;
    Core.Confirmation = false;

    CreateTimer(3.0, Timer_CheckTeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnConfigsExecuted()
{
    PrecacheAvailableSounds();
    PrecacheCountdownSounds();
}

public void OnClientPutInServer(int client)
{
    g_iPlayer[client].Reset();
}

public void OnClientDisconnect(int client)
{
    if (LR_IsClientValid(client) && g_iPlayer[client].InLR)
    {
        LR_StopLastRequest(g_iPlayer[client].Target, client);
    }

    g_iPlayer[client].Reset();
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (LR_IsClientValid(client) && g_iPlayer[client].InLR)
    {
        LR_StopLastRequest(g_iPlayer[client].Target, client);
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
            LR_StopLastRequest();
        }
    }
}

void CheckTeams(bool openMenu = false)
{
    int iTIndex = -1;
    int iT = 0;
    int iCT = 0;
    
    LR_LoopClients(i)
    {
        if (IsPlayerAlive(i))
        {
            if (GetClientTeam(i) == CS_TEAM_T)
            {
                iTIndex = i;
                iT++;
            }
            else if (GetClientTeam(i) == CS_TEAM_CT)
            {
                iCT++;
            }
        }
    }

    if (Config.Debug.BoolValue)
    {
        PrintToChatAll("T: %d, CT: %d, Running: %d, CustomStart: %d, Confirmation: %d, Available: %d", iT, iCT, Core.RunningLR, Core.CustomStart, Core.Confirmation, Core.IsAvailable);
    }

    if (iT == 1 && iCT > 0 && !Core.RunningLR && !Core.CustomStart && !Core.Confirmation && !Core.IsAvailable)
    {
        int client = iTIndex;
        
        if (Config.AvailableSounds.IntValue > 0)
        {
            PlayAvailableSound();
        }
        
        if (openMenu && Config.OpenMenu.BoolValue)
        {
            ShowPlayerList(client);
        }

        Core.IsAvailable = true;
        
        Call_StartForward(Forward.OnLRAvailable);
        Call_PushCell(client);
        Call_Finish();
    }
}

void PrecacheAvailableSounds()
{
    char sFile[PLATFORM_MAX_PATH + 1], sid[2];
    Config.AvailablePath.GetString(sFile, sizeof(sFile));
    
    for (int i = 1; i <= Config.AvailableSounds.IntValue; i++)
    {
        IntToString(i, sid, sizeof(sid));
        ReplaceString(sFile, sizeof(sFile), "X", sid, true);
        PrecacheSoundAny(sFile);
    }
}

void PlayAvailableSound()
{
    char sFile[PLATFORM_MAX_PATH + 1], sid[2];
    Config.AvailablePath.GetString(sFile, sizeof(sFile));
    
    int id;
    if (Config.AvailableSounds.IntValue > 1)
    {
        id = GetRandomInt(1, Config.AvailableSounds.IntValue);
    }
    else
    {
        id = 1;
    }
    
    IntToString(id, sid, sizeof(sid));
    ReplaceString(sFile, sizeof(sFile), "X", sid, true);
    EmitSoundToAllAny(sFile);
}

public Action Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast)
{
    Core.RunningLR = false;
    Core.IsAvailable = false;
    Core.CustomStart = false;
    Core.Confirmation = false;

    LR_LoopClients(i)
    {
        g_iPlayer[i].Reset();
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
        LR_StopLastRequest(-2, client);
        return;
    }

    if (Config.PlayerCanStop.BoolValue && g_iPlayer[client].InLR)
    {
        AskOpponentToStop(client);
        return;
    }
}

void AskOpponentToStop(int client)
{
    int iTarget = LR_GetClientOpponent(client);

    if (!LR_IsClientValid(iTarget))
    {
         // TODO: Add message/translation or debug?
        return;
    }

    Menu menu = new Menu(Menu_AskToStop);
    menu.SetTitle("%N ask to stop this LR", iTarget); // TODO: Add translation
    menu.AddItem("yes", "Yes, stop LR."); // TODO: Add translation
    menu.AddItem("no", "No, don't stop!"); // TODO: Add translation
    menu.ExitBackButton = false;
    menu.ExitButton = false;
    menu.Display(iTarget, Config.MenuTime.IntValue);
}

public int Menu_AskToStop(Menu menu, MenuAction action, int target, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[6];
        menu.GetItem(param, sParam, sizeof(sParam));

        int client = LR_GetClientOpponent(target);

        if (!LR_IsClientValid(client))
        {
             // TODO: Add message/translation or debug?
            return;
        }

        if (StrEqual(sParam, "yes", false))
        {
            PrintToChat(target, "You accepted the request from %N to stop this LR.", client); // TODO: Add translation
            PrintToChat(client, "%N has accepted your request to stop this LR.", target); // TODO: Add translation

            LR_StopLastRequest(target, client);
        }
        else
        {
            PrintToChat(target, "You declined the request from %N to stop this LR.", client); // TODO: Add translation
            PrintToChat(client, "%N has declined your request to stop this LR.", target); // TODO: Add translation
        }
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Timeout)
        {
            if (Config.Debug.BoolValue)
            {
                PrintToChatAll("MenuCancel_Timeout %N", target); // TODO: Add message/translation or debug?
            }

            if (Config.TimeoutPunishment.IntValue == 1)
            {
                ForcePlayerSuicide(target);
            }
            else if (Config.TimeoutPunishment.IntValue == 2)
            {
                KickClient(target, "You was kicked due afk during menu selection."); // TODO: Add translation
            }
        }
    }	
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void ShowLastRequestList(int client)
{
    Menu menu = new Menu(Menu_Empty); // TODO: As panel
    menu.SetTitle("Last Requests:"); // TODO: Add translation
    
    Call_StartForward(Forward.OnMenu);
    Call_PushCell(menu);
    Call_Finish();
    
    menu.ExitButton = true;
    menu.Display(client, Config.MenuTime.IntValue);
}

void ShowPlayerList(int client)
{
    Menu menu = new Menu(Menu_LastRequest);
    menu.SetTitle("Choose your opponent:"); // TODO: Add translation

    int iCount = 0;
    
    LR_LoopClients(i)
    {
        if (GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i) && !g_iPlayer[i].InLR)
        {
            char sIndex[12], sName[MAX_NAME_LENGTH];
            IntToString(i, sIndex, sizeof(sIndex));
            GetClientName(i, sName, sizeof(sName));
            menu.AddItem(sIndex, sName);

            iCount++;
        }
    }

    if (iCount == 0)
    {
        PrintToChat(client, "Can not find a valid CT."); // TODO: Add translation
        delete menu;
        return;
    }
    
    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, Config.MenuTime.IntValue);
}

public int Menu_LastRequest(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (!IsLRReady(client))
        {
            return;
        }

        char sParam[32];
        menu.GetItem(param, sParam, sizeof(sParam));

        int target = StringToInt(sParam);
        g_iPlayer[client].Target = target;
        g_iPlayer[target].Target = client;
        
        PrintToChat(client, "Target: %N", target); // TODO: Add message/translation or debug?

        Menu gMenu = new Menu(Menu_TMenu);
        gMenu.SetTitle("Choose a game:"); // TODO: Add translation
        
        Call_StartForward(Forward.OnMenu);
        Call_PushCell(gMenu);
        Call_Finish();
        
        gMenu.ExitBackButton = false;
        gMenu.ExitButton = true;
        gMenu.Display(client, Config.MenuTime.IntValue);
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Timeout)
        {
            PrintToChatAll("MenuCancel_Timeout %N", client); // TODO: Add message/translation or debug?

            if (Config.TimeoutPunishment.IntValue == 1)
            {
                ForcePlayerSuicide(client);
            }
            else if (Config.TimeoutPunishment.IntValue == 2)
            {
                KickClient(client, "You was kicked due afk during lr menu selection."); // TODO: Add translation
            }
        }
        else if (param == MenuCancel_Exit)
        {
            g_iPlayer[client].Reset();
        }
    }		
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public int Menu_TMenu(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (!IsLRReady(client))
        {
            return;
        }

        char sParam[32];
        menu.GetItem(param, sParam, sizeof(sParam));

        Games game;
        if (g_smGames.GetArray(sParam, game, sizeof(Games)))
        {
            g_iPlayer[client].Game = game;
        }
        else
        {
            PrintToChat(client, "Can not set game."); // TODO: Add message/translation or debug?
        }
        
        PrintToChat(client, "LR: %s - Opponent: %N", g_iPlayer[client].Game.Name, g_iPlayer[client].Target); // TODO: Add message/translation or debug?

        Core.CustomStart = true;
        Core.Confirmation = false;
        Core.RunningLR = false;

        Core.IsAvailable = false;
        
        g_iPlayer[client].InLR = true;
        g_iPlayer[g_iPlayer[client].Target].InLR = true;

        Call_StartFunction(g_iPlayer[client].Game.plugin, g_iPlayer[client].Game.PreStartCB);
        Call_PushCell(client);
        Call_PushCell(g_iPlayer[client].Target);
        Call_PushString(g_iPlayer[client].Game.Name);
        Call_Finish();
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Timeout)
        {
            PrintToChatAll("MenuCancel_Timeout %N", client); // TODO: Add message/translation or debug?

            if (Config.TimeoutPunishment.IntValue == 1)
            {
                ForcePlayerSuicide(client);
            }
            else if (Config.TimeoutPunishment.IntValue == 2)
            {
                KickClient(client, "You was kicked due afk during lr menu selection."); // TODO: Add translation
            }
        }
        else if (param == MenuCancel_Exit)
        {
            g_iPlayer[client].Reset();
        }
    }		
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public int Native_StartLastRequest(Handle plugin, int numParams)
{
    Core.CustomStart = false;
    Core.Confirmation = true;
    Core.RunningLR = false;

    int client = GetNativeCell(1);

    char sMode[32];
    GetNativeString(2, sMode, sizeof(sMode));

    char sWeapon[32];
    GetNativeString(3, sWeapon, sizeof(sWeapon));

    int health = GetNativeCell(4);

    int kevlar = GetNativeCell(5);

    if (Core.Confirmation && !Core.CustomStart && !Core.RunningLR)
    {
        AskForConfirmation(client, sMode, sWeapon, health, kevlar);
    }
}

void AskForConfirmation(int client, const char[] mode, const char[] weapon, int health, int kevlar)
{
    int iTarget = LR_GetClientOpponent(client);

    if (!LR_IsClientValid(iTarget))
    {
        // TODO: Add message/translation or debug?
        return;
    }

    char sKevlar[24];
    if (kevlar == 0)
    {
        Format(sKevlar, sizeof(sKevlar), "No kevlar"); // TODO: Add translation
    }
    else if (kevlar == 1)
    {
        Format(sKevlar, sizeof(sKevlar), "Kevlar"); // TODO: Add translation
    }
    else if (kevlar == 2)
    {
        Format(sKevlar, sizeof(sKevlar), "Kevlar + Helm"); // TODO: Add translation
    }

    Menu menu = new Menu(Menu_AskForConfirmation);
    menu.SetTitle("%N wants to play against you!\n \nLast Request: %s\nMode: %s\nWeapons: %s\nHealth: %d\nKevlar: %s\n \nDo you accept this setting?\n ",
                    client, g_iPlayer[client].Game.FullName, mode, weapon, health, sKevlar); // TODO: Add translation
    menu.AddItem("yes", "Yes, I accept!"); // TODO: Add translation
    menu.AddItem("no", "No, please..."); // TODO: Add translation
    menu.ExitBackButton = false;
    menu.ExitButton = false;
    menu.Display(iTarget, Config.MenuTime.IntValue);
}

public int Menu_AskForConfirmation(Menu menu, MenuAction action, int target, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[6];
        menu.GetItem(param, sParam, sizeof(sParam));

        int client = LR_GetClientOpponent(target);

        if (!LR_IsClientValid(client))
        {
            // TODO: Add message/translation or debug?
            return;
        }

        Core.RunningLR = true;
        Core.CustomStart = false;
        Core.Confirmation = false;
        Core.IsAvailable = false;

        if (StrEqual(sParam, "yes", false))
        {
            PrintToChat(target, "You accepted the game setting!"); // TODO: Add translation
            PrintToChat(client, "%N has accepted your game setting!", target); // TODO: Add translation

            StartCountdown(Config.StartCountdown.IntValue, client);
        }
        else
        {
            PrintToChat(target, "You declined the game setting!"); // TODO: Add translation
            PrintToChat(client, "%N has declined your game setting!", target); // TODO: Add translation
        }
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Timeout)
        {
            PrintToChatAll("MenuCancel_Timeout %N", target); // TODO: Add message/translation or debug?

            if (Config.TimeoutPunishment.IntValue == 1)
            {
                ForcePlayerSuicide(target);
            }
            else if (Config.TimeoutPunishment.IntValue == 2)
            {
                KickClient(target, "You was kicked due afk during menu selection."); // TODO: Add translation
            }
        }
    }	
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public int Menu_Empty(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public int Native_RegisterLRGame(Handle plugin, int numParams)
{
    char name[LR_MAX_SHORTNAME_LENGTH];
    
    GetNativeString(1, name, sizeof(name));
    
    if (!CheckLRShortName(name))
    {
        Games game;

        strcopy(game.Name, sizeof(Games::Name), name);

        char sFullName[LR_MAX_FULLNAME_LENGTH];
        strcopy(game.FullName, sizeof(Games::FullName), sFullName);

        game.plugin = plugin;
        game.PreStartCB = GetNativeFunction(2);
        game.StartCB = GetNativeFunction(3);
        game.EndCB = GetNativeFunction(4);

        if (Config.Debug.BoolValue)
        {
            LogMessage("[%s] Name: %s, FullName: %s", PLUGIN_NAME, game.Name, game.FullName);
        }

        return g_smGames.SetArray(game.Name, game, sizeof(Games));
    }
    
    return false;
}

public int Native_IsClientInLastRequest(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_iPlayer[client].InLR;
}

public int Native_StopLastRequest(Handle plugin, int numParams)
{
    int winner = GetNativeCell(1);
    int loser = GetNativeCell(2);
    
    LR_LoopClients(i)
    {
        if (GetClientTeam(i) == CS_TEAM_T && g_iPlayer[i].InLR && g_iPlayer[i].Target > 0)
        {
            Call_StartFunction(g_iPlayer[i].Game.plugin, g_iPlayer[i].Game.EndCB);
            Call_PushCell(winner);
            Call_PushCell(loser);
            Call_Finish();

            if (winner > 0)
            {
                LR_LoopClients(j)
                {
                    if (LR_IsClientValid(j))
                    {
                        PrintToChat(j, "Last request over! ( Game: %s, Winner: %N, Loser: %N )", g_iPlayer[i].Game.Name, winner, loser); // TODO: Add translation
                    }
                }
            }
            else if (winner == -2)
            {
                LR_LoopClients(j)
                {
                    if (LR_IsClientValid(j))
                    {
                        PrintToChat(j, "Last request cancled by Admin %N!", loser); // TODO: Add translation
                    }
                }
            }
        }
    }
    
    if (winner > 0)
    {
        g_iPlayer[winner].Reset();
        g_iPlayer[loser].Reset();
    }
    else
    {
        LR_LoopClients(i)
        {
            g_iPlayer[i].Reset();
        }
    }

    Core.RunningLR = false;
    Core.CustomStart = false;
    Core.Confirmation = false;
    Core.IsAvailable = false;
}

public int Native_IsLastRequestAvailable(Handle plugin, int numParams)
{
    return Core.IsAvailable;
}

bool CheckLRShortName(const char[] name)
{
    Games game;
    return g_smGames.GetArray(name, game, sizeof(Games));
}

void StartCountdown(int seconds, int client)
{
    DataPack pack = new DataPack();
    pack.WriteCell(seconds);
    pack.WriteCell(GetClientUserId(client));
    CreateTimer(0.0, Timer_Countdown, pack);
}

public Action Timer_Countdown(Handle timer, DataPack pack)
{
    pack.Reset();
    int seconds = ReadPackCell(pack);
    int client = GetClientOfUserId(ReadPackCell(pack));
    delete pack;
    
    if (LR_IsClientValid(client) && LR_IsClientValid(g_iPlayer[client].Target))
    {
        LR_LoopClients(i)
        {
            if (seconds == 1)
            {
                PrintToChat(i, "Last request started in %d second ( Game: %s, Player: %N, Opponent: %N)", seconds, g_iPlayer[client].Game.Name, client, g_iPlayer[client].Target); // TODO: Add translation
            }
            else if (seconds == 0)
            {
                PrintToChat(i, "Go! ( Game: %s, Player: %N, Opponent: %N)", g_iPlayer[client].Game.Name, client, g_iPlayer[client].Target); // TODO: Add translation
                StartLastRequest(client);
            }
            else
            {
                PrintToChat(i, "Last request started in %d seconds ( Game: %s, Player: %N, Opponent: %N)", seconds, g_iPlayer[client].Game.Name, client, g_iPlayer[client].Target); // TODO: Add translation
            }
            
            if (Config.StartCountdown.BoolValue)
            {
                PlayCountdownSounds(seconds);
            }
        }
    }
    
    seconds--;

    if (seconds >= 0)
    {
        pack = new DataPack();
        pack.WriteCell(seconds);
        pack.WriteCell(GetClientUserId(client));
        CreateTimer(1.0, Timer_Countdown, pack);
    }

    return Plugin_Stop;
}

void PrecacheCountdownSounds()
{
    char sFile[PLATFORM_MAX_PATH + 1], sid[2];
    Config.CountdownPath.GetString(sFile, sizeof(sFile));
    
    for (int i = 0; i <= 3; i++)
    {
        IntToString(i, sid, sizeof(sid));
        ReplaceString(sFile, sizeof(sFile), "X", sid, true);
        PrecacheSoundAny(sFile);
    }
}

void PlayCountdownSounds(int seconds)
{
    if (seconds >= 0 && seconds <= 3)
    {
        char sFile[PLATFORM_MAX_PATH + 1], sid[2];
        Config.CountdownPath.GetString(sFile, sizeof(sFile));
        IntToString(seconds, sid, sizeof(sid));
        ReplaceString(sFile, sizeof(sFile), "X", sid, true);
        EmitSoundToAllAny(sFile);
    }
}

void StartLastRequest(int client)
{
    if (!LR_IsClientValid(client) || !LR_IsClientValid(g_iPlayer[client].Target))
    {
        LR_LoopClients(i)
        {
            PrintToChat(i, "Last request aborted! Client invalid"); // TODO: Add translation
        }
    }
    
    Call_StartFunction(g_iPlayer[client].Game.plugin, g_iPlayer[client].Game.StartCB);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Target);
    Call_PushString(g_iPlayer[client].Game.Name);
    Call_Finish();
}

int GetTeamCountAmount(int team)
{
    int iCount = 0;

    LR_LoopClients(i)
    {
        if (IsPlayerAlive(i))
        {
            if (GetClientTeam(i) == team)
            {
                iCount++;
            }
        }
    }

    return iCount;
}

bool IsLRReady(int client)
{
    if (!LR_IsClientValid(client))
    {
        return false;
    }
    
    if (GetClientTeam(client) != CS_TEAM_T)
    {
        ReplyToCommand(client, "You must be a Terrorist to use last request!"); // TODO: Add translation
        return false;
    }
    
    PrintToChat(client, "Core.IsAvailable: %d, Core.RunningLR: %d, Core.CustomStart: %d, Core.Confirmation: %d, Core.InLR: %d", Core.IsAvailable, Core.RunningLR, Core.CustomStart, Core.Confirmation, g_iPlayer[client].InLR);
    
    if (Core.RunningLR)
    {
        ReplyToCommand(client, "Last Request is already running..."); // TODO: Add translation
        return false;
    }
    
    if (Core.CustomStart)
    {
        ReplyToCommand(client, "Last Request is awaiting on plugin start..."); // TODO: Add translation
        return false;
    }

    if (!Core.IsAvailable)
    {
        ReplyToCommand(client, "Last Request is not available..."); // TODO: Add translation
        return false;
    }
    
    if (g_iPlayer[client].InLR)
    {
        ReplyToCommand(client, "You are already in a last request!"); // TODO: Add translation
        return false;
    }

    return true;
}

public int Native_GetClientOpponent(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (g_iPlayer[client].InLR)
    {
        return g_iPlayer[client].Target;
    }

    return -1;
}

public int Native_GetMenuTime(Handle plugin, int numParams)
{
    return Config.MenuTime.IntValue;
}

public int Native_GetTimeoutPunishment(Handle plugin, int numParams)
{
    return Config.TimeoutPunishment.IntValue;
}
