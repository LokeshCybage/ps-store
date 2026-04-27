const { pool } = require('../db');

async function getCartItems(userId) {
  const { rows } = await pool.query(
    `SELECT id, user_id, game_id, game_title, game_price, added_at
     FROM cart_items WHERE user_id = $1 ORDER BY added_at DESC`,
    [userId]
  );
  return rows;
}

async function addCartItem(userId, gameId, gameTitle, gamePrice) {
  const { rows } = await pool.query(
    `INSERT INTO cart_items (user_id, game_id, game_title, game_price)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, game_id) DO NOTHING
     RETURNING *`,
    [userId, gameId, gameTitle, gamePrice]
  );
  return rows[0] || null;
}

async function removeCartItem(userId, gameId) {
  const { rowCount } = await pool.query(
    'DELETE FROM cart_items WHERE user_id = $1 AND game_id = $2',
    [userId, gameId]
  );
  return rowCount > 0;
}

async function clearCart(userId) {
  await pool.query('DELETE FROM cart_items WHERE user_id = $1', [userId]);
}

async function getCartItemCount(userId) {
  const { rows } = await pool.query(
    'SELECT COUNT(*)::int AS count FROM cart_items WHERE user_id = $1',
    [userId]
  );
  return rows[0].count;
}

module.exports = { getCartItems, addCartItem, removeCartItem, clearCart, getCartItemCount };
