const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const {
  assertSessionActive,
  createHttpError,
  createLoginSession,
  generateSessionId,
  hashDeviceId,
  revokeSessionForLogout,
  updateSessionRefreshHash,
} = require('./sessionService');

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '7d';
const REFRESH_TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;

const hashToken = (token) =>
  crypto.createHash('sha256').update(token).digest('hex');

const getRefreshSecret = () =>
  process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET;

const createTokenPair = async (
  user,
  {
    deviceId,
    deviceName,
    deviceType,
    operatingSystem,
    ipAddress,
    userAgent,
    isTrusted = true,
  } = {},
  db = pool
) => {
  if (!user?.id) {
    throw createHttpError('userId khong hop le khi tao refresh token', 500);
  }
  if (!deviceId) {
    throw createHttpError('Thieu thong tin thiet bi', 400);
  }

  const deviceIdHash = hashDeviceId(deviceId);
  const sessionId = generateSessionId();

  const refreshToken = jwt.sign(
    {
      id: user.id,
      email: user.email,
      type: 'refresh',
      sessionId,
      deviceIdHash,
      nonce: crypto.randomUUID(),
    },
    getRefreshSecret(),
    { expiresIn: REFRESH_TOKEN_TTL }
  );
  const refreshTokenHash = hashToken(refreshToken);

  await createLoginSession({
    userId: user.id,
    sessionId,
    deviceIdHash,
    deviceName,
    deviceType,
    operatingSystem,
    ipAddress,
    userAgent,
    refreshTokenHash,
    isTrusted,
    db,
  });

  const accessToken = jwt.sign(
    {
      id: user.id,
      email: user.email,
      type: 'access',
      sessionId,
      deviceIdHash,
    },
    process.env.JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_TTL }
  );

  await db.query(
    `INSERT INTO refresh_tokens
     (user_id, session_id, device_id_hash, token_hash, expires_at)
     VALUES (?, ?, ?, ?, ?)`,
    [
      user.id,
      sessionId,
      deviceIdHash,
      refreshTokenHash,
      new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
    ]
  );

  return {
    access_token: accessToken,
    refresh_token: refreshToken,
    session_id: sessionId,
    token_type: 'Bearer',
    expires_in: 15 * 60,
  };
};

const rotateRefreshToken = async (refreshToken, deviceId) => {
  if (!refreshToken) {
    throw createHttpError('Thiếu refresh token', 400);
  }
  if (!deviceId) {
    throw createHttpError('Thiếu thông tin thiết bị', 400);
  }

  const deviceIdHash = hashDeviceId(deviceId);
  let decoded;
  try {
    decoded = jwt.verify(refreshToken, getRefreshSecret());
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw createHttpError(
        'Refresh token đã hết hạn hoặc không hợp lệ',
        401,
        'ACCESS_TOKEN_EXPIRED'
      );
    }
    throw createHttpError('Refresh token không hợp lệ', 401, 'INVALID_TOKEN');
  }

  if (decoded.type !== 'refresh') {
    throw createHttpError('Refresh token không hợp lệ', 401, 'INVALID_TOKEN');
  }

  if (decoded.deviceIdHash && decoded.deviceIdHash !== deviceIdHash) {
    throw createHttpError(
      'Phiên đăng nhập đã bị thu hồi',
      401,
      'SESSION_REVOKED'
    );
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [[storedToken]] = await connection.query(
      `SELECT id, user_id, session_id, device_id_hash
       FROM refresh_tokens
       WHERE token_hash = ?
         AND revoked_at IS NULL
         AND expires_at > NOW()
       FOR UPDATE`,
      [hashToken(refreshToken)]
    );

    if (!storedToken) {
      throw createHttpError(
        'Phiên đăng nhập đã bị thu hồi',
        401,
        'REFRESH_TOKEN_REVOKED'
      );
    }

    if (
      storedToken.device_id_hash &&
      storedToken.device_id_hash !== deviceIdHash
    ) {
      throw createHttpError(
        'Phiên đăng nhập đã bị thu hồi',
        401,
        'SESSION_REVOKED'
      );
    }

    const sessionId = storedToken.session_id || decoded.sessionId;
    await assertSessionActive({
      sessionId,
      userId: storedToken.user_id,
      deviceIdHash,
      db: connection,
    });

    const [[device]] = await connection.query(
      `SELECT id, is_trusted, revoked_at
       FROM devices
       WHERE user_id = ?
         AND device_fingerprint = ?
       LIMIT 1`,
      [storedToken.user_id, deviceIdHash]
    );

    if (!device || !device.is_trusted || device.revoked_at) {
      throw createHttpError(
        'Phiên đăng nhập đã bị thu hồi',
        401,
        'SESSION_REVOKED'
      );
    }

    const [[user]] = await connection.query(
      `SELECT id, full_name, email, email_verified_at, created_at, updated_at
       FROM users WHERE id = ?`,
      [storedToken.user_id]
    );

    await connection.query(
      'UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = ?',
      [storedToken.id]
    );

    const newRefreshToken = jwt.sign(
      {
        id: user.id,
        email: user.email,
        type: 'refresh',
        sessionId,
        deviceIdHash,
        nonce: crypto.randomUUID(),
      },
      getRefreshSecret(),
      { expiresIn: REFRESH_TOKEN_TTL }
    );
    const newRefreshHash = hashToken(newRefreshToken);

    await connection.query(
      `INSERT INTO refresh_tokens
       (user_id, session_id, device_id_hash, token_hash, expires_at)
       VALUES (?, ?, ?, ?, ?)`,
      [
        user.id,
        sessionId,
        deviceIdHash,
        newRefreshHash,
        new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
      ]
    );

    await updateSessionRefreshHash({
      sessionId,
      refreshTokenHash: newRefreshHash,
      db: connection,
    });

    const accessToken = jwt.sign(
      {
        id: user.id,
        email: user.email,
        type: 'access',
        sessionId,
        deviceIdHash,
      },
      process.env.JWT_SECRET,
      { expiresIn: ACCESS_TOKEN_TTL }
    );

    await connection.commit();

    return {
      access_token: accessToken,
      refresh_token: newRefreshToken,
      session_id: sessionId,
      token_type: 'Bearer',
      expires_in: 15 * 60,
      user: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        email_verified_at: user.email_verified_at,
        created_at: user.created_at,
        updated_at: user.updated_at,
      },
    };
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
};

const revokeRefreshToken = async (refreshToken) => {
  if (!refreshToken) return null;

  const tokenHash = hashToken(refreshToken);
  const [[storedToken]] = await pool.query(
    `SELECT user_id, session_id
     FROM refresh_tokens
     WHERE token_hash = ?
     LIMIT 1`,
    [tokenHash]
  );

  if (storedToken?.session_id) {
    await revokeSessionForLogout({
      sessionId: storedToken.session_id,
      refreshTokenHash: tokenHash,
    });
  } else {
    await pool.query(
      `UPDATE refresh_tokens
       SET revoked_at = COALESCE(revoked_at, NOW())
       WHERE token_hash = ?`,
      [tokenHash]
    );
  }

  return storedToken?.user_id || null;
};

const revokeAllUserRefreshTokens = async (userId, db = pool) => {
  await db.query(
    `UPDATE refresh_tokens
     SET revoked_at = NOW()
     WHERE user_id = ?
       AND revoked_at IS NULL`,
    [userId]
  );
  await db.query(
    `UPDATE login_sessions
     SET is_active = FALSE,
         revoked_at = NOW(),
         revoked_reason = 'PASSWORD_RESET'
     WHERE user_id = ?
       AND is_active = TRUE`,
    [userId]
  );
};

module.exports = {
  createTokenPair,
  hashToken,
  revokeAllUserRefreshTokens,
  revokeRefreshToken,
  rotateRefreshToken,
};
