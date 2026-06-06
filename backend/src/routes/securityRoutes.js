const express = require('express');
const authMiddleware = require('../middleware/authMiddleware');
const securityController = require('../controllers/securityController');

const router = express.Router();

router.get('/login-history', authMiddleware, securityController.getLoginHistory);
router.get('/dashboard', authMiddleware, securityController.getDashboard);

module.exports = router;
