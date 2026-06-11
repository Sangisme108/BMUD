const fs = require('fs');

const isEnabled = (value) =>
  ['1', 'true', 'yes', 'on'].includes(String(value || '').toLowerCase());

const getDatabaseOptions = (overrides = {}) => {
  const sslEnabled = isEnabled(process.env.DB_SSL);
  const sslCaPath = process.env.DB_SSL_CA_PATH?.trim();

  return {
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'abnormal_login_detection',
    ...(sslEnabled && {
      ssl: {
        minVersion: 'TLSv1.2',
        rejectUnauthorized: true,
        ...(sslCaPath && { ca: fs.readFileSync(sslCaPath, 'utf8') }),
      },
    }),
    ...overrides,
  };
};

module.exports = getDatabaseOptions;
