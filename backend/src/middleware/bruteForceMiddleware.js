const authService = require('../services/authService');
const { assertDeviceNotLocked } = require('../services/deviceLockoutService');
const { hashDeviceId } = require('../services/sessionService');

const bruteForceMiddleware = async (req, res, next) => {
  try {
    const email = req.body?.email;
    let deviceFingerprint = req.body?.device_fingerprint;

    if (email) {
      // Check IP-based lockout (legacy)
      await authService.assertLoginAllowed({
        email,
        ipAddress: req.ip || req.socket.remoteAddress || 'unknown',
      });

      // Check device-based lockout (per-device)
      // Hash device ID if not already hashed
      if (!deviceFingerprint) {
        const deviceId = req.body?.deviceId || req.body?.device_id;
        if (deviceId) {
          deviceFingerprint = hashDeviceId(deviceId);
        }
      }

      if (deviceFingerprint) {
        await assertDeviceNotLocked({ email, deviceFingerprint });
      }
    }
    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = bruteForceMiddleware;
