const messageRecoveryService = require('../services/messageRecoveryService');

const status = async (req, res, next) => {
  try {
    const deviceFingerprint = messageRecoveryService.readDeviceFingerprint(req);
    const data = await messageRecoveryService.getStatus({
      userId: req.user.id,
      deviceFingerprint,
      req,
    });
    return res.json({ data });
  } catch (error) {
    return next(error);
  }
};

const setup = async (req, res, next) => {
  try {
    const deviceFingerprint = messageRecoveryService.readDeviceFingerprint(req);
    const data = await messageRecoveryService.setupRecoveryCode({
      userId: req.user.id,
      currentPassword: req.body.current_password,
      recoveryCode: req.body.recovery_code,
      deviceFingerprint,
      req,
    });
    return res.json(data);
  } catch (error) {
    return next(error);
  }
};

const verify = async (req, res, next) => {
  try {
    const deviceFingerprint = messageRecoveryService.readDeviceFingerprint(req);
    const data = await messageRecoveryService.verifyRecoveryCode({
      userId: req.user.id,
      recoveryCode: req.body.recovery_code,
      deviceFingerprint,
      req,
    });
    return res.json(data);
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  setup,
  status,
  verify,
};
