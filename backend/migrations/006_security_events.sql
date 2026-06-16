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
