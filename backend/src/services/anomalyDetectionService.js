const pool = require('../config/db');

const classifyRisk = (score) => {
  if (score >= 50) return 'HIGH';
  if (score >= 20) return 'MEDIUM';
  return 'LOW';
};

const detectLoginRisk = async ({
  userId,
  email,
  ipAddress,
  userAgent,
  deviceFingerprint,
}) => {
  let score = 0;
  const reasons = [];
  const signals = {
    untrustedDevice: false,
    ipChanged: false,
    userAgentChanged: false,
    unusualHour: false,
    recentFailedPasswordCount: 0,
  };

  const [[device]] = await pool.query(
    `SELECT id, is_trusted, revoked_at
     FROM devices
     WHERE user_id = ? AND device_fingerprint = ?
     LIMIT 1`,
    [userId, deviceFingerprint]
  );

  if (!device || !device.is_trusted || device.revoked_at) {
    score += 30;
    signals.untrustedDevice = true;
    reasons.push('Thiết bị mới, chưa được tin cậy hoặc đã bị gỡ');
  }

  const [[lastSuccess]] = await pool.query(
    `SELECT ip_address, user_agent
     FROM login_attempts
     WHERE user_id = ? AND is_successful = TRUE
     ORDER BY created_at DESC
     LIMIT 1`,
    [userId]
  );

  if (lastSuccess && lastSuccess.ip_address !== ipAddress) {
    score += 15;
    signals.ipChanged = true;
    reasons.push('Địa chỉ IP khác lần đăng nhập thành công gần nhất');
  }

  if (lastSuccess && (lastSuccess.user_agent || '') !== userAgent) {
    score += 10;
    signals.userAgentChanged = true;
    reasons.push('User-Agent khác lần đăng nhập thành công gần nhất');
  }

  const currentHour = new Date().getHours();
  if (currentHour >= 1 && currentHour <= 5) {
    score += 10;
    signals.unusualHour = true;
    reasons.push('Đăng nhập trong khung giờ bất thường từ 01:00 đến 05:59');
  }

  const [[failedStats]] = await pool.query(
    `SELECT COUNT(*) AS total
     FROM login_attempts
     WHERE email = ?
       AND failure_type = 'INVALID_CREDENTIALS'
       AND is_resolved = FALSE
       AND created_at >= (NOW() - INTERVAL 15 MINUTE)`,
    [email]
  );

  const failedCount = Number(failedStats.total || 0);
  signals.recentFailedPasswordCount = failedCount;
  if (failedCount >= 5) {
    score += 40;
    reasons.push('Có ít nhất 5 lần nhập sai mật khẩu trong 15 phút');
  } else if (failedCount >= 3) {
    score += 20;
    reasons.push('Có ít nhất 3 lần nhập sai mật khẩu trong 15 phút');
  }

  return {
    riskScore: score,
    riskLevel: classifyRisk(score),
    reasons,
    signals,
    reason: reasons.length > 0
      ? reasons.join('; ')
      : 'Không phát hiện dấu hiệu đăng nhập bất thường',
  };
};

module.exports = {
  classifyRisk,
  detectLoginRisk,
};
