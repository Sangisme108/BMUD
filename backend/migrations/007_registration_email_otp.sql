ALTER TABLE users
  ADD COLUMN email_verified_at DATETIME NULL AFTER password_hash;

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
