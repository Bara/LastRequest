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

    RemoveWeapons(client);
    RemoveWeapons(Player[client].Target);
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
    
    PrintToChat(client, "Core.IsAvailable: %d, Core.RunningLR: %d, Core.CustomStart: %d, Core.Confirmation: %d, Core.InLR: %d", Core.IsAvailable, Core.RunningLR, Core.CustomStart, Core.Confirmation, Player[client].InLR);
    
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
    
    if (Player[client].InLR)
    {
        ReplyToCommand(client, "You are already in a last request!"); // TODO: Add translation
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

        Core.SetState(true, false, false, false);
        
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
    
    if (LR_IsClientValid(client) && LR_IsClientValid(Player[client].Target))
    {
        LR_LoopClients(i)
        {
            if (seconds == 1)
            {
                PrintToChat(i, "Last request started in %d second ( Game: %s, Player: %N, Opponent: %N)", seconds, Player[client].Game.Name, client, Player[client].Target); // TODO: Add translation
            }
            else if (seconds == 0)
            {
                PrintToChat(i, "Go! ( Game: %s, Player: %N, Opponent: %N)", Player[client].Game.Name, client, Player[client].Target); // TODO: Add translation
                StartLastRequest(client);
            }
            else
            {
                PrintToChat(i, "Last request started in %d seconds ( Game: %s, Player: %N, Opponent: %N)", seconds, Player[client].Game.Name, client, Player[client].Target); // TODO: Add translation
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

void RemoveWeapons(int client, bool clearArray = true, bool addToArray = true)
{
    if (clearArray)
    {
        if (Config.Debug.BoolValue)
        {
            PrintToChat(client, "clearArray");
        }

        delete Player[client].Weapons;
    }

    if (addToArray)
    {
        if (Config.Debug.BoolValue)
        {
            PrintToChat(client, "addToArray");
        }

        if (Player[client].Weapons == null)
        {
            if (Config.Debug.BoolValue)
            {
                PrintToChat(client, "new ArrayList");
            }

            Player[client].Weapons = new ArrayList(32);
        }
    }

    char sClass[32];
    
    for(int i = 0; i < GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons"); i++)
    {
        int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);

        if (IsValidEntity(iWeapon))
        {
            GetEntityClassname(iWeapon, sClass, sizeof(sClass));

            if (addToArray)
            {
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
