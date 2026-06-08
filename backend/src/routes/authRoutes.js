const express = require('express');
const authController = require('../controllers/authController');
const bruteForceMiddleware = require('../middleware/bruteForceMiddleware');
const recoveryRateLimiter = require('../middleware/recoveryRateLimitMiddleware');
const authRateLimiter = require('../middleware/rateLimitMiddleware');

const router = express.Router();

router.post('/register', authRateLimiter, authController.register);
router.post('/login', authRateLimiter, bruteForceMiddleware, authController.login);
router.post('/verify-otp', authRateLimiter, authController.verifyOtp);
router.post('/refresh', authRateLimiter, authController.refresh);
router.post('/logout', authRateLimiter, authController.logout);
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
