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