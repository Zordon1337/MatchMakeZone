const exp = require('express')
const path = require('path');
var app = exp();
var port = 5500;

app.use(exp.static("http"))

app.get("/login",(req,res)=>{
    res.sendFile(path.join(__dirname, 'http','login.html'));
})
app.get("/register",(req,res)=>{
    res.sendFile(path.join(__dirname, 'http','register.html'))
})
app.get("/",(req,res)=>{
    res.sendFile(path.join(__dirname, 'http',"index.html"))
})

app.listen(port, ()=> {
    console.log("Frontend listening on port 5500")
})