-- WARNING: This permanently deletes all account and authentication data.
-- Run this only against the test database.
USE abnormal_login_detection;

START TRANSACTION;

-- Delete child records first to satisfy foreign-key constraints.
DELETE FROM account_action_tokens;
DELETE FROM refresh_tokens;
DELETE FROM auth_otps;
DELETE FROM login_history;
DELETE FROM devices;

-- This table must be cleared explicitly because its user_id foreign key uses
-- ON DELETE SET NULL, so deleting users alone would retain login attempts.
DELETE FROM login_attempts;
DELETE FROM users;

COMMIT;

-- Every value should be 0 after a successful reset.
SELECT
  (SELECT COUNT(*) FROM users) AS users,
  (SELECT COUNT(*) FROM devices) AS devices,
  (SELECT COUNT(*) FROM login_attempts) AS login_attempts,
  (SELECT COUNT(*) FROM auth_otps) AS auth_otps,
  (SELECT COUNT(*) FROM refresh_tokens) AS refresh_tokens,
  (SELECT COUNT(*) FROM account_action_tokens) AS account_action_tokens,
  (SELECT COUNT(*) FROM login_history) AS login_history;
