const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const securityRoutes = require('./routes/securityRoutes');

const app = express();

app.set('trust proxy', 1);

app.use(cors({ origin: '*', credentials: false }));
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Backend đang hoạt động' });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/security', securityRoutes);

app.use((req, res) => {
  res.status(404).json({ message: 'Không tìm thấy endpoint' });
});

app.use((error, req, res, next) => {
  console.error(error);
  res.status(error.statusCode || 500).json({
    message: error.message || 'Lỗi server',
  });
});

module.exports = app;
