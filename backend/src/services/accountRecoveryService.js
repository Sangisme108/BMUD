const crypto = require('crypto');
const bcrypt = require('bcrypt');
const pool = require('../config/db');
const { resetVerifiedDevices } = require('./messageRecoveryService');
const { recordSecurityEvent } = require('./securityEventService');
const {
  sendPasswordResetOtpEmail,
  sendUnlockAccountOtpEmail,
} = require('./emailService');

const OTP_TTL_MS = 5 * 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;
const GENERIC_MESSAGE =
  'Nếu email tồn tại trong hệ thống, mã OTP sẽ được gửi trong ít phút.';

const createHttpError = (message, statusCode) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

const normalizeEmail = (email = '') => email.toLowerCase().trim();
const hashOtp = (otp) =>
  crypto
    .createHash('sha256')
    .update(`${otp}:${process.env.OTP_SECRET || process.env.JWT_SECRET}`)
    .digest('hex');

const createRecoveryOtp = async ({ userId, actionType }) => {
  const otpCode = crypto.randomInt(100000, 1000000).toString();
  await pool.query(
    `UPDATE account_action_tokens
     SET used_at = NOW()
     WHERE user_id = ? AND action_type = ? AND used_at IS NULL`,
    [userId, actionType]
  );
  await pool.query(
    `INSERT INTO account_action_tokens
     (user_id, token_hash, action_type, expires_at, attempts)
     VALUES (?, ?, ?, ?, 0)`,
    [
      userId,
      hashOtp(otpCode),
      actionType,
      new Date(Date.now() + OTP_TTL_MS),
    ]
  );
  return otpCode;
};

const requestPasswordReset = async ({ email }) => {
  const normalizedEmail = normalizeEmail(email);
  const [[user]] = await pool.query(
    'SELECT id, full_name, email FROM users WHERE email = ?',
    [normalizedEmail]
  );
  if (!user) return { message: GENERIC_MESSAGE };

  const otpCode = await createRecoveryOtp({
    userId: user.id,
    actionType: 'RESET_PASSWORD',
  });
  await sendPasswordResetOtpEmail({
    user,
    otpCode,
    expiresInMinutes: 5,
  });
  return { message: GENERIC_MESSAGE };
};

const requestUnlock = async ({ email }) => {
  const normalizedEmail = normalizeEmail(email);
  const [[user]] = await pool.query(
    'SELECT id, full_name, email FROM users WHERE email = ?',
    [normalizedEmail]
  );
  if (!user) return { message: GENERIC_MESSAGE };

  const otpCode = await createRecoveryOtp({
    userId: user.id,
    actionType: 'UNLOCK_ACCOUNT',
  });
  await sendUnlockAccountOtpEmail({
    user,
    otpCode,
    expiresInMinutes: 5,
  });
  return { message: GENERIC_MESSAGE };
};

const verifyRecoveryOtp = async ({
  email,
  otpCode,
  actionType,
  handler,
}) => {
  const normalizedEmail = normalizeEmail(email);
  const connection = await pool.getConnection();
  let transactionOpen = false;

  try {
    await connection.beginTransaction();
    transactionOpen = true;
    const [[record]] = await connection.query(
      `SELECT token.id, token.user_id, token.token_hash, token.attempts
       FROM account_action_tokens AS token
       JOIN users ON users.id = token.user_id
       WHERE users.email = ?
         AND token.action_type = ?
         AND token.used_at IS NULL
         AND token.expires_at > NOW()
       ORDER BY token.created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [normalizedEmail, actionType]
    );

    if (!record) {
      throw createHttpError('Mã OTP không hợp lệ hoặc đã hết hạn', 400);
    }
    if (record.attempts >= MAX_OTP_ATTEMPTS) {
      throw createHttpError('Bạn đã nhập sai OTP quá số lần cho phép', 423);
    }
    if (record.token_hash !== hashOtp(otpCode)) {
      await connection.query(
        'UPDATE account_action_tokens SET attempts = attempts + 1 WHERE id = ?',
        [record.id]
      );
      await connection.commit();
      transactionOpen = false;
      throw createHttpError('Mã OTP không chính xác', 400);
    }

    await handler(connection, record.user_id);
    await connection.query(
      `UPDATE account_action_tokens
       SET used_at = NOW()
       WHERE user_id = ? AND action_type = ? AND used_at IS NULL`,
      [record.user_id, actionType]
    );
    await connection.commit();
    transactionOpen = false;
  } catch (error) {
    if (transactionOpen) await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
};

const unlockAccount = async ({ email, otpCode }) => {
  await verifyRecoveryOtp({
    email,
    otpCode,
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
      await recordSecurityEvent({
        userId,
        eventType: 'ACCOUNT_UNLOCKED',
        title: 'Mo khoa tai khoan',
        description: 'Tai khoan da duoc mo khoa bang OTP.',
        riskLevel: 'MEDIUM',
      });
    },
  });
  return { message: 'Tài khoản đã được mở khóa. Bạn có thể đăng nhập lại.' };
};

const resetPassword = async ({ email, otpCode, newPassword }) => {
  if (!newPassword || newPassword.length < 8) {
    throw createHttpError('Mật khẩu mới phải có ít nhất 8 ký tự', 400);
  }
  const passwordHash = await bcrypt.hash(newPassword, 12);

  await verifyRecoveryOtp({
    email,
    otpCode,
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
      await resetVerifiedDevices(userId);
      await recordSecurityEvent({
        userId,
        eventType: 'PASSWORD_RESET',
        title: 'Doi mat khau thanh cong',
        description: 'Mat khau da duoc dat lai, cac thiet bi can xac minh lai tin nhan.',
        riskLevel: 'HIGH',
      });
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
