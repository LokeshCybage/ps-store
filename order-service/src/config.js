require('dotenv').config();

module.exports = {
  DATABASE_URL: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/order_db',
  PORT: parseInt(process.env.PORT, 10) || 8003,
  JWT_SECRET: process.env.JWT_SECRET || 'ps-store-jwt-secret-key-change-in-production',
  CATALOG_SERVICE_URL: process.env.CATALOG_SERVICE_URL || 'http://localhost:8001',
  USER_SERVICE_URL: process.env.USER_SERVICE_URL || 'http://localhost:8002',
};
