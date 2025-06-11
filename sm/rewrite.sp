// my sourcemod experience is very basic, i dont know even if i can move funcs to other files(i would love to)
#include <dbi>
#include <cstrike>
#include <sdktools>


// vars

bool g_bJoinTeamAllowed[MAXPLAYERS +1];

// rank shit
char g_RankType[32] = "-1"

// whitelist shit
char g_Whitelist[10][32]; // max 10 whitelisted players, unless my lazy ass decides to support spectators, wait that wouldnt make sense, like free esp :troll_face:
int g_WhitelistCount = 0;

// stats
int g_Kills[MAXPLAYERS + 1];
int g_Deaths[MAXPLAYERS + 1];
int g_Assists[MAXPLAYERS + 1];
int g_RoundsWon[2];
int g_MVPs[MAXPLAYERS + 1];
int g_RoundKills[MAXPLAYERS + 1];
char g_CurrentMap[32]; // i think 16 would be enough but just in case someone gets great idea of using this plugin with custom maps

// Database
Database g_db;


// funcs
public void OnPluginStart() {
	RegServerCmd("sm_setwhitelist", CMD_WHITELIST);
	RegServerCmd("sm_setranktype", CMD_SETRANKTYPE);
	RegServerCmd("sm_getgamestage", CMD_GETGAMESTAGE);
	HookEvent("player_connect_full", HANDLER_PLAYERCONN);
	AddCommandListener(HANDLER_JOINTEAM, "teammenu");
	AddCommandListener(HANDLER_JOINTEAM, "jointeam");
	SQL_TConnect(OnDatabaseConn, "mmzone", 0);
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

public Action CMD_WHITELIST(int args) {
	Handle cnv = FindConVar("mp_force_pick_time");
	if(cnv) {
		SetConVarInt(cnv, 0);
	}
	if (args < 1) {
		PrintToServer("Missing parameters, sm_setwhitelist <steam2_id>");
	}
	
    char arg[256];
    GetCmdArgString(arg, sizeof(arg));
    g_WhitelistCount = ExplodeString(arg, ",", g_Whitelist, sizeof(g_Whitelist), sizeof(g_Whitelist[]));
    PrintToServer("Whitelisted %d.", g_WhitelistCount);
}

public Action CMD_SETRANKTYPE(int args) {
	if(args < 1) {
		PrintToServer("Missing parameters, sm_setranktype <rank_type>");
		return Plugin_Handled;
	}
	GetCmdArg(1, g_RankType, sizeof(g_RankType));
	
	return Plugin_Handled;
}

public Action CMD_GETGAMESTAGE(int args) {
	// im thinking also, about making instead of just getting game stage, blocking rcon connection instead and do an check on matchmaker side, anyways currently todo
}

public void OnDatabaseConn(Handle own, Handle handle, const char[] err, any data) {
	if(err[0] != '\0') {
		PrintToServer("[MM] Database connection err: %s", err);
		return;
	}
	g_db = view_as<Database>(handle);
	PrintToServer("[MM] Connected to DB");
}

public Action HANDLER_JOINTEAM(int client, const char[] command, int argc) {
    if (!IsValidClient(client))
        return Plugin_Continue;


    return Plugin_Handled;
}

void HANDLER_PLAYERCONN(Event event, const char[] name, bool dontBroadcast) {
	int cl = GetClientOfUserId(event.GetInt("userid"));
	
	CreateTimer(1.0, TIMER_TEAMASSAIGN, cl);
}

public Action TIMER_TEAMASSAIGN(Handle tm, any client) {
    if (!IsClientInGame(client))
        return Plugin_Stop;

    int team = GetClientTeam(client);
    if (team == 2 || team == 3) 
        return Plugin_Stop;

    int randomTeam = GetRandomInt(2, 3);
    ChangeClientTeam(client, randomTeam);

    CS_RespawnPlayer(client);

    return Plugin_Stop;
}
