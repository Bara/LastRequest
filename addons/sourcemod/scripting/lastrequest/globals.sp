enum struct Variables {
    bool IsAvailable;
    bool CustomStart;
    bool Confirmation;
    bool RunningLR;
    StringMap Games;

    GlobalForward OnMenu;
    GlobalForward OnLRAvailable;

    void SetState(bool available, bool custom, bool confirmation, bool running) {
        this.IsAvailable = available;
        this.CustomStart = custom;
        this.Confirmation = confirmation;
        this.RunningLR = running;
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
}

enum struct Games
{
    int Health;
    int Kevlar;
    bool Helm;

    char Name[LR_MAX_SHORTNAME_LENGTH];
    char FullName[LR_MAX_FULLNAME_LENGTH];

    Handle plugin;

    Function PreStartCB;
    Function StartCB;
    Function EndCB;
}

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

        delete this.Weapons;
    }
}

Variables Core;
Configs Config;

PlayerData Player[MAXPLAYERS + 1];
