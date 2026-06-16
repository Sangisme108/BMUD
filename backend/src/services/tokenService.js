const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '7d';
const REFRESH_TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;

const hashToken = (token) =>
  crypto.createHash('sha256').update(token).digest('hex');

const getRefreshSecret = () =>
  process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET;

const createTokenPair = async (user) => {
  const accessToken = jwt.sign(
    { id: user.id, email: user.email, type: 'access' },
    process.env.JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_TTL }
  );

  const refreshToken = jwt.sign(
    {
      id: user.id,
      email: user.email,
      type: 'refresh',
      nonce: crypto.randomUUID(),
    },
    getRefreshSecret(),
    { expiresIn: REFRESH_TOKEN_TTL }
  );

  await pool.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
     VALUES (?, ?, ?)`,
    [
      user.id,
      hashToken(refreshToken),
      new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
    ]
  );

  return {
    access_token: accessToken,
    refresh_token: refreshToken,
    token_type: 'Bearer',
    expires_in: 15 * 60,
  };
};

const rotateRefreshToken = async (refreshToken) => {
  let decoded;
  try {
    decoded = jwt.verify(refreshToken, getRefreshSecret());
  } catch (_) {
    const error = new Error('Refresh token đã hết hạn hoặc không hợp lệ');
    error.statusCode = 401;
    throw error;
  }
  if (decoded.type !== 'refresh') {
    const error = new Error('Refresh token không hợp lệ');
    error.statusCode = 401;
    throw error;
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [[storedToken]] = await connection.query(
      `SELECT id, user_id
       FROM refresh_tokens
       WHERE token_hash = ?
         AND revoked_at IS NULL
         AND expires_at > NOW()
       FOR UPDATE`,
      [hashToken(refreshToken)]
    );

    if (!storedToken) {
      const error = new Error('Refresh token đã hết hạn hoặc bị thu hồi');
      error.statusCode = 401;
      throw error;
    }

    const [[user]] = await connection.query(
      `SELECT id, full_name, email, created_at, updated_at
       FROM users WHERE id = ?`,
      [storedToken.user_id]
    );

    await connection.query(
      'UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = ?',
      [storedToken.id]
    );
    await connection.commit();

    return createTokenPair(user);
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
};

const revokeRefreshToken = async (refreshToken) => {
  if (!refreshToken) return null;
  const [[storedToken]] = await pool.query(
    `SELECT user_id
     FROM refresh_tokens
     WHERE token_hash = ?
     LIMIT 1`,
    [hashToken(refreshToken)]
  );
  await pool.query(
    `UPDATE refresh_tokens
     SET revoked_at = COALESCE(revoked_at, NOW())
     WHERE token_hash = ?`,
    [hashToken(refreshToken)]
  );
  return storedToken?.user_id || null;
};

module.exports = {
  createTokenPair,
  revokeRefreshToken,
  rotateRefreshToken,
};
