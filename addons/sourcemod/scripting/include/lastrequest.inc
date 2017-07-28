#if defined _lr_included
  #endinput
#endif
#define _lr_included

#define LR_LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(LR_IsClientValid(%1))

#include <cstrike>

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

stock bool LR_IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
		{
			return true;
		}
	}
	return false;
}

stock void LR_StripAllWeapons(int client)
{
	for(int i = CS_SLOT_PRIMARY; i <= CS_SLOT_C4; i++)
	{
		int index = -1;
		while((index = GetPlayerWeaponSlot(client, i)) != -1)
		{
			LR_SafeRemoveWeapon(client, index);
		}
	}
}

stock bool LR_SafeRemoveWeapon(int client, int weapon)
{
	if (!IsValidEntity(weapon) || !IsValidEdict(weapon))
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
	
	if (!AcceptEntityInput(weapon, "Kill"))
	{
		return false;
	}
	
	return true;
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
