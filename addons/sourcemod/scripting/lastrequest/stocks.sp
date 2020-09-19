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
    if (!LR_IsClientValid(client) || !LR_IsClientValid(Player[client].Target))
    {
        LR_LoopClients(i)
        {
            PrintToChat(i, "Last request aborted! Client invalid"); // TODO: Add translation
        }
    }

    RemoveWeapons(client, true);
    RemoveWeapons(Player[client].Target, true);
    LR_SetHealthKevlarHelm(client, Player[client].Target, Player[client].Game.Health, Player[client].Game.Kevlar, Player[client].Game.Helm);
    
    Call_StartFunction(Player[client].Game.plugin, Player[client].Game.StartCB);
    Call_PushCell(client);
    Call_PushCell(Player[client].Target);
    Call_PushString(Player[client].Game.Name);
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

bool CheckClientStatus(int client)
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
    
    int iCount = GetLastRequestCount();
    
    PrintToChat(client, "GetLastRequestCount: %d, Core.Available: %d, Player.InLR: %d", iCount, Core.Available, Player[client].InLR);

    if (iCount >= Config.MaxActive.IntValue)
    {
        ReplyToCommand(client, "No empty last request slot available (%d/%d)", iCount, Config.MaxActive.IntValue); // TODO: Add translation
        return false;
    }
    
    if (!Core.Available)
    {
        ReplyToCommand(client, "Something went wrong with players array..."); // TODO: Add translation
        return false;
    }
    
    if (Player[client].InLR)
    {
        ReplyToCommand(client, "You are already in a last request!"); // TODO: Add translation
        return false;
    }

    return true;
}

// TODO: Merge it into CheckClientStatus?
bool CheckTargetStatus(int client, int target)
{
    if (!LR_IsClientValid(target))
    {
        return false;
    }
    
    if (GetClientTeam(target) != CS_TEAM_CT)
    {
        PrintToChat(client, "You must be a Terrorist to use last request!"); // TODO: Add translation
        return false;
    }
    
    int iCount = GetLastRequestCount();
    
    PrintToChat(target, "GetLastRequestCount: %d, Core.Available: %d, Player.InLR: %d", iCount, Core.Available, Player[target].InLR);

    if (iCount >= Config.MaxActive.IntValue)
    {
        PrintToChat(client, "No empty last request slot available (%d/%d)", iCount, Config.MaxActive.IntValue); // TODO: Add translation
        return false;
    }
    
    if (!Core.Available)
    {
        PrintToChat(client, "Something went wrong with players array..."); // TODO: Add translation
        return false;
    }
    
    if (Player[target].InLR)
    {
        PrintToChat(client, "You are already in a last request!"); // TODO: Add translation
        return false;
    }

    return true;
}

bool CheckLRShortName(const char[] name)
{
    Games game;
    return Core.Games.GetArray(name, game, sizeof(Games));
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
        PrintToChatAll("T: %d, CT: %d, Core.Available: %d", iT, iCT, Core.Available);
    }

    if (iT <= Config.MaxActive.IntValue && iCT > 0 && !Core.Available)
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

        Core.Status(true);
        PrintToChatAll("T: %d, CT: %d, Core.Available: %d", iT, iCT, Core.Available);
        
        Call_StartForward(Core.OnLRAvailable);
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

    seconds--;
    
    if (LR_IsClientValid(client) && LR_IsClientValid(Player[client].Target))
    {
        LR_LoopClients(i)
        {
            if (seconds == 1)
            {
                PrintToChat(i, "Last request started in %d second ( Game: %s, Mode: %s, Player: %N, Opponent: %N)", seconds, Player[client].Game.FullName, Player[client].Game.Mode, client, Player[client].Target); // TODO: Add translation
            }
            else if (seconds == 0)
            {
                PrintToChat(i, "Go! ( Game: %s, Mode: %s, Player: %N, Opponent: %N)", Player[client].Game.FullName, Player[client].Game.Mode, client, Player[client].Target); // TODO: Add translation
                StartLastRequest(client);
				
                return Plugin_Stop;
            }
            else
            {
                PrintToChat(i, "Last request started in %d seconds ( Game: %s, Mode: %s, Player: %N, Opponent: %N)", seconds, Player[client].Game.FullName, Player[client].Game.Mode, client, Player[client].Target); // TODO: Add translation
            }
            
            if (Config.StartCountdown.BoolValue)
            {
                PlayCountdownSounds(seconds);
            }
        }
    }

    if (seconds > 0)
    {
        pack = new DataPack();
        pack.WriteCell(seconds);
        pack.WriteCell(GetClientUserId(client));
        CreateTimer(1.0, Timer_Countdown, pack);
    }

    return Plugin_Stop;
}

public Action Timer_CheckTeams(Handle timer)
{
    if (!Core.Available)
    {
        CheckTeams();
    }
    else
    {
        if (GetTeamCountAmount(CS_TEAM_T) == 0 || GetTeamCountAmount(CS_TEAM_CT) == 0)
        {
            LR_StopLastRequest(Server);
        }
    }
}

void RemoveWeapons(int client, bool addToArray)
{
    if (addToArray)
    {
        if (Config.Debug.BoolValue)
        {
            PrintToChat(client, "deleteArray");
        }

        delete Player[client].Weapons;
        
        if (Config.Debug.BoolValue)
        {
            PrintToChat(client, "initArray");
        }

        Player[client].Weapons = new ArrayList(32);
    }

    char sClass[32];
    
    for(int i = 0; i < GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons"); i++)
    {
        int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);

        if (IsValidEntity(iWeapon))
        {
            if (addToArray)
            {
                GetEntityClassname(iWeapon, sClass, sizeof(sClass));
                
                if (Config.Debug.BoolValue)
                {
                    PrintToChat(client, "Add %s to ArrayList", sClass);
                }

                Player[client].Weapons.PushString(sClass);
            }

            LR_RemovePlayerWeapon(client, iWeapon);
        }
    }
}

int GetLastRequestCount()
{
    int[] clients = new int[MaxClients];
    int iCount = 0;

    LR_LoopClients(i)
    {
        if (!LR_IsClientInLastRequest(i))
        {
            continue;
        }

        if (clients[i] != i && clients[i] != LR_GetClientOpponent(i))
        {
            clients[i] = LR_GetClientOpponent(i);
            clients[LR_GetClientOpponent(i)] = i;

            iCount++;
        }
    }

    return iCount;
}
