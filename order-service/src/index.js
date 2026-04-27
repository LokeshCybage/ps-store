require('dotenv').config();
require('./tracing');

const express = require('express');
const cors = require('cors');
const config = require('./config');
const { initDB } = require('./db');
const cartRoutes = require('./routes/cart');
const orderRoutes = require('./routes/orders');
const internalRoutes = require('./routes/internal');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'healthy', service: 'order-service' });
});

app.use('/api/cart', cartRoutes);
app.use('/api/orders', orderRoutes);
app.use('/internal/orders', internalRoutes);

app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

async function start() {
  try {
    await initDB();
    app.listen(config.PORT, () => {
      console.log(`Order service running on port ${config.PORT}`);
    });
  } catch (err) {
    console.error('Failed to start order service:', err.message);
    process.exit(1);
  }
}

start();
