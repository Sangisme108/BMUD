const pool = require('../config/db');
const { recordSecurityEvent } = require('./securityEventService');

const createHttpError = (message, statusCode) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

const listDevices = async (userId) => {
  const [rows] = await pool.query(
    `SELECT id, ip_address, user_agent, is_trusted,
            message_recovery_verified, message_recovery_verified_at,
            last_used_at, created_at
     FROM devices
     WHERE user_id = ?
     ORDER BY last_used_at DESC, created_at DESC`,
    [userId]
  );
  return rows.map((row) => ({
    ...row,
    device_name: inferDeviceName(row.user_agent),
    os_name: inferOs(row.user_agent),
  }));
};

const revokeDevice = async ({ userId, deviceId, req }) => {
  const [[device]] = await pool.query(
    `SELECT id, ip_address, user_agent
     FROM devices
     WHERE id = ? AND user_id = ?
     LIMIT 1`,
    [deviceId, userId]
  );
  if (!device) {
    throw createHttpError('Không tìm thấy thiết bị', 404);
  }

  await pool.query(
    `UPDATE devices
     SET is_trusted = FALSE,
         message_recovery_verified = FALSE,
         message_recovery_verified_at = NULL
     WHERE id = ? AND user_id = ?`,
    [deviceId, userId]
  );

  await recordSecurityEvent({
    userId,
    eventType: 'DEVICE_REVOKED',
    title: 'Đã gỡ thiết bị tin cậy',
    description: `Thiết bị ${inferDeviceName(device.user_agent)} đã bị gỡ quyền tin cậy.`,
    ipAddress: req.ip || req.socket.remoteAddress,
    userAgent: req.get('user-agent') || 'Unknown',
    riskLevel: 'MEDIUM',
    metadata: { device_id: device.id, revoked_device_ip: device.ip_address },
  });

  return { message: 'Đã gỡ thiết bị tin cậy' };
};

const inferOs = (userAgent = '') => {
  const raw = String(userAgent).toLowerCase();
  if (raw.includes('android')) return 'Android';
  if (raw.includes('iphone') || raw.includes('ipad') || raw.includes('ios')) return 'iOS';
  if (raw.includes('windows')) return 'Windows';
  if (raw.includes('mac os') || raw.includes('macintosh')) return 'macOS';
  if (raw.includes('linux')) return 'Linux';
  return 'Không xác định';
};

const inferDeviceName = (userAgent = '') => {
  const os = inferOs(userAgent);
  if (os === 'Android') return 'Android';
  if (os === 'iOS') return 'iPhone/iPad';
  if (os === 'Windows') return 'Windows PC';
  if (os === 'macOS') return 'Mac';
  if (String(userAgent).toLowerCase().includes('chrome')) return 'Chrome Browser';
  return 'Thiết bị ứng dụng';
};

module.exports = {
  listDevices,
  revokeDevice,
};
