const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const db = require('../db');
const tokenUtils = require('../utils/token');
router.post('/register', (req, res) => {
    const { username, password, email } = req.body;
    if (!username || !password || !email) {
      return res.status(400).json({ error: 'All fields are required' });
    }
    db.query('SELECT * FROM users WHERE username = ? OR email = ?', [username, email], (err, result) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }
    
      if (result.length > 0) {
        return res.status(400).json({ error: 'Account with such name or email already exists' });
      }
      const hashedPassword = bcrypt.hashSync(password, 10);
      var response = {}
      db.query('INSERT INTO users (username, password, email) VALUES (?, ?, ?)', [username, hashedPassword, email], (err, result) => {
          if (err) {
              console.error('Database error:', err);
              return res.status(500).json({ error: 'Internal server error' });
          }
          if (result.affectedRows === 0) {
              return res.status(400).json({ error: 'Failed to register user' });
          }
          const user = {
              user_id: result.insertId,
              username: username,
              email: email,
              steamid: 0
          };
          const token = tokenUtils.generateToken(user);
          res.cookie('user', JSON.stringify({ token: token, user: { id: user.user_id, username: user.username, email: user.email, steamid: user.steamid } }), {
            httpOnly: true,
            secure: false,
            sameSite: "strict",
            maxAge: 180 * 24 * 60 * 60 * 1000
          })
          res.json({ token: token, user: { id: user.user_id, username: user.username, email: user.email, steamid: user.steamid } }); 
        });
    });
    
});

router.post('/login', (req, res) => {
    const {username, password} = req.body;
    if (!username || !password) {
        return res.status(400).json({ error: 'Username or Password not present' });
    }
    db.query('SELECT * FROM users WHERE username = ?', [username] , (err, rows,fields) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ error: 'Internal server error' });
        }
        if (rows.length === 0) {
            return res.status(401).json({ error: 'Invalid username or password' });
        }
        const user = rows[0];
        bcrypt.compare(password, user.password, (err, isMatch)=>{
          if (!isMatch || err) 
          {
            return res.status(401).json({ error: 'Invalid username or password'})
          }

          const token = tokenUtils.generateToken(user);
          res.cookie('user', JSON.stringify({ token: token, user: { id: user.user_id, username: user.username, email: user.email, steamid: user.steamid } }), {
            httpOnly: true,
            secure: false,
            sameSite: "strict",
            maxAge: 180 * 24 * 60 * 60 * 1000
          })
          return res.json({ token: token, user: { id: user.user_id, username: user.username, email: user.email, steamid: user.steamid } });
        })
    });
});


module.exports = router;