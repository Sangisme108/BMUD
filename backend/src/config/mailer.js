const nodemailer = require('nodemailer');
require('dotenv').config();

const readTimeout = (name, fallback) => {
  const value = Number.parseInt(process.env[name] || '', 10);
  return Number.isFinite(value) && value > 0 ? value : fallback;
};

const createTransporter = () => {
  const smtpHost = process.env.SMTP_HOST?.trim();
  const smtpPort = Number.parseInt(process.env.SMTP_PORT || '', 10);
  const smtpUser = process.env.SMTP_USER?.trim();
  const smtpPass = process.env.SMTP_PASS?.trim();
  if (smtpHost && smtpUser && smtpPass) {
    return nodemailer.createTransport({
      host: smtpHost,
      port: Number.isFinite(smtpPort) ? smtpPort : 587,
      secure: Number.isFinite(smtpPort) ? smtpPort === 465 : false,
      connectionTimeout: readTimeout('EMAIL_CONNECTION_TIMEOUT_MS', 30000),
      greetingTimeout: readTimeout('EMAIL_GREETING_TIMEOUT_MS', 30000),
      socketTimeout: readTimeout('EMAIL_SOCKET_TIMEOUT_MS', 30000),
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    });
  }

  const emailUser = process.env.EMAIL_USER?.trim();
  const emailPass = process.env.EMAIL_PASS?.trim();
  if (
    !emailUser ||
    !emailPass ||
    emailUser.startsWith('your_') ||
    emailPass.startsWith('your_')
  ) {
    return null;
  }

  return nodemailer.createTransport({
    service: 'gmail',
    connectionTimeout: readTimeout('EMAIL_CONNECTION_TIMEOUT_MS', 30000),
    greetingTimeout: readTimeout('EMAIL_GREETING_TIMEOUT_MS', 30000),
    socketTimeout: readTimeout('EMAIL_SOCKET_TIMEOUT_MS', 30000),
    auth: {
      user: emailUser,
      pass: emailPass,
    },
  });
};

module.exports = createTransporter;
