ALTER TABLE account_action_tokens
  ADD COLUMN attempts INT NOT NULL DEFAULT 0 AFTER used_at;
