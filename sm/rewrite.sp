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
int g_Aces[MAXPLAYERS + 1];
int g_RoundKills[MAXPLAYERS + 1];
char g_CurrentMap[32]; // i think 16 would be enough but just in case someone gets great idea of using this plugin with custom maps

int g_GameStage = 0;

bool MatchEnd = true;
// Database
Database g_db;

int g_ConnectedPlayers = 0;
// funcs
public void OnPluginStart() {
	RegServerCmd("sm_setwhitelist", CMD_WHITELIST);
	RegServerCmd("sm_setranktype", CMD_SETRANKTYPE);
	RegServerCmd("sm_getgamestage", CMD_GETGAMESTAGE);
	HookEvent("player_connect_full", HANDLER_PLAYERCONN);
	HookEvent("player_spawn", HANDLER_PLRSPAWN);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("cs_win_panel_match", Event_GameEnd);
    HookEvent("nextlevel_changed", Event_MapStart);
    HookEvent("round_mvp", Event_RoundMVP);
	// for some reason still cannot completely disable team menu, but joining is blocked so fuck it
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
    PrintToServer("Rank type set to: %s", g_RankType);
    ServerCommand("game_mode %s", g_RankType);
	return Plugin_Handled;
}

public Action CMD_GETGAMESTAGE(int args) {
	// im thinking also, about making instead of just getting game stage, blocking rcon connection instead and do an check on matchmaker side, anyways currently todo
	PrintToServer(g_GameStage)
    return Plugin_Handled;
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
	g_ConnectedPlayers++;
	CreateTimer(1.0, TIMER_TEAMASSAIGN, cl);
	
	
}
void HANDLER_PLRSPAWN(Event event, const char[] name, bool dontBroadcast) {
    int realPlayers = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            realPlayers++;
        }
    }

    if (realPlayers >= g_WhitelistCount) {
        ServerCommand("mp_warmup_end");
        ServerCommand("bot_quota_mode fill");
        ServerCommand("bot_difficulty 3");
        g_GameStage = 1;
    }
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

public void OnClientAuthorized(int client, const char[] auth) {
	
	if(StrEqual(auth, "BOT"))
		return;
		
	PrintToServer("[Whitelist check] Client %d auth: %s", client, auth);
	
	bool bIsAllowed = false;
	
	for (int i = 0; i < g_WhitelistCount; i++) {
		PrintToServer("[Whitelist check] Checking %d: %s",i, g_Whitelist[i]);
		if(StrEqual(g_Whitelist[i], auth)) {
			bIsAllowed = true;
			break;
		}
	}
	
	if(!bIsAllowed) {
		PrintToServer("[Whitelist check] Client %d failed check, kicking...", client);
		KickClient(client, "You are not whitelisted.");
	}
	else {
		PrintToServer("[Whitelist check] Client %d passed check", client);
	}

}
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(5.0, Timer_ShowWelcomeMessage);
}
public Action Timer_ShowWelcomeMessage(Handle timer)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i))
        {
            PrintCenterText(i, "You are playing on MatchmakeZone");
        }
    }
    return Plugin_Stop;
}

public void Event_MapStart(Event event, const char[] name, bool dontBroadcast)
{
    GetCurrentMap(g_CurrentMap, sizeof(g_CurrentMap));
    ResetStats();
}

void ResetStats()
{
    PrintToServer("[MM] ResetStats START")
    for (int i = 1; i <= MaxClients; i++)
    {
        g_Kills[i] = 0;
        g_Deaths[i] = 0;
        g_Assists[i] = 0;
        g_Aces[i] = 0;
    }
    g_RoundsWon[0] = 0;
    g_RoundsWon[1] = 0;
    PrintToServer("[MM] ResetStats END")
}
public void SQL_Callback_Nothing(Handle owner, Handle hndl, const char[] error, any data) {
    if (error[0] != '\0') {
        PrintToServer("[MM] SQL error: %s", error);
    }
}
int CalculateEloChange(int client, bool didWin, int wonRounds, int lostRounds)
{
    int newElo = 0;

    float safeDeaths = (g_Deaths[client] > 0) ? float(g_Deaths[client]) : 1.0;

    float kdr = float(g_Kills[client]) / safeDeaths;
    float assistBonus = float(g_Assists[client]) * 0.3;
    float aceBonus = float(g_Aces[client]) * 2.0;
    float mvpBonus = float(g_MVPs[client]) * 1.0;

    float performanceScore = kdr + assistBonus + aceBonus + mvpBonus;

    float roundMargin = float(wonRounds - lostRounds);
    float closenessFactor = 1.0 - (FloatAbs(roundMargin) / 15.0);
    if (closenessFactor < 0.1)
    {
        closenessFactor = 0.1;
    }

    int baseEloChange = 25;

    if (didWin)
    {
        newElo += RoundToFloor(float(baseEloChange) * closenessFactor);
        newElo += RoundToFloor(performanceScore);
    }
    else
    {
        newElo -= RoundToCeil(float(baseEloChange) * (1.1 - closenessFactor));
        newElo += RoundToFloor(performanceScore * 0.5);
    }

    if (newElo > 50)
    {
        newElo = 50;
    }
    else if (newElo < -40)
    {
        newElo = -40;
    }

    return newElo;
}
void GetCSGORankName(int elo, char[] rankName, int maxLen)
{
    if (elo <= 0)
    {
        strcopy(rankName, maxLen, "Silver I");
    }
    else if (elo <= 100)
    {
        strcopy(rankName, maxLen, "Silver II");
    }
    else if (elo <= 200)
    {
        strcopy(rankName, maxLen, "Silver III");
    }
    else if (elo <= 300)
    {
        strcopy(rankName, maxLen, "Silver IV");
    }
    else if (elo <= 400)
    {
        strcopy(rankName, maxLen, "Silver Elite");
    }
    else if (elo <= 500)
    {
        strcopy(rankName, maxLen, "Silver Elite Master");
    }
    else if (elo <= 600)
    {
        strcopy(rankName, maxLen, "Gold Nova I");
    }
    else if (elo <= 700)
    {
        strcopy(rankName, maxLen, "Gold Nova II");
    }
    else if (elo <= 800)
    {
        strcopy(rankName, maxLen, "Gold Nova III");
    }
    else if (elo <= 900)
    {
        strcopy(rankName, maxLen, "Gold Nova Master");
    }
    else if (elo <= 1000)
    {
        strcopy(rankName, maxLen, "Master Guardian I");
    }
    else if (elo <= 1100)
    {
        strcopy(rankName, maxLen, "Master Guardian II");
    }
    else if (elo <= 1200)
    {
        strcopy(rankName, maxLen, "Master Guardian Elite");
    }
    else if (elo <= 1300)
    {
        strcopy(rankName, maxLen, "Distinguished Master");
    }
    else if (elo <= 1400)
    {
        strcopy(rankName, maxLen, "Legendary Eagle");
    }
    else if (elo <= 1500)
    {
        strcopy(rankName, maxLen, "Legendary Eagle Master");
    }
    else if (elo <= 1600)
    {
        strcopy(rankName, maxLen, "Supreme Master First");
    }
    else
    {
        strcopy(rankName, maxLen, "Global Elite");
    }
}


void UpdateOrInsertRank(int user_id, int client)
{
    int team = GetClientTeam(client);
    bool didWin = false;
    int wonRounds = 0;
    int lostRounds = 0;

    if (team == 2)
    {
        wonRounds = g_RoundsWon[0];
        lostRounds = g_RoundsWon[1];
        if (wonRounds > lostRounds)
        {
            didWin = true;
        }
    }
    else if (team == 3)
    {
        wonRounds = g_RoundsWon[1];
        lostRounds = g_RoundsWon[0];
        if (wonRounds > lostRounds)
        {
            didWin = true;
        }
    }

    int wins = didWin ? 1 : 0;

    if (g_db == null)
    {
        PrintToServer("[MM] Database not connected.");
        return;
    }

    char escapedRankType[64];
    g_db.Escape(g_RankType, escapedRankType, sizeof(escapedRankType));

    char checkQuery[256];
    Format(checkQuery, sizeof(checkQuery),
        "SELECT rank_id, kills, deaths, assists, ace_count, elo FROM ranks WHERE user_id = %d AND rank_type = '%s'",
        user_id, escapedRankType);

    DBResultSet res = SQL_Query(g_db, checkQuery);

    int oldElo = 0;
    char oldRankName[64] = "";
    if (res != null && res.FetchRow())
    {
        int currentKills   = res.FetchInt(1);
        int currentDeaths  = res.FetchInt(2);
        int currentAssists = res.FetchInt(3);
        int currentAces    = res.FetchInt(4);

        GetCSGORankName(oldElo, oldRankName, sizeof(oldRankName));
        int newEloDelta = CalculateEloChange(client, didWin, wonRounds, lostRounds);
        if (newEloDelta > 50) newEloDelta = 50;
        else if (newEloDelta < -40) newEloDelta = -40;
        int updatedElo = oldElo + newEloDelta;

        char updateQuery[512];
        Format(updateQuery, sizeof(updateQuery),
            "UPDATE ranks SET \
                kills = kills + %d, \
                deaths = deaths + %d, \
                assists = assists + %d, \
                ace_count = ace_count + %d, \
                wins = wins + %d, \
                elo = elo + %d \
            WHERE user_id = %d AND rank_type = '%s'",
            g_Kills[client],
            g_Deaths[client],
            g_Assists[client],
            g_Aces[client],
            wins,
            updatedElo,
            user_id,
            escapedRankType
        );

        SQL_TQuery(g_db, SQL_Callback_Nothing, updateQuery);
        PrintToServer("[MM] Updated rank for user_id %d (type: %s).", user_id, escapedRankType);
        char newRankName[64];
        GetCSGORankName(oldElo, newRankName, sizeof(newRankName));
        if (StrEqual(oldRankName, newRankName, false) == false)
        {
            if (IsClientInGame(client))
            {
                PrintToChat(client, "[MM] Your rank changed from %s to %s!", oldRankName, newRankName);
            }
        }
    }
    else
    {
        char insertQuery[512];
        Format(insertQuery, sizeof(insertQuery),
            "INSERT INTO ranks (user_id, rank_type, elo, ace_count, kills, deaths, assists, wins) VALUES (%d, '%s', 0, %d, %d, %d, %d, %d)",
            user_id,
            escapedRankType,
            g_Aces[client],
            g_Kills[client],
            g_Deaths[client],
            g_Assists[client],
            wins
        );
        SQL_TQuery(g_db, SQL_Callback_Nothing, insertQuery);
        PrintToServer("[MM] Inserted new rank for user_id %d (type: %s).", user_id, escapedRankType);
    }

    delete res;
    PrintToServer("[MM] UpdateOrInsertRank END");
}




public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int assister = GetClientOfUserId(event.GetInt("assister"));

    if (IsClientInGame(attacker) && attacker != victim)
    {
        g_Kills[attacker]++;
    }

    if (IsClientInGame(victim))
    {
        g_Deaths[victim]++;
    }

    if (IsClientInGame(assister))
    {
        g_Assists[assister]++;
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    int winner = event.GetInt("winner");
    if (winner == 2) g_RoundsWon[0]++;
    else if (winner == 3) g_RoundsWon[1]++;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            int kills = GetEntProp(i, Prop_Data, "m_iNumRoundKills");
            if (kills >= 5)
            {
                g_Aces[i]++;
            }
        }
    }
}

public void Event_GameEnd(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("[MM] Event_GameEnd START");
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SavePlayerMatchStats(i);
        }
    }
    for (int i = 0; i < g_WhitelistCount; i++)
    {
        g_Whitelist[i][0] = '\0';
    }
    g_WhitelistCount = 0;
    PrintToServer("[MM] Whitelist cleared.");



    CreateTimer(15.0, Timer_KickPlayers, _, TIMER_FLAG_NO_MAPCHANGE);
    PrintToServer("[MM] Event_GameEnd END");
}
public Action Timer_KickPlayers(Handle timer)
{
    PrintToServer("[MM] Kicking players after stats save...");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsClientConnected(i))
        {
            KickClient(i, "Match ended. Returning to queue...");
        }
    }
    g_GameStage = 0;
    return Plugin_Stop;
}

void SavePlayerMatchStats(int client)
{
    PrintToServer("[MM] SavePlayerMatchStats START")
    if (g_db == null)
    {
        PrintToServer("[MM] Database not connected. Can't save stats.");
        return;
    }

    char steamid[32];
    GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));

    char escaped[64];
    g_db.Escape(steamid, escaped, sizeof(escaped));

    char query[256];
    Format(query, sizeof(query), "SELECT user_id FROM users WHERE steamid = '%s'", escaped);
    SQL_TQuery(g_db, OnUserIdFetched, query, client);

    PrintToServer("[MM] SavePlayerMatchStats END")

    MatchEnd = true;
    

}

public void OnUserIdFetched(Handle owner, Handle hndl, const char[] error, any data)
{
    PrintToServer("[MM] OnUserIdFetched START")
    int client = data;

    if (error[0] != '\0')
    {
        PrintToServer("[MM] SQL error: %s", error);
        MatchEnd = false;
        return;
    }

    if (SQL_GetRowCount(hndl) == 0)
    {
        PrintToServer("[MM] No user found for client %d.", client);
        MatchEnd = false;
        return;
    }

    SQL_FetchRow(hndl);
    int user_id = SQL_FetchInt(hndl, 0);

    if (MatchEnd) {
        char deleteQuery[128];
        Format(deleteQuery, sizeof(deleteQuery),
            "DELETE FROM ongoing_matches WHERE user_id = %d",
            user_id);
        SQL_Query(owner, deleteQuery);
        MatchEnd = false;
    }

    char escapedMap[64];
    g_db.Escape(g_CurrentMap, escapedMap, sizeof(escapedMap));

    char query[512];
    Format(query, sizeof(query),
        "INSERT INTO matches (user_id, map, rounds_won, rounds_lost, kills, deaths, assists, ace_count) VALUES (%d, '%s', %d, %d, %d, %d, %d, %d)",
        user_id,
        escapedMap,
        g_RoundsWon[0],
        g_RoundsWon[1],
        g_Kills[client],
        g_Deaths[client],
        g_Assists[client],
        g_Aces[client]
    );

    SQL_Query(owner, query);
    PrintToServer("[MM] Saved stats for user_id %d (client %d).", user_id, client);

    UpdateOrInsertRank(user_id, client);
    PrintToServer("[MM] OnUserIdFetched END")
}


public void Event_RoundMVP(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    if (client > 0 && client <= MaxClients && IsClientInGame(client))
    {
        g_MVPs[client]++;
        PrintToServer("[MM] MVP awarded to: %N", client);
    }
}
