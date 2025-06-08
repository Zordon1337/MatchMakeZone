const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const db = require('../db');
const tokenUtils = require('../utils/token');

router.get('/info', (req,res) => {
        const u = req.cookies.user;
        if (!u) res.status(401);
        let jsonparsed = JSON.parse(u);
        if(!jsonparsed) res.status(500);


        const user = tokenUtils.verifyToken(jsonparsed.token)
        if(user != false) {
            db.query("SELECT username, steamid FROM users WHERE user_id = ?", [user.id], (err, rows,fields) => {
                if(err) {
                    res.json({error: "Server-side error"});
                }
                if (rows.length === 0) {
                    // what?
                    res.json({error: "User doesn't exist"}).status(401);
                }
                res.json({
                    user_id: user.id,
                    user: rows[0]
                })
            });
        } else {
            res.status(401);
        }
})

module.exports = router