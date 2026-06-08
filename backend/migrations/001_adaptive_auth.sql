ALTER TABLE users
  ADD COLUMN is_locked BOOLEAN NOT NULL DEFAULT FALSE AFTER password_hash,
  ADD COLUMN lock_until DATETIME NULL AFTER is_locked;

CREATE TABLE devices (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  device_fingerprint VARCHAR(64) NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  user_agent TEXT,
  is_trusted BOOLEAN NOT NULL DEFAULT FALSE,
  last_used_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_devices_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_devices_user_fingerprint (user_id, device_fingerprint),
  INDEX idx_devices_user (user_id)
);

CREATE TABLE login_attempts (
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
  INDEX idx_login_attempts_failure_time (failure_type, created_at)
);

CREATE TABLE auth_otps (
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

CREATE TABLE refresh_tokens (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token_hash VARCHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_refresh_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_refresh_tokens_user (user_id)
);
