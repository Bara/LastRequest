void ShowLastRequestList(int client)
{
    Menu menu = new Menu(Menu_Empty); // TODO: As panel
    menu.SetTitle("Last Requests:"); // TODO: Add translation
    
    Call_StartForward(Core.OnMenu);
    Call_PushCell(menu);
    Call_Finish();
    
    menu.ExitButton = true;
    menu.Display(client, Config.MenuTime.IntValue);
}

public int Menu_Empty(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
}

void ShowPlayerList(int client)
{
    Menu menu = new Menu(Menu_LastRequest);
    menu.SetTitle("Choose your opponent:"); // TODO: Add translation

    int iCount = 0;
    
    LR_LoopClients(i)
    {
        if (GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i) && !Player[i].InLR)
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
        if (!CheckClientStatus(client))
        {
            return;
        }

        char sParam[32];
        menu.GetItem(param, sParam, sizeof(sParam));

        int target = StringToInt(sParam);

        if (!CheckClientStatus(target))
        {
            PrintToChat(client, "Target is no longer valid!");

            Player[client].Reset();

            return;
        }

        Player[client].Target = target;
        Player[target].Target = client;
        
        PrintToChat(client, "Target: %N", target); // TODO: Add message/translation or debug?

        Menu gMenu = new Menu(Menu_TMenu);
        gMenu.SetTitle("Choose a game:"); // TODO: Add translation
        
        Call_StartForward(Core.OnMenu);
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
            LR_MenuTimeout(client);
        }
        else if (param == MenuCancel_Exit)
        {
            Player[client].Reset();
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
        if (!CheckClientStatus(client))
        {
            return;
        }

        char sParam[32];
        menu.GetItem(param, sParam, sizeof(sParam));

        Games game;
        if (Core.Games.GetArray(sParam, game, sizeof(Games)))
        {
            Player[client].Game = game;
        }
        else
        {
            PrintToChat(client, "Can not set game."); // TODO: Add message/translation or debug?
            LR_StopLastRequest(Server);
            return;
        }
        
        PrintToChat(client, "LR: %s - Opponent: %N", Player[client].Game.Name, Player[client].Target); // TODO: Add message/translation or debug?
        
        Player[client].InLR = true;
        Player[Player[client].Target].InLR = true;

        Call_StartFunction(Player[client].Game.plugin, Player[client].Game.PreStartCB);
        Call_PushCell(client);
        Call_PushCell(Player[client].Target);
        Call_PushString(Player[client].Game.Name);
        Call_Finish();
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Timeout)
        {
            LR_MenuTimeout(client);
        }
        else if (param == MenuCancel_Exit)
        {
            Player[client].Reset();
        }
    }		
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void AskForConfirmation(int client, const char[] weapon)
{
    int iTarget = LR_GetClientOpponent(client);

    if (!LR_IsClientValid(iTarget))
    {
        // TODO: Add message/translation or debug?
        LR_StopLastRequest(Server);
        return;
    }

    if (Config.ForceAccept.BoolValue)
    {
        Menu menu = new Menu(Menu_Empty);
        menu.SetTitle("%N plays against you!\n \nLast Request: %s\nMode: %s\nWeapons: %s\nHealth: %d\nKevlar: %d\nHelm: %s",
                        client, Player[client].Game.FullName, Player[client].Game.Mode, weapon, Player[client].Game.Health, Player[client].Game.Kevlar, Player[client].Game.Helm ? "Yes" : "No"); // TODO: Add translation
        
        char sBuffer[32];
        Format(sBuffer, sizeof(sBuffer), "%T", "Exit", iTarget);
        menu.AddItem("exit", sBuffer);
        menu.ExitBackButton = false;
        menu.ExitButton = false;
        menu.Display(iTarget, Config.MenuTime.IntValue);

        StartCountdown(Config.StartCountdown.IntValue, client);
    }
    else
    {
        PrintToChat(client, "Request to %N has been sended.", iTarget); // TODO: Add translation

        Menu menu = new Menu(Menu_AskForConfirmation);
        menu.SetTitle("%N wants to play against you!\n \nLast Request: %s\nMode: %s\nWeapons: %s\nHealth: %d\nKevlar: %d\nHelm: %s\n \nDo you accept this setting?\n ",
                        client, Player[client].Game.FullName, Player[client].Game.Mode, weapon, Player[client].Game.Health, Player[client].Game.Kevlar, Player[client].Game.Helm ? "Yes" : "No"); // TODO: Add translation
        menu.AddItem("yes", "Yes, I accept!"); // TODO: Add translation
        menu.AddItem("no", "No, please..."); // TODO: Add translation
        menu.ExitBackButton = false;
        menu.ExitButton = false;
        menu.Display(iTarget, Config.MenuTime.IntValue);
    }
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
            LR_StopLastRequest(Server);
            return;
        }

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
            LR_MenuTimeout(target);
        }
    }	
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void AskOpponentToStop(int client)
{
    int iTarget = LR_GetClientOpponent(client);

    if (!LR_IsClientValid(iTarget))
    {
        // TODO: Add message/translation or debug?
        LR_StopLastRequest(Server);
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
            LR_StopLastRequest(Server);
            return;
        }

        if (StrEqual(sParam, "yes", false))
        {
            PrintToChat(target, "You accepted the request from %N to stop this LR.", client); // TODO: Add translation
            PrintToChat(client, "%N has accepted your request to stop this LR.", target); // TODO: Add translation

            LR_StopLastRequest(Unknown, target, client);
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
            LR_MenuTimeout(target);
        }
    }	
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void ShowActiveLastRequests(int client)
{
    StringMap smList = new StringMap();
    char sClient[12], sTarget[12], sBuffer[12], sText[128];
    int iT, iCT;

    LR_LoopClients(i)
    {
        if (!LR_IsClientInLastRequest(i))
        {
            continue;
        }
        
        IntToString(i, sClient, sizeof(sClient));
        IntToString(LR_GetClientOpponent(i), sTarget, sizeof(sTarget));

        if (!smList.GetString(sTarget, sBuffer, sizeof(sBuffer)))
        {
            smList.SetString(sClient, sTarget);
        }
    }

    if (smList.Size < 1)
    {
        delete smList;
        PrintToChat(client, "No running last requests found...");
        return;
    }

    Menu menu = new Menu(Menu_Empty);
    menu.SetTitle("Running last requests:\n ");

    StringMapSnapshot snap = smList.Snapshot();
    for (int i = 0; i < snap.Length; i++)
    {
        snap.GetKey(i, sClient, sizeof(sClient));
        smList.GetString(sClient, sTarget, sizeof(sTarget));

        if (GetClientTeam(StringToInt(sClient)) == CS_TEAM_T)
        {
            iT = StringToInt(sClient);
            iCT = StringToInt(sTarget);
        }
        else
        {
            iT = StringToInt(sTarget);
            iCT = StringToInt(sClient);
        }
        
        Format(sText, sizeof(sText), "%N vs. %N\nGame: %s, Mode: %s", iT, iCT, Player[iT].Game.FullName, Player[iT].Game.Mode);
        menu.AddItem("", sText);
    }

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, Config.MenuTime.IntValue);

    delete smList;
    delete snap;
}
