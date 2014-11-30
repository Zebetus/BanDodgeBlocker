#include <sourcemod>
#include <regex>
#undef REQUIRE_PLUGIN
#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS
#include <steamtools>

public Plugin:myinfo = {
	name = "IP Checker",
	author = "Zebetus",
	description = "This auto kicks a suspected ban dodger",
	version = "0.1",
	url = "none"
	
};

new serverID;
new Handle:db = INVALID_HANDLE;
new configSection = 0;

public OnPluginStart() {
	decl String:error[64];
	db = SQL_Connect("default", true, error, sizeof(error));
	if (db == INVALID_HANDLE) {
		SetFailState("Failed to connect to database: %s", error);
	}
	
	new String:keyValueFile[128];
	BuildPath(Path_SM, keyValueFile, sizeof(keyValueFile), "configs/sourcepunish.cfg");
	if (!FileExists(keyValueFile)) 
	{
		SetFailState("configs/sourcepunish.cfg does not exist!");
	}

	new Handle:smc = SMC_CreateParser();
	SMC_SetReaders(smc, SMC_NewSection, SMC_KeyValue, SMC_EndSection);
	SMC_ParseFile(smc, keyValueFile);
	
	if (serverID < 1) {
		SetFailState("Server ID in config is invalid! Should be at least 1");
	}
}

public SMCResult:SMC_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes) {
	switch (configSection) {
		case 0: {
			if (StrEqual(key, "ServerID")) {
				serverID = StringToInt(value);
			}
		}
	}
	return SMCParse_Continue;
}

public SMCResult:SMC_NewSection(Handle:smc, const String:sectionName[], bool:opt_quotes) {
	configSection = 0;
	if (StrEqual(sectionName, "DefaultReasons", false)) {
		configSection = 1;
	} else if (StrEqual(sectionName, "DefaultTimes", false)) {
		configSection = 2;
	}
	return SMCParse_Continue;
}

public SMCResult:SMC_EndSection(Handle:smc) {
	configSection = 0;
	return SMCParse_Continue;
}

public OnClientConnected(client)
{
	decl String:name[32], String:auth[32], String:IP_Address[32];
	
	GetClientName(client, name, sizeof(name));
	GetClientAuthString(client, auth, sizeof(auth));
	GetClientIP(client, IP_Address, sizeof(IP_Address));
	
	decl String:escapedIP[64], String:query[512];
	SQL_EscapeString(db, IP_Address, escapedIP, sizeof(escapedIP));
	Format(
		query,
		sizeof(query),
		"SELECT \
			1 \
		FROM \
			sourcepunish_punishments \
		WHERE \
			UnPunish = 0 AND \
			(Punish_Server_ID = %i OR Punish_All_Servers = 1) AND \
			((Punish_Time + (Punish_Length * 60)) > UNIX_TIMESTAMP(NOW()) OR Punish_Length = 0) AND \
			Punish_Player_IP = '%s' AND \
			Punish_Type = 'ban' \
			;",
		escapedIP,
		serverID
		);
	SQL_TQuery(db, UsersActivePunishmentsLookupComplete, query, client);
}

public UsersActivePunishmentsLookupComplete(Handle:owner, Handle:query, const String:error[], any:client) {
	if (query == INVALID_HANDLE) {
		ThrowError("Error querying DB: %s", error);
	}
	if (SQL_GetRowCount(query) > 0 && Steam_CheckClientSubscription(client, 0) && !Steam_CheckClientDLC(client, 459)) {
		KickClient(client, "Ban Evasion Detected");
	}
}