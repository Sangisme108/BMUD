const bcrypt = require('bcrypt');
const crypto = require('crypto');
const pool = require('../config/db');

const MAX_FAILURES = 5;
const WINDOW_MINUTES = 15;
const LOCK_MINUTES = 15;

const createHttpError = (message, statusCode) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

const normalizeIpAddress = (ipAddress = '') =>
  ipAddress.startsWith('::ffff:') ? ipAddress.slice(7) : ipAddress;

const getRequestIp = (req) =>
  normalizeIpAddress(req.ip || req.socket.remoteAddress || 'unknown');

const hashDeviceFingerprint = (deviceFingerprint) =>
  crypto.createHash('sha256').update(String(deviceFingerprint)).digest('hex');

const readDeviceFingerprint = (req) =>
  (
    req.get('x-device-fingerprint') ||
    req.body?.device_fingerprint ||
    req.query?.device_fingerprint ||
    ''
  )
    .toString()
    .trim();

const ensureDeviceFingerprint = (deviceFingerprint) => {
  if (!/^[a-f0-9]{64}$/i.test(deviceFingerprint)) {
    throw createHttpError('Device fingerprint không hợp lệ', 400);
  }
};

const ensureDeviceRow = async ({ userId, deviceFingerprint, req }) => {
  ensureDeviceFingerprint(deviceFingerprint);
  const deviceHash = hashDeviceFingerprint(deviceFingerprint);
  await pool.query(
    `INSERT INTO devices
     (user_id, device_fingerprint, device_fingerprint_hash, ip_address,
      user_agent, is_trusted, message_recovery_verified, last_used_at)
     VALUES (?, ?, ?, ?, ?, TRUE, FALSE, NOW())
     ON DUPLICATE KEY UPDATE
       device_fingerprint_hash = VALUES(device_fingerprint_hash),
       ip_address = VALUES(ip_address),
       user_agent = VALUES(user_agent),
       last_used_at = NOW()`,
    [
      userId,
      deviceFingerprint,
      deviceHash,
      getRequestIp(req),
      req.get('user-agent') || 'Unknown',
    ]
  );
  return deviceHash;
};

const getStatus = async ({ userId, deviceFingerprint, req }) => {
  const deviceHash = await ensureDeviceRow({ userId, deviceFingerprint, req });
  const [[user]] = await pool.query(
    `SELECT message_recovery_code_hash
     FROM users
     WHERE id = ?`,
    [userId]
  );
  const [[device]] = await pool.query(
    `SELECT message_recovery_verified, message_recovery_verified_at
     FROM devices
     WHERE user_id = ? AND device_fingerprint = ?
     LIMIT 1`,
    [userId, deviceFingerprint]
  );

  return {
    has_recovery_code: Boolean(user?.message_recovery_code_hash),
    message_recovery_verified: Boolean(device?.message_recovery_verified),
    verified_at: device?.message_recovery_verified_at || null,
    device_fingerprint_hash: deviceHash,
  };
};

const setupRecoveryCode = async ({
  userId,
  currentPassword,
  recoveryCode,
  deviceFingerprint,
  req,
}) => {
  if (!currentPassword || !recoveryCode) {
    throw createHttpError('Thiếu mật khẩu hiện tại hoặc mã khôi phục', 400);
  }
  if (String(recoveryCode).trim().length < 6) {
    throw createHttpError('Mã khôi phục phải có ít nhất 6 ký tự', 400);
  }

  const [[user]] = await pool.query(
    'SELECT id, password_hash FROM users WHERE id = ?',
    [userId]
  );
  if (!user || !(await bcrypt.compare(currentPassword, user.password_hash))) {
    throw createHttpError('Mật khẩu hiện tại không chính xác', 401);
  }

  const codeHash = await bcrypt.hash(String(recoveryCode).trim(), 12);
  await ensureDeviceRow({ userId, deviceFingerprint, req });
  await pool.query(
    `UPDATE users
     SET message_recovery_code_hash = ?
     WHERE id = ?`,
    [codeHash, userId]
  );
  await pool.query(
    `UPDATE devices
     SET message_recovery_verified = FALSE,
         message_recovery_verified_at = NULL
     WHERE user_id = ?`,
    [userId]
  );
  await pool.query(
    `UPDATE devices
     SET message_recovery_verified = TRUE,
         message_recovery_verified_at = NOW()
     WHERE user_id = ? AND device_fingerprint = ?`,
    [userId, deviceFingerprint]
  );

  return { message: 'Đã cập nhật mã khôi phục tin nhắn' };
};

const assertNotLocked = async ({ userId, deviceHash, ipAddress }) => {
  const [[stats]] = await pool.query(
    `SELECT COUNT(*) AS total, MAX(created_at) AS last_failed_at
     FROM message_recovery_attempts
     WHERE user_id = ?
       AND is_successful = FALSE
       AND created_at >= (NOW() - INTERVAL ? MINUTE)
       AND (device_fingerprint_hash = ? OR ip_address = ?)`,
    [userId, WINDOW_MINUTES, deviceHash, ipAddress]
  );

  if (Number(stats.total || 0) >= MAX_FAILURES) {
    const lastFailedAt = new Date(stats.last_failed_at);
    const unlockAt = new Date(lastFailedAt.getTime() + LOCK_MINUTES * 60000);
    if (unlockAt > new Date()) {
      throw createHttpError(
        `Bạn nhập sai quá nhiều lần. Hãy thử lại sau ${LOCK_MINUTES} phút.`,
        429
      );
    }
  }
};

const verifyRecoveryCode = async ({
  userId,
  recoveryCode,
  deviceFingerprint,
  req,
}) => {
  if (!recoveryCode) {
    throw createHttpError('Vui lòng nhập mã khôi phục tin nhắn', 400);
  }

  const deviceHash = await ensureDeviceRow({ userId, deviceFingerprint, req });
  const ipAddress = getRequestIp(req);
  await assertNotLocked({ userId, deviceHash, ipAddress });

  const [[user]] = await pool.query(
    `SELECT message_recovery_code_hash
     FROM users
     WHERE id = ?`,
    [userId]
  );
  if (!user?.message_recovery_code_hash) {
    throw createHttpError('Bạn chưa tạo mã khôi phục tin nhắn', 409);
  }

  const valid = await bcrypt.compare(
    String(recoveryCode).trim(),
    user.message_recovery_code_hash
  );
  await pool.query(
    `INSERT INTO message_recovery_attempts
     (user_id, ip_address, device_fingerprint_hash, is_successful)
     VALUES (?, ?, ?, ?)`,
    [userId, ipAddress, deviceHash, valid]
  );

  if (!valid) {
    throw createHttpError('Mã khôi phục tin nhắn không chính xác', 401);
  }

  await pool.query(
    `UPDATE devices
     SET message_recovery_verified = TRUE,
         message_recovery_verified_at = NOW(),
         last_used_at = NOW()
     WHERE user_id = ? AND device_fingerprint = ?`,
    [userId, deviceFingerprint]
  );

  return { message: 'Đã khôi phục quyền xem tin nhắn' };
};

const assertMessageRecoveryVerified = async ({ userId, deviceFingerprint, req }) => {
  const status = await getStatus({ userId, deviceFingerprint, req });
  if (!status.has_recovery_code) {
    throw createHttpError('Cần tạo mã khôi phục tin nhắn', 403);
  }
  if (!status.message_recovery_verified) {
    throw createHttpError('Cần nhập mã khôi phục tin nhắn', 403);
  }
  return status;
};

const resetVerifiedDevices = async (userId) => {
  await pool.query(
    `UPDATE devices
     SET message_recovery_verified = FALSE,
         message_recovery_verified_at = NULL
     WHERE user_id = ?`,
    [userId]
  );
};

module.exports = {
  assertMessageRecoveryVerified,
  getStatus,
  readDeviceFingerprint,
  resetVerifiedDevices,
  setupRecoveryCode,
  verifyRecoveryCode,
};
