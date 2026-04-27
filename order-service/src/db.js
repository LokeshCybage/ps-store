const { Pool } = require('pg');
const config = require('./config');

const pool = new Pool({ connectionString: config.DATABASE_URL });

async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cart_items (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL,
      game_id UUID NOT NULL,
      game_title VARCHAR(255) NOT NULL,
      game_price DECIMAL(10,2) NOT NULL,
      added_at TIMESTAMP DEFAULT NOW(),
      UNIQUE(user_id, game_id)
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS orders (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL,
      total_amount DECIMAL(10,2) NOT NULL,
      status VARCHAR(50) DEFAULT 'completed',
      created_at TIMESTAMP DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS order_items (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
      game_id UUID NOT NULL,
      game_title VARCHAR(255) NOT NULL,
      price DECIMAL(10,2) NOT NULL,
      UNIQUE(order_id, game_id)
    )
  `);

  console.log('Database tables initialized');
}

module.exports = { pool, initDB };
