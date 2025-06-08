const jwt = require('jsonwebtoken');
const cfg = require('../config');
const db = require('../db');
function generateToken(user) {
    const payload = {
        id: user.user_id
    };
    var token = jwt.sign(payload, cfg.secureKey, { expiresIn: '180d' }); // generate user token for 180 days
    db.query('INSERT INTO tokens (user_id, token) VALUES (?, ?)', [user.user_id, token], (err) => {
        if (err) {
            console.error('Error inserting token into database:', err);
            return false;
        }
    });
    return token;
}

function verifyToken(token) {
    try {
        const decoded = jwt.verify(token, cfg.secureKey);
        db.query('SELECT * FROM tokens WHERE token = ?', [token], (err, results) => {
            if (err) {
                console.error('Error querying token in database:', err);
                return false;
            }
            if (results.length === 0) {
                return false;
            }
        });
        return decoded;
    } catch (err) {
        console.error('Token verification failed:', err);
        return false;
    }
}

module.exports = {
    generateToken,
    verifyToken
};