const createTransporter = require('../config/mailer');

const sendLoginAlertEmail = async ({ user, ipAddress, deviceName, riskLevel, reason, loginTime }) => {
  const transporter = createTransporter();

  if (!transporter) {
    console.warn('EMAIL_USER hoặc EMAIL_PASS chưa được cấu hình, bỏ qua gửi email cảnh báo.');
    return;
  }

  const html = `
    <p>Xin chào ${user.full_name},</p>
    <p>Hệ thống phát hiện một lần đăng nhập có dấu hiệu bất thường vào tài khoản của bạn.</p>
    <p><strong>Thông tin:</strong></p>
    <ul>
      <li>Thời gian: ${loginTime}</li>
      <li>Địa chỉ IP: ${ipAddress}</li>
      <li>Thiết bị: ${deviceName || 'Không xác định'}</li>
      <li>Mức độ rủi ro: ${riskLevel}</li>
      <li>Lý do: ${reason}</li>
    </ul>
    <p>Nếu đây không phải bạn, vui lòng đổi mật khẩu ngay.</p>
  `;

  await transporter.sendMail({
    from: process.env.EMAIL_USER,
    to: user.email,
    subject: 'Cảnh báo đăng nhập bất thường',
    html,
  });
};

module.exports = {
  sendLoginAlertEmail,
};
