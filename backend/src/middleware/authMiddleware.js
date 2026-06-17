const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const {
  assertSessionActive,
  touchSession,
} = require('../services/sessionService');

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Thiếu token xác thực',
        errorCode: 'INVALID_TOKEN',
      });
    }

    const token = authHeader.split(' ')[1];
    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET);
    } catch (error) {
      const errorCode =
        error.name === 'TokenExpiredError'
          ? 'ACCESS_TOKEN_EXPIRED'
          : 'INVALID_TOKEN';
      return res.status(401).json({
        success: false,
        message: 'Token hết hạn hoặc không hợp lệ',
        errorCode,
      });
    }

    if (decoded.type !== 'access') {
      return res.status(401).json({
        success: false,
        message: 'Sai loại token xác thực',
        errorCode: 'INVALID_TOKEN',
      });
    }

    const [users] = await pool.query(
      'SELECT id, full_name, email, created_at, updated_at FROM users WHERE id = ?',
      [decoded.id]
    );

    if (users.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Token không hợp lệ',
        errorCode: 'INVALID_TOKEN',
      });
    }

    if (!decoded.sessionId || !decoded.deviceIdHash) {
      return res.status(401).json({
        success: false,
        message: 'Token không hợp lệ, vui lòng đăng nhập lại',
        errorCode: 'INVALID_TOKEN',
      });
    }

    try {
      await assertSessionActive({
        sessionId: decoded.sessionId,
        userId: decoded.id,
        deviceIdHash: decoded.deviceIdHash,
      });
      await touchSession(decoded.sessionId);
      req.sessionId = decoded.sessionId;
      req.deviceIdHash = decoded.deviceIdHash;
    } catch (error) {
      return res.status(error.statusCode || 401).json({
        success: false,
        message: error.message,
        errorCode: error.errorCode || 'SESSION_REVOKED',
      });
    }

    req.user = users[0];
    next();
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Không thể xác thực phiên đăng nhập',
    });
  }
};

module.exports = authMiddleware;
