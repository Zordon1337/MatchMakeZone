const Express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const auth = require('./routes/auth');
const token = require('./routes/token')
const user = require('./routes/user')
const cookieparser = require('cookie-parser')
var app = Express();
var port = 1337;


app.use(cookieparser());
app.use(cors({
  origin: 'http://127.0.0.1:5500', 
  credentials: true
}));

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

app.use('/api/v1/auth/', auth);
app.use('/api/v1/token/', token)
app.use('/api/v1/user/', user)




app.listen(port, () => {
  console.log(`Backend is running on 0.0.0.0:${port}`);
});