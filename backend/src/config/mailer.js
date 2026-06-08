const nodemailer = require('nodemailer');
require('dotenv').config();

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
    auth: {
      user: emailUser,
      pass: emailPass,
    },
  });
};

module.exports = createTransporter;
