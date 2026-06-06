const express = require('express');
const authController = require('../controllers/authController');
const authRateLimiter = require('../middleware/rateLimitMiddleware');

const router = express.Router();

router.post('/register', authRateLimiter, authController.register);
router.post('/login', authRateLimiter, authController.login);

module.exports = router;
