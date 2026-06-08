const crypto = require('crypto');
const bcrypt = require('bcrypt');
const pool = require('../config/db');
const {
  sendPasswordResetEmail,
  sendUnlockAccountEmail,
} = require('./emailService');

const RESET_TTL_MS = 30 * 60 * 1000;
const UNLOCK_TTL_MS = 15 * 60 * 1000;
const GENERIC_MESSAGE =
  'Nếu email tồn tại trong hệ thống, hướng dẫn sẽ được gửi trong ít phút.';

const createHttpError = (message, statusCode) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

const normalizeEmail = (email = '') => email.toLowerCase().trim();
const hashToken = (token) =>
  crypto.createHash('sha256').update(token).digest('hex');

const createActionToken = async ({ userId, actionType, ttlMs }) => {
  const rawToken = crypto.randomBytes(32).toString('hex');
  await pool.query(
    `UPDATE account_action_tokens
     SET used_at = NOW()
     WHERE user_id = ? AND action_type = ? AND used_at IS NULL`,
    [userId, actionType]
  );
  await pool.query(
    `INSERT INTO account_action_tokens
     (user_id, token_hash, action_type, expires_at)
     VALUES (?, ?, ?, ?)`,
    [userId, hashToken(rawToken), actionType, new Date(Date.now() + ttlMs)]
  );
  return rawToken;
};

const buildActionLink = ({ action, token }) => {
  const baseUrl = process.env.APP_DEEP_LINK_BASE || 'bmud://account-action';
  const separator = baseUrl.includes('?') ? '&' : '?';
  return `${baseUrl}${separator}action=${encodeURIComponent(action)}&token=${encodeURIComponent(token)}`;
};

const requestPasswordReset = async ({ email }) => {
  const normalizedEmail = normalizeEmail(email);
  const [[user]] = await pool.query(
    'SELECT id, full_name, email FROM users WHERE email = ?',
    [normalizedEmail]
  );
  if (!user) return { message: GENERIC_MESSAGE };

  const token = await createActionToken({
    userId: user.id,
    actionType: 'RESET_PASSWORD',
    ttlMs: RESET_TTL_MS,
  });
  await sendPasswordResetEmail({
    user,
    actionLink: buildActionLink({ action: 'reset-password', token }),
    expiresInMinutes: 30,
  });
  return { message: GENERIC_MESSAGE };
};

const requestUnlock = async ({ email }) => {
  const normalizedEmail = normalizeEmail(email);
  const [[user]] = await pool.query(
    'SELECT id, full_name, email, is_locked FROM users WHERE email = ?',
    [normalizedEmail]
  );
  if (!user) return { message: GENERIC_MESSAGE };

  const token = await createActionToken({
    userId: user.id,
    actionType: 'UNLOCK_ACCOUNT',
    ttlMs: UNLOCK_TTL_MS,
  });
  await sendUnlockAccountEmail({
    user,
    actionLink: buildActionLink({ action: 'unlock', token }),
    expiresInMinutes: 15,
  });
  return { message: GENERIC_MESSAGE };
};

const consumeActionToken = async ({ token, actionType, handler }) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [[record]] = await connection.query(
      `SELECT id, user_id
       FROM account_action_tokens
       WHERE token_hash = ?
         AND action_type = ?
         AND used_at IS NULL
         AND expires_at > NOW()
       LIMIT 1
       FOR UPDATE`,
      [hashToken(token), actionType]
    );
    if (!record) {
      throw createHttpError('Liên kết không hợp lệ hoặc đã hết hạn', 400);
    }

    await handler(connection, record.user_id);
    await connection.query(
      'UPDATE account_action_tokens SET used_at = NOW() WHERE id = ?',
      [record.id]
    );
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
};

const unlockAccount = async ({ token }) => {
  await consumeActionToken({
    token,
    actionType: 'UNLOCK_ACCOUNT',
    handler: async (connection, userId) => {
      await connection.query(
        'UPDATE users SET is_locked = FALSE, lock_until = NULL WHERE id = ?',
        [userId]
      );
      await connection.query(
        `UPDATE login_attempts
         SET is_resolved = TRUE
         WHERE user_id = ? AND failure_type = 'INVALID_CREDENTIALS'`,
        [userId]
      );
    },
  });
  return { message: 'Tài khoản đã được mở khóa. Bạn có thể đăng nhập lại.' };
};

const resetPassword = async ({ token, newPassword }) => {
  if (!newPassword || newPassword.length < 8) {
    throw createHttpError('Mật khẩu mới phải có ít nhất 8 ký tự', 400);
  }
  const passwordHash = await bcrypt.hash(newPassword, 12);

  await consumeActionToken({
    token,
    actionType: 'RESET_PASSWORD',
    handler: async (connection, userId) => {
      await connection.query(
        `UPDATE users
         SET password_hash = ?, is_locked = FALSE, lock_until = NULL
         WHERE id = ?`,
        [passwordHash, userId]
      );
      await connection.query(
        `UPDATE login_attempts
         SET is_resolved = TRUE
         WHERE user_id = ? AND failure_type = 'INVALID_CREDENTIALS'`,
        [userId]
      );
      await connection.query(
        `UPDATE refresh_tokens
         SET revoked_at = COALESCE(revoked_at, NOW())
         WHERE user_id = ?`,
        [userId]
      );
      await connection.query(
        `UPDATE account_action_tokens
         SET used_at = COALESCE(used_at, NOW())
         WHERE user_id = ?`,
        [userId]
      );
    },
  });
  return { message: 'Mật khẩu đã được thay đổi. Hãy đăng nhập lại.' };
};

module.exports = {
  requestPasswordReset,
  requestUnlock,
  resetPassword,
  unlockAccount,
};
