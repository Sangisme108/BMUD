const pool = require('../config/db');
const deviceManagementService = require('../services/deviceManagementService');

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

    const [events] = await pool.query(
      `SELECT id, event_type, title, description, ip_address, user_agent,
              risk_level, created_at
       FROM security_events
       WHERE user_id = ?
       ORDER BY created_at DESC
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
      events,
    });
  } catch (error) {
    next(error);
  }
};

const getSecurityEvents = async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT id, event_type, title, description, ip_address, user_agent,
              risk_level, metadata, created_at
       FROM security_events
       WHERE user_id = ?
       ORDER BY created_at DESC
       LIMIT 100`,
      [req.user.id]
    );
    res.json({ data: rows });
  } catch (error) {
    next(error);
  }
};

const getDevices = async (req, res, next) => {
  try {
    const devices = await deviceManagementService.listDevices(req.user.id);
    res.json({ data: devices });
  } catch (error) {
    next(error);
  }
};

const revokeDevice = async (req, res, next) => {
  try {
    const result = await deviceManagementService.revokeDevice({
      userId: req.user.id,
      deviceId: Number(req.params.id),
      req,
    });
    res.json(result);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getDashboard,
  getDevices,
  getLoginHistory,
  getSecurityEvents,
  revokeDevice,
};
