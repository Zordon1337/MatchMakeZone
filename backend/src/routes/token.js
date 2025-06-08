const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const db = require('../db');
const tokenUtils = require('../utils/token');

router.get('/validate', (req, res) => {
    const u = req.cookies.user;
    if (!u) {
      return res.status(401).json({ error: 'No user cookie' });
    }
  
    let parsed;
    try {
      parsed = JSON.parse(u);
    } catch (e) {
      return res.status(400).json({ error: 'Invalid cookie format' });
    }
  
    const user = tokenUtils.verifyToken(parsed.token);
    if (user) {
      return res.json({ result: 1 });
    } else {
      return res.status(401).json({ error: 'Invalid token' });
    }
  });
  
module.exports = router