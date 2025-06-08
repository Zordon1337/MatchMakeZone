let ws;
let steamid = 0;
let username = "";
let searching = false;
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
            addMap("de_shortdust");
            addMap("de_lake");
            addMap("de_shortnuke");
            addMap("de_vertigo");
            addMap("gd_cbble");

            document.getElementById("wmbtn").classList.add("mode-card-active")
            break;
        }
    }
}

function matchmake() {

    if(searching) {
        cancelSearch();
        return;
    }
    let isWingman = document.getElementById("wmbtn").classList.contains("mode-card-active");
    let isComp = !isWingman

    let maps = []
    let mappick = document.getElementsByClassName("map-tile-active");
    for(let i = 0; i < mappick.length; i++) {
        maps.push(mappick.item(i).innerText)
    }
    let packet = {
        "pid": "Client2MM_FindMatch",
        "gamemode": isWingman ? 1 : 0,
        "maps": maps
    }

    document.getElementById("mm-clock").style.display = 'block';

    if(ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(packet));
    } else {
      alert("Connection to server lost...");
    }

    document.getElementsByClassName("queue-btn")[0].innerText = "Cancel Search";
    searching = true;
}

function cancelSearch() {
    if(ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ pid: "Client2MM_CancelSearch" }));
      document.getElementById("mm-clock").style.display = 'none';
      document.getElementsByClassName("queue-btn")[0].innerText = "Find Match";
    }
    searching = false;
  }
  