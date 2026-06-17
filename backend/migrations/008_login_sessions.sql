ALTER TABLE devices
  ADD COLUMN device_name VARCHAR(255) NULL AFTER user_agent;

ALTER TABLE devices
  ADD COLUMN device_type VARCHAR(50) NULL AFTER device_name;

ALTER TABLE devices
  ADD COLUMN operating_system VARCHAR(255) NULL AFTER device_type;

ALTER TABLE devices
  ADD COLUMN revoked_at DATETIME NULL AFTER last_used_at;

ALTER TABLE devices
  ADD COLUMN revoked_reason VARCHAR(255) NULL AFTER revoked_at;

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

ALTER TABLE refresh_tokens
  ADD COLUMN session_id VARCHAR(64) NULL AFTER user_id;

ALTER TABLE refresh_tokens
  ADD COLUMN device_id_hash CHAR(64) NULL AFTER session_id;

CREATE INDEX idx_refresh_tokens_session ON refresh_tokens (session_id);

ALTER TABLE email_otps
  ADD COLUMN challenge_id VARCHAR(64) NULL AFTER id;

ALTER TABLE email_otps
  ADD COLUMN user_id INT NULL AFTER email;

ALTER TABLE email_otps
  ADD COLUMN device_id_hash CHAR(64) NULL AFTER user_id;

ALTER TABLE email_otps
  ADD COLUMN ip_address VARCHAR(45) NULL AFTER device_id_hash;

ALTER TABLE email_otps
  ADD COLUMN user_agent TEXT NULL AFTER ip_address;

ALTER TABLE email_otps
  ADD COLUMN device_name VARCHAR(255) NULL AFTER user_agent;

ALTER TABLE email_otps
  ADD COLUMN device_type VARCHAR(50) NULL AFTER device_name;

ALTER TABLE email_otps
  ADD COLUMN operating_system VARCHAR(255) NULL AFTER device_type;

CREATE UNIQUE INDEX idx_email_otps_challenge ON email_otps (challenge_id);
