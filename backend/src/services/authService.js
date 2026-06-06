const bcrypt = require('bcrypt');
const pool = require('../config/db');
const generateToken = require('../utils/generateToken');
const createDeviceFingerprint = require('../utils/deviceFingerprint');
const { detectLoginRisk } = require('./anomalyDetectionService');
const { sendLoginAlertEmail } = require('./emailService');

const sanitizeUser = (user) => ({
  id: user.id,
  full_name: user.full_name,
  email: user.email,
  created_at: user.created_at,
  updated_at: user.updated_at,
});

const getClientIp = (req) => {
  const forwardedFor = req.headers['x-forwarded-for'];
  if (forwardedFor) {
    return forwardedFor.split(',')[0].trim();
  }
  return req.ip || req.socket.remoteAddress || 'unknown';
};

const saveFailedAttempt = async ({ email, ipAddress }) => {
  await pool.query(
    'INSERT INTO failed_login_attempts (email, ip_address) VALUES (?, ?)',
    [email, ipAddress]
  );
};

const countRecentFailedAttempts = async ({ email }) => {
  const [[stats]] = await pool.query(
    `SELECT COUNT(*) AS total
     FROM failed_login_attempts
     WHERE email = ? AND attempt_time >= (NOW() - INTERVAL 15 MINUTE)`,
    [email]
  );
  return stats.total || 0;
};

const register = async ({ full_name, email, password }) => {
  const normalizedEmail = email.toLowerCase().trim();

  const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [normalizedEmail]);
  if (existing.length > 0) {
    const error = new Error('Email đã được sử dụng');
    error.statusCode = 409;
    throw error;
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const [result] = await pool.query(
    'INSERT INTO users (full_name, email, password_hash) VALUES (?, ?, ?)',
    [full_name.trim(), normalizedEmail, passwordHash]
  );

  const [users] = await pool.query(
    'SELECT id, full_name, email, created_at, updated_at FROM users WHERE id = ?',
    [result.insertId]
  );

  return sanitizeUser(users[0]);
};

const login = async ({ email, password, deviceName, req }) => {
  const normalizedEmail = email.toLowerCase().trim();
  const ipAddress = getClientIp(req);
  const userAgent = req.headers['user-agent'] || 'Unknown';

  const [users] = await pool.query('SELECT * FROM users WHERE email = ?', [normalizedEmail]);

  if (users.length === 0) {
    await saveFailedAttempt({ email: normalizedEmail, ipAddress });
    const error = new Error('Email hoặc mật khẩu không đúng');
    error.statusCode = 401;
    throw error;
  }

  const user = users[0];
  const isPasswordValid = await bcrypt.compare(password, user.password_hash);

  if (!isPasswordValid) {
    await saveFailedAttempt({ email: normalizedEmail, ipAddress });
    const failedCount = await countRecentFailedAttempts({ email: normalizedEmail });
    const error = new Error(
      failedCount >= 5
        ? 'Cảnh báo brute force: Sai mật khẩu quá 5 lần trong 15 phút'
        : 'Email hoặc mật khẩu không đúng'
    );
    error.statusCode = failedCount >= 5 ? 429 : 401;
    throw error;
  }

  const deviceFingerprint = createDeviceFingerprint(userAgent, deviceName);
  const { riskLevel, reason } = await detectLoginRisk({
    userId: user.id,
    email: normalizedEmail,
    ipAddress,
    userAgent,
    deviceFingerprint,
  });

  await pool.query(
    `INSERT INTO login_history
     (user_id, ip_address, user_agent, device_name, login_status, risk_level, reason)
     VALUES (?, ?, ?, ?, 'SUCCESS', ?, ?)`,
    [user.id, ipAddress, userAgent, deviceName, riskLevel, reason]
  );

  // Thiết bị đã xác thực thành công được ghi nhận để so sánh cho các lần sau.
  await pool.query(
    `INSERT IGNORE INTO trusted_devices
     (user_id, device_fingerprint, device_name, ip_address)
     VALUES (?, ?, ?, ?)`,
    [user.id, deviceFingerprint, deviceName, ipAddress]
  );

  const safeUser = sanitizeUser(user);
  const token = generateToken(safeUser);

  if (riskLevel === 'MEDIUM' || riskLevel === 'HIGH') {
    sendLoginAlertEmail({
      user: safeUser,
      ipAddress,
      deviceName,
      riskLevel,
      reason,
      loginTime: new Date().toLocaleString('vi-VN'),
    }).catch((error) => {
      console.error('Không thể gửi email cảnh báo:', error.message);
    });
  }

  return {
    token,
    user: safeUser,
    risk_level: riskLevel,
    message: 'Đăng nhập thành công',
  };
};

module.exports = {
  register,
  login,
};
