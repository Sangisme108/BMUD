const crypto = require('crypto');
const pool = require('../config/db');

const normalizeIpAddress = (ipAddress = '') =>
  ipAddress.startsWith('::ffff:') ? ipAddress.slice(7) : ipAddress;

const hashDeviceFingerprint = (deviceFingerprint) => {
  if (!deviceFingerprint) return null;
  return crypto.createHash('sha256').update(String(deviceFingerprint)).digest('hex');
};

const getRequestContext = (req, deviceFingerprint) => ({
  ipAddress: normalizeIpAddress(req?.ip || req?.socket?.remoteAddress || 'unknown'),
  userAgent: req?.get?.('user-agent') || 'Unknown',
  deviceFingerprintHash: hashDeviceFingerprint(deviceFingerprint),
});

const recordSecurityEvent = async ({
  userId = null,
  eventType,
  title,
  description = null,
  ipAddress = null,
  userAgent = null,
  deviceFingerprint = null,
  deviceFingerprintHash = null,
  riskLevel = 'LOW',
  metadata = null,
  db = pool,
}) => {
  if (!eventType || !title) return;
  try {
    await db.query(
      `INSERT INTO security_events
       (user_id, event_type, title, description, ip_address, user_agent,
        device_fingerprint_hash, risk_level, metadata)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        userId,
        eventType,
        title,
        description,
        ipAddress ? normalizeIpAddress(ipAddress) : null,
        userAgent,
        deviceFingerprintHash || hashDeviceFingerprint(deviceFingerprint),
        riskLevel,
        metadata ? JSON.stringify(metadata) : null,
      ]
    );
  } catch (error) {
    if (error.code === 'ER_NO_SUCH_TABLE') {
      console.warn('security_events table is missing; skipped security event log');
      return;
    }
    throw error;
  }
};

module.exports = {
  getRequestContext,
  hashDeviceFingerprint,
  recordSecurityEvent,
};
