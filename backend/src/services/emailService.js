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

const sendAccountActionEmail = async ({
  user,
  subject,
  heading,
  description,
  buttonLabel,
  actionLink,
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
      <p>
        <a href="${escapeHtml(actionLink)}"
           style="display:inline-block;padding:12px 18px;background:#0f766e;color:white;text-decoration:none;border-radius:6px">
          ${escapeHtml(buttonLabel)}
        </a>
      </p>
      <p>Liên kết có hiệu lực trong ${escapeHtml(expiresInMinutes)} phút và chỉ dùng được một lần.</p>
      <p>Nếu nút không mở ứng dụng, hãy sao chép liên kết này:</p>
      <p style="word-break:break-all">${escapeHtml(actionLink)}</p>
      <p>Nếu bạn không yêu cầu thao tác này, hãy bỏ qua email.</p>
    `,
    text: `${heading}\n\n${description}\n\n${actionLink}\n\nLiên kết có hiệu lực trong ${expiresInMinutes} phút và chỉ dùng được một lần.`,
  });
};

const sendPasswordResetEmail = (params) =>
  sendAccountActionEmail({
    ...params,
    subject: 'BMUD - Đặt lại mật khẩu',
    heading: 'Đặt lại mật khẩu',
    description: 'Bạn vừa yêu cầu đặt lại mật khẩu cho tài khoản BMUD.',
    buttonLabel: 'Đặt lại mật khẩu',
  });

const sendUnlockAccountEmail = (params) =>
  sendAccountActionEmail({
    ...params,
    subject: 'BMUD - Mở khóa tài khoản',
    heading: 'Mở khóa tài khoản',
    description: 'Bạn vừa yêu cầu mở khóa tài khoản BMUD.',
    buttonLabel: 'Mở khóa tài khoản',
  });

module.exports = {
  sendLoginAlertEmail,
  sendOtpEmail,
  sendPasswordResetEmail,
  sendUnlockAccountEmail,
};
