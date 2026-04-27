const { pool } = require('../db');

async function createOrder(userId, totalAmount, items) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const { rows: orderRows } = await client.query(
      `INSERT INTO orders (user_id, total_amount) VALUES ($1, $2) RETURNING *`,
      [userId, totalAmount]
    );
    const order = orderRows[0];

    for (const item of items) {
      await client.query(
        `INSERT INTO order_items (order_id, game_id, game_title, price)
         VALUES ($1, $2, $3, $4)`,
        [order.id, item.game_id, item.game_title, item.price]
      );
    }

    await client.query('COMMIT');
    return order;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function getOrdersByUser(userId) {
  const { rows } = await pool.query(
    `SELECT o.id, o.user_id, o.total_amount, o.status, o.created_at,
            COUNT(oi.id)::int AS item_count
     FROM orders o
     LEFT JOIN order_items oi ON oi.order_id = o.id
     WHERE o.user_id = $1
     GROUP BY o.id
     ORDER BY o.created_at DESC`,
    [userId]
  );
  return rows;
}

async function getOrderById(orderId, userId) {
  const { rows: orderRows } = await pool.query(
    'SELECT * FROM orders WHERE id = $1 AND user_id = $2',
    [orderId, userId]
  );
  if (orderRows.length === 0) return null;

  const order = orderRows[0];
  const { rows: items } = await pool.query(
    'SELECT id, game_id, game_title, price FROM order_items WHERE order_id = $1',
    [orderId]
  );
  return { ...order, items };
}

async function getGamePurchaseCount(gameId) {
  const { rows } = await pool.query(
    'SELECT COUNT(*)::int AS purchase_count FROM order_items WHERE game_id = $1',
    [gameId]
  );
  return rows[0].purchase_count;
}

async function getPopularGames(limit = 10) {
  const { rows } = await pool.query(
    `SELECT game_id, COUNT(*)::int AS purchase_count
     FROM order_items
     GROUP BY game_id
     ORDER BY purchase_count DESC
     LIMIT $1`,
    [limit]
  );
  return rows;
}

async function getUserOrderStats(userId) {
  const { rows } = await pool.query(
    `SELECT COUNT(DISTINCT id)::int AS order_count,
            COALESCE(SUM(total_amount), 0)::numeric AS total_spent
     FROM orders
     WHERE user_id = $1`,
    [userId]
  );
  return rows[0];
}

module.exports = {
  createOrder,
  getOrdersByUser,
  getOrderById,
  getGamePurchaseCount,
  getPopularGames,
  getUserOrderStats,
};
