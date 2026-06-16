ALTER TABLE users
  ADD COLUMN message_recovery_code_hash VARCHAR(255) NULL AFTER password_hash;

ALTER TABLE devices
  ADD COLUMN device_fingerprint_hash VARCHAR(64) NULL AFTER device_fingerprint,
  ADD COLUMN message_recovery_verified BOOLEAN NOT NULL DEFAULT FALSE AFTER is_trusted,
  ADD COLUMN message_recovery_verified_at DATETIME NULL AFTER message_recovery_verified;

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

CREATE INDEX idx_devices_message_recovery
  ON devices (user_id, device_fingerprint_hash, message_recovery_verified);
