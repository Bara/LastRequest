#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

#include <lastrequest>

#define LR_SHORTNAME "Test"
#define PLUGIN_NAME "Last Request - " ... LR_SHORTNAME

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = "github.com/Bara"
};

public void OnAllPluginsLoaded()
{
	if (LR_RegisterGame(LR_SHORTNAME))
	{
		SetFailState("Can't register last request: %s", LR_SHORTNAME);
	}
}

public void LR_OnOpenMenu(Menu menu)
{
	PrintToChatAll("(LR_OnOpenMenu) called!");
	
	menu.AddItem(LR_SHORTNAME, "Test");
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
