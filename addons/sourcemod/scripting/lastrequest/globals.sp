enum struct Variables {
    bool Available;
    
    StringMap Games;

    GlobalForward OnMenu;
    GlobalForward OnLRAvailable;

    void Status(bool status) {
        this.Available = status;
    }
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
    ConVar MaxActive;
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

    void Reset()
    {
        this.InLR = false;
        this.Target = -1;
    }
}

PlayerData Player[MAXPLAYERS + 1];
