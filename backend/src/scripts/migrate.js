const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config();
const getDatabaseOptions = require('../config/databaseOptions');

const run = async () => {
  const connection = await mysql.createConnection({
    ...getDatabaseOptions(),
    multipleStatements: true,
  });

  try {
    const [[state]] = await connection.query(
      `SELECT
         COUNT(*) = 4 AS tables_ready,
         (
           SELECT COUNT(*)
           FROM information_schema.columns
           WHERE table_schema = DATABASE()
             AND table_name = 'users'
             AND column_name IN ('is_locked', 'lock_until')
         ) = 2 AS columns_ready
       FROM information_schema.tables
       WHERE table_schema = DATABASE()
         AND table_name IN ('devices', 'login_attempts', 'auth_otps', 'refresh_tokens')`
    );

    if (!state.tables_ready || !state.columns_ready) {
      const migrationPath = path.join(
        __dirname,
        '..',
        '..',
        'migrations',
        '001_adaptive_auth.sql'
      );
      const sql = fs.readFileSync(migrationPath, 'utf8');
      await connection.query(sql);
      console.log('Adaptive authentication migration completed.');
    } else {
      console.log('Adaptive authentication migration is already applied.');
    }

    const [[recoveryState]] = await connection.query(
      `SELECT COUNT(*) AS total
       FROM information_schema.tables
       WHERE table_schema = DATABASE()
         AND table_name = 'account_action_tokens'`
    );
    if (Number(recoveryState.total) === 0) {
      const recoveryPath = path.join(
        __dirname,
        '..',
        '..',
        'migrations',
        '002_account_recovery.sql'
      );
      await connection.query(fs.readFileSync(recoveryPath, 'utf8'));
      console.log('Account recovery migration completed.');
    } else {
      console.log('Account recovery migration is already applied.');
    }

    const [[otpState]] = await connection.query(
      `SELECT COUNT(*) AS total
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = 'account_action_tokens'
         AND column_name = 'attempts'`
    );
    if (Number(otpState.total) === 0) {
      const otpPath = path.join(
        __dirname,
        '..',
        '..',
        'migrations',
        '003_recovery_otp.sql'
      );
      await connection.query(fs.readFileSync(otpPath, 'utf8'));
      console.log('Recovery OTP migration completed.');
    } else {
      console.log('Recovery OTP migration is already applied.');
    }

    const [[messagingState]] = await connection.query(
      `SELECT COUNT(*) AS total
       FROM information_schema.tables
       WHERE table_schema = DATABASE()
         AND table_name IN ('friendships', 'messages')`
    );
    if (Number(messagingState.total) < 2) {
      const messagingPath = path.join(
        __dirname,
        '..',
        '..',
        'migrations',
        '004_friendships_messages.sql'
      );
      await connection.query(fs.readFileSync(messagingPath, 'utf8'));
      console.log('Friendship and messaging migration completed.');
    } else {
      console.log('Friendship and messaging migration is already applied.');
    }

    const [[messageRecoveryState]] = await connection.query(
      `SELECT
         (
           SELECT COUNT(*)
           FROM information_schema.columns
           WHERE table_schema = DATABASE()
             AND table_name = 'users'
             AND column_name = 'message_recovery_code_hash'
         ) AS user_column_ready,
         (
           SELECT COUNT(*)
           FROM information_schema.columns
           WHERE table_schema = DATABASE()
             AND table_name = 'devices'
             AND column_name = 'device_fingerprint_hash'
         ) AS device_hash_column_ready,
         (
           SELECT COUNT(*)
           FROM information_schema.columns
           WHERE table_schema = DATABASE()
             AND table_name = 'devices'
             AND column_name = 'message_recovery_verified'
         ) AS device_column_ready,
         (
           SELECT COUNT(*)
           FROM information_schema.columns
           WHERE table_schema = DATABASE()
             AND table_name = 'devices'
             AND column_name = 'message_recovery_verified_at'
         ) AS device_verified_at_column_ready,
         (
           SELECT COUNT(*)
           FROM information_schema.tables
           WHERE table_schema = DATABASE()
             AND table_name = 'message_recovery_attempts'
         ) AS attempts_table_ready,
         (
           SELECT COUNT(*)
           FROM information_schema.statistics
           WHERE table_schema = DATABASE()
             AND table_name = 'devices'
             AND index_name = 'idx_devices_message_recovery'
         ) AS devices_recovery_index_ready`
    );

    if (Number(messageRecoveryState.user_column_ready) === 0) {
      await connection.query(
        `ALTER TABLE users
         ADD COLUMN message_recovery_code_hash VARCHAR(255) NULL AFTER password_hash`
      );
    }
    if (Number(messageRecoveryState.device_hash_column_ready) === 0) {
      await connection.query(
        `ALTER TABLE devices
         ADD COLUMN device_fingerprint_hash VARCHAR(64) NULL AFTER device_fingerprint`
      );
    }
    if (Number(messageRecoveryState.device_column_ready) === 0) {
      await connection.query(
        `ALTER TABLE devices
         ADD COLUMN message_recovery_verified BOOLEAN NOT NULL DEFAULT FALSE AFTER is_trusted`
      );
    }
    if (Number(messageRecoveryState.device_verified_at_column_ready) === 0) {
      await connection.query(
        `ALTER TABLE devices
         ADD COLUMN message_recovery_verified_at DATETIME NULL AFTER message_recovery_verified`
      );
    }
    if (Number(messageRecoveryState.attempts_table_ready) === 0) {
      await connection.query(
        `CREATE TABLE IF NOT EXISTS message_recovery_attempts (
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
        )`
      );
    }
    if (Number(messageRecoveryState.devices_recovery_index_ready) === 0) {
      await connection.query(
        `CREATE INDEX idx_devices_message_recovery
         ON devices (user_id, device_fingerprint_hash, message_recovery_verified)`
      );
    }

    if (
      Number(messageRecoveryState.user_column_ready) === 0 ||
      Number(messageRecoveryState.device_hash_column_ready) === 0 ||
      Number(messageRecoveryState.device_column_ready) === 0 ||
      Number(messageRecoveryState.device_verified_at_column_ready) === 0 ||
      Number(messageRecoveryState.attempts_table_ready) === 0 ||
      Number(messageRecoveryState.devices_recovery_index_ready) === 0
    ) {
      console.log('Message recovery migration completed.');
    } else {
      console.log('Message recovery migration is already applied.');
    }

    const [[securityEventsState]] = await connection.query(
      `SELECT COUNT(*) AS total
       FROM information_schema.tables
       WHERE table_schema = DATABASE()
         AND table_name = 'security_events'`
    );
    if (Number(securityEventsState.total) === 0) {
      const securityEventsPath = path.join(
        __dirname,
        '..',
        '..',
        'migrations',
        '006_security_events.sql'
      );
      await connection.query(fs.readFileSync(securityEventsPath, 'utf8'));
      console.log('Security events migration completed.');
    } else {
      console.log('Security events migration is already applied.');
    }
  } finally {
    await connection.end();
  }
};

run().catch((error) => {
  console.error('Migration failed:', error.message);
  process.exit(1);
});
