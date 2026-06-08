const authService = require('../services/authService');

const bruteForceMiddleware = async (req, res, next) => {
  try {
    if (req.body?.email) {
      await authService.assertLoginAllowed({
        email: req.body.email,
        ipAddress: req.ip || req.socket.remoteAddress || 'unknown',
      });
    }
    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = bruteForceMiddleware;
