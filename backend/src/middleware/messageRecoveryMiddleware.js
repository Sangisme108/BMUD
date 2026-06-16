const messageRecoveryService = require('../services/messageRecoveryService');

const requireMessageRecovery = async (req, res, next) => {
  try {
    const deviceFingerprint = messageRecoveryService.readDeviceFingerprint(req);
    await messageRecoveryService.assertMessageRecoveryVerified({
      userId: req.user.id,
      deviceFingerprint,
      req,
    });
    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = requireMessageRecovery;
