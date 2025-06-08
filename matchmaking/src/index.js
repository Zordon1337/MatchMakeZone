const webSocket = require('ws');
const ws = new webSocket.Server({port:9797})
const mysql = require('mysql2/promise');
const cfg = require('./config.json')
const serverpool = require("./serverpool.json")
const pool = mysql.createPool({
    host: cfg.host,
    user: cfg.user,
    database: cfg.db,
    password: cfg.password,
    waitForConnections: true
});

let peopleSearching = 0;
let usersSearching = [];
const matchedUsers = new Set();

async function isUserInMatch(steamid) {
    const [rows] = await pool.execute(
        `SELECT ongoing_matches.user_id FROM ongoing_matches
         JOIN users ON users.user_id = ongoing_matches.user_id
         WHERE users.steamid = ?`, [steamid]);

    return rows.length > 0;
}
function steam64ToSteam2(steam64) {
    const steam64BigInt = BigInt(steam64);
    const steam64Base = BigInt("76561197960265728");
  
    if (steam64BigInt < steam64Base) {
      throw new Error("Invalid Steam64 ID");
    }
  
    const accountId = steam64BigInt - steam64Base;
    const authServer = accountId & BigInt(1);
    const accountNumber = accountId >> BigInt(1);  
    const universe = 1;
  
    return `STEAM_${universe}:${authServer.toString()}:${accountNumber.toString()}`;
}
function removeUsersFromMatched(users) {
    for (const user of users) {
      matchedUsers.delete(user.steamid);
    }
}
  
async function syncMatchedUsersWithDB() {
    const [rows] = await pool.execute(`SELECT users.steamid FROM ongoing_matches JOIN users ON ongoing_matches.user_id = users.user_id`);
    const steamidsInDb = new Set(rows.map(row => row.steamid));
  
    for (const steamid of matchedUsers) {
      if (!steamidsInDb.has(steamid)) {
        matchedUsers.delete(steamid);
      }
    }
  }
setInterval(syncMatchedUsersWithDB, 10000);
  
ws.on('connection',client => {
    let user = {
        steamid: 0,
        username: "Unknown",
        mapSelection: [],
        gameMode: -1,
        client
    }
    client.on("message", message => {
        let msg = JSON.parse(message);
        let packet = msg.pid;
        console.log(`Received packet ${packet} from ${user.username}`)

        switch(packet) {
            case "Client2MM_Hello": {
                user.steamid = msg.steamid
                user.username = msg.username;
                user.client = client;
                break;
            }
            case "Client2MM_FindMatch": {
                isUserInMatch(user.steamid).then(inMatch => {
                    if (inMatch || matchedUsers.has(user.steamid)) { 
                        console.log(`${user.username} tried to search but is already in a match.`);
                        client.send(JSON.stringify({
                            "pid":"MM2Client_MatchmakeFail",
                            "why":"You are already in ongoing match"
                        }))
                        return;
                    }
                    if (user.steamid === 0 || user.steamid == '') {
                        console.log(`${user.username} attempted to search match without valid steamid`);
                        client.send(JSON.stringify({
                            "pid":"MM2Client_MatchmakeFail",
                            "why":"You didin't link your steam account yet"
                        }))
                        return;
                    }
                    user.gameMode = msg.gamemode;
                    user.mapSelection = msg.maps;
                    if (!usersSearching.some(u => u.steamid === user.steamid) && !matchedUsers.has(user.steamid)) {
                        usersSearching.push(user);
                        peopleSearching++;
                      }
                      
                    console.log(`${user.username} searches for match on ${user.mapSelection}, GameMode: ${user.gameMode}`);
                });
                break;
            }  
            case "Client2MM_CancelSearch": {
                usersSearching = usersSearching.filter(usr => usr !== user);
                peopleSearching = Math.max(0, usersSearching.length); 
                user.mapSelection = [];
                user.gameMode = -1;
                break;
            }
        }
    })
}) 

function findMatchWithCommonMap(usersSearching, requiredPlayers = 4) {
    if (usersSearching.length < requiredPlayers) {
        console.log(`Not enough users searching: ${usersSearching.length} < ${requiredPlayers}`);
        return null;
    }

    for (let i = 0; i <= usersSearching.length - requiredPlayers; i++) {
        let baseUser = usersSearching[i];
        console.log(`Trying base user ${baseUser.username} with maps: ${baseUser.mapSelection}`);

        let potentialGroup = [baseUser];
        let commonMaps = new Set(baseUser.mapSelection);

        for (let j = i + 1; j < usersSearching.length && potentialGroup.length < requiredPlayers; j++) {
            let candidate = usersSearching[j];
            let intersection = candidate.mapSelection.filter(map => commonMaps.has(map));
            console.log(`Candidate ${candidate.username} maps: ${candidate.mapSelection}, intersection with commonMaps: ${intersection}`);

            if (intersection.length > 0) {
                commonMaps = new Set(intersection);
                potentialGroup.push(candidate);
                console.log(`Added ${candidate.username} to potential group; commonMaps now: ${[...commonMaps]}`);
            }
        }

        if (potentialGroup.length === requiredPlayers && commonMaps.size > 0) {
            console.log(`Found group with common map: ${[...commonMaps][0]} -> Group: ${potentialGroup.map(u => u.username)}`);
            return {
                group: potentialGroup,
                commonMap: [...commonMaps][0]
            };
        }
    }
    console.log(`No match found this iteration.`);
    return null;
}

setInterval(async () => {
    while (true) {
        let result = findMatchWithCommonMap(usersSearching, 4);
        if (!result) break;

        let { group, commonMap } = result;

        const matchedSteamIds = new Set(group.map(u => u.steamid));
        usersSearching = usersSearching.filter(u => !matchedSteamIds.has(u.steamid));

        peopleSearching -= group.length;

        // todo pick server
        let server = serverpool[0];

        for (let user of group) {
            try {
                const [rows] = await pool.execute(
                    `SELECT user_id FROM users WHERE steamid = ?`,
                    [user.steamid]
                );

                if (rows.length > 0) {
                    const userId = rows[0].user_id;
                    await pool.execute(
                        'INSERT INTO ongoing_matches (user_id, serverip, serverport) VALUES (?,?,?)',
                        [userId, server.ip, server.port]
                      );
                      
                    matchedUsers.add(user.steamid); // <-- added
                }
            } catch (err) {
                console.error(`Error inserting into ongoing_matches for ${user.username}:`, err);
            }
        }
        let i = 1;
        let whitelist = ''
        group.forEach(user => {
            user.client.send(JSON.stringify({
                pid: "MM2Client_FoundMatch",
                map: commonMap,
                serverip: `connect ${server.ip}:${server.port}`
            }));
            if(i === 1) {
                whitelist +=steam64ToSteam2(user.steamid)
            } else {

                whitelist += ","+steam64ToSteam2(user.steamid)
            }
            console.log(`Sent MM2Client_FoundMatch to ${user.username} on ${commonMap}`);
            i++;
        });

        // connect to rcon and execute some commands
        let rcon = require('srcds-rcon')({
            address: server.ip + `:${server.port}`,
            password: server.rconpassword,
        });
        rcon.connect().then(()=> {
            rcon.command(`game_mode 2; game_type 0; map ${commonMap}`) // todo, handle wingman and mm
            console.log(`sm_setranktype 2;sm_setwhitelist ${whitelist}`)
            rcon.command(`sm_setranktype 2;sm_setwhitelist ${whitelist}`)
        })
    }
}, 1000);