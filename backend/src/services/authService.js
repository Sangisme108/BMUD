const bcrypt = require('bcrypt');
const pool = require('../config/db');
const { detectLoginRisk } = require('./anomalyDetectionService');
const { sendLoginAlertEmail, sendOtpEmail } = require('./emailService');
const { createOtpChallenge, verifyOtpChallenge } = require('./otpService');
const {
  createTokenPair,
  revokeRefreshToken,
  rotateRefreshToken,
} = require('./tokenService');

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const LOCK_MINUTES = 15;

const sanitizeUser = (user) => ({
  id: user.id,
  full_name: user.full_name,
  email: user.email,
  created_at: user.created_at,
  updated_at: user.updated_at,
});

const createHttpError = (message, statusCode) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

const normalizeEmail = (email = '') => email.toLowerCase().trim();

const validateEmail = (email) => {
  if (!EMAIL_PATTERN.test(email)) {
    throw createHttpError('Định dạng email không hợp lệ', 400);
  }
};

const getRequestContext = (req, deviceFingerprint) => ({
  ipAddress: req.ip || req.socket.remoteAddress || 'unknown',
  userAgent: req.get('user-agent') || 'Unknown',
  deviceFingerprint,
});

const recordAttempt = async ({
  userId = null,
  email,
  ipAddress,
  userAgent,
  deviceFingerprint,
  isSuccessful,
  failureType = 'NONE',
  riskScore = 0,
  riskLevel = 'LOW',
  reason,
}) => {
  await pool.query(
    `INSERT INTO login_attempts
     (user_id, email, ip_address, user_agent, device_fingerprint,
      is_successful, failure_type, risk_score, risk_level, reason)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      userId,
      email,
      ipAddress,
      userAgent,
      deviceFingerprint,
      isSuccessful,
      failureType,
      riskScore,
      riskLevel,
      reason,
    ]
  );
};

const recordLegacyHistory = async ({
  userId,
  ipAddress,
  userAgent,
  isSuccessful,
  riskLevel,
  reason,
}) => {
  await pool.query(
    `INSERT INTO login_history
     (user_id, ip_address, user_agent, device_name, login_status, risk_level, reason)
     VALUES (?, ?, ?, 'Thiết bị ứng dụng', ?, ?, ?)`,
    [
      userId,
      ipAddress,
      userAgent,
      isSuccessful ? 'SUCCESS' : 'FAILED',
      riskLevel,
      reason,
    ]
  );
};

const getRecentFailureCounts = async ({ email, ipAddress }) => {
  const [[counts]] = await pool.query(
    `SELECT
       SUM(email = ?) AS email_count,
       SUM(ip_address = ?) AS ip_count
     FROM login_attempts
     WHERE failure_type = 'INVALID_CREDENTIALS'
       AND is_resolved = FALSE
       AND created_at >= (NOW() - INTERVAL 15 MINUTE)
       AND (email = ? OR ip_address = ?)`,
    [email, ipAddress, email, ipAddress]
  );

  return {
    emailCount: Number(counts.email_count || 0),
    ipCount: Number(counts.ip_count || 0),
  };
};

const lockUserIfThresholdReached = async ({ userId, email, ipAddress }) => {
  const counts = await getRecentFailureCounts({ email, ipAddress });
  if (userId && counts.emailCount >= 5) {
    await pool.query(
      `UPDATE users
       SET is_locked = TRUE,
           lock_until = DATE_ADD(NOW(), INTERVAL ? MINUTE)
       WHERE id = ?`,
      [LOCK_MINUTES, userId]
    );
  }
  return counts;
};

const assertLoginAllowed = async ({ email, ipAddress }) => {
  const normalizedEmail = normalizeEmail(email);
  const [[user]] = await pool.query(
    'SELECT id, is_locked, lock_until FROM users WHERE email = ?',
    [normalizedEmail]
  );

  if (user?.is_locked && user.lock_until && new Date(user.lock_until) > new Date()) {
    throw createHttpError(
      `Tài khoản đang bị khóa tạm thời đến ${new Date(user.lock_until).toLocaleString('vi-VN')}`,
      423
    );
  }

  if (user?.is_locked) {
    await pool.query(
      'UPDATE users SET is_locked = FALSE, lock_until = NULL WHERE id = ?',
      [user.id]
    );
  }

  const counts = await getRecentFailureCounts({
    email: normalizedEmail,
    ipAddress,
  });
  if (counts.emailCount >= 5) {
    if (user) {
      await lockUserIfThresholdReached({
        userId: user.id,
        email: normalizedEmail,
        ipAddress,
      });
      throw createHttpError('Tài khoản đang bị khóa tạm thời trong 15 phút', 423);
    }
    throw createHttpError('Quá nhiều lần đăng nhập thất bại, vui lòng thử lại sau', 429);
  }

  if (counts.ipCount >= 5) {
    throw createHttpError(
      'Địa chỉ IP này có quá nhiều lần đăng nhập thất bại, vui lòng thử lại sau',
      429
    );
  }
};

const upsertTrustedDevice = async ({
  userId,
  deviceFingerprint,
  ipAddress,
  userAgent,
}) => {
  await pool.query(
    `INSERT INTO devices
     (user_id, device_fingerprint, ip_address, user_agent, is_trusted, last_used_at)
     VALUES (?, ?, ?, ?, TRUE, NOW())
     ON DUPLICATE KEY UPDATE
       ip_address = VALUES(ip_address),
       user_agent = VALUES(user_agent),
       is_trusted = TRUE,
       last_used_at = NOW()`,
    [userId, deviceFingerprint, ipAddress, userAgent]
  );
};

const completeLogin = async ({
  user,
  email,
  ipAddress,
  userAgent,
  deviceFingerprint,
  riskScore,
  riskLevel,
  reason,
}) => {
  await upsertTrustedDevice({
    userId: user.id,
    deviceFingerprint,
    ipAddress,
    userAgent,
  });

  await recordAttempt({
    userId: user.id,
    email,
    ipAddress,
    userAgent,
    deviceFingerprint,
    isSuccessful: true,
    riskScore,
    riskLevel,
    reason,
  });

  await recordLegacyHistory({
    userId: user.id,
    ipAddress,
    userAgent,
    isSuccessful: true,
    riskLevel,
    reason,
  });

  await pool.query(
    `UPDATE login_attempts
     SET is_resolved = TRUE
     WHERE email = ? AND failure_type = 'INVALID_CREDENTIALS'`,
    [email]
  );
  await pool.query(
    'UPDATE users SET is_locked = FALSE, lock_until = NULL WHERE id = ?',
    [user.id]
  );

  return {
    ...(await createTokenPair(user)),
    user: sanitizeUser(user),
    risk_score: riskScore,
    risk_level: riskLevel,
    message: 'Đăng nhập thành công',
  };
};

const register = async ({ full_name, email, password }) => {
  const normalizedEmail = normalizeEmail(email);
  validateEmail(normalizedEmail);

  const [existing] = await pool.query(
    'SELECT id FROM users WHERE email = ?',
    [normalizedEmail]
  );
  if (existing.length > 0) {
    throw createHttpError('Email đã được sử dụng', 409);
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const [result] = await pool.query(
    'INSERT INTO users (full_name, email, password_hash) VALUES (?, ?, ?)',
    [full_name.trim(), normalizedEmail, passwordHash]
  );

  const [[user]] = await pool.query(
    `SELECT id, full_name, email, created_at, updated_at
     FROM users WHERE id = ?`,
    [result.insertId]
  );
  return sanitizeUser(user);
};

const login = async ({ email, password, deviceFingerprint, req }) => {
  const normalizedEmail = normalizeEmail(email);
  validateEmail(normalizedEmail);
  const context = getRequestContext(req, deviceFingerprint);
  await assertLoginAllowed({
    email: normalizedEmail,
    ipAddress: context.ipAddress,
  });

  const [[user]] = await pool.query(
    'SELECT * FROM users WHERE email = ?',
    [normalizedEmail]
  );

  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    await recordAttempt({
      userId: user?.id,
      email: normalizedEmail,
      ...context,
      isSuccessful: false,
      failureType: 'INVALID_CREDENTIALS',
      reason: 'INVALID_CREDENTIALS',
    });
    await lockUserIfThresholdReached({
      userId: user?.id,
      email: normalizedEmail,
      ipAddress: context.ipAddress,
    });
    throw createHttpError('Email hoặc mật khẩu không chính xác', 401);
  }

  const risk = await detectLoginRisk({
    userId: user.id,
    email: normalizedEmail,
    ...context,
  });

  if (risk.riskLevel === 'HIGH') {
    await recordAttempt({
      userId: user.id,
      email: normalizedEmail,
      ...context,
      isSuccessful: false,
      failureType: 'RISK_BLOCKED',
      riskScore: risk.riskScore,
      riskLevel: risk.riskLevel,
      reason: risk.reason,
    });
    await recordLegacyHistory({
      userId: user.id,
      ...context,
      isSuccessful: false,
      riskLevel: risk.riskLevel,
      reason: risk.reason,
    });
    sendLoginAlertEmail({
      user: sanitizeUser(user),
      ipAddress: context.ipAddress,
      deviceName: 'Thiết bị chưa xác minh',
      riskLevel: risk.riskLevel,
      reason: risk.reason,
      loginTime: new Date().toLocaleString('vi-VN'),
    }).catch((error) => console.error('Không thể gửi email cảnh báo:', error.message));
    throw createHttpError(
      'Đăng nhập bị chặn do rủi ro cao. Hãy kiểm tra email và đổi mật khẩu nếu đây không phải bạn.',
      403
    );
  }

  if (risk.riskLevel === 'MEDIUM') {
    const challenge = await createOtpChallenge({
      user,
      ...context,
      ...risk,
    });
    await recordAttempt({
      userId: user.id,
      email: normalizedEmail,
      ...context,
      isSuccessful: false,
      failureType: 'OTP_REQUIRED',
      riskScore: risk.riskScore,
      riskLevel: risk.riskLevel,
      reason: risk.reason,
    });
    let emailSent = false;
    try {
      emailSent = await sendOtpEmail({
        user: sanitizeUser(user),
        otpCode: challenge.otpCode,
        riskLevel: risk.riskLevel,
        reason: risk.reason,
        expiresInMinutes: 5,
      });
    } catch (error) {
      console.error('Không thể gửi email OTP:', error.message);
      if (process.env.NODE_ENV === 'production') {
        throw createHttpError(
          'Không thể gửi mã OTP lúc này. Vui lòng thử lại sau.',
          503
        );
      }
    }

    return {
      statusCode: 202,
      requires_otp: true,
      challenge_id: challenge.challengeId,
      expires_in: challenge.expiresIn,
      risk_score: risk.riskScore,
      risk_level: risk.riskLevel,
      message: 'Yêu cầu xác thực OTP cho thiết bị mới',
      ...(process.env.NODE_ENV !== 'production' && !emailSent
        ? { debug_otp: challenge.otpCode }
        : {}),
    };
  }

  return completeLogin({
    user,
    email: normalizedEmail,
    ...context,
    ...risk,
  });
};

const verifyOtp = async ({ email, otpCode, deviceFingerprint }) => {
  const normalizedEmail = normalizeEmail(email);
  validateEmail(normalizedEmail);

  const challenge = await verifyOtpChallenge({
    email: normalizedEmail,
    otpCode,
    deviceFingerprint,
  });
  const [[user]] = await pool.query(
    'SELECT * FROM users WHERE id = ?',
    [challenge.user_id]
  );
  if (!user) {
    throw createHttpError('Tài khoản không tồn tại', 404);
  }

  return completeLogin({
    user,
    email: normalizedEmail,
    ipAddress: challenge.ip_address,
    userAgent: challenge.user_agent || 'Unknown',
    deviceFingerprint: challenge.device_fingerprint,
    riskScore: challenge.risk_score,
    riskLevel: challenge.risk_level,
    reason: `${challenge.reason}; OTP hợp lệ, thiết bị đã được tin cậy`,
  });
};

const refresh = async ({ refreshToken }) => {
  if (!refreshToken) {
    throw createHttpError('Thiếu refresh token', 400);
  }
  return rotateRefreshToken(refreshToken);
};

const logout = async ({ refreshToken }) => {
  await revokeRefreshToken(refreshToken);
  return { message: 'Đăng xuất thành công' };
};

module.exports = {
  assertLoginAllowed,
  login,
  logout,
  refresh,
  register,
  verifyOtp,
};
