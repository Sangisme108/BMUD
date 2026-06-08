const rateLimit = require('express-rate-limit');

const recoveryRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message: 'Bạn đã yêu cầu quá nhiều email. Vui lòng thử lại sau một giờ.',
  },
});

module.exports = recoveryRateLimiter;
