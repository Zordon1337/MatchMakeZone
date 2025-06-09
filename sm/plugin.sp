#include <sdktools>
#include <cstrike>
#include <dbi>

#define MAX_WHITELIST 10
#define MAX_MAP_NAME 32

char g_Whitelist[MAX_WHITELIST][32];
int g_WhitelistCount = 0;

int g_Kills[MAXPLAYERS + 1];
int g_Deaths[MAXPLAYERS + 1];
int g_Assists[MAXPLAYERS + 1];
int g_Aces[MAXPLAYERS + 1];
int g_RoundsWon[2];
int g_EnemyCountAtRoundStart[MAXPLAYERS + 1];

char g_CurrentMap[MAX_MAP_NAME];
Database g_db;
Handle g_dbHandle;
char g_RankType[32] = "None";
bool MatchEnd = false;

public void OnPluginStart()
{
    RegServerCmd("sm_setwhitelist", Command_SetWhitelist);
    RegServerCmd("sm_setranktype", Command_SetRankType);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("cs_win_panel_match", Event_GameEnd);
    HookEvent("nextlevel_changed", Event_MapStart);
    HookEvent("round_freeze_end", Event_RoundFreezeEnd, EventHookMode_Post);
    SQL_TConnect(OnDBConnect, "mmzone", 0);


    GetCurrentMap(g_CurrentMap, sizeof(g_CurrentMap));
    ResetStats();
}
public Action Command_SetRankType(int args)
{
    if (args < 1)
    {
        PrintToServer("Usage: sm_setranktype <rank_type>");
        return Plugin_Handled;
    }

    GetCmdArg(1, g_RankType, sizeof(g_RankType));
    PrintToServer("Rank type set to: %s", g_RankType);
    return Plugin_Handled;
}
public void Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i))
            continue;

        int myTeam = GetClientTeam(i);
        int enemyCount = 0;

        for (int j = 1; j <= MaxClients; j++)
        {
            if (i == j || !IsClientInGame(j) || !IsPlayerAlive(j))
                continue;

            if (GetClientTeam(j) != myTeam && (GetClientTeam(j) == 2 || GetClientTeam(j) == 3))
                enemyCount++;
        }

        g_EnemyCountAtRoundStart[i] = enemyCount;
    }
}


public void OnDBConnect(Handle owner, Handle hndl, const char[] error, any data)
{
    if (error[0] != '\0')
    {
        PrintToServer("[MM] Database connection error: %s", error);
        return;
    }

    g_db = view_as<Database>(hndl);
    g_dbHandle = hndl;
    PrintToServer("[MM] Connected to MySQL database.");
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
void UpdateOrInsertRank(int user_id, int client)
{
    PrintToServer("[MM] UpdateOrInsertRank Start")
    if (g_db == null)
    {
        PrintToServer("[MM] Database not connected.");
        return;
    }

    char escapedRankType[64];
    g_db.Escape(g_RankType, escapedRankType, sizeof(escapedRankType));

    char checkQuery[256];
    Format(checkQuery, sizeof(checkQuery),
        "SELECT rank_id FROM ranks WHERE user_id = %d AND rank_type = '%s'",
        user_id, escapedRankType);

    DBResultSet res = SQL_Query(g_db, checkQuery);
    if (res != null && res.FetchRow())
    {   
        char updateQuery[512];
        Format(updateQuery, sizeof(updateQuery),
            "UPDATE ranks SET \
                kills = kills + %d, \
                deaths = deaths + %d, \
                assists = assists + %d, \
                ace_count = ace_count + %d \
             WHERE user_id = %d AND rank_type = '%s'",
            g_Kills[client],
            g_Deaths[client],
            g_Assists[client],
            g_Aces[client],
            user_id,
            escapedRankType
        );

        SQL_TQuery(g_db, SQL_Callback_Nothing, updateQuery);
        PrintToServer("[MM] Updated rank for user_id %d (type: %s).", user_id, escapedRankType);
    }
    else
    {
        char insertQuery[512];
        Format(insertQuery, sizeof(insertQuery),
            "INSERT INTO ranks (user_id, rank_type, elo, ace_count, kills, deaths, assists) VALUES (%d, '%s', 0, %d, %d, %d, %d)",
            user_id,
            escapedRankType,
            g_Aces[client],
            g_Kills[client],
            g_Deaths[client],
            g_Assists[client]
        );
        SQL_TQuery(g_db, SQL_Callback_Nothing, insertQuery);
        PrintToServer("[MM] Inserted new rank for user_id %d (type: %s).", user_id, escapedRankType);
    }

    delete res;
    PrintToServer("[MM] UpdateOrInsertRank END")
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
            if (kills >= g_EnemyCountAtRoundStart[i] && g_EnemyCountAtRoundStart[i] > 0)
            {
                g_Aces[i]++;
            }
        }
    }
}

public void Event_GameEnd(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("[MM] Event_GameEnd START")
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SavePlayerMatchStats(i);
        }
    }
    PrintToServer("[MM] Event_GameEnd END")
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



public Action Command_SetWhitelist(int args)
{
    if (args < 1)
    {
        PrintToServer("Usage: sm_setwhitelist <steamid1,steamid2,...>");
        return Plugin_Handled;
    }

    char arg[256];
    GetCmdArgString(arg, sizeof(arg));
    g_WhitelistCount = ExplodeString(arg, ",", g_Whitelist, sizeof(g_Whitelist), sizeof(g_Whitelist[]));
    PrintToServer("Whitelist set with %d players.", g_WhitelistCount);
    return Plugin_Handled;
}

public void OnClientAuthorized(int client, const char[] auth)
{

    
       if (StrEqual(auth, "BOT"))
        return;
    PrintToServer("[Whitelist Debug] Client %d auth: %s", client, auth);

    bool allowed = false;
    for (int i = 0; i < g_WhitelistCount; i++)
    {
        PrintToServer("[Whitelist Debug] Checking whitelist entry %d: %s", i, g_Whitelist[i]);
        if (StrEqual(g_Whitelist[i], auth))
        {
            allowed = true;
            break;
        }
    }

    if (!allowed)
    {
        PrintToServer("[Whitelist Debug] Client %d NOT whitelisted, kicking.", client);
        KickClient(client, "You are not whitelisted for this match.");
    }
    else
    {
        PrintToServer("[Whitelist Debug] Client %d whitelisted.", client);
    }
}


public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(3.0, Timer_ShowWelcomeMessage);
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
