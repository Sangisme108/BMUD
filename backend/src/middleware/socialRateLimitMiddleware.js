const rateLimit = require('express-rate-limit');

const userKey = (req) => String(req.user.id);

const socialRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 180,
  keyGenerator: userKey,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message: 'Quá nhiều yêu cầu, vui lòng thử lại sau',
  },
});

const socialWriteRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  keyGenerator: userKey,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message: 'Bạn thao tác quá nhanh, vui lòng thử lại sau',
  },
});

module.exports = {
  socialRateLimiter,
  socialWriteRateLimiter,
};
