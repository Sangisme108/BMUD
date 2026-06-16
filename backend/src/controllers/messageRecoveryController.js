const messageRecoveryService = require('../services/messageRecoveryService');
const { recordSecurityEvent } = require('../services/securityEventService');

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
    await recordSecurityEvent({
      userId: req.user.id,
      eventType: 'MESSAGE_RECOVERY_CODE_SET',
      title: 'Cap nhat ma khoi phuc tin nhan',
      description: 'Ma khoi phuc tin nhan da duoc tao hoac thay doi.',
      ipAddress: req.ip || req.socket.remoteAddress,
      userAgent: req.get('user-agent') || 'Unknown',
      deviceFingerprint,
      riskLevel: 'MEDIUM',
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
    await recordSecurityEvent({
      userId: req.user.id,
      eventType: 'MESSAGE_RECOVERY_VERIFIED',
      title: 'Khoi phuc tin nhan thanh cong',
      description: 'Thiet bi da duoc phep xem lai tin nhan cu.',
      ipAddress: req.ip || req.socket.remoteAddress,
      userAgent: req.get('user-agent') || 'Unknown',
      deviceFingerprint,
      riskLevel: 'LOW',
    });
    return res.json(data);
  } catch (error) {
    if (error.statusCode === 401) {
      await recordSecurityEvent({
        userId: req.user.id,
        eventType: 'MESSAGE_RECOVERY_FAILED',
        title: 'Nhap sai ma khoi phuc tin nhan',
        description: 'Thiet bi da nhap sai ma khoi phuc tin nhan.',
        ipAddress: req.ip || req.socket.remoteAddress,
        userAgent: req.get('user-agent') || 'Unknown',
        deviceFingerprint: messageRecoveryService.readDeviceFingerprint(req),
        riskLevel: 'HIGH',
      }).catch(() => {});
    }
    return next(error);
  }
};

module.exports = {
  setup,
  status,
  verify,
};
