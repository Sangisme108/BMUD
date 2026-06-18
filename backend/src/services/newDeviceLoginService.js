const crypto = require('crypto');
const pool = require('../config/db');
const { sendOtpEmail } = require('./emailService');
const { createHttpError, hashDeviceId, maskEmail } = require('./sessionService');

const OTP_TTL_MS = 5 * 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;
const ENABLE_DEBUG_OTP = process.env.ENABLE_DEBUG_OTP === 'true';

const hashOtp = (otp) =>
  crypto
    .createHash('sha256')
    .update(`${otp}:${process.env.OTP_SECRET || process.env.JWT_SECRET}`)
    .digest('hex');

const createNewDeviceLoginChallenge = async ({
  user,
  deviceId,
  deviceName,
  deviceType,
  operatingSystem,
  ipAddress,
  userAgent,
  riskLevel = 'MEDIUM',
  reason = 'Thiet bi moi hoac chua duoc tin cay can xac minh OTP',
}) => {
  const deviceIdHash = hashDeviceId(deviceId);
  const challengeId = crypto.randomUUID().replace(/-/g, '');
  const otpCode = crypto.randomInt(100000, 1000000).toString();

  await pool.query(
    `UPDATE email_otps
     SET used_at = NOW()
     WHERE user_id = ?
       AND purpose = 'NEW_DEVICE_LOGIN'
       AND device_id_hash = ?
       AND used_at IS NULL`,
    [user.id, deviceIdHash]
  );

  await pool.query(
    `INSERT INTO email_otps
     (challenge_id, user_id, email, otp_hash, purpose, device_id_hash,
      ip_address, user_agent, device_name, device_type, operating_system, expires_at)
     VALUES (?, ?, ?, ?, 'NEW_DEVICE_LOGIN', ?, ?, ?, ?, ?, ?, ?)`,
    [
      challengeId,
      user.id,
      user.email,
      hashOtp(otpCode),
      deviceIdHash,
      ipAddress,
      userAgent,
      deviceName || null,
      deviceType || null,
      operatingSystem || null,
      new Date(Date.now() + OTP_TTL_MS),
    ]
  );

  let emailSent = false;
  try {
    emailSent = await sendOtpEmail({
      user: {
        full_name: user.full_name,
        email: user.email,
      },
      otpCode,
      riskLevel,
      reason,
      expiresInMinutes: OTP_TTL_MS / 60000,
    });
  } catch (error) {
    console.error('Khong the gui email OTP thiet bi moi:', error.message);
  }

  return {
    challengeId,
    otpCode: ENABLE_DEBUG_OTP && !emailSent ? otpCode : undefined,
    expiresIn: OTP_TTL_MS / 1000,
    maskedEmail: maskEmail(user.email),
  };
};

module.exports = {
  createNewDeviceLoginChallenge,
};
