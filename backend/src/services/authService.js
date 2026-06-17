const bcrypt = require('bcrypt');
const crypto = require('crypto');
const pool = require('../config/db');
const { detectLoginRisk } = require('./anomalyDetectionService');
const {
  sendLoginAlertEmail,
  sendRegistrationOtpEmail,
} = require('./emailService');
const { verifyOtpChallenge } = require('./otpService');
const {
  createNewDeviceLoginChallenge,
} = require('./newDeviceLoginService');
const { recordSecurityEvent } = require('./securityEventService');
const {
  hashDeviceId,
} = require('./sessionService');
const {
  createTokenPair,
  revokeRefreshToken,
  rotateRefreshToken,
} = require('./tokenService');
const {
  lockDeviceIfThresholdReached,
  clearDeviceLockoutOnSuccess,
  assertDeviceNotLocked,
} = require('./deviceLockoutService');

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const LEGACY_LOCK_MINUTES = 15;
const LEGACY_EMAIL_IP_FAILURE_LIMIT = Number.parseInt(
  process.env.AUTH_EMAIL_IP_FAILURE_LIMIT || '5',
  10
);
const IP_FAILURE_LIMIT = Number.parseInt(
  process.env.AUTH_IP_FAILURE_LIMIT || '25',
  10
);
const REGISTER_OTP_TTL_MS = 5 * 60 * 1000;
const REGISTER_OTP_RESEND_SECONDS = 60;
const REGISTER_OTP_MAX_ATTEMPTS = 5;
const REGISTER_OTP_SEND_LIMIT = 5;

const sanitizeUser = (user) => ({
  id: user.id,
  full_name: user.full_name,
  email: user.email,
  email_verified_at: user.email_verified_at,
  created_at: user.created_at,
  updated_at: user.updated_at,
});

const createHttpError = (message, statusCode) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

const normalizeEmail = (email = '') => email.toLowerCase().trim();
const normalizeIpAddress = (ipAddress = '') =>
  ipAddress.startsWith('::ffff:') ? ipAddress.slice(7) : ipAddress;

const isLoopbackIp = (ipAddress) => {
  const normalizedIp = normalizeIpAddress(ipAddress);
  return normalizedIp === '127.0.0.1' || normalizedIp === '::1';
};

const hashDeviceFingerprint = (deviceFingerprint) =>
  crypto.createHash('sha256').update(String(deviceFingerprint)).digest('hex');

const hashOtp = (otp) =>
  crypto
    .createHash('sha256')
    .update(`${otp}:${process.env.OTP_SECRET || process.env.JWT_SECRET}`)
    .digest('hex');

const validateEmail = (email) => {
  if (!EMAIL_PATTERN.test(email)) {
    throw createHttpError('Định dạng email không hợp lệ', 400);
  }
};

const getRequestContext = (req, deviceFingerprint) => ({
  ipAddress: normalizeIpAddress(
    req.ip || req.socket.remoteAddress || 'unknown'
  ),
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
  db = pool,
}) => {
  await db.query(
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
  db = pool,
}) => {
  await db.query(
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
  const normalizedIp = normalizeIpAddress(ipAddress);
  const [[counts]] = await pool.query(
    `SELECT
       SUM(ip_address = ?) AS ip_count,
       SUM(email = ? AND ip_address = ?) AS email_ip_count
     FROM login_attempts
     WHERE failure_type = 'INVALID_CREDENTIALS'
       AND is_resolved = FALSE
       AND created_at >= (NOW() - INTERVAL 15 MINUTE)
       AND (email = ? OR ip_address = ?)`,
    [normalizedIp, email, normalizedIp, email, normalizedIp]
  );

  return {
    ipCount: Number(counts.ip_count || 0),
    emailIpCount: Number(counts.email_ip_count || 0),
  };
};

const getActiveIpLockout = async ({ email, ipAddress }) => {
  const normalizedEmail = normalizeEmail(email);
  const normalizedIp = normalizeIpAddress(ipAddress);
  const [[lockout]] = await pool.query(
    `SELECT locked_until, failure_count
     FROM ip_device_lockouts
     WHERE email = ?
       AND ip_address = ?
       AND locked_until > NOW()
     LIMIT 1`,
    [normalizedEmail, normalizedIp]
  );
  return lockout || null;
};

const lockEmailIpIfThresholdReached = async ({
  email,
  ipAddress,
  deviceFingerprint = null,
}) => {
  const normalizedEmail = normalizeEmail(email);
  const normalizedIp = normalizeIpAddress(ipAddress);
  const counts = await getRecentFailureCounts({
    email: normalizedEmail,
    ipAddress: normalizedIp,
  });

  if (counts.emailIpCount >= LEGACY_EMAIL_IP_FAILURE_LIMIT) {
    await pool.query(
      `INSERT INTO ip_device_lockouts
       (email, ip_address, device_fingerprint, locked_until, failure_count, unlock_reason)
       VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE), ?, 'TOO_MANY_FAILED_ATTEMPTS')
       ON DUPLICATE KEY UPDATE
         device_fingerprint = VALUES(device_fingerprint),
         locked_until = DATE_ADD(NOW(), INTERVAL ? MINUTE),
         failure_count = VALUES(failure_count),
         unlock_reason = 'TOO_MANY_FAILED_ATTEMPTS'`,
      [
        normalizedEmail,
        normalizedIp,
        deviceFingerprint,
        LEGACY_LOCK_MINUTES,
        counts.emailIpCount,
        LEGACY_LOCK_MINUTES,
      ]
    );
  }

  return counts;
};

const clearIpLockoutOnSuccess = async ({ email, ipAddress, db = pool }) => {
  const normalizedEmail = normalizeEmail(email);
  const normalizedIp = normalizeIpAddress(ipAddress);

  await db.query(
    `DELETE FROM ip_device_lockouts
     WHERE email = ?
       AND ip_address = ?`,
    [normalizedEmail, normalizedIp]
  );
  await db.query(
    `UPDATE login_attempts
     SET is_resolved = TRUE
     WHERE email = ?
       AND ip_address = ?
       AND failure_type = 'INVALID_CREDENTIALS'`,
    [normalizedEmail, normalizedIp]
  );
};

const assertIpLockout = async ({ email, ipAddress }) => {
  const lockout = await getActiveIpLockout({ email, ipAddress });
  if (!lockout) {
    return null;
  }

  throw createHttpError(
    `Đăng nhập từ địa chỉ IP này đang bị khóa tạm thời đến ${new Date(lockout.locked_until).toLocaleString('vi-VN')}. Bạn vẫn có thể đăng nhập từ IP khác.`,
    423
  );
};

const assertLoginAllowed = async ({ email, ipAddress, deviceFingerprint }) => {
  const normalizedEmail = normalizeEmail(email);

  if (deviceFingerprint) {
    await assertDeviceNotLocked({
      email: normalizedEmail,
      deviceFingerprint,
    });
    return;
  }

  const counts = await getRecentFailureCounts({
    email: normalizedEmail,
    ipAddress,
  });

  if (!isLoopbackIp(ipAddress) && counts.ipCount >= IP_FAILURE_LIMIT) {
    throw createHttpError(
      'Địa chỉ IP này có quá nhiều lần đăng nhập thất bại, vui lòng thử lại sau',
      429
    );
  }
};

const upsertTrustedDevice = async ({
  userId,
  deviceId,
  deviceName,
  deviceType,
  operatingSystem,
  ipAddress,
  userAgent,
  db = pool,
}) => {
  const deviceIdHash = hashDeviceId(deviceId);
  await db.query(
    `INSERT INTO devices
     (user_id, device_fingerprint, device_fingerprint_hash, device_name,
      device_type, operating_system, ip_address, user_agent, is_trusted,
      message_recovery_verified, revoked_at, revoked_reason, last_used_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, TRUE, FALSE, NULL, NULL, NOW())
     ON DUPLICATE KEY UPDATE
       device_fingerprint_hash = VALUES(device_fingerprint_hash),
       device_name = COALESCE(VALUES(device_name), device_name),
       device_type = COALESCE(VALUES(device_type), device_type),
       operating_system = COALESCE(VALUES(operating_system), operating_system),
       ip_address = VALUES(ip_address),
       user_agent = VALUES(user_agent),
       is_trusted = TRUE,
       revoked_at = NULL,
       revoked_reason = NULL,
       last_used_at = NOW()`,
    [
      userId,
      deviceIdHash,
      deviceIdHash,
      deviceName || null,
      deviceType || null,
      operatingSystem || null,
      ipAddress,
      userAgent,
    ]
  );
};

const completeLogin = async ({
  user,
  email,
  ipAddress,
  userAgent,
  deviceId,
  deviceName,
  deviceType,
  operatingSystem,
  riskScore,
  riskLevel,
  reason,
  db = pool,
}) => {
  await upsertTrustedDevice({
    userId: user.id,
    deviceId,
    deviceName,
    deviceType,
    operatingSystem,
    ipAddress,
    userAgent,
    db,
  });

  await recordAttempt({
    userId: user.id,
    email,
    ipAddress,
    userAgent,
    deviceFingerprint: hashDeviceId(deviceId),
    isSuccessful: true,
    riskScore,
    riskLevel,
    reason,
    db,
  });

  await recordLegacyHistory({
    userId: user.id,
    ipAddress,
    userAgent,
    isSuccessful: true,
    riskLevel,
    reason,
    db,
  });

  // Clear device lockout (per-device brute force protection)
  const deviceIdHash = hashDeviceId(deviceId);
  await clearDeviceLockoutOnSuccess({
    email,
    deviceFingerprint: deviceIdHash,
    db,
  });

  await recordSecurityEvent({
    userId: user.id,
    eventType: 'LOGIN_SUCCESS',
    title: 'Dang nhap thanh cong',
    description: reason,
    ipAddress,
    userAgent,
    deviceFingerprintHash: hashDeviceId(deviceId),
    riskLevel,
    metadata: { risk_score: riskScore },
    db,
  });

  const tokens = await createTokenPair(
    user,
    {
      deviceId,
      deviceName,
      deviceType,
      operatingSystem,
      ipAddress,
      userAgent,
      isTrusted: true,
    },
    db
  );

  return {
    success: true,
    requiresOtp: false,
    requires_otp: false,
    ...tokens,
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
  await recordSecurityEvent({
    userId: user.id,
    eventType: 'REGISTER',
    title: 'Tạo tài khoản mới',
    description: 'Tài khoản đã được đăng ký thành công.',
    riskLevel: 'LOW',
  });
  return sanitizeUser(user);
};

const requestRegistrationOtp = async ({ fullName, email }) => {
  const normalizedEmail = normalizeEmail(email);
  const normalizedName = String(fullName || '').trim();
  if (!normalizedName) {
    throw createHttpError('Vui long nhap ho ten', 400);
  }
  validateEmail(normalizedEmail);

  const [existing] = await pool.query(
    'SELECT id FROM users WHERE email = ?',
    [normalizedEmail]
  );
  if (existing.length > 0) {
    throw createHttpError('Email da duoc su dung', 409);
  }

  const [[recent]] = await pool.query(
    `SELECT created_at
     FROM email_otps
     WHERE email = ? AND purpose = 'REGISTER'
     ORDER BY created_at DESC
     LIMIT 1`,
    [normalizedEmail]
  );
  if (
    recent?.created_at &&
    Date.now() - new Date(recent.created_at).getTime() <
      REGISTER_OTP_RESEND_SECONDS * 1000
  ) {
    throw createHttpError(
      `Vui long doi ${REGISTER_OTP_RESEND_SECONDS} giay truoc khi gui lai ma`,
      429
    );
  }

  const [[sendStats]] = await pool.query(
    `SELECT COUNT(*) AS total
     FROM email_otps
     WHERE email = ?
       AND purpose = 'REGISTER'
       AND created_at >= (NOW() - INTERVAL 15 MINUTE)`,
    [normalizedEmail]
  );
  if (Number(sendStats.total || 0) >= REGISTER_OTP_SEND_LIMIT) {
    throw createHttpError('Ban da gui OTP qua nhieu lan. Vui long thu lai sau.', 429);
  }

  const otpCode = crypto.randomInt(100000, 1000000).toString();
  await pool.query(
    `UPDATE email_otps
     SET used_at = NOW()
     WHERE email = ?
       AND purpose = 'REGISTER'
       AND used_at IS NULL`,
    [normalizedEmail]
  );
  await pool.query(
    `INSERT INTO email_otps (email, otp_hash, purpose, expires_at)
     VALUES (?, ?, 'REGISTER', ?)`,
    [
      normalizedEmail,
      hashOtp(otpCode),
      new Date(Date.now() + REGISTER_OTP_TTL_MS),
    ]
  );

  try {
    await sendRegistrationOtpEmail({
      fullName: normalizedName,
      email: normalizedEmail,
      otpCode,
      expiresInMinutes: REGISTER_OTP_TTL_MS / 60000,
    });
  } catch (error) {
    throw createHttpError(
      'Khong the gui ma OTP luc nay. Vui long thu lai sau.',
      error.statusCode || 503
    );
  }

  return {
    success: true,
    message: 'Ma OTP da duoc gui den email',
    expiresIn: REGISTER_OTP_TTL_MS / 1000,
  };
};

const verifyRegistrationOtp = async ({
  fullName,
  email,
  password,
  confirmPassword,
  otp,
  deviceFingerprint,
  req,
}) => {
  const normalizedEmail = normalizeEmail(email);
  const normalizedName = String(fullName || '').trim();
  if (!normalizedName || !normalizedEmail || !password || !confirmPassword || !otp) {
    throw createHttpError('Vui long nhap day du thong tin dang ky', 400);
  }
  validateEmail(normalizedEmail);
  if (password.length < 8) {
    throw createHttpError('Mat khau phai co it nhat 8 ky tu', 400);
  }
  if (password !== confirmPassword) {
    throw createHttpError('Xac nhan mat khau khong khop', 400);
  }
  if (!/^\d{6}$/.test(String(otp))) {
    throw createHttpError('OTP phai gom dung 6 chu so', 400);
  }
  if (!deviceFingerprint) {
    throw createHttpError('Thong tin thiet bi khong hop le', 400);
  }

  const context = getRequestContext(req, hashDeviceId(deviceFingerprint));
  const connection = await pool.getConnection();
  let committed = false;
  try {
    await connection.beginTransaction();

    const [[existingUser]] = await connection.query(
      'SELECT id FROM users WHERE email = ? FOR UPDATE',
      [normalizedEmail]
    );
    if (existingUser) {
      throw createHttpError('Email da duoc su dung', 409);
    }

    const [[challenge]] = await connection.query(
      `SELECT id, otp_hash, expires_at, used_at, attempt_count
       FROM email_otps
       WHERE email = ?
         AND purpose = 'REGISTER'
       ORDER BY created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [normalizedEmail]
    );

    if (!challenge || challenge.used_at) {
      throw createHttpError('Ma OTP khong ton tai hoac da duoc su dung', 400);
    }
    if (new Date(challenge.expires_at) <= new Date()) {
      await connection.query(
        'UPDATE email_otps SET used_at = NOW() WHERE id = ?',
        [challenge.id]
      );
      await connection.commit();
      committed = true;
      throw createHttpError('Ma OTP da het han. Vui long gui lai ma moi.', 410);
    }
    if (challenge.attempt_count >= REGISTER_OTP_MAX_ATTEMPTS) {
      throw createHttpError('Ban da nhap sai OTP qua so lan cho phep', 429);
    }
    if (hashOtp(otp) !== challenge.otp_hash) {
      await connection.query(
        'UPDATE email_otps SET attempt_count = attempt_count + 1 WHERE id = ?',
        [challenge.id]
      );
      await connection.commit();
      committed = true;
      throw createHttpError('Ma OTP khong chinh xac', 400);
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const [result] = await connection.query(
      `INSERT INTO users (full_name, email, password_hash, email_verified_at)
       VALUES (?, ?, ?, NOW())`,
      [normalizedName, normalizedEmail, passwordHash]
    );
    const userId = result.insertId;
    if (!userId) {
      throw createHttpError('Khong lay duoc ID cua tai khoan vua tao', 500);
    }
    await connection.query(
      'UPDATE email_otps SET used_at = NOW() WHERE id = ?',
      [challenge.id]
    );

    const [[user]] = await connection.query(
      `SELECT id, full_name, email, email_verified_at, created_at, updated_at
       FROM users WHERE id = ?`,
      [userId]
    );
    if (!user?.id) {
      throw createHttpError('Khong tim thay tai khoan vua tao', 500);
    }

    await upsertTrustedDevice({
      userId: user.id,
      deviceId: deviceFingerprint,
      ipAddress: context.ipAddress,
      userAgent: context.userAgent,
      db: connection,
    });
    await recordAttempt({
      userId: user.id,
      email: normalizedEmail,
      ...context,
      isSuccessful: true,
      riskScore: 0,
      riskLevel: 'LOW',
      reason: 'Dang ky va xac minh email thanh cong',
      db: connection,
    });
    await recordLegacyHistory({
      userId: user.id,
      ipAddress: context.ipAddress,
      userAgent: context.userAgent,
      isSuccessful: true,
      riskLevel: 'LOW',
      reason: 'Dang ky va xac minh email thanh cong',
      db: connection,
    });
    await recordSecurityEvent({
      userId: user.id,
      eventType: 'REGISTER_VERIFIED',
      title: 'Dang ky va xac minh email thanh cong',
      description: 'Tai khoan da duoc tao sau khi xac minh OTP email.',
      ipAddress: context.ipAddress,
      userAgent: context.userAgent,
      deviceFingerprint,
      riskLevel: 'LOW',
      db: connection,
    });

    const tokens = await createTokenPair(
      user,
      {
        deviceId: deviceFingerprint,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        isTrusted: true,
      },
      connection
    );
    await connection.commit();
    committed = true;

    return {
      success: true,
      message: 'Dang ky va xac minh email thanh cong',
      ...tokens,
      user: sanitizeUser(user),
      requires_otp: false,
      is_trusted_device: true,
    };
  } catch (error) {
    if (!committed) {
      await connection.rollback();
    }
    throw error;
  } finally {
    connection.release();
  }
};

const login = async ({
  email,
  password,
  deviceId,
  deviceName,
  deviceType,
  operatingSystem,
  req,
}) => {
  const normalizedEmail = normalizeEmail(email);
  validateEmail(normalizedEmail);
  if (!deviceId) {
    throw createHttpError('Thiếu thông tin thiết bị', 400);
  }

  const deviceIdHash = hashDeviceId(deviceId);
  const context = getRequestContext(req, deviceIdHash);
  await assertLoginAllowed({
    email: normalizedEmail,
    ipAddress: context.ipAddress,
    deviceFingerprint: deviceIdHash,
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
      deviceFingerprint: deviceIdHash,
      isSuccessful: false,
      failureType: 'INVALID_CREDENTIALS',
      reason: 'INVALID_CREDENTIALS',
    });
    // Lock device after repeated failures
    await lockDeviceIfThresholdReached({
      userId: user?.id,
      email: normalizedEmail,
      deviceFingerprint: deviceIdHash,
      deviceName,
      ipAddress: context.ipAddress,
      userAgent: context.userAgent,
    });
    await recordSecurityEvent({
      userId: user?.id || null,
      eventType: 'LOGIN_FAILED',
      title: 'Dang nhap that bai',
      description: 'Sai email hoac mat khau.',
      ipAddress: context.ipAddress,
      userAgent: context.userAgent,
      deviceFingerprintHash: deviceIdHash,
      riskLevel: 'MEDIUM',
      metadata: { email: normalizedEmail },
    });
    throw createHttpError('Email hoặc mật khẩu không chính xác', 401);
  }

  const risk = await detectLoginRisk({
    userId: user.id,
    email: normalizedEmail,
    ...context,
    deviceFingerprint: deviceIdHash,
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
    await recordSecurityEvent({
      userId: user.id,
      eventType: 'LOGIN_BLOCKED_HIGH_RISK',
      title: 'Dang nhap bi chan do rui ro cao',
      description: risk.reason,
      ipAddress: context.ipAddress,
      userAgent: context.userAgent,
      deviceFingerprintHash: deviceIdHash,
      riskLevel: 'HIGH',
      metadata: { risk_score: risk.riskScore },
    });
    sendLoginAlertEmail({
      user: sanitizeUser(user),
      ipAddress: context.ipAddress,
      deviceName: deviceName || 'Thiết bị chưa xác minh',
      riskLevel: risk.riskLevel,
      reason: risk.reason,
      loginTime: new Date().toLocaleString('vi-VN'),
    }).catch((error) => console.error('Không thể gửi email cảnh báo:', error.message));
    throw createHttpError(
      'Đăng nhập bị chặn do rủi ro cao. Hãy kiểm tra email và đổi mật khẩu nếu đây không phải bạn.',
      403
    );
  }

  const [[device]] = await pool.query(
    `SELECT id, is_trusted, revoked_at
     FROM devices
     WHERE user_id = ?
       AND device_fingerprint = ?
     LIMIT 1`,
    [user.id, deviceIdHash]
  );

  const needsDeviceOtp =
    !device || !device.is_trusted || device.revoked_at != null;

  if (needsDeviceOtp) {
    const challenge = await createNewDeviceLoginChallenge({
      user,
      deviceId,
      deviceName,
      deviceType,
      operatingSystem,
      ipAddress: context.ipAddress,
      userAgent: context.userAgent,
    });
    await recordAttempt({
      userId: user.id,
      email: normalizedEmail,
      ...context,
      isSuccessful: false,
      failureType: 'OTP_REQUIRED',
      riskScore: risk.riskScore,
      riskLevel: 'MEDIUM',
      reason: 'Thiet bi moi hoac da bi go can xac minh OTP',
    });
    await recordSecurityEvent({
      userId: user.id,
      eventType: 'OTP_REQUIRED',
      title: 'Yeu cau OTP cho thiet bi moi',
      description: 'Thiet bi moi hoac da bi go can xac minh OTP qua email.',
      ipAddress: context.ipAddress,
      userAgent: context.userAgent,
      deviceFingerprintHash: deviceIdHash,
      riskLevel: 'MEDIUM',
    });

    return {
      statusCode: 202,
      success: true,
      requiresOtp: true,
      requires_otp: true,
      message: 'Thiết bị mới cần xác minh OTP',
      data: {
        challengeId: challenge.challengeId,
        challenge_id: challenge.challengeId,
        maskedEmail: challenge.maskedEmail,
        expiresIn: challenge.expiresIn,
        expires_in: challenge.expiresIn,
      },
      ...(challenge.otpCode ? { debug_otp: challenge.otpCode } : {}),
    };
  }

  return completeLogin({
    user,
    email: normalizedEmail,
    ...context,
    deviceId,
    deviceName,
    deviceType,
    operatingSystem,
    riskScore: risk.riskScore,
    riskLevel: risk.riskLevel,
    reason: risk.reason,
  });
};

const verifyDeviceOtp = async ({
  challengeId,
  otp,
  deviceId,
  deviceName,
  deviceType,
  operatingSystem,
}) => {
  if (!challengeId || !otp || !deviceId) {
    throw createHttpError('Thieu thong tin xac minh OTP', 400);
  }
  if (!/^\d{6}$/.test(String(otp))) {
    throw createHttpError('OTP phai gom dung 6 chu so', 400);
  }

  const deviceIdHash = hashDeviceId(deviceId);
  const connection = await pool.getConnection();
  let committed = false;

  try {
    await connection.beginTransaction();
    const [[challenge]] = await connection.query(
      `SELECT *
       FROM email_otps
       WHERE challenge_id = ?
         AND purpose = 'NEW_DEVICE_LOGIN'
       LIMIT 1
       FOR UPDATE`,
      [challengeId]
    );

    if (!challenge || challenge.used_at) {
      throw createHttpError('Ma OTP khong ton tai hoac da duoc su dung', 400);
    }
    if (challenge.device_id_hash !== deviceIdHash) {
      throw createHttpError('Thiet bi khong khop voi yeu cau xac minh', 403);
    }
    if (new Date(challenge.expires_at) <= new Date()) {
      await connection.query(
        'UPDATE email_otps SET used_at = NOW() WHERE id = ?',
        [challenge.id]
      );
      await connection.commit();
      committed = true;
      throw createHttpError('Ma OTP da het han. Vui long dang nhap lai.', 410);
    }
    if (challenge.attempt_count >= REGISTER_OTP_MAX_ATTEMPTS) {
      throw createHttpError('Ban da nhap sai OTP qua so lan cho phep', 429);
    }
    if (hashOtp(otp) !== challenge.otp_hash) {
      await connection.query(
        'UPDATE email_otps SET attempt_count = attempt_count + 1 WHERE id = ?',
        [challenge.id]
      );
      await connection.commit();
      committed = true;
      throw createHttpError('Ma OTP khong chinh xac', 400);
    }

    await connection.query(
      'UPDATE email_otps SET used_at = NOW() WHERE id = ?',
      [challenge.id]
    );

    const [[user]] = await connection.query(
      'SELECT * FROM users WHERE id = ?',
      [challenge.user_id]
    );
    if (!user) {
      throw createHttpError('Tai khoan khong ton tai', 404);
    }

    const result = await completeLogin({
      user,
      email: user.email,
      ipAddress: challenge.ip_address,
      userAgent: challenge.user_agent || 'Unknown',
      deviceId,
      deviceName: deviceName || challenge.device_name,
      deviceType: deviceType || challenge.device_type,
      operatingSystem: operatingSystem || challenge.operating_system,
      riskScore: 0,
      riskLevel: 'LOW',
      reason: 'Xac minh OTP thiet bi moi thanh cong',
      db: connection,
    });

    await connection.commit();
    committed = true;
    return result;
  } catch (error) {
    if (!committed) {
      await connection.rollback();
    }
    throw error;
  } finally {
    connection.release();
  }
};

const verifyOtp = async ({ email, otpCode, deviceFingerprint }) => {
  const normalizedEmail = normalizeEmail(email);
  validateEmail(normalizedEmail);

  const challenge = await verifyOtpChallenge({
    email: normalizedEmail,
    otpCode,
    deviceFingerprint: hashDeviceId(deviceFingerprint),
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
    deviceId: deviceFingerprint,
    riskScore: challenge.risk_score,
    riskLevel: challenge.risk_level,
    reason: `${challenge.reason}; OTP hợp lệ, thiết bị đã được tin cậy`,
  });
};

const refresh = async ({ refreshToken, deviceId }) => {
  if (!refreshToken) {
    throw createHttpError('Thiếu refresh token', 400);
  }
  if (!deviceId) {
    throw createHttpError('Thiếu thông tin thiết bị', 400);
  }
  return rotateRefreshToken(refreshToken, deviceId);
};

const logout = async ({ refreshToken }) => {
  const userId = await revokeRefreshToken(refreshToken);
  await recordSecurityEvent({
    userId,
    eventType: 'LOGOUT',
    title: 'Dang xuat',
    description: 'Mot phien dang nhap da duoc dang xuat.',
    riskLevel: 'LOW',
  });
  return { message: 'Đăng xuất thành công' };
};

module.exports = {
  assertLoginAllowed,
  login,
  logout,
  refresh,
  register,
  requestRegistrationOtp,
  verifyDeviceOtp,
  verifyRegistrationOtp,
  verifyOtp,
};
