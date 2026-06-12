const isProduction = () => process.env.NODE_ENV === 'production';

const isHttpsRequest = (req) => {
  const forwardedProto = req.get('x-forwarded-proto');
  if (forwardedProto) {
    return forwardedProto.split(',')[0].trim() === 'https';
  }
  return req.secure;
};

const requireHttpsInProduction = (req, res, next) => {
  if (!isProduction() || isHttpsRequest(req)) {
    return next();
  }

  return res.status(426).json({
    message: 'HTTPS is required in production',
  });
};

const secureHeaders = (req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('X-DNS-Prefetch-Control', 'off');
  res.setHeader(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=(), payment=()'
  );
  res.setHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");

  if (isProduction() && isHttpsRequest(req)) {
    res.setHeader(
      'Strict-Transport-Security',
      'max-age=31536000; includeSubDomains'
    );
  }

  next();
};

module.exports = {
  requireHttpsInProduction,
  secureHeaders,
};
