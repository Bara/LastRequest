void InitCommands()
{
    RegConsoleCmd("sm_lr", Command_LastRequest);
    RegConsoleCmd("sm_activelr", Command_ActiveLastRequests);
    RegConsoleCmd("sm_stoplr", Command_StopLR);
    RegConsoleCmd("sm_lrlist", Command_LastRequestList);
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

public Action Command_ActiveLastRequests(int client, int args)
{
    if (!LR_IsClientValid(client))
    {
        return Plugin_Handled;
    }
    
    ShowActiveLastRequests(client);
    
    return Plugin_Continue;
}
