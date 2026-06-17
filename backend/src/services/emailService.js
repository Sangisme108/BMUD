const createTransporter = require('../config/mailer');

const escapeHtml = (value) =>
  String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');

const readTimeout = (name, fallback) => {
  const value = Number.parseInt(process.env[name] || '', 10);
  return Number.isFinite(value) && value > 0 ? value : fallback;
};

const getEmailFrom = () =>
  process.env.MAIL_FROM?.trim() ||
  process.env.EMAIL_FROM?.trim() ||
  process.env.SMTP_USER?.trim() ||
  process.env.EMAIL_USER?.trim();

const sendSmtpWithTimeout = async (transporter, mailOptions) => {
  const timeoutMs = readTimeout('EMAIL_SEND_TIMEOUT_MS', 30000);
  let timeoutId;
  const timeout = new Promise((_, reject) => {
    timeoutId = setTimeout(() => {
      const error = new Error('Gui email qua lau. Vui long thu lai sau.');
      error.statusCode = 503;
      error.code = 'EMAIL_SEND_TIMEOUT';
      reject(error);
    }, timeoutMs);
  });

  try {
    return await Promise.race([transporter.sendMail(mailOptions), timeout]);
  } finally {
    clearTimeout(timeoutId);
  }
};

const sendResendWithTimeout = async (mailOptions) => {
  const apiKey = process.env.RESEND_API_KEY?.trim();
  if (!apiKey) return false;
  if (typeof fetch !== 'function') {
    const error = new Error('Node runtime khong ho tro fetch de gui Resend API');
    error.statusCode = 500;
    throw error;
  }

  const timeoutMs = readTimeout('EMAIL_SEND_TIMEOUT_MS', 30000);
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      signal: controller.signal,
      body: JSON.stringify({
        from: getEmailFrom(),
        to: [mailOptions.to],
        subject: mailOptions.subject,
        html: mailOptions.html,
        text: mailOptions.text,
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      const error = new Error(`Resend gui email that bai: ${body}`);
      error.statusCode = response.status;
      throw error;
    }
    return true;
  } catch (error) {
    if (error.name === 'AbortError') {
      const timeoutError = new Error('Gui email qua Resend qua lau.');
      timeoutError.statusCode = 503;
      timeoutError.code = 'EMAIL_SEND_TIMEOUT';
      throw timeoutError;
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
  }
};

const sendConfiguredMail = async (
  mailOptions,
  { throwWhenMissing = false } = {}
) => {
  if (process.env.RESEND_API_KEY?.trim()) {
    return sendResendWithTimeout(mailOptions);
  }

  const transporter = createTransporter();
  if (!transporter) {
    if (throwWhenMissing) {
      const error = new Error('Email chua duoc cau hinh');
      error.statusCode = 503;
      throw error;
    }
    return false;
  }

  await sendSmtpWithTimeout(transporter, {
    ...mailOptions,
    from: getEmailFrom(),
  });
  return true;
};

const sendLoginAlertEmail = async ({
  user,
  ipAddress,
  deviceName,
  riskLevel,
  reason,
  loginTime,
}) => {
  const sent = await sendConfiguredMail({
    to: user.email,
    subject: 'Canh bao dang nhap bat thuong',
    html: `
      <p>Xin chao ${escapeHtml(user.full_name)},</p>
      <p>He thong vua chan hoac phat hien mot lan dang nhap bat thuong.</p>
      <ul>
        <li>Thoi gian: ${escapeHtml(loginTime)}</li>
        <li>IP: ${escapeHtml(ipAddress)}</li>
        <li>Thiet bi: ${escapeHtml(deviceName || 'Khong xac dinh')}</li>
        <li>Muc rui ro: ${escapeHtml(riskLevel)}</li>
        <li>Ly do: ${escapeHtml(reason)}</li>
      </ul>
      <p>Neu day khong phai ban, hay doi mat khau ngay.</p>
    `,
  });
  if (!sent) {
    console.warn('Email chua duoc cau hinh, bo qua canh bao dang nhap.');
    return false;
  }
  return true;
};

const sendOtpEmail = async ({
  user,
  otpCode,
  riskLevel,
  reason,
  expiresInMinutes,
}) => {
  const sent = await sendConfiguredMail({
    to: user.email,
    subject: 'Ma OTP xac thuc thiet bi dang nhap',
    html: `
      <p>Xin chao ${escapeHtml(user.full_name)},</p>
      <p>Ma xac thuc thiet bi cua ban la:</p>
      <p style="font-size: 28px; font-weight: bold; letter-spacing: 6px">
        ${escapeHtml(otpCode)}
      </p>
      <p>Ma co hieu luc trong ${escapeHtml(expiresInMinutes)} phut.</p>
      <p>Muc rui ro: ${escapeHtml(riskLevel)}</p>
      <p>Ly do: ${escapeHtml(reason)}</p>
    `,
    text: `Ma OTP xac thuc thiet bi: ${otpCode}`,
  });
  if (!sent) {
    console.warn(`[DEV OTP] ${user.email}: ${otpCode}`);
    return false;
  }
  return true;
};

const sendRegistrationOtpEmail = async ({
  fullName,
  email,
  otpCode,
  expiresInMinutes,
}) => {
  await sendConfiguredMail(
    {
      to: email,
      subject: 'Xac minh email dang ky tai khoan',
      html: `
        <p>Xin chao ${escapeHtml(fullName || email)},</p>
        <p>Ma OTP xac minh email dang ky tai khoan cua ban la:</p>
        <p style="font-size: 28px; font-weight: bold; letter-spacing: 6px">
          ${escapeHtml(otpCode)}
        </p>
        <p>Ma co hieu luc trong ${escapeHtml(expiresInMinutes)} phut.</p>
        <p>Khong chia se ma OTP nay cho bat ky ai.</p>
        <p>Neu ban khong thuc hien dang ky, hay bo qua email nay.</p>
      `,
      text:
        `Ma OTP xac minh email dang ky tai khoan: ${otpCode}\n\n` +
        `Ma co hieu luc trong ${expiresInMinutes} phut. Khong chia se ma OTP nay.`,
    },
    { throwWhenMissing: true }
  );
  return true;
};

const sendRecoveryOtpEmail = async ({
  user,
  subject,
  description,
  otpCode,
  expiresInMinutes,
}) => {
  await sendConfiguredMail(
    {
      to: user.email,
      subject,
      html: `
        <p>Xin chao ${escapeHtml(user.full_name)},</p>
        <p>${escapeHtml(description)}</p>
        <p style="font-size: 28px; font-weight: bold; letter-spacing: 6px">
          ${escapeHtml(otpCode)}
        </p>
        <p>Ma co hieu luc trong ${escapeHtml(expiresInMinutes)} phut va chi dung duoc mot lan.</p>
        <p>Neu ban khong yeu cau thao tac nay, hay bo qua email.</p>
      `,
      text: `${description}\n\nMa OTP: ${otpCode}\n\nMa co hieu luc trong ${expiresInMinutes} phut va chi dung duoc mot lan.`,
    },
    { throwWhenMissing: true }
  );
};

const sendPasswordResetOtpEmail = (params) =>
  sendRecoveryOtpEmail({
    ...params,
    subject: 'BMUD - Ma OTP dat lai mat khau',
    description: 'Dung ma OTP sau de dat lai mat khau tai khoan BMUD.',
  });

const sendUnlockAccountOtpEmail = (params) =>
  sendRecoveryOtpEmail({
    ...params,
    subject: 'BMUD - Ma OTP mo khoa tai khoan',
    description: 'Dung ma OTP sau de mo khoa tai khoan BMUD.',
  });

module.exports = {
  sendLoginAlertEmail,
  sendOtpEmail,
  sendRegistrationOtpEmail,
  sendPasswordResetOtpEmail,
  sendUnlockAccountOtpEmail,
};
