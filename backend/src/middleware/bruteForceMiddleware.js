const authService = require('../services/authService');
const { hashDeviceId } = require('../services/sessionService');

const bruteForceMiddleware = async (req, res, next) => {
  try {
    const email = req.body?.email;
    let deviceFingerprint =
      req.body?.device_fingerprint || req.body?.deviceFingerprint;

    if (email) {
      if (!deviceFingerprint) {
        const deviceId = req.body?.deviceId || req.body?.device_id;
        if (deviceId) {
          deviceFingerprint = deviceId;
        }
      }
      if (deviceFingerprint) {
        deviceFingerprint = hashDeviceId(deviceFingerprint);
      }

      await authService.assertLoginAllowed({
        email,
        ipAddress: req.ip || req.socket.remoteAddress || 'unknown',
        deviceFingerprint,
      });
    }
    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = bruteForceMiddleware;
