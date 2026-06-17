CREATE DATABASE IF NOT EXISTS abnormal_login_detection
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE abnormal_login_detection;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(180) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  email_verified_at DATETIME NULL,
  message_recovery_code_hash VARCHAR(255) NULL,
  is_locked BOOLEAN NOT NULL DEFAULT FALSE,
  lock_until DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS devices (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  device_fingerprint VARCHAR(64) NOT NULL,
  device_fingerprint_hash VARCHAR(64) NULL,
  ip_address VARCHAR(64) NOT NULL,
  user_agent TEXT,
  device_name VARCHAR(255) NULL,
  device_type VARCHAR(50) NULL,
  operating_system VARCHAR(255) NULL,
  is_trusted BOOLEAN NOT NULL DEFAULT FALSE,
  message_recovery_verified BOOLEAN NOT NULL DEFAULT FALSE,
  message_recovery_verified_at DATETIME NULL,
  last_used_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_at DATETIME NULL,
  revoked_reason VARCHAR(255) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_devices_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_devices_user_fingerprint (user_id, device_fingerprint),
  INDEX idx_devices_user (user_id),
  INDEX idx_devices_message_recovery
    (user_id, device_fingerprint_hash, message_recovery_verified)
);

CREATE TABLE IF NOT EXISTS login_attempts (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  email VARCHAR(180) NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  user_agent TEXT,
  device_fingerprint VARCHAR(64),
  is_successful BOOLEAN NOT NULL DEFAULT FALSE,
  failure_type ENUM('NONE', 'INVALID_CREDENTIALS', 'OTP_REQUIRED', 'RISK_BLOCKED')
    NOT NULL DEFAULT 'NONE',
  is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
  risk_score INT NOT NULL DEFAULT 0,
  risk_level ENUM('LOW', 'MEDIUM', 'HIGH') NOT NULL DEFAULT 'LOW',
  reason TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_login_attempts_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE SET NULL,
  INDEX idx_login_attempts_email_time (email, created_at),
  INDEX idx_login_attempts_ip_time (ip_address, created_at),
  INDEX idx_login_attempts_user_time (user_id, created_at),
  INDEX idx_login_attempts_failure_time (failure_type, created_at),
  INDEX idx_login_attempts_email_ip_time (email, ip_address, created_at)
);

CREATE TABLE IF NOT EXISTS ip_device_lockouts (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(180) NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  device_fingerprint VARCHAR(64) NULL,
  locked_until DATETIME NOT NULL,
  failure_count INT NOT NULL DEFAULT 5,
  unlock_reason VARCHAR(100) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_ip_device_lockouts_email_ip (email, ip_address),
  INDEX idx_ip_device_lockouts_locked_until (locked_until),
  INDEX idx_ip_device_lockouts_email_ip_until (email, ip_address, locked_until)
);

CREATE TABLE IF NOT EXISTS auth_otps (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  email VARCHAR(180) NOT NULL,
  otp_hash VARCHAR(64) NOT NULL,
  device_fingerprint VARCHAR(64) NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  user_agent TEXT,
  risk_score INT NOT NULL,
  risk_level ENUM('MEDIUM', 'HIGH') NOT NULL,
  reason TEXT,
  expires_at DATETIME NOT NULL,
  verified_at DATETIME NULL,
  attempts INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_auth_otps_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_auth_otps_lookup (email, device_fingerprint, created_at)
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  session_id VARCHAR(64) NULL,
  device_id_hash CHAR(64) NULL,
  token_hash VARCHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_refresh_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_refresh_tokens_user (user_id),
  INDEX idx_refresh_tokens_session (session_id)
);

CREATE TABLE IF NOT EXISTS login_sessions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  session_id VARCHAR(64) NOT NULL,
  user_id INT NOT NULL,
  device_id_hash CHAR(64) NOT NULL,
  device_name VARCHAR(255) NULL,
  device_type VARCHAR(50) NULL,
  operating_system VARCHAR(255) NULL,
  ip_address VARCHAR(45) NULL,
  user_agent TEXT NULL,
  refresh_token_hash CHAR(64) NOT NULL,
  is_trusted BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  revoked_reason VARCHAR(255) NULL,
  CONSTRAINT fk_login_sessions_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_login_sessions_session_id (session_id),
  INDEX idx_login_sessions_user_id (user_id),
  INDEX idx_login_sessions_device (user_id, device_id_hash),
  INDEX idx_login_sessions_active (user_id, is_active)
);

CREATE TABLE IF NOT EXISTS account_action_tokens (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token_hash VARCHAR(64) NOT NULL UNIQUE,
  action_type ENUM('UNLOCK_ACCOUNT', 'RESET_PASSWORD') NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  attempts INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_account_action_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_account_action_lookup (action_type, token_hash, expires_at),
  INDEX idx_account_action_user (user_id, action_type)
);

-- Legacy table retained so existing history/dashboard code remains compatible.
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

CREATE TABLE IF NOT EXISTS friendships (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_low_id INT NOT NULL,
  user_high_id INT NOT NULL,
  requested_by INT NOT NULL,
  status ENUM('PENDING', 'ACCEPTED', 'REJECTED') NOT NULL DEFAULT 'PENDING',
  accepted_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_friendships_low_user
    FOREIGN KEY (user_low_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_friendships_high_user
    FOREIGN KEY (user_high_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_friendships_requester
    FOREIGN KEY (requested_by) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_friendships_pair (user_low_id, user_high_id),
  INDEX idx_friendships_low_status (user_low_id, status),
  INDEX idx_friendships_high_status (user_high_id, status)
);

CREATE TABLE IF NOT EXISTS messages (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  sender_id INT NOT NULL,
  receiver_id INT NOT NULL,
  content VARCHAR(2000) NOT NULL,
  read_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_messages_sender
    FOREIGN KEY (sender_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_messages_receiver
    FOREIGN KEY (receiver_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_messages_pair_time (sender_id, receiver_id, id),
  INDEX idx_messages_receiver_read (receiver_id, read_at, id)
);

CREATE TABLE IF NOT EXISTS email_otps (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(180) NOT NULL,
  otp_hash VARCHAR(64) NOT NULL,
  purpose ENUM('REGISTER', 'NEW_DEVICE_LOGIN', 'PASSWORD_RESET') NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  attempt_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email_otps_lookup (email, purpose, created_at),
  INDEX idx_email_otps_expiry (expires_at)
);

CREATE TABLE IF NOT EXISTS message_recovery_attempts (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  device_fingerprint_hash VARCHAR(64) NOT NULL,
  is_successful BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_message_recovery_attempts_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_message_recovery_user_time (user_id, created_at),
  INDEX idx_message_recovery_device_time (device_fingerprint_hash, created_at),
  INDEX idx_message_recovery_ip_time (ip_address, created_at)
);

CREATE TABLE IF NOT EXISTS security_events (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  event_type VARCHAR(80) NOT NULL,
  title VARCHAR(180) NOT NULL,
  description TEXT NULL,
  ip_address VARCHAR(64) NULL,
  user_agent TEXT NULL,
  device_fingerprint_hash VARCHAR(64) NULL,
  risk_level ENUM('LOW', 'MEDIUM', 'HIGH') NOT NULL DEFAULT 'LOW',
  metadata JSON NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_security_events_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_security_events_user_time (user_id, created_at),
  INDEX idx_security_events_type_time (event_type, created_at),
  INDEX idx_security_events_risk_time (risk_level, created_at)
);
