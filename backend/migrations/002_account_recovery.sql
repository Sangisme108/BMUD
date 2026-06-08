CREATE TABLE account_action_tokens (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token_hash VARCHAR(64) NOT NULL UNIQUE,
  action_type ENUM('UNLOCK_ACCOUNT', 'RESET_PASSWORD') NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_account_action_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_account_action_lookup (action_type, token_hash, expires_at),
  INDEX idx_account_action_user (user_id, action_type)
);
