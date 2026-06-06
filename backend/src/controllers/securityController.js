const pool = require('../config/db');

const getLoginHistory = async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT id, ip_address, user_agent, device_name, login_status,
              risk_level, reason, login_time
       FROM login_history
       WHERE user_id = ?
       ORDER BY login_time DESC`,
      [req.user.id]
    );

    res.json({ data: rows });
  } catch (error) {
    next(error);
  }
};

const getDashboard = async (req, res, next) => {
  try {
    const [[summary]] = await pool.query(
      `SELECT
        COUNT(*) AS total_logins,
        SUM(risk_level = 'LOW') AS low_count,
        SUM(risk_level = 'MEDIUM') AS medium_count,
        SUM(risk_level = 'HIGH') AS high_count
       FROM login_history
       WHERE user_id = ? AND login_status = 'SUCCESS'`,
      [req.user.id]
    );

    const [[lastLogin]] = await pool.query(
      `SELECT id, ip_address, device_name, risk_level, reason, login_time
       FROM login_history
       WHERE user_id = ?
       ORDER BY login_time DESC
       LIMIT 1`,
      [req.user.id]
    );

    const [alerts] = await pool.query(
      `SELECT id, ip_address, device_name, risk_level, reason, login_time
       FROM login_history
       WHERE user_id = ? AND risk_level IN ('MEDIUM', 'HIGH')
       ORDER BY login_time DESC
       LIMIT 10`,
      [req.user.id]
    );

    res.json({
      total_logins: Number(summary.total_logins || 0),
      low_count: Number(summary.low_count || 0),
      medium_count: Number(summary.medium_count || 0),
      high_count: Number(summary.high_count || 0),
      last_login: lastLogin || null,
      alerts,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getLoginHistory,
  getDashboard,
};
