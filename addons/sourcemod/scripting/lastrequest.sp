#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <lastrequest>
#include <emitsoundany>
#include <autoexecconfig>

#include "lastrequest/globals.sp"
#include "lastrequest/api.sp"
#include "lastrequest/config.sp"
#include "lastrequest/events.sp"
#include "lastrequest/commands.sp"
#include "lastrequest/stocks.sp"
#include "lastrequest/menus.sp"

public Plugin myinfo =
{
    name = LR_PLUGIN_NAME ... "Core",
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    InitAPI();
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    InitConfig();
    InitEvents();
    InitCommands();

    LoadTranslations("core.phrases");
}

public void OnMapStart()
{
    delete Core.Games;
    Core.Games = new StringMap();

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
