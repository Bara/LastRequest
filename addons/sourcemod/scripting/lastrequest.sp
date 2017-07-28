#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <emitsoundany>

#pragma newdecls required

#include <lastrequest>

#define PLUGIN_NAME "Last Request"
#define LR_MAX_NAME_LENGTH 32
#define LR_MAX_TRANSLATIONS_LENGTH 64

bool g_bLastRequest = false;
bool g_bLastRequestRound = false;
bool g_bInLR[MAXPLAYERS + 1] =  { false, ... };

ConVar g_cMenuTime = null;
ConVar g_cOpenMenu = null;
ConVar g_cAvailableSounds = null;
ConVar g_cAvailablePath = null;
ConVar g_cPlayCountdownSounds = null;
ConVar g_cCountdownPath = null;
ConVar g_cLRCommands = null;
ConVar g_cLRListCommands = null;

Handle g_hOnLRChoosen;
Handle g_hOnLRAvailable;
Handle g_hOnLREnd;

char g_sLRGame[MAXPLAYERS + 1][128];
int g_iLRTarget[MAXPLAYERS + 1] =  { 0, ... };

enum lrCache
{
	lrId,
	String:lrName[LR_MAX_NAME_LENGTH],
	String:lrTranslation[LR_MAX_TRANSLATIONS_LENGTH]
};

int g_iLRGames[lrCache];
ArrayList g_aLRGames = null;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = "github.com/Bara20"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("LR_RegisterLRGame", Native_RegisterLRGame);
	CreateNative("LR_IsLastRequestAvailable", Native_IsLastRequestAvailable);
	CreateNative("LR_IsClientInLastRequest", Native_IsClientInLastRequest);
	CreateNative("LR_SetLastRequestStatus", Native_SetLastRequestStatus);
	CreateNative("LR_StopLastRequest", Native_StopLastRequest);
	
	g_hOnLRChoosen = CreateGlobalForward("LR_OnLastRequestChoosen", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_hOnLRAvailable = CreateGlobalForward("LR_OnLastRequestAvailable", ET_Ignore, Param_Cell);
	g_hOnLREnd = CreateGlobalForward("LR_OnLastRequestEnd", ET_Ignore, Param_Cell, Param_Cell);
	
	RegPluginLibrary("lastrequest");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	if(g_aLRGames != null)
	{
		g_aLRGames.Clear();
	}
	
	g_cMenuTime = CreateConVar("lastrequest_menu_time", "30", "Time in seconds to choose a last request");
	g_cOpenMenu = CreateConVar("lastrequest_open_menu", "1", "Open last request menu for the last player?", _, true, 0.0, true, 1.0);
	g_cAvailableSounds = CreateConVar("lastrequest_available_sounds", "3", "How many last request available to you have? 0 to disable it");
	g_cAvailablePath = CreateConVar("lastrequet_available_path", "lastrequest/availableX.mp3", "Sounds for available last request");
	g_cPlayCountdownSounds = CreateConVar("lastrequest_play_sounds", "1", "Play countdown sounds?", _, true, 0.0, true, 1.0);
	g_cCountdownPath = CreateConVar("lastrequest_countdown_path", "lastrequest/countdownX.mp3", "Sounds for 3...2...1...Go ( Go = 0 )");
	g_cLRCommands = CreateConVar("lastrequest_commands", "lr;lastrequest", "Commands to open last request menu");
	g_cLRListCommands = CreateConVar("lastrequest_list_commands", "lrs;lastrequests", "Commands to open a list of all last requests");
	
	RegAdminCmd("sm_lrdebug", LRDebug, ADMFLAG_ROOT);
	
	CreateTimer(3.0, Timer_CheckTeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	g_aLRGames = new ArrayList(sizeof(g_iLRGames));
	
	HookEvent("round_prestart", Event_RoundPreStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public void OnConfigsExecuted()
{
	char sLRCommands[128];
	g_cLRCommands.GetString(sLRCommands, sizeof(sLRCommands));
	int iLRCommands;
	char sLRCommandsList[8][32];
	iLRCommands = ExplodeString(sLRCommands, ";", sLRCommandsList, sizeof(sLRCommandsList), sizeof(sLRCommandsList[]));
	
	
	for(int i = 0; i < iLRCommands; i++)
	{
		char sBuffer[32];
		Format(sBuffer, sizeof(sBuffer), "sm_%s", sLRCommandsList[i]);
		RegConsoleCmd(sBuffer, Command_LastRequest);
		LogMessage("[%s] Register Command: %s Full: %s", PLUGIN_NAME, sLRCommandsList[i], sBuffer);
	}
	
	char sLRSCommands[128];
	g_cLRListCommands.GetString(sLRSCommands, sizeof(sLRSCommands));
	int iLRSCommands;
	char sLRSCommandsList[8][32];
	iLRSCommands = ExplodeString(sLRSCommands, ";", sLRSCommandsList, sizeof(sLRSCommandsList), sizeof(sLRSCommandsList[]));
	
	for(int i = 0; i < iLRSCommands; i++)
	{
		char sBuffer[32];
		Format(sBuffer, sizeof(sBuffer), "sm_%s", sLRSCommandsList[i]);
		RegConsoleCmd(sBuffer, Command_LastRequestList);
		LogMessage("[%s] Register Command: %s Full: %s", PLUGIN_NAME, sLRSCommandsList[i], sBuffer);
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(LR_IsClientValid(client) && g_bInLR[client])
	{
		LR_StopLastRequest();
		return;
	}
	
	CheckTeams();
	return;
}

public Action Timer_CheckTeams(Handle timer)
{
	if(!g_bLastRequest)
	{
		CheckTeams();
	}
	else
	{
		int T = 0;
		int CT = 0;
		LR_LoopClients(i)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				if(GetClientTeam(i) == CS_TEAM_T)
				{
					T++;
				}
				else if(GetClientTeam(i) == CS_TEAM_CT)
				{
					CT++;
				}
			}
		}
		
		if(T == 0 || CT == 0)
		{
			LR_StopLastRequest();
		}
	}
}

void CheckTeams()
{
	int iCount = 0;
	int lastT[65];
	
	LR_LoopClients(i)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
		{
			iCount++;
			lastT[iCount] = i;
		}
	}
	
	if(iCount == 1)
	{
		int client = lastT[1];
		g_bLastRequest = true;
		
		if(g_cAvailableSounds.IntValue > 0)
		{
			PlayAvailableSound();
		}
		
		if(g_cOpenMenu.BoolValue)
		{
			ShowLastRequestMenu(client);
		}
		
		Call_StartForward(g_hOnLRAvailable);
		Call_PushCell(client);
		Call_Finish();
	}
}

void PlayAvailableSound()
{
	char sFile[PLATFORM_MAX_PATH + 1], sid[2];
	g_cAvailablePath.GetString(sFile, sizeof(sFile));
	
	int id;
	if(g_cAvailableSounds.IntValue > 1)
	{
		id = GetRandomInt(1, g_cAvailableSounds.IntValue);
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
	g_bLastRequest = false;
	g_bLastRequestRound = true;
}

public Action LRDebug(int client, int args)
{
	for (int i = 0; i < g_aLRGames.Length; i++)
	{
		int iGang[lrCache];
		g_aLRGames.GetArray(i, iGang[0]);

		PrintToServer("[%s]: %s", PLUGIN_NAME, iGang[lrName]);
	}
	
	CreateCountdown(3, client);
	
	if(g_bInLR[client])
	{
		PrintToChat(client, "You're in a last request!");
	}
}


public Action Command_LastRequestList(int client, int args)
{
	if(!LR_IsClientValid(client)) // TODO: Add message
	{
		return Plugin_Handled;
	}
	
	ShowLastRequestList(client);
	
	return Plugin_Continue;
}


public Action Command_LastRequest(int client, int args)
{
	if(!LR_IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	if(GetClientTeam(client) != CS_TEAM_T) // TODO: Add message
	{
		return Plugin_Handled;
	}
	
	PrintToChat(client, "LR_IsLastRequestAvailable: %d, g_bInLR: %d", g_bLastRequest, g_bInLR[client]);
	
	if(g_bLastRequest) // TODO: Add message
	{
		return Plugin_Handled;
	}
	
	if(g_bInLR[client]) // TODO: Add message
	{
		return Plugin_Handled;
	}
		
	ShowLastRequestMenu(client);
	
	return Plugin_Continue;
}

void ShowLastRequestList(int client)
{
	Menu menu = new Menu(Menu_Empty); // TODO: As panel
	menu.SetTitle("Last requests:"); // TODO: Add translation
	
	for (int i = 0; i < g_aLRGames.Length; i++)
	{
		int iGang[lrCache];
		g_aLRGames.GetArray(i, iGang[0]);

		menu.AddItem(iGang[lrTranslation], iGang[lrTranslation], ITEMDRAW_DISABLED); // TODO: Add translation
	}
	
	menu.ExitButton = true;
	menu.Display(client, g_cMenuTime.IntValue);
}

void ShowLastRequestMenu(int client)
{
	Menu menu = new Menu(Menu_LastRequest);
	menu.SetTitle("Choose a last request:"); // TODO: Add translation
	
	for (int i = 0; i < g_aLRGames.Length; i++)
	{
		int iGang[lrCache];
		g_aLRGames.GetArray(i, iGang[0]);

		menu.AddItem(iGang[lrTranslation], iGang[lrTranslation]); // TODO: Add translation
	}
	
	menu.ExitButton = true;
	menu.Display(client, g_cMenuTime.IntValue);
}


public int Menu_LastRequest(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char sParam[32];
		GetMenuItem(menu, param, sParam, sizeof(sParam));
		
		PrintToChat(client, "LR: %s", sParam);
		strcopy(g_sLRGame[client], sizeof(g_sLRGame[]), sParam);
		
		Menu tMenu = new Menu(Menu_TMenu);
		tMenu.SetTitle("Choose your opponent:");
		
		LR_LoopClients(i)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i) && !g_bInLR[i])
			{
				char sIndex[12], sName[MAX_NAME_LENGTH];
				IntToString(i, sIndex, sizeof(sIndex));
				GetClientName(i, sName, sizeof(sName));
				tMenu.AddItem(sIndex, sName);
			}
		}
		
		tMenu.ExitButton = true;
		tMenu.Display(client, g_cMenuTime.IntValue);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param == MenuCancel_Timeout)
		{
			PrintToChatAll("MenuCancel_Timeout %N", client); // TODO: Add translation & function (Nothing or slay?)
		}
	}		
	else if (action == MenuAction_End)
	{
		if(menu != null)
		{
			delete menu;
		}
	}
	return 0;
}

public int Menu_TMenu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char sParam[32];
		GetMenuItem(menu, param, sParam, sizeof(sParam));
		
		int target = StringToInt(sParam);
		g_iLRTarget[client] = target;
		
		PrintToChat(client, "LR: %s - Opponent: %N", g_sLRGame[client], target);
		
		CreateCountdown(3, client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param == MenuCancel_Timeout)
		{
			PrintToChatAll("MenuCancel_Timeout %N", client); // TODO: Add translation & function (Nothing or slay?)
		}
	}		
	else if (action == MenuAction_End)
	{
		if(menu != null)
		{
			delete menu;
		}
	}
	return 0;
}

public int Menu_Empty(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_End)
	{
		if(menu != null)
		{
			delete menu;
		}
	}
	return 0;
}

public int Native_RegisterLRGame(Handle plugin, int numParams)
{
	char name[LR_MAX_NAME_LENGTH];
	char translations[LR_MAX_TRANSLATIONS_LENGTH];
	
	GetNativeString(1, name, sizeof(name));
	GetNativeString(2, translations, sizeof(translations));
	
	CheckExistsLRGames(name);
	
	int iCache[lrCache];
	
	iCache[lrId] = g_aLRGames.Length + 1;
	strcopy(iCache[lrName], sizeof(name), name);
	strcopy(iCache[lrTranslation], sizeof(translations), translations);

	LogMessage("[%s] ID: %d - Name: %s - Translations: %s", PLUGIN_NAME, iCache[lrId], iCache[lrName], iCache[lrTranslation]);

	g_aLRGames.PushArray(iCache[0]);
	
	CheckExistsLRGames(name);
	
	return false;
}

public int Native_IsClientInLastRequest(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_bInLR[client];
}

public int Native_SetLastRequestStatus(Handle plugin, int numParams)
{
	g_bLastRequestRound = GetNativeCell(1);
	return g_bLastRequestRound;
}

public int Native_StopLastRequest(Handle plugin, int numParams)
{
	LR_LoopClients(i)
	{
		if(LR_IsClientValid(i))
		{
			if(GetClientTeam(i) == CS_TEAM_T && g_iLRTarget[i] > 0)
			{
				Call_StartForward(g_hOnLREnd);
				Call_PushCell(i);
				Call_PushCell(g_iLRTarget[i]);
				Call_Finish();
			}
		}
	}
	
	LR_LoopClients(i)
	{
		if(LR_IsClientValid(i))
		{
			if(g_bInLR[i])
			{
				g_bInLR[i] = false;
			}
			
			if(GetClientTeam(i) == CS_TEAM_T && g_iLRTarget[i] > 0)
			{
				LR_LoopClients(j)
				{
					if(LR_IsClientValid(j))
					{
						PrintToChat(j, "Last request was ended ( Game: %s, Player: %N, Opponent: %N )", g_sLRGame[i], i, g_iLRTarget[i]); // TODO: Add translation
					}
				}
				g_iLRTarget[i] = 0;
				g_sLRGame[i] = "";
			}
		}
	}
	
	g_bLastRequest = true;
}

public int Native_IsLastRequestAvailable(Handle plugin, int numParams)
{
	return g_bLastRequest;
}

bool CheckExistsLRGames(const char[] name)
{
	for (int i = 0; i < g_aLRGames.Length; i++)
	{
		int iGang[lrCache];
		g_aLRGames.GetArray(i, iGang[0]);

		if(StrEqual(iGang[lrName], name, false))
		{
			return true;
		}
	}
	return false;
}


stock void CreateCountdown(int seconds, int client)
{
	Handle pack = CreateDataPack();
	WritePackCell(pack, seconds);
	WritePackCell(pack, GetClientUserId(client));
	CreateTimer(0.0, Timer_Countdown, pack);
}

public Action Timer_Countdown(Handle timer, any pack)
{
	ResetPack(pack, false);
	int seconds = ReadPackCell(pack);
	int client = GetClientOfUserId(ReadPackCell(pack));
	CloseHandle(pack);
	
	if(LR_IsClientValid(client) && LR_IsClientValid(g_iLRTarget[client]))
	{
		LR_LoopClients(i)
		{
			if(LR_IsClientValid(i))
			{
				if(seconds == 1)
				{
					PrintToChat(i, "Last request started in %d second ( Game: %s, Player: %N, Opponent: %N)", seconds, g_sLRGame[client], i, g_iLRTarget[client]); // TODO: Add translation
				}
				else if(seconds == 0)
				{
					PrintToChat(i, "Go! ( Game: %s, Player: %N, Opponent: %N)", g_sLRGame[client], i, g_iLRTarget[client]); // TODO: Add translation
					StartLastRequest(client);
				}
				else
				{
					PrintToChat(i, "Last request started in %d seconds ( Game: %s, Player: %N, Opponent: %N)", seconds, g_sLRGame[client], i, g_iLRTarget[client]); // TODO: Add translation
				}
				
				if(g_cPlayCountdownSounds.BoolValue)
				{
					PlayCountdownSounds(seconds);
				}
			}
		}
	}
	
	seconds--;

	if(seconds >= 0)
	{
		Handle hPack = CreateDataPack();
		WritePackCell(hPack, seconds);
		WritePackCell(hPack, GetClientUserId(client));
		CreateTimer(1.0, Timer_Countdown, hPack);
	}

	return Plugin_Stop;
}

void PlayCountdownSounds(int seconds)
{
	if(seconds >= 0 && seconds <= 3)
	{
		char sFile[PLATFORM_MAX_PATH + 1], sid[2];
		g_cCountdownPath.GetString(sFile, sizeof(sFile));
		IntToString(seconds, sid, sizeof(sid));
		ReplaceString(sFile, sizeof(sFile), "X", sid, true);
		EmitSoundToAllAny(sFile);
	}
}

void StartLastRequest(int client)
{
	if(!LR_IsClientValid(client) || !LR_IsClientValid(g_iLRTarget[client]))
	{
		LR_LoopClients(i)
		{
			if(LR_IsClientValid(i))
			{
				PrintToChat(i, "Last request aborted! Client invalid"); // TODO: Add translation
			}
		}
	}
	
	g_bLastRequest = false;
	g_bInLR[g_iLRTarget[client]] = true;
	
	Call_StartForward(g_hOnLRChoosen);
	Call_PushCell(client);
	Call_PushCell(g_iLRTarget[client]);
	for (int i = 0; i < g_aLRGames.Length; i++)
	{
		int iGang[lrCache];
		g_aLRGames.GetArray(i, iGang[0]);

		if(StrEqual(iGang[lrTranslation], g_sLRGame[client], false))
		{
			Call_PushString(iGang[lrName]);
		}
	}
	Call_Finish();
}
