-- Migration: Device-level account lockouts
-- Purpose: Lock specific device only, not entire account
-- Replaces: Global is_locked on users table for authentication

CREATE TABLE IF NOT EXISTS device_lockouts (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  email VARCHAR(180) NOT NULL,
  device_fingerprint VARCHAR(64) NOT NULL,
  device_name VARCHAR(255),
  ip_address VARCHAR(64),
  user_agent TEXT,
  locked_until DATETIME NOT NULL,
  failure_count INT NOT NULL DEFAULT 5,
  reason VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  UNIQUE KEY uq_device_lockouts_email_device (email, device_fingerprint),
  INDEX idx_device_lockouts_locked_until (locked_until),
  INDEX idx_device_lockouts_user (user_id),
  INDEX idx_device_lockouts_email_device_until (email, device_fingerprint, locked_until),
  
  CONSTRAINT fk_device_lockouts_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

-- Extend devices table with lockout tracking
ALTER TABLE devices ADD COLUMN IF NOT EXISTS is_device_locked BOOLEAN DEFAULT FALSE;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS device_lock_until DATETIME NULL;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS device_lock_reason VARCHAR(255);

-- Add index for querying locked devices
CREATE INDEX IF NOT EXISTS idx_devices_lock_status 
ON devices(user_id, is_device_locked, device_lock_until);

-- Drop global lock columns from users (optional - keep for backward compatibility)
-- ALTER TABLE users DROP COLUMN IF EXISTS is_locked;
-- ALTER TABLE users DROP COLUMN IF EXISTS lock_until;
