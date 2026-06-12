const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const securityRoutes = require('./routes/securityRoutes');
const socialRoutes = require('./routes/socialRoutes');

const app = express();

const trustProxyHops = Number.parseInt(process.env.TRUST_PROXY_HOPS || '1', 10);
app.set('trust proxy', Number.isNaN(trustProxyHops) ? 1 : trustProxyHops);

app.use(cors({ origin: '*', credentials: false }));
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Backend đang hoạt động' });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/security', securityRoutes);
app.use('/api/social', socialRoutes);

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
