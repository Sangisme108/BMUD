const app = require('./app');
const pool = require('./config/db');

const PORT = process.env.PORT || 5000;

const startServer = async () => {
  try {
    await pool.query('SELECT 1');
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server đang chạy tại http://0.0.0.0:${PORT}`);
    });
  } catch (error) {
    console.error('Không thể kết nối MySQL:', error.message);
    process.exit(1);
  }
};

startServer();
