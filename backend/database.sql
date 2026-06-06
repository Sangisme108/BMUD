CREATE DATABASE IF NOT EXISTS abnormal_login_detection
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE abnormal_login_detection;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(180) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS login_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  user_agent TEXT,
  device_name VARCHAR(120),
  login_status ENUM('SUCCESS', 'FAILED') NOT NULL,
  risk_level ENUM('LOW', 'MEDIUM', 'HIGH') NOT NULL DEFAULT 'LOW',
  reason TEXT,
  login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_login_history_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_login_history_user_time (user_id, login_time),
  INDEX idx_login_history_risk (risk_level)
);

CREATE TABLE IF NOT EXISTS failed_login_attempts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(180) NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  attempt_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_failed_email_time (email, attempt_time),
  INDEX idx_failed_ip_time (ip_address, attempt_time)
);

CREATE TABLE IF NOT EXISTS trusted_devices (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  device_fingerprint VARCHAR(64) NOT NULL,
  device_name VARCHAR(120) NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_trusted_devices_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_user_device_fingerprint (user_id, device_fingerprint),
  INDEX idx_trusted_devices_user (user_id)
);
