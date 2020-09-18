void InitEvents()
{
    HookEvent("round_prestart", Event_RoundPreStart, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
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

public Action Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast)
{
    Core.Status(false);

    LR_LoopClients(i)
    {
        Player[i].Reset();
    }
}
