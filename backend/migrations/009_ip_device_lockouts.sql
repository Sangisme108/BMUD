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

CREATE INDEX idx_login_attempts_email_ip_time
  ON login_attempts (email, ip_address, created_at);
