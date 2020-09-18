void InitAPI()
{
    CreateNative("LR_RegisterGame", Native_RegisterLRGame);
    CreateNative("LR_IsLastRequestAvailable", Native_IsLastRequestAvailable);
    CreateNative("LR_IsClientInLastRequest", Native_IsClientInLastRequest);
    CreateNative("LR_GetClientOpponent", Native_GetClientOpponent);
    CreateNative("LR_StopLastRequest", Native_StopLastRequest);
    CreateNative("LR_StartLastRequest", Native_StartLastRequest);
    CreateNative("LR_GetMenuTime", Native_GetMenuTime);
    CreateNative("LR_IsDebugActive", Native_IsDebugActive);
    CreateNative("LR_MenuTimeout", Native_MenuTimeout);
    CreateNative("LR_RemovePlayerWeapon", Native_RemovePlayerWeapon);
    CreateNative("LR_ResetClient", Native_ResetClient);
    
    Core.OnMenu = new GlobalForward("LR_OnOpenMenu", ET_Ignore, Param_Cell);
    Core.OnLRAvailable = new GlobalForward("LR_OnLastRequestAvailable", ET_Ignore, Param_Cell);

    RegPluginLibrary("lastrequest");
}

public int Native_RegisterLRGame(Handle plugin, int numParams)
{
    char shortName[LR_MAX_SHORTNAME_LENGTH];
    char fullname[LR_MAX_FULLNAME_LENGTH];
    
    GetNativeString(1, shortName, sizeof(shortName));
    GetNativeString(2, fullname, sizeof(fullname));
    
    if (!CheckLRShortName(shortName))
    {
        Games game;

        strcopy(game.Name, sizeof(Games::Name), shortName);
        strcopy(game.FullName, sizeof(Games::FullName), fullname);

        game.plugin = plugin;
        game.PreStartCB = GetNativeFunction(3);
        game.StartCB = GetNativeFunction(4);
        game.EndCB = GetNativeFunction(5);

        if (Config.Debug.BoolValue)
        {
            LogMessage("[%s] Name: %s, FullName: %s", LR_BASE_NAME, game.Name, game.FullName);
        }

        return Core.Games.SetArray(game.Name, game, sizeof(Games));
    }
    
    return false;
}

public int Native_StartLastRequest(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    GetNativeString(2, Player[client].Game.Mode, sizeof(Games::Mode));

    char sWeapon[32];
    GetNativeString(3, sWeapon, sizeof(sWeapon));

    Player[client].Game.Health = GetNativeCell(4);
    Player[client].Game.Kevlar = GetNativeCell(5);
    Player[client].Game.Helm = GetNativeCell(6);

    AskForConfirmation(client, sWeapon);
}

public int Native_StopLastRequest(Handle plugin, int numParams)
{
    LR_End_Reason reason = view_as<LR_End_Reason>(GetNativeCell(1));
    int winner = GetNativeCell(2);
    int loser = GetNativeCell(3);
    bool blockSlay = view_as<bool>(GetNativeCell(4));
    
    LR_LoopClients(i)
    {
        if ((i == winner || i == loser) && GetClientTeam(i) == CS_TEAM_T && Player[i].InLR && Player[i].Target > 0)
        {
            Call_StartFunction(Player[i].Game.plugin, Player[i].Game.EndCB);
            Call_PushCell(reason);
            Call_PushCell(winner);
            Call_PushCell(loser);
            Call_Finish();

            
            LR_LoopClients(j)
            {
                if (LR_IsClientValid(j))
                {
                    if (reason == Normal)
                    {
                        PrintToChat(j, "Last request over, Winner of %s (Mode: %s) is %N!", Player[i].Game.FullName, Player[i].Game.Mode, winner); // TODO: Add translation
                    }
                    else if (reason == Unknown)
                    {
                        // TODO: Unknown?
                    }
                    else if (reason == Tie)
                    {
                        PrintToChat(j, "Tie, Game has been ended!"); // TODO: Add translation
                    }
                    else if (reason == Admin)
                    {
                        PrintToChat(j, "Last request canceled by Admin %N!", winner); // TODO: Add translation
                    }
                    else if (reason == Server)
                    {
                        PrintToChat(j, "Last request canceled by Server!"); // TODO: Add translation
                    }
                }
            }
        }
    }
    
    if (reason != Admin && winner > 0)
    {
        if (Config.WinnerWeaponsBack.BoolValue && (Player[winner].Weapons != null && Player[winner].Weapons.Length > 0))
        {
            RemoveWeapons(winner, false);

            if (Config.Debug.BoolValue)
            {
                PrintToChat(winner, "Remove weapons");
            }
            
            if (IsPlayerAlive(winner))
            {
                char sClass[32];

                for (int i = 0; i < Player[winner].Weapons.Length; i++)
                {
                    Player[winner].Weapons.GetString(i, sClass, sizeof(sClass));

                    if (Config.Debug.BoolValue)
                    {
                        PrintToChat(winner, "Adding %s back...", sClass);
                    }

                    LR_GivePlayerItem(winner, sClass);
                }
            }
        }

        Player[winner].Reset();
    }

    if (reason != Admin && loser > 0)
    {
        if (IsPlayerAlive(loser) && Config.KillLoser.BoolValue && !blockSlay)
        {
            ForcePlayerSuicide(loser);
        }
        else if (IsPlayerAlive(loser) && !Config.KillLoser.BoolValue && Config.LoserWeaponsBack.BoolValue && (Player[loser].Weapons != null && Player[loser].Weapons.Length > 0))
        {
            RemoveWeapons(loser, false);

            if (Config.Debug.BoolValue)
            {
                PrintToChat(loser, "Remove weapons");
            }

            char sClass[32];

            for (int i = 0; i < Player[loser].Weapons.Length; i++)
            {
                Player[loser].Weapons.GetString(i, sClass, sizeof(sClass));

                if (Config.Debug.BoolValue)
                {
                    PrintToChat(loser, "Adding %s back...", sClass);
                }

                LR_GivePlayerItem(loser, sClass);
            }
        }

        Player[loser].Reset();
    }
}

public int Native_IsLastRequestAvailable(Handle plugin, int numParams)
{
    return Core.Available;
}

public int Native_IsClientInLastRequest(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return Player[client].InLR;
}

public int Native_GetClientOpponent(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (Player[client].InLR)
    {
        return Player[client].Target;
    }

    return -1;
}

public int Native_GetMenuTime(Handle plugin, int numParams)
{
    return Config.MenuTime.IntValue;
}

public int Native_IsDebugActive(Handle plugin, int numParams)
{
    return Config.Debug.BoolValue;
}

public int Native_MenuTimeout(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (Config.Debug.BoolValue)
    {
        PrintToChatAll("MenuCancel_Timeout %N", client); // TODO: Add message/translation or debug?
    }

    int target = LR_GetClientOpponent(client);

    bool blockSlay = (Config.TimeoutPunishment.IntValue == 0);

    if (LR_IsClientValid(target))
    {
        LR_StopLastRequest(Unknown, target, client, blockSlay);
    }

    if (Config.TimeoutPunishment.IntValue == 1)
    {
        ForcePlayerSuicide(client);
    }
    else if (Config.TimeoutPunishment.IntValue == 2)
    {
        KickClient(client, "You was kicked due afk during menu selection."); // TODO: Add translation
    }
}

public int Native_RemovePlayerWeapon(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int weapon = GetNativeCell(2);

    if (!IsValidEntity(weapon))
    {
        return false;
    }
    
    if (!HasEntProp(weapon, Prop_Send, "m_hOwnerEntity"))
    {
        return false;
    }
    
    int iOwner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    
    if (iOwner != client)
    {
        SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);
    }

    CS_DropWeapon(client, weapon, false);

    if (HasEntProp(weapon, Prop_Send, "m_hWeaponWorldModel"))
    {
        int iWorldModel = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");
        
        if (IsValidEdict(iWorldModel) && IsValidEntity(iWorldModel))
        {
            if (!AcceptEntityInput(iWorldModel, "Kill"))
            {
                return false;
            }
        }
    }

    return AcceptEntityInput(weapon, "Kill");
}

public int Native_ResetClient(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    Player[client].Reset();
}
