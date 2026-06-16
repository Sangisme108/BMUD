const express = require('express');
const authMiddleware = require('../middleware/authMiddleware');
const rateLimiter = require('../middleware/rateLimitMiddleware');
const messageRecoveryController = require('../controllers/messageRecoveryController');

const router = express.Router();

router.use(authMiddleware);
router.use(rateLimiter);

router.get('/status', messageRecoveryController.status);
router.post('/setup', messageRecoveryController.setup);
router.post('/verify', messageRecoveryController.verify);

module.exports = router;
