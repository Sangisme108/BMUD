const nodemailer = require('nodemailer');
require('dotenv').config();

const readTimeout = (name, fallback) => {
  const value = Number.parseInt(process.env[name] || '', 10);
  return Number.isFinite(value) && value > 0 ? value : fallback;
};

const createTransporter = () => {
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
    connectionTimeout: readTimeout('EMAIL_CONNECTION_TIMEOUT_MS', 8000),
    greetingTimeout: readTimeout('EMAIL_GREETING_TIMEOUT_MS', 8000),
    socketTimeout: readTimeout('EMAIL_SOCKET_TIMEOUT_MS', 10000),
    auth: {
      user: emailUser,
      pass: emailPass,
    },
  });
};

module.exports = createTransporter;
