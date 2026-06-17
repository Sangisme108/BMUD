const authService = require('../services/authService');
const accountRecoveryService = require('../services/accountRecoveryService');
const deviceManagementService = require('../services/deviceManagementService');
const { getLockedDevicesForUser, unlockDeviceManual } = require('../services/deviceLockoutService');

const parseDevicePayload = (body = {}) => ({
  deviceId:
    body.deviceId ||
    body.device_id ||
    body.deviceFingerprint ||
    body.device_fingerprint,
  deviceName: body.deviceName || body.device_name,
  deviceType: body.deviceType || body.device_type,
  operatingSystem: body.operatingSystem || body.operating_system,
});

const register = async (req, res, next) => {
  try {
    const { full_name, email, password } = req.body;
    if (!full_name || !email || !password) {
      return res.status(400).json({ message: 'Vui lòng nhập đầy đủ thông tin' });
    }
    if (password.length < 8) {
      return res.status(400).json({ message: 'Mật khẩu phải có ít nhất 8 ký tự' });
    }

    const user = await authService.register({ full_name, email, password });
    return res.status(201).json({ message: 'Đăng ký thành công', user });
  } catch (error) {
    return next(error);
  }
};

const sendRegisterOtp = async (req, res, next) => {
  try {
    const fullName = req.body.fullName || req.body.full_name;
    const { email } = req.body;
    const result = await authService.requestRegistrationOtp({
      fullName,
      email,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

const verifyRegisterOtp = async (req, res, next) => {
  try {
    const fullName = req.body.fullName || req.body.full_name;
    const confirmPassword = req.body.confirmPassword || req.body.confirm_password;
    const otp = req.body.otp || req.body.otp_code;
    const { deviceId } = parseDevicePayload(req.body);
    const result = await authService.verifyRegistrationOtp({
      fullName,
      email: req.body.email,
      password: req.body.password,
      confirmPassword,
      otp,
      deviceFingerprint: deviceId,
      req,
    });
    return res.status(201).json(result);
  } catch (error) {
    return next(error);
  }
};

const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const device = parseDevicePayload(req.body);
    if (!email || !password || !device.deviceId) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập email, mật khẩu và thông tin thiết bị',
      });
    }

    const result = await authService.login({
      email,
      password,
      ...device,
      req,
    });
    return res.status(result.statusCode || 200).json(result);
  } catch (error) {
    return next(error);
  }
};

const verifyDeviceOtp = async (req, res, next) => {
  try {
    const otp = req.body.otp || req.body.otp_code;
    const challengeId = req.body.challengeId || req.body.challenge_id;
    const device = parseDevicePayload(req.body);
    if (!challengeId || !otp || !device.deviceId) {
      return res.status(400).json({
        success: false,
        message: 'Thiếu thông tin xác minh OTP thiết bị',
      });
    }
    if (!/^\d{6}$/.test(String(otp))) {
      return res.status(400).json({ message: 'OTP phải gồm 6 chữ số' });
    }

    const result = await authService.verifyDeviceOtp({
      challengeId,
      otp,
      ...device,
      req,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

const verifyOtp = async (req, res, next) => {
  try {
    const { email, otp_code } = req.body;
    const { deviceId } = parseDevicePayload(req.body);
    if (!email || !otp_code || !deviceId) {
      return res.status(400).json({ message: 'Thiếu thông tin xác thực OTP' });
    }
    if (!/^\d{6}$/.test(otp_code)) {
      return res.status(400).json({ message: 'OTP phải gồm 6 chữ số' });
    }

    const result = await authService.verifyOtp({
      email,
      otpCode: otp_code,
      deviceFingerprint: deviceId,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

const refresh = async (req, res, next) => {
  try {
    const { deviceId } = parseDevicePayload(req.body);
    const result = await authService.refresh({
      refreshToken: req.body.refresh_token,
      deviceId,
    });
    return res.json({ success: true, data: result, ...result });
  } catch (error) {
    return next(error);
  }
};

const logout = async (req, res, next) => {
  try {
    const result = await authService.logout({
      refreshToken: req.body.refresh_token,
    });
    return res.json({ success: true, ...result });
  } catch (error) {
    return next(error);
  }
};

const getDevices = async (req, res, next) => {
  try {
    const devices = await deviceManagementService.listDevices(
      req.user.id,
      req.sessionId || null
    );
    return res.json({ success: true, data: devices });
  } catch (error) {
    return next(error);
  }
};

const revokeDevice = async (req, res, next) => {
  try {
    const sessionId = deviceManagementService.resolveDeviceRecordId(
      req.params.deviceRecordId || req.params.id
    );
    req.sessionId = req.sessionId || null;
    const result = await deviceManagementService.revokeDevice({
      userId: req.user.id,
      sessionId,
      req,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

const requestPasswordReset = async (req, res, next) => {
  try {
    if (!req.body.email) {
      return res.status(400).json({ message: 'Vui lòng nhập email' });
    }
    const result = await accountRecoveryService.requestPasswordReset({
      email: req.body.email,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

const resetPassword = async (req, res, next) => {
  try {
    const { email, otp_code, new_password } = req.body;
    if (!email || !otp_code || !new_password) {
      return res.status(400).json({
        message: 'Thiếu email, OTP hoặc mật khẩu mới',
      });
    }
    if (!/^\d{6}$/.test(otp_code)) {
      return res.status(400).json({ message: 'OTP phải gồm 6 chữ số' });
    }
    const result = await accountRecoveryService.resetPassword({
      email,
      otpCode: otp_code,
      newPassword: new_password,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

const requestUnlock = async (req, res, next) => {
  try {
    if (!req.body.email) {
      return res.status(400).json({ message: 'Vui lòng nhập email' });
    }
    const result = await accountRecoveryService.requestUnlock({
      email: req.body.email,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

const unlockAccount = async (req, res, next) => {
  try {
    const { email, otp_code } = req.body;
    if (!email || !otp_code) {
      return res.status(400).json({ message: 'Thiếu email hoặc OTP mở khóa' });
    }
    if (!/^\d{6}$/.test(otp_code)) {
      return res.status(400).json({ message: 'OTP phải gồm 6 chữ số' });
    }
    const result = await accountRecoveryService.unlockAccount({
      email,
      otpCode: otp_code,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

const getLockedDevices = async (req, res, next) => {
  try {
    const lockedDevices = await getLockedDevicesForUser({
      userId: req.user.id,
    });
    return res.json({
      success: true,
      data: lockedDevices,
      message: `Bạn có ${lockedDevices.length} thiết bị bị khóa`,
    });
  } catch (error) {
    return next(error);
  }
};

const unlockDevice = async (req, res, next) => {
  try {
    const { deviceFingerprint } = req.params;
    if (!deviceFingerprint) {
      return res.status(400).json({ message: 'Thiếu device fingerprint' });
    }

    const result = await unlockDeviceManual({
      email: req.user.email,
      deviceFingerprint,
      reason: 'USER_REQUESTED',
    });

    if (!result) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy thiết bị bị khóa này',
      });
    }

    return res.json({
      success: true,
      message: 'Đã mở khóa thiết bị thành công',
    });
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  getDevices,
  getLockedDevices,
  login,
  logout,
  requestPasswordReset,
  requestUnlock,
  refresh,
  register,
  revokeDevice,
  sendRegisterOtp,
  resetPassword,
  unlockAccount,
  unlockDevice,
  verifyDeviceOtp,
  verifyRegisterOtp,
  verifyOtp,
};
