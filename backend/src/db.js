const sql = require('mysql2');
const cfg = require('./config');

var db = sql.createPool({
    host: cfg.db.host,
    user: cfg.db.user,
    password: cfg.db.password,
    database: cfg.db.database,
    connectionLimit: 30,
    waitForConnections: true,
    queueLimit: 0
})

    
module.exports = db