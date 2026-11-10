require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const userRoutes = require('./routes/userRoutes');
const app = express();
app.disable('x-powered-by');
app.use(helmet());
const origins = (process.env.CORS_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
app.use(cors({ origin: origins.length ? origins : true })); // For local demo; restrict in production.
// Cho phep gui avatar dang data URI trong bai demo (nen uu tien URL anh nho).
app.use(express.json({ limit: '5mb' }));
app.get('/', (_req, res) => res.json({ message: 'API quan ly nguoi dung dang hoat dong', health: '/api/health' }));
app.get('/api/health', (_req, res) => res.json({ status: mongoose.connection.readyState === 1 ? 'ok' : 'disconnected' }));
app.use('/api/users', userRoutes);
app.use((_req, res) => res.status(404).json({ message: 'Khong tim thay API' }));
const port = Number(process.env.PORT || 3000);
async function start() {
  if (!process.env.MONGO_URI || !process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
    throw new Error('Cau hinh MONGO_URI va JWT_SECRET (>=32 ky tu) trong .env');
  }
  await mongoose.connect(process.env.MONGO_URI);
  console.log('Ket noi MongoDB thanh cong!');
  app.listen(port, () => console.log(`Server: http://localhost:${port}`));
}
start().catch(err => { console.error('Loi khoi dong:', err.message); process.exit(1); });
