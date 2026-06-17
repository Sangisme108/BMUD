const crypto = require('crypto');
const pool = require('../config/db');

const REFRESH_TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;

const createHttpError = (message, statusCode, errorCode) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  if (errorCode) error.errorCode = errorCode;
  return error;
};

const hashDeviceId = (deviceId) => {
  const raw = String(deviceId || '').trim();
  if (/^[a-f0-9]{64}$/i.test(raw)) {
    return raw.toLowerCase();
  }
  return crypto.createHash('sha256').update(raw).digest('hex');
};

const generateSessionId = () => crypto.randomUUID().replace(/-/g, '');

const getActiveSession = async (sessionId, db = pool) => {
  const [[session]] = await db.query(
    `SELECT *
     FROM login_sessions
     WHERE session_id = ?
       AND is_active = TRUE
       AND revoked_at IS NULL
       AND expires_at > NOW()
     LIMIT 1`,
    [sessionId]
  );
  return session || null;
};

const assertSessionActive = async ({ sessionId, userId, deviceIdHash, db = pool }) => {
  const [[session]] = await db.query(
    `SELECT *
     FROM login_sessions
     WHERE session_id = ?
     LIMIT 1`,
    [sessionId]
  );

  if (!session) {
    throw createHttpError(
      'Thiết bị này đã bị đăng xuất',
      401,
      'SESSION_REVOKED'
    );
  }

  if (
    Number(session.user_id) !== Number(userId) ||
    session.device_id_hash !== deviceIdHash ||
    !session.is_active ||
    session.revoked_at ||
    new Date(session.expires_at) <= new Date()
  ) {
    throw createHttpError(
      'Thiết bị này đã bị đăng xuất',
      401,
      'SESSION_REVOKED'
    );
  }

  return session;
};

const revokePreviousDeviceSessions = async ({
  userId,
  deviceIdHash,
  reason = 'NEW_LOGIN',
  db = pool,
}) => {
  const [sessions] = await db.query(
    `SELECT session_id, refresh_token_hash
     FROM login_sessions
     WHERE user_id = ?
       AND device_id_hash = ?
       AND is_active = TRUE
       AND revoked_at IS NULL`,
    [userId, deviceIdHash]
  );

  if (sessions.length === 0) return;

  const sessionIds = sessions.map((row) => row.session_id);
  const tokenHashes = sessions.map((row) => row.refresh_token_hash);

  await db.query(
    `UPDATE login_sessions
     SET is_active = FALSE,
         revoked_at = NOW(),
         revoked_reason = ?
     WHERE user_id = ?
       AND device_id_hash = ?
       AND is_active = TRUE`,
    [reason, userId, deviceIdHash]
  );

  if (tokenHashes.length > 0) {
    await db.query(
      `UPDATE refresh_tokens
       SET revoked_at = NOW()
       WHERE token_hash IN (?)
         AND revoked_at IS NULL`,
      [tokenHashes]
    );
  }

  return sessionIds;
};

const createLoginSession = async ({
  userId,
  deviceIdHash,
  deviceName,
  deviceType,
  operatingSystem,
  ipAddress,
  userAgent,
  refreshTokenHash,
  isTrusted = true,
  sessionId = generateSessionId(),
  db = pool,
}) => {
  await revokePreviousDeviceSessions({
    userId,
    deviceIdHash,
    reason: 'NEW_LOGIN',
    db,
  });

  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);

  await db.query(
    `INSERT INTO login_sessions
     (session_id, user_id, device_id_hash, device_name, device_type,
      operating_system, ip_address, user_agent, refresh_token_hash,
      is_trusted, is_active, expires_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, TRUE, ?)`,
    [
      sessionId,
      userId,
      deviceIdHash,
      deviceName || null,
      deviceType || null,
      operatingSystem || null,
      ipAddress || null,
      userAgent || null,
      refreshTokenHash,
      isTrusted,
      expiresAt,
    ]
  );

  return { sessionId, expiresAt };
};

const touchSession = async (sessionId, db = pool) => {
  await db.query(
    `UPDATE login_sessions
     SET last_seen_at = NOW()
     WHERE session_id = ?
       AND is_active = TRUE`,
    [sessionId]
  );
};

const revokeSessionById = async ({
  userId,
  sessionId,
  reason = 'USER_REMOVED_DEVICE',
  db = pool,
}) => {
  const [[session]] = await db.query(
    `SELECT session_id, device_id_hash, refresh_token_hash, ip_address
     FROM login_sessions
     WHERE session_id = ?
       AND user_id = ?
     LIMIT 1
       FOR UPDATE`,
    [sessionId, userId]
  );

  if (!session) {
    throw createHttpError('Không tìm thấy phiên đăng nhập', 404);
  }

  await revokeDeviceSessions({
    userId,
    deviceIdHash: session.device_id_hash,
    reason,
    db,
  });

  return session;
};

const revokeDeviceSessions = async ({
  userId,
  deviceIdHash,
  reason = 'USER_REMOVED_DEVICE',
  db = pool,
}) => {
  const [sessions] = await db.query(
    `SELECT refresh_token_hash
     FROM login_sessions
     WHERE user_id = ?
       AND device_id_hash = ?
       AND is_active = TRUE`,
    [userId, deviceIdHash]
  );

  await db.query(
    `UPDATE login_sessions
     SET is_active = FALSE,
         revoked_at = NOW(),
         revoked_reason = ?
     WHERE user_id = ?
       AND device_id_hash = ?
       AND is_active = TRUE`,
    [reason, userId, deviceIdHash]
  );

  if (sessions.length > 0) {
    const hashes = sessions.map((row) => row.refresh_token_hash);
    await db.query(
      `UPDATE refresh_tokens
       SET revoked_at = NOW()
       WHERE token_hash IN (?)
         AND revoked_at IS NULL`,
      [hashes]
    );
  }

  await db.query(
    `UPDATE devices
     SET is_trusted = FALSE,
         message_recovery_verified = FALSE,
         message_recovery_verified_at = NULL,
         revoked_at = NOW(),
         revoked_reason = ?
     WHERE user_id = ?
       AND device_fingerprint = ?`,
    [reason, userId, deviceIdHash]
  );
};

const revokeSessionForLogout = async ({
  sessionId,
  refreshTokenHash,
  db = pool,
}) => {
  await db.query(
    `UPDATE login_sessions
     SET is_active = FALSE,
         revoked_at = NOW(),
         revoked_reason = 'LOGOUT'
     WHERE session_id = ?
       AND is_active = TRUE`,
    [sessionId]
  );

  await db.query(
    `UPDATE refresh_tokens
     SET revoked_at = NOW()
     WHERE token_hash = ?
       AND revoked_at IS NULL`,
    [refreshTokenHash]
  );
};

const updateSessionRefreshHash = async ({
  sessionId,
  refreshTokenHash,
  db = pool,
}) => {
  await db.query(
    `UPDATE login_sessions
     SET refresh_token_hash = ?,
         last_seen_at = NOW(),
         expires_at = ?
     WHERE session_id = ?
       AND is_active = TRUE`,
    [
      refreshTokenHash,
      new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
      sessionId,
    ]
  );
};

const maskEmail = (email = '') => {
  const normalized = String(email).trim();
  const [local, domain] = normalized.split('@');
  if (!local || !domain) return normalized;
  const visible = local.length <= 1 ? '*' : `${local[0]}${'*'.repeat(Math.min(local.length - 1, 4))}`;
  return `${visible}@${domain}`;
};

module.exports = {
  assertSessionActive,
  createHttpError,
  createLoginSession,
  generateSessionId,
  getActiveSession,
  hashDeviceId,
  maskEmail,
  revokeDeviceSessions,
  revokePreviousDeviceSessions,
  revokeSessionById,
  revokeSessionForLogout,
  touchSession,
  updateSessionRefreshHash,
};
