const pool = require('../config/db');
const { recordSecurityEvent } = require('./securityEventService');
const {
  createHttpError,
  hashDeviceId,
  revokeSessionById,
} = require('./sessionService');

const inferOs = (userAgent = '', operatingSystem = null) => {
  if (operatingSystem) return operatingSystem;
  const raw = String(userAgent).toLowerCase();
  if (raw.includes('android')) return 'Android';
  if (raw.includes('iphone') || raw.includes('ipad') || raw.includes('ios')) {
    return 'iOS';
  }
  if (raw.includes('windows')) return 'Windows';
  if (raw.includes('mac os') || raw.includes('macintosh')) return 'macOS';
  if (raw.includes('linux')) return 'Linux';
  return 'Không xác định';
};

const inferDeviceName = (userAgent = '', deviceName = null, deviceType = null) => {
  if (deviceName) return deviceName;
  const os = inferOs(userAgent);
  if (deviceType === 'android' || os === 'Android') return 'Android';
  if (deviceType === 'ios' || os === 'iOS') return 'iPhone/iPad';
  if (os === 'Windows') return 'Windows PC';
  if (os === 'macOS') return 'Mac';
  if (String(userAgent).toLowerCase().includes('chrome')) return 'Chrome Browser';
  return 'Thiết bị ứng dụng';
};

const listDevices = async (userId, currentSessionId = null) => {
  const [rows] = await pool.query(
    `SELECT
       ls.session_id,
       ls.device_id_hash,
       ls.device_name,
       ls.device_type,
       ls.operating_system,
       ls.ip_address,
       ls.user_agent,
       ls.is_trusted,
       ls.last_seen_at,
       ls.created_at,
       d.message_recovery_verified,
       d.revoked_at AS device_revoked_at
     FROM login_sessions ls
     LEFT JOIN devices d
       ON d.user_id = ls.user_id
      AND d.device_fingerprint = ls.device_id_hash
     WHERE ls.user_id = ?
       AND ls.is_active = TRUE
       AND ls.revoked_at IS NULL
       AND ls.expires_at > NOW()
     ORDER BY ls.last_seen_at DESC, ls.created_at DESC`,
    [userId]
  );

  return rows.map((row) => ({
    sessionId: row.session_id,
    deviceRecordId: row.session_id,
    deviceName: inferDeviceName(
      row.user_agent,
      row.device_name,
      row.device_type
    ),
    deviceType: row.device_type || 'unknown',
    operatingSystem: inferOs(row.user_agent, row.operating_system),
    ipAddress: row.ip_address,
    lastSeenAt: row.last_seen_at,
    isTrusted: Boolean(row.is_trusted) && !row.device_revoked_at,
    isCurrentDevice: currentSessionId
      ? row.session_id === currentSessionId
      : false,
    messageRecoveryStatus:
      row.message_recovery_verified === 1 || row.message_recovery_verified === true
        ? 'RECOVERED'
        : 'NOT_RECOVERED',
  }));
};

const revokeDevice = async ({ userId, sessionId, req }) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const session = await revokeSessionById({
      userId,
      sessionId,
      reason: 'USER_REMOVED_DEVICE',
      db: connection,
    });

    await recordSecurityEvent({
      userId,
      eventType: 'DEVICE_REVOKED',
      title: 'Da go thiet bi dang nhap',
      description: 'Mot thiet bi da bi go va dang xuat khoi tai khoan.',
      ipAddress: req.ip || req.socket.remoteAddress,
      userAgent: req.get('user-agent') || 'Unknown',
      deviceFingerprint: session.device_id_hash,
      riskLevel: 'MEDIUM',
      metadata: {
        session_id: sessionId,
        revoked_device_ip: session.ip_address,
      },
      db: connection,
    });

    await connection.commit();

    return {
      success: true,
      message: 'Đã gỡ thiết bị và đăng xuất thiết bị đó',
      revokedCurrentDevice: req.sessionId === sessionId,
    };
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
};

const resolveDeviceRecordId = (value) => {
  const raw = String(value || '').trim();
  if (!raw) {
    throw createHttpError('Thiếu định danh thiết bị', 400);
  }
  return raw;
};

module.exports = {
  hashDeviceId,
  inferDeviceName,
  inferOs,
  listDevices,
  resolveDeviceRecordId,
  revokeDevice,
};
