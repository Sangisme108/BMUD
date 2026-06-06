const authService = require('../services/authService');

const register = async (req, res, next) => {
  try {
    const { full_name, email, password } = req.body;

    if (!full_name || !email || !password) {
      return res.status(400).json({ message: 'Vui lòng nhập đầy đủ thông tin' });
    }

    if (password.length < 6) {
      return res.status(400).json({ message: 'Mật khẩu phải có ít nhất 6 ký tự' });
    }

    const user = await authService.register({ full_name, email, password });
    return res.status(201).json({ message: 'Đăng ký thành công', user });
  } catch (error) {
    next(error);
  }
};

const login = async (req, res, next) => {
  try {
    const { email, password, device_name } = req.body;

    if (!email || !password || !device_name) {
      return res.status(400).json({ message: 'Vui lòng nhập email, mật khẩu và tên thiết bị' });
    }

    const result = await authService.login({
      email,
      password,
      deviceName: device_name,
      req,
    });

    return res.json(result);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
};
