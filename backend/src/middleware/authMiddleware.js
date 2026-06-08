const jwt = require('jsonwebtoken');
const pool = require('../config/db');

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'Thiếu token xác thực' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.type !== 'access') {
      return res.status(401).json({ message: 'Sai loại token xác thực' });
    }

    const [users] = await pool.query(
      'SELECT id, full_name, email, created_at, updated_at FROM users WHERE id = ?',
      [decoded.id]
    );

    if (users.length === 0) {
      return res.status(401).json({ message: 'Token không hợp lệ' });
    }

    req.user = users[0];
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Token hết hạn hoặc không hợp lệ' });
  }
};

module.exports = authMiddleware;
