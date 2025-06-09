let ws;
let steamid = 0;
let username = "";
let searching = false;
let timerInterval;
let secondsElapsed = 0;

function updateTimerDisplay() {
    let minutes = String(Math.floor(secondsElapsed / 60)).padStart(2, '0');
    let seconds = String(secondsElapsed % 60).padStart(2, '0');
    document.getElementById("mm-clock").innerText = `${minutes}:${seconds}`;
}

function connectWS() {
    ws = new WebSocket('ws://127.0.0.1:9797'); 

    ws.onopen = () => {
      let packet = {
          "pid": "Client2MM_Hello",
          "steamid": steamid,
          "username": username
      }
      ws.send(JSON.stringify(packet))
    };

    ws.onmessage = (event) => {
      let msg = JSON.parse(event.data);
      console.log("Received from server:", msg);

      if (msg.pid === "MM2Client_FoundMatch") {
        alert(`Match found! Map: ${msg.map}, Server IP: ${msg.serverip}`);
        document.getElementById("mm-clock").style.display = 'none';
        cancelSearch(true);
      }
      if (msg.pid === "MM2Client_MatchmakeFail") {
        alert(`Matchmaking failed for following reason: ${msg.why}`)
        cancelSearch(true);
      }
    };

    ws.onclose = () => {
      console.log("WebSocket disconnected, reconnecting in 3s...");
      setTimeout(connectWS, 3000);
    };

    ws.onerror = (e) => {
      console.error("WebSocket error", e);
    };
}

window.onload = () => {
    connectWS();
};

function pickMap(map) {
    let m = document.getElementById(map);
    if(!m) return;

    if(m.classList.contains("map-tile-active")) 
    {
        m.classList.remove("map-tile-active")
    } else {
        m.classList.add("map-tile-active")
    }
}

function addMap(map) {
    let m = document.createElement("div");
    m.classList.add('map-tile');
    m.style = `background-image: url('src/icons/${map}.png');`;
    m.id = map;
    m.onclick = () => pickMap(map);
    let cstn = map.replace("de_","")
    .replace("gd_","")
    .replace("ar_","")
    .replace("dz_","")
    .replace("cs_","");
    m.innerText = cstn;
    var lst = document.getElementsByClassName("map-grid")[0]
    if(lst) lst.appendChild(m);
}

function setGamemode(mode) {
    document.getElementsByClassName("map-grid")[0].innerHTML = ''
    document.getElementById("compbtn").classList.remove("mode-card-active")
    document.getElementById("wmbtn").classList.remove("mode-card-active")
    switch(mode) {
        case "5v5": {
            addMap("de_mirage");
            addMap("de_dust2");
            addMap("de_vertigo");
            addMap("de_cbble");
            addMap("de_nuke");
            addMap("de_inferno");
            addMap("cs_office");
            addMap("cs_agency");

            document.getElementById("compbtn").classList.add("mode-card-active")
            break;
        }
        case "2v2": {
            addMap("gd_cbble");
            addMap("de_inferno");
            addMap("de_lake");
            addMap("de_shortdust");
            addMap("de_shortnuke");
            addMap("de_vertigo");
            addMap("de_overpass");
            addMap("de_train");

            document.getElementById("wmbtn").classList.add("mode-card-active")
            break;
        }
    }
}

function matchmake() {
    if(searching) {
        cancelSearch(false);
        return;
    }

    let isWingman = document.getElementById("wmbtn").classList.contains("mode-card-active");
    let maps = []
    let mappick = document.getElementsByClassName("map-tile-active");
    for(let i = 0; i < mappick.length; i++) {
        maps.push(mappick.item(i).innerText)
    }

    let packet = {
        "pid": "Client2MM_FindMatch",
        "gamemode": isWingman ? 2 : 1,
        "maps": maps
    }

    if(ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(packet));
    } else {
        alert("Connection to server lost...");
    }

    document.getElementById("mm-clock").style.display = 'block';
    document.getElementsByClassName("queue-btn")[0].innerText = "Cancel Search";
    searching = true;

    secondsElapsed = 0;
    updateTimerDisplay(); 
    timerInterval = setInterval(() => {
      secondsElapsed++;
      updateTimerDisplay();
    }, 1000);
}

function cancelSearch(skipWS) {
    if(!skipWS && ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ pid: "Client2MM_CancelSearch" }));
    }

    document.getElementById("mm-clock").style.display = 'none';
    document.getElementsByClassName("queue-btn")[0].innerText = "Find Match";
    searching = false;

    clearInterval(timerInterval);
    secondsElapsed = 0;
    updateTimerDisplay();
}
