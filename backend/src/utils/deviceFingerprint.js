const crypto = require('crypto');

const createDeviceFingerprint = (userAgent = '', deviceName = '') => {
  return crypto
    .createHash('sha256')
    .update(`${userAgent}|${deviceName}`.toLowerCase().trim())
    .digest('hex');
};

module.exports = createDeviceFingerprint;
