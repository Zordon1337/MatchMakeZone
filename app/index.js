const exp = require('express')
var app = exp();
var port = 5500;

app.use(exp.static("http"))

app.get("/login",(req,res)=>{
    res.sendFile("http/login.html")
})
app.get("/register",(req,res)=>{
    res.sendFile("http/register.html")
})
app.get("/",(req,res)=>{
    res.sendFile("http/index.html")
})

app.listen(port, ()=> {
    console.log("Frontend listening on port 5500")
})