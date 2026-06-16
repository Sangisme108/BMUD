const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const securityRoutes = require('./routes/securityRoutes');
const socialRoutes = require('./routes/socialRoutes');
const chatCompatibilityRoutes = require('./routes/chatCompatibilityRoutes');
const messageRecoveryRoutes = require('./routes/messageRecoveryRoutes');
const {
  requireHttpsInProduction,
  secureHeaders,
} = require('./middleware/securityMiddleware');

const app = express();

const trustProxyHops = Number.parseInt(process.env.TRUST_PROXY_HOPS || '1', 10);
app.set('trust proxy', Number.isNaN(trustProxyHops) ? 1 : trustProxyHops);
app.disable('x-powered-by');

const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(secureHeaders);
app.use(requireHttpsInProduction);
app.use(
  cors({
    origin(origin, callback) {
      if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error('CORS origin is not allowed'));
    },
    credentials: false,
  })
);
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Backend đang hoạt động' });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/security', securityRoutes);
app.use('/api/social', socialRoutes);
app.use('/api', chatCompatibilityRoutes);
app.use('/api/message-recovery', messageRecoveryRoutes);

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
