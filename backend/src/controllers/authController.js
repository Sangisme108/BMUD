const authService = require('../services/authService');
const accountRecoveryService = require('../services/accountRecoveryService');

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

const login = async (req, res, next) => {
  try {
    const { email, password, device_fingerprint } = req.body;
    if (!email || !password || !device_fingerprint) {
      return res.status(400).json({
        message: 'Vui lòng nhập email, mật khẩu và thông tin thiết bị',
      });
    }
    if (!/^[a-f0-9]{64}$/i.test(device_fingerprint)) {
      return res.status(400).json({ message: 'Device fingerprint không hợp lệ' });
    }

    const result = await authService.login({
      email,
      password,
      deviceFingerprint: device_fingerprint,
      req,
    });
    return res.status(result.statusCode || 200).json(result);
  } catch (error) {
    return next(error);
  }
};

const verifyOtp = async (req, res, next) => {
  try {
    const { email, otp_code, device_fingerprint } = req.body;
    if (!email || !otp_code || !device_fingerprint) {
      return res.status(400).json({ message: 'Thiếu thông tin xác thực OTP' });
    }
    if (!/^\d{6}$/.test(otp_code)) {
      return res.status(400).json({ message: 'OTP phải gồm 6 chữ số' });
    }

    const result = await authService.verifyOtp({
      email,
      otpCode: otp_code,
      deviceFingerprint: device_fingerprint,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

const refresh = async (req, res, next) => {
  try {
    const result = await authService.refresh({
      refreshToken: req.body.refresh_token,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

const logout = async (req, res, next) => {
  try {
    const result = await authService.logout({
      refreshToken: req.body.refresh_token,
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
    const { token, new_password } = req.body;
    if (!token || !new_password) {
      return res.status(400).json({ message: 'Thiếu token hoặc mật khẩu mới' });
    }
    const result = await accountRecoveryService.resetPassword({
      token,
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
    if (!req.body.token) {
      return res.status(400).json({ message: 'Thiếu token mở khóa' });
    }
    const result = await accountRecoveryService.unlockAccount({
      token: req.body.token,
    });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  login,
  logout,
  requestPasswordReset,
  requestUnlock,
  refresh,
  register,
  resetPassword,
  unlockAccount,
  verifyOtp,
};
