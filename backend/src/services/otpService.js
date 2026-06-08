const crypto = require('crypto');
const pool = require('../config/db');

const OTP_TTL_MS = 5 * 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;

const hashOtp = (otp) =>
  crypto
    .createHash('sha256')
    .update(`${otp}:${process.env.OTP_SECRET || process.env.JWT_SECRET}`)
    .digest('hex');

const createOtpChallenge = async ({
  user,
  deviceFingerprint,
  ipAddress,
  userAgent,
  riskScore,
  riskLevel,
  reason,
}) => {
  const otpCode = crypto.randomInt(100000, 1000000).toString();

  await pool.query(
    `UPDATE auth_otps
     SET expires_at = NOW()
     WHERE user_id = ? AND verified_at IS NULL`,
    [user.id]
  );

  const [result] = await pool.query(
    `INSERT INTO auth_otps
     (user_id, email, otp_hash, device_fingerprint, ip_address, user_agent,
      risk_score, risk_level, reason, expires_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      user.id,
      user.email,
      hashOtp(otpCode),
      deviceFingerprint,
      ipAddress,
      userAgent,
      riskScore,
      riskLevel,
      reason,
      new Date(Date.now() + OTP_TTL_MS),
    ]
  );

  return {
    challengeId: result.insertId,
    otpCode,
    expiresIn: OTP_TTL_MS / 1000,
  };
};

const verifyOtpChallenge = async ({
  email,
  otpCode,
  deviceFingerprint,
}) => {
  const normalizedEmail = email.toLowerCase().trim();
  const connection = await pool.getConnection();
  let transactionOpen = false;

  try {
    await connection.beginTransaction();
    transactionOpen = true;
    const [[challenge]] = await connection.query(
      `SELECT *
       FROM auth_otps
       WHERE email = ?
         AND device_fingerprint = ?
         AND verified_at IS NULL
       ORDER BY created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [normalizedEmail, deviceFingerprint]
    );

    if (!challenge || new Date(challenge.expires_at) <= new Date()) {
      const error = new Error('Mã OTP đã hết hạn hoặc không tồn tại');
      error.statusCode = 400;
      throw error;
    }

    if (challenge.attempts >= MAX_OTP_ATTEMPTS) {
      const error = new Error('Bạn đã nhập sai OTP quá số lần cho phép');
      error.statusCode = 423;
      throw error;
    }

    if (hashOtp(otpCode) !== challenge.otp_hash) {
      await connection.query(
        'UPDATE auth_otps SET attempts = attempts + 1 WHERE id = ?',
        [challenge.id]
      );
      await connection.commit();
      transactionOpen = false;
      const error = new Error('Mã OTP không chính xác');
      error.statusCode = 400;
      throw error;
    }

    await connection.query(
      'UPDATE auth_otps SET verified_at = NOW() WHERE id = ?',
      [challenge.id]
    );
    await connection.commit();
    transactionOpen = false;
    return challenge;
  } catch (error) {
    if (transactionOpen) {
      await connection.rollback();
    }
    throw error;
  } finally {
    connection.release();
  }
};

module.exports = {
  createOtpChallenge,
  verifyOtpChallenge,
};
