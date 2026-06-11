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
  } finally {
    await connection.end();
  }
};

run().catch((error) => {
  console.error('Migration failed:', error.message);
  process.exit(1);
});
