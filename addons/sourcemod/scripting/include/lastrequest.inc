#if defined _lr_included
  #endinput
#endif
#define _lr_included

forward void LR_OnLastRequestChoosen(int client, int target, const char[] name);
forward bool LR_OnLastRequestAvailable(int lastT);
forward void LR_OnLastRequestEnd(int client, int target);

native bool LR_RegisterLRGame(const char[] name, const char[] translations); // TODO translations?
native bool LR_IsClientInLastRequest(int client);
native bool LR_IsLastRequestAvailable();
native bool LR_SetLastRequestStatus(bool status);
native void LR_StopLastRequest();

stock bool IsLastRequestAvailable()
{
	if (!LibraryExists("lastrequest"))
	{
		return SetFailState("Last Request is not loaded!");
	}
}

public SharedPlugin __pl_lr = 
{
	name = "lastrequest",
	file = "lastrequest.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN

public __pl_lr_SetNTVOptional()
{
	// MarkNativeAsOptional("");
}
#endif
