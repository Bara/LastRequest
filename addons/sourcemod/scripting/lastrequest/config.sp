void InitConfig()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("core", "lastrequest");
    Config.Debug = AutoExecConfig_CreateConVar("lastrequest_debug", "1", "Show/Log debug messages?", _, true, 0.0, true, 1.0);
    Config.MenuTime = AutoExecConfig_CreateConVar("lastrequest_menu_time", "30", "Time in seconds to choose a last request");
    Config.OpenMenu = AutoExecConfig_CreateConVar("lastrequest_open_menu", "0", "Open last request menu (on player death only) for the last player?", _, true, 0.0, true, 1.0);
    Config.AvailableSounds = AutoExecConfig_CreateConVar("lastrequest_available_sounds", "0", "How many last request available to you have? 0 to disable it");
    Config.AvailablePath = AutoExecConfig_CreateConVar("lastrequet_available_path", "lastrequest/availableX.mp3", "Sounds for available last request");
    Config.StartCountdown = AutoExecConfig_CreateConVar("lastrequest_start_countdown", "4", "Countdown after accepting game until the game starts", _, true, 3.0);
    Config.CountdownPath = AutoExecConfig_CreateConVar("lastrequest_countdown_path", "lastrequest/countdownX.mp3", "Sounds for 3...2...1...Go ( Go = 0 )");
    Config.TimeoutPunishment = AutoExecConfig_CreateConVar("lastrequest_timeout_punishment", "0", "How punish the player who didn't response to the menu? (0 - Nothing, 1 - Slay, 2 - Kick)", _, true, 0.0, true, 2.0);
    Config.AdminFlag = AutoExecConfig_CreateConVar("lastrequest_admin_flag", "b", "Admin flag to cancel/stop active last requests.");
    Config.PlayerCanStop = AutoExecConfig_CreateConVar("lastrequest_player_can_stop_lr", "1", "The player, which is in a active last request, can stop the last request with the agreement of the opponent.", _, true, 0.0, true, 1.0);
    Config.KillLoser = AutoExecConfig_CreateConVar("lastrequest_kill_loser", "1", "Kill the loser after games end?", _, true, 0.0, true, 1.0);
    Config.WinnerWeaponsBack = AutoExecConfig_CreateConVar("lastrequest_give_winner_weapons_back", "1", "Give winner weapons back on game end?", _, true, 0.0, true, 1.0);
    Config.LoserWeaponsBack = AutoExecConfig_CreateConVar("lastrequest_give_loser_weapons_back", "1", "Give loser weapons back on game end? Doesn't work when lastrequest_kill_loser is 1", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}