// my sourcemod experience is very basic, i dont know even if i can move funcs to other files(i would love to)
#include <dbi>
#include <cstrike>
#include <sdktools>


// vars

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
}

public Action CMD_WHITELIST(int args) {
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