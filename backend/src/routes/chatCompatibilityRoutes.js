const express = require('express');
const authMiddleware = require('../middleware/authMiddleware');
const requireMessageRecovery = require('../middleware/messageRecoveryMiddleware');
const {
  socialRateLimiter,
  socialWriteRateLimiter,
} = require('../middleware/socialRateLimitMiddleware');
const socialController = require('../controllers/socialController');

const router = express.Router();

router.use(authMiddleware);
router.use(socialRateLimiter);

router.get(
  '/conversations',
  requireMessageRecovery,
  socialController.getConversations
);
router.get(
  '/messages/:friendId',
  requireMessageRecovery,
  socialController.getMessages
);
router.post(
  '/messages/:friendId',
  socialWriteRateLimiter,
  requireMessageRecovery,
  socialController.sendMessage
);

module.exports = router;
