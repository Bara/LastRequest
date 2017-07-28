#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

#include <lastrequest>

#define LR_NAME "Test"
#define PLUGIN_NAME "LastRequest - " ... LR_NAME

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = "github.com/Bara20"
};

public void OnAllPluginsLoaded()
{
	if (LR_RegisterLRGame(LR_NAME, "example"))
	{
		SetFailState("Can't register last request: %s", LR_NAME);
	}
}

public void LR_OnLastRequestChoosen(int client, int target, const char[] name)
{
	PrintToChatAll("(LR_OnLastRequestChoosen) called!");
	PrintToChatAll("Game: %s", name);
}

public bool Hosties_OnLastRequestAvailable(int client)
{
	if(LR_IsLastRequestAvailable())
	{
		PrintToChatAll("Last request is now available!");
		PrintToChatAll("Last T is: %N", client);
	}
	PrintToChatAll("(Hosties_OnLastRequestAvailable) called!");
}

public void LR_OnLastRequestEnd(int client, int target)
{
	PrintToChatAll("(LR_OnLastRequestEnd) called!");
}
