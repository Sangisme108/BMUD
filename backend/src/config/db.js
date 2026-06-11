const mysql = require('mysql2/promise');
require('dotenv').config();
const getDatabaseOptions = require('./databaseOptions');

const pool = mysql.createPool({
  ...getDatabaseOptions(),
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: 'Z',
});

module.exports = pool;
