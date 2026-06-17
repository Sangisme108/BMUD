const express = require('express');
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');
const bruteForceMiddleware = require('../middleware/bruteForceMiddleware');
const recoveryRateLimiter = require('../middleware/recoveryRateLimitMiddleware');
const authRateLimiter = require('../middleware/rateLimitMiddleware');

const router = express.Router();

router.post('/register', authRateLimiter, authController.sendRegisterOtp);
router.post(
  '/register/send-otp',
  authRateLimiter,
  authController.sendRegisterOtp
);
router.post(
  '/register/verify-otp',
  authRateLimiter,
  authController.verifyRegisterOtp
);
router.post('/login', authRateLimiter, bruteForceMiddleware, authController.login);
router.post(
  '/login/verify-device-otp',
  authRateLimiter,
  authController.verifyDeviceOtp
);
router.post('/verify-otp', authRateLimiter, authController.verifyOtp);
router.post('/refresh', authRateLimiter, authController.refresh);
router.post('/logout', authRateLimiter, authController.logout);
router.get('/devices', authRateLimiter, authMiddleware, authController.getDevices);
router.get('/my-devices', authRateLimiter, authMiddleware, authController.getDevices);
router.get(
  '/devices/locked',
  authRateLimiter,
  authMiddleware,
  authController.getLockedDevices
);
router.delete(
  '/devices/:deviceRecordId',
  authRateLimiter,
  authMiddleware,
  authController.revokeDevice
);
router.post(
  '/devices/:deviceRecordId/revoke',
  authRateLimiter,
  authMiddleware,
  authController.revokeDevice
);
router.post(
  '/devices/:deviceFingerprint/unlock',
  authRateLimiter,
  authMiddleware,
  authController.unlockDevice
);
router.post(
  '/unlock-device',
  authRateLimiter,
  authMiddleware,
  authController.unlockDevice
);
router.post(
  '/forgot-password',
  recoveryRateLimiter,
  authController.requestPasswordReset
);
router.post('/reset-password', authRateLimiter, authController.resetPassword);
router.post(
  '/request-unlock',
  recoveryRateLimiter,
  authController.requestUnlock
);
router.post('/unlock-account', authRateLimiter, authController.unlockAccount);

module.exports = router;
