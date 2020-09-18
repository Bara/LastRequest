enum struct Variables {
    ArrayList Players;
    
    StringMap Games;

    GlobalForward OnMenu;
    GlobalForward OnLRAvailable;
}

enum struct Configs {
    ConVar MenuTime;
    ConVar OpenMenu;
    ConVar AvailableSounds;
    ConVar AvailablePath;
    ConVar StartCountdown;
    ConVar CountdownPath;
    ConVar TimeoutPunishment;
    ConVar AdminFlag;
    ConVar PlayerCanStop;
    ConVar Debug;
    ConVar KillLoser;
    ConVar WinnerWeaponsBack;
    ConVar LoserWeaponsBack;
    ConVar ForceAccept;
}

enum struct Games
{
    int Health;
    int Kevlar;
    bool Helm;

    char Name[LR_MAX_SHORTNAME_LENGTH];
    char FullName[LR_MAX_FULLNAME_LENGTH];
    char Mode[LR_MAX_MODENAME_LENGTH];

    Handle plugin;

    Function PreStartCB;
    Function StartCB;
    Function EndCB;
}

Variables Core;
Configs Config;

enum struct PlayerData
{
    bool InLR;

    int Target;

    Games Game;

    ArrayList Weapons;

    void Reset(int client)
    {
        this.InLR = false;
        this.Target = -1;

        delete this.Weapons;

        int index = Core.Players.FindValue(client);

        if (index != -1)
        {
            Core.Players.Erase(index);
        }
    }
}

PlayerData Player[MAXPLAYERS + 1];
