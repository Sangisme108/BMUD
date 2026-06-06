const pool = require('../config/db');

const getRiskScore = (riskLevel) => {
  if (riskLevel === 'HIGH') return 3;
  if (riskLevel === 'MEDIUM') return 2;
  return 1;
};

const detectLoginRisk = async ({ userId, email, ipAddress, userAgent, deviceFingerprint }) => {
  const reasons = [];
  let riskLevel = 'LOW';

  const [[failedStats]] = await pool.query(
    `SELECT COUNT(*) AS total
     FROM failed_login_attempts
     WHERE email = ? AND attempt_time >= (NOW() - INTERVAL 15 MINUTE)`,
    [email]
  );

  const [[historyStats]] = await pool.query(
    `SELECT COUNT(*) AS total
     FROM login_history
     WHERE user_id = ? AND login_status = 'SUCCESS'`,
    [userId]
  );

  if ((historyStats.total || 0) === 0) {
    return {
      riskLevel: 'LOW',
      reason: 'Lần đăng nhập thành công đầu tiên, dùng làm dữ liệu tin cậy ban đầu',
    };
  }

  const [[knownIp]] = await pool.query(
    `SELECT id FROM login_history
     WHERE user_id = ? AND ip_address = ? AND login_status = 'SUCCESS'
     LIMIT 1`,
    [userId, ipAddress]
  );

  const [[knownUserAgent]] = await pool.query(
    `SELECT id FROM login_history
     WHERE user_id = ? AND user_agent = ? AND login_status = 'SUCCESS'
     LIMIT 1`,
    [userId, userAgent]
  );

  const [[trustedDevice]] = await pool.query(
    `SELECT id FROM trusted_devices
     WHERE user_id = ? AND device_fingerprint = ?
     LIMIT 1`,
    [userId, deviceFingerprint]
  );

  const [[commonHour]] = await pool.query(
    `SELECT HOUR(login_time) AS login_hour, COUNT(*) AS total
     FROM login_history
     WHERE user_id = ? AND login_status = 'SUCCESS'
     GROUP BY HOUR(login_time)
     ORDER BY total DESC
     LIMIT 1`,
    [userId]
  );

  const currentHour = new Date().getHours();
  const failedCount = failedStats.total || 0;
  const isNewIp = !knownIp;
  const isNewDevice = !trustedDevice;
  const isNewUserAgent = !knownUserAgent;
  const isUnusualHour =
    commonHour && Math.abs(Number(commonHour.login_hour) - currentHour) >= 6;

  if (failedCount >= 5) {
    riskLevel = 'HIGH';
    reasons.push('Có nhiều lần đăng nhập thất bại trong 15 phút gần đây');
  }

  if (isNewIp && isNewDevice) {
    riskLevel = 'HIGH';
    reasons.push('Đăng nhập từ IP mới và thiết bị mới');
  } else {
    if (isNewIp) {
      riskLevel = getRiskScore(riskLevel) < 2 ? 'MEDIUM' : riskLevel;
      reasons.push('Đăng nhập từ IP mới');
    }

    if (isNewDevice) {
      riskLevel = getRiskScore(riskLevel) < 2 ? 'MEDIUM' : riskLevel;
      reasons.push('Đăng nhập từ thiết bị mới');
    }
  }

  if (isNewUserAgent) {
    riskLevel = getRiskScore(riskLevel) < 2 ? 'MEDIUM' : riskLevel;
    reasons.push('User-Agent mới');
  }

  if (isUnusualHour) {
    riskLevel = getRiskScore(riskLevel) < 2 ? 'MEDIUM' : riskLevel;
    reasons.push('Đăng nhập ngoài khung giờ thường dùng');
  }

  if (reasons.length === 0) {
    reasons.push('IP và thiết bị đã từng đăng nhập, không có dấu hiệu bất thường');
  }

  return {
    riskLevel,
    reason: reasons.join('; '),
  };
};

module.exports = {
  detectLoginRisk,
};
