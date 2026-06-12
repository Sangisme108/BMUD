const express = require('express');
const authMiddleware = require('../middleware/authMiddleware');
const {
  socialRateLimiter,
  socialWriteRateLimiter,
} = require('../middleware/socialRateLimitMiddleware');
const socialController = require('../controllers/socialController');

const router = express.Router();

router.use(authMiddleware);
router.use(socialRateLimiter);
router.get('/users', socialController.searchUsers);
router.get('/friends', socialController.getFriends);
router.get('/friend-requests', socialController.getFriendRequests);
router.post(
  '/friend-requests',
  socialWriteRateLimiter,
  socialController.sendFriendRequest
);
router.post(
  '/friend-requests/:id/respond',
  socialWriteRateLimiter,
  socialController.respondToFriendRequest
);
router.get('/conversations', socialController.getConversations);
router.get('/messages/:friendId', socialController.getMessages);
router.post(
  '/messages/:friendId',
  socialWriteRateLimiter,
  socialController.sendMessage
);

module.exports = router;
