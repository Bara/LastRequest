#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <lastrequest>
#include <autoexecconfig>

#define LR_NAME "Shot 4 Shot" // TODO: Replace this with a string buffer
#define LR_SHORT  "shot4shot"

enum struct General
{
    ConVar Enable;
    ConVar Debug;
    ConVar Knife;

    char Weapon[32];

    void Reset() {
        this.Weapon[0] = '\0';
    }
}

enum struct PlayerData {
    int Weapon;

    void Reset() {
        this.Weapon = -1;
    }
}

General Core;
PlayerData Player[MAXPLAYERS + 1];

StringMap g_smWeapons = null;

public Plugin myinfo =
{
    name = LR_PLUGIN_NAME ... LR_NAME,
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara"
};

public void OnPluginStart()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("shot4shot", "lastrequest");
    Core.Enable = AutoExecConfig_CreateConVar("shot4shot_enable", "1", "Enable or disable shot 4 shot?", _, true, 0.0, true, 1.0);
    Core.Knife = AutoExecConfig_CreateConVar("shot4shot_give_knife", "1", "Give players a knife too?", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
}

public void OnConfigsExecuted()
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/lastrequest/shot4shot_weapons.ini");

    if (!FileExists(sFile))
    {
        SetFailState("Can not found the following file: \"%s\"", sFile);
        return;
    }

    KeyValues kvConfig = new KeyValues("Weapons");

    if (!kvConfig.ImportFromFile(sFile))
    {
        SetFailState("Can not read from the following file: \"%s\"", sFile);
        return;
    }

    Core.Debug = FindConVar("lastrequest_debug");

    delete g_smWeapons;
    g_smWeapons = new StringMap();

    if (kvConfig.GotoFirstSubKey(false))
    {
        char sClass[32];
        char sName[64];

        int iCount = 0;

        do
        {
            kvConfig.GetSectionName(sClass, sizeof(sClass));
            kvConfig.GetString(NULL_STRING, sName, sizeof(sName));

            if (strlen(sClass) > 1 && strlen(sName) > 1)
            {
                if (Core.Debug.BoolValue)
                {
                    LogMessage("[Shot4Shot] Adding %s (Class: %s) to weapon stringmap.", sName, sClass);
                }

                g_smWeapons.SetString(sClass, sName, true);
                iCount++;
            }
        }
        while (kvConfig.GotoNextKey(false));

        if (iCount == 0)
        {
            SetFailState("[Shot4Shot] No weapons found!");
            return;
        }
    }

    delete kvConfig;

    if (!LR_RegisterGame(LR_SHORT, LR_NAME, OnGamePreStart, OnGameStart, OnGameEnd))
    {
        SetFailState("Can't register last request: %s", LR_SHORT);
        return;
    }
}

public void LR_OnOpenMenu(Menu menu)
{
    if (Core.Enable.BoolValue)
    {
        menu.AddItem(LR_SHORT, "Shot 4 Shot"); // TODO: Add translation
    }
}

public Action OnGamePreStart(int requester, int opponent, const char[] shortname)
{
    Menu menu = new Menu(Menu_WeaponSelection);
    menu.SetTitle("Select weapon"); // TODO: Add translation

    if (Core.Enable.BoolValue)
    {
        StringMapSnapshot snap = g_smWeapons.Snapshot();

        char sName[32], sClass[32];

        for (int i = 0; i < snap.Length; i++)
        {
            snap.GetKey(i, sClass, sizeof(sClass));
            g_smWeapons.GetString(sClass, sName, sizeof(sName));
            menu.AddItem(sClass, sName);
        }

        delete snap;
    }

    menu.ExitBackButton = false;
    menu.ExitButton = false;
    menu.Display(requester, LR_GetMenuTime());
}

public int Menu_WeaponSelection(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sClass[32], sDisplay[32];
        menu.GetItem(param, sClass, sizeof(sClass), _, sDisplay, sizeof(sDisplay));

        strcopy(Core.Weapon, sizeof(General::Weapon), sClass);

        LR_StartLastRequest(client, "Normal", sDisplay); // TODO: Add translation
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Timeout)
        {
            LR_MenuTimeout(client);
        }
    }	
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public void OnGameStart(int client, int target, const char[] name)
{
    if (Core.Knife.BoolValue)
    {
        int iWeapon = GivePlayerItem(client, "weapon_knife");
        EquipPlayerWeapon(client, iWeapon);
        iWeapon = GivePlayerItem(target, "weapon_knife");
        EquipPlayerWeapon(target, iWeapon);
    }

    int iRandom = GetRandomInt(0, 1);

    GivePlayerWeapon(client, iRandom ? 1 : 0);
    GivePlayerWeapon(target, iRandom ? 0 : 1);
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    if (!LR_IsLastRequestAvailable())
    {
        return;
    }

    if (strlen(Core.Weapon) < 4)
    {
        return;
    }

    int client = GetClientUserId(event.GetInt("userid"));

    if (!LR_IsClientValid(client))
    {
        return;
    }

    if (!LR_IsClientInLastRequest(client))
    {
        return;
    }

    char sWeapon[32];
    event.GetString("weapon", sWeapon, sizeof(sWeapon));

    if (StrContains(Core.Weapon, sWeapon, false) != -1)
    {
        RequestFrame(Frame_SetAmmo, GetClientUserId(LR_GetClientOpponent(client)));
    }
}

public void Frame_SetAmmo(int userid)
{
    int iTarget = GetClientOfUserId(userid);

    if (LR_IsClientValid(iTarget) && IsPlayerAlive(iTarget))
    {
        SetAmmo(iTarget, 1);
    }
}

public void OnGameEnd(LR_End_Reason reason, int winner, int loser)
{
    Core.Reset();
    
    if (winner != -1)
    {
        Player[winner].Reset();
    }

    if (loser != -1)
    {
        Player[loser].Reset();
    }
}

void GivePlayerWeapon(int client, int clip = 0, int ammo = 0)
{
    int iWeapon = GivePlayerItem(client, Core.Weapon);
    EquipPlayerWeapon(client, iWeapon);
    Player[client].Weapon = EntIndexToEntRef(iWeapon);

    SetAmmo(client, clip, ammo);
}

void SetAmmo(int client, int clip, int ammo = 0) // TODO Make it dynamically, when someone adds a primary it doesn't work.
{
    int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

    if (IsValidEntity(EntRefToEntIndex(Player[client].Weapon)) && iWeapon == EntRefToEntIndex(Player[client].Weapon))
    {
        if (clip > -1)
        {
            SetEntProp(iWeapon, Prop_Send, "m_iClip1", clip);
        }
        
        if (ammo > -1)
        {
            SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo);
        }
    }
    else
    {
        GivePlayerWeapon(client, clip);
    }
}
