/**
 * Device-level Account Lockout Service
 * Locks specific device after repeated failed login attempts,
 * not the entire account
 */

const pool = require('../config/db');

const DEVICE_LOCK_MINUTES = 15;
const DEVICE_FAILURE_LIMIT = Number.parseInt(
  process.env.DEVICE_FAILURE_LIMIT || '5',
  10
);

const normalizeEmail = (email = '') => email.toLowerCase().trim();

const normalizeIpAddress = (ipAddress = '') =>
  ipAddress.startsWith('::ffff:') ? ipAddress.slice(7) : ipAddress;

const createHttpError = (message, statusCode) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

/**
 * Get recent failure count for specific device
 * Returns number of failed attempts in last 15 minutes
 */
const getRecentDeviceFailureCount = async ({
  email,
  deviceFingerprint,
}) => {
  const normalizedEmail = normalizeEmail(email);

  const [[count]] = await pool.query(
    `SELECT COUNT(*) AS failure_count
     FROM login_attempts
     WHERE email = ?
       AND device_fingerprint = ?
       AND is_successful = FALSE
       AND failure_type = 'INVALID_CREDENTIALS'
       AND created_at >= (NOW() - INTERVAL ? MINUTE)`,
    [normalizedEmail, deviceFingerprint, DEVICE_LOCK_MINUTES]
  );

  return Number(count?.failure_count || 0);
};

/**
 * Check if device is currently locked
 */
const getActiveDeviceLockout = async ({ email, deviceFingerprint }) => {
  const normalizedEmail = normalizeEmail(email);

  const [[lockout]] = await pool.query(
    `SELECT id, locked_until, failure_count, reason
     FROM device_lockouts
     WHERE email = ?
       AND device_fingerprint = ?
       AND locked_until > NOW()
     LIMIT 1`,
    [normalizedEmail, deviceFingerprint]
  );

  return lockout || null;
};

/**
 * Lock device if failure threshold reached
 */
const lockDeviceIfThresholdReached = async ({
  userId = null,
  email,
  deviceFingerprint,
  deviceName = null,
  ipAddress = null,
  userAgent = null,
}) => {
  const normalizedEmail = normalizeEmail(email);
  const normalizedIp = normalizeIpAddress(ipAddress);

  const failureCount = await getRecentDeviceFailureCount({
    email: normalizedEmail,
    deviceFingerprint,
  });

  if (failureCount >= DEVICE_FAILURE_LIMIT) {
    await pool.query(
      `INSERT INTO device_lockouts
       (user_id, email, device_fingerprint, device_name, ip_address, user_agent,
        locked_until, failure_count, reason)
       VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE), ?, 'TOO_MANY_FAILED_ATTEMPTS')
       ON DUPLICATE KEY UPDATE
         ip_address = VALUES(ip_address),
         user_agent = VALUES(user_agent),
         locked_until = DATE_ADD(NOW(), INTERVAL ? MINUTE),
         failure_count = VALUES(failure_count),
         reason = 'TOO_MANY_FAILED_ATTEMPTS',
         updated_at = NOW()`,
      [
        userId,
        normalizedEmail,
        deviceFingerprint,
        deviceName,
        normalizedIp,
        userAgent,
        DEVICE_LOCK_MINUTES,
        failureCount,
        DEVICE_LOCK_MINUTES,
      ]
    );

    return true;
  }

  return false;
};

/**
 * Clear device lockout on successful login
 */
const clearDeviceLockoutOnSuccess = async ({
  email,
  deviceFingerprint,
  db = pool,
}) => {
  const normalizedEmail = normalizeEmail(email);

  // Delete lockout record
  await db.query(
    `DELETE FROM device_lockouts
     WHERE email = ?
       AND device_fingerprint = ?`,
    [normalizedEmail, deviceFingerprint]
  );

  // Mark all related failed attempts as resolved
  await db.query(
    `UPDATE login_attempts
     SET is_resolved = TRUE
     WHERE email = ?
       AND device_fingerprint = ?
       AND is_successful = FALSE`,
    [normalizedEmail, deviceFingerprint]
  );
};

/**
 * Assert device is allowed to login
 * Throws error if device is locked
 */
const assertDeviceNotLocked = async ({ email, deviceFingerprint }) => {
  const lockout = await getActiveDeviceLockout({ email, deviceFingerprint });

  if (lockout) {
    const lockedUntil = new Date(lockout.locked_until).toLocaleString('vi-VN');
    throw createHttpError(
      `Thiết bị này đã bị khóa do quá nhiều lần đăng nhập thất bại. Vui lòng thử lại sau ${lockedUntil}.`,
      423
    );
  }
};

/**
 * Check if device will be locked after this attempt
 */
const willDeviceBeLocked = async ({ email, deviceFingerprint }) => {
  const failureCount = await getRecentDeviceFailureCount({
    email,
    deviceFingerprint,
  });

  return failureCount >= DEVICE_FAILURE_LIMIT - 1;
};

/**
 * Get all locked devices for a user
 */
const getLockedDevicesForUser = async ({ userId }) => {
  const [[devices]] = await pool.query(
    `SELECT 
       email, 
       device_fingerprint,
       device_name,
       ip_address,
       locked_until,
       failure_count,
       reason,
       created_at
     FROM device_lockouts
     WHERE user_id = ?
       AND locked_until > NOW()
     ORDER BY locked_until DESC`,
    [userId]
  );

  return devices || [];
};

/**
 * Manual unlock device (admin/support)
 */
const unlockDeviceManual = async ({ email, deviceFingerprint, reason = 'MANUAL_UNLOCK' }) => {
  const normalizedEmail = normalizeEmail(email);

  const [result] = await pool.query(
    `DELETE FROM device_lockouts
     WHERE email = ?
       AND device_fingerprint = ?`,
    [normalizedEmail, deviceFingerprint]
  );

  return result.affectedRows > 0;
};

module.exports = {
  getRecentDeviceFailureCount,
  getActiveDeviceLockout,
  lockDeviceIfThresholdReached,
  clearDeviceLockoutOnSuccess,
  assertDeviceNotLocked,
  willDeviceBeLocked,
  getLockedDevicesForUser,
  unlockDeviceManual,
  DEVICE_LOCK_MINUTES,
  DEVICE_FAILURE_LIMIT,
};
