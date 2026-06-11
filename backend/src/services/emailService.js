const createTransporter = require('../config/mailer');

const escapeHtml = (value) =>
  String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');

const sendLoginAlertEmail = async ({
  user,
  ipAddress,
  deviceName,
  riskLevel,
  reason,
  loginTime,
}) => {
  const transporter = createTransporter();
  if (!transporter) {
    console.warn('Email chưa được cấu hình, bỏ qua cảnh báo đăng nhập.');
    return false;
  }

  await transporter.sendMail({
    from: process.env.EMAIL_USER,
    to: user.email,
    subject: 'Cảnh báo đăng nhập bất thường',
    html: `
      <p>Xin chào ${escapeHtml(user.full_name)},</p>
      <p>Hệ thống vừa chặn hoặc phát hiện một lần đăng nhập bất thường.</p>
      <ul>
        <li>Thời gian: ${escapeHtml(loginTime)}</li>
        <li>IP: ${escapeHtml(ipAddress)}</li>
        <li>Thiết bị: ${escapeHtml(deviceName || 'Không xác định')}</li>
        <li>Mức rủi ro: ${escapeHtml(riskLevel)}</li>
        <li>Lý do: ${escapeHtml(reason)}</li>
      </ul>
      <p>Nếu đây không phải bạn, hãy đổi mật khẩu ngay.</p>
    `,
  });
  return true;
};

const sendOtpEmail = async ({
  user,
  otpCode,
  riskLevel,
  reason,
  expiresInMinutes,
}) => {
  const transporter = createTransporter();
  if (!transporter) {
    console.warn(`[DEV OTP] ${user.email}: ${otpCode}`);
    return false;
  }

  await transporter.sendMail({
    from: process.env.EMAIL_USER,
    to: user.email,
    subject: 'Mã OTP xác thực thiết bị đăng nhập',
    html: `
      <p>Xin chào ${escapeHtml(user.full_name)},</p>
      <p>Mã xác thực thiết bị của bạn là:</p>
      <p style="font-size: 28px; font-weight: bold; letter-spacing: 6px">
        ${escapeHtml(otpCode)}
      </p>
      <p>Mã có hiệu lực trong ${escapeHtml(expiresInMinutes)} phút.</p>
      <p>Mức rủi ro: ${escapeHtml(riskLevel)}</p>
      <p>Lý do: ${escapeHtml(reason)}</p>
    `,
  });
  return true;
};

const sendRecoveryOtpEmail = async ({
  user,
  subject,
  description,
  otpCode,
  expiresInMinutes,
}) => {
  const transporter = createTransporter();
  if (!transporter) {
    const error = new Error('Email chưa được cấu hình');
    error.statusCode = 503;
    throw error;
  }

  await transporter.sendMail({
    from: process.env.EMAIL_USER,
    to: user.email,
    subject,
    html: `
      <p>Xin chào ${escapeHtml(user.full_name)},</p>
      <p>${escapeHtml(description)}</p>
      <p style="font-size: 28px; font-weight: bold; letter-spacing: 6px">
        ${escapeHtml(otpCode)}
      </p>
      <p>Mã có hiệu lực trong ${escapeHtml(expiresInMinutes)} phút và chỉ dùng được một lần.</p>
      <p>Nếu bạn không yêu cầu thao tác này, hãy bỏ qua email.</p>
    `,
    text: `${description}\n\nMã OTP: ${otpCode}\n\nMã có hiệu lực trong ${expiresInMinutes} phút và chỉ dùng được một lần.`,
  });
};

const sendPasswordResetOtpEmail = (params) =>
  sendRecoveryOtpEmail({
    ...params,
    subject: 'BMUD - Mã OTP đặt lại mật khẩu',
    description: 'Dùng mã OTP sau để đặt lại mật khẩu tài khoản BMUD.',
  });

const sendUnlockAccountOtpEmail = (params) =>
  sendRecoveryOtpEmail({
    ...params,
    subject: 'BMUD - Mã OTP mở khóa tài khoản',
    description: 'Dùng mã OTP sau để mở khóa tài khoản BMUD.',
  });

module.exports = {
  sendLoginAlertEmail,
  sendOtpEmail,
  sendPasswordResetOtpEmail,
  sendUnlockAccountOtpEmail,
};
