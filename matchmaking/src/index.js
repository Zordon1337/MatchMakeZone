const webSocket = require('ws');
const ws = new webSocket.Server({port:9797})

let peopleSearching = 0;
let usersSearching = [];
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
            case "Client2MM_FindMatch":
                {
                    user.gameMode = msg.gamemode;
                    user.mapSelection = msg.maps;
                    if (!usersSearching.includes(user)) {
                        usersSearching.push(user);
                        peopleSearching++;
                    }                    
                    console.log(`${user.username} searches for match on ${user.mapSelection}, GameMode: ${user.gameMode}`)
                    break;
                }
            case "Client2MM_CancelSearch": {
                peopleSearching--;
                usersSearching = usersSearching.filter(usr => usr !== user);
                user.mapSelection = []
                user.gameMode = -1;
                break;
            }
        }
    })
}) 
function findMatchWithCommonMap(usersSearching, requiredPlayers = 4) {
    if (usersSearching.length < requiredPlayers) return null;


    for (let i = 0; i <= usersSearching.length - requiredPlayers; i++) {
        let baseUser = usersSearching[i];
        let potentialGroup = [baseUser];

        let commonMaps = new Set(baseUser.mapSelection);

        for (let j = i + 1; j < usersSearching.length && potentialGroup.length < requiredPlayers; j++) {
            let candidate = usersSearching[j];

            let intersection = candidate.mapSelection.filter(map => commonMaps.has(map));

            if (intersection.length > 0) {
                commonMaps = new Set(intersection);
                potentialGroup.push(candidate);
            }
        }

        if (potentialGroup.length === requiredPlayers && commonMaps.size > 0) {
            return {
                group: potentialGroup,
                commonMap: [...commonMaps][0]
            };
        }
    }
    return null;
}

setInterval(() => {
    while (true) {
        let result = findMatchWithCommonMap(usersSearching, 4);
        if (!result) break; 

        let { group, commonMap } = result;

        usersSearching = usersSearching.filter(u => !group.includes(u));
        peopleSearching -= group.length;

        group.forEach(user => {
            user.client.send(JSON.stringify({
                pid: "MM2Client_FoundMatch",
                map: commonMap,
                serverip: "TODO"
            }));
            console.log(`Sent MM2Client_FoundMatch to ${user.username} on ${commonMap}`)
        });
    }
}, 1000);
