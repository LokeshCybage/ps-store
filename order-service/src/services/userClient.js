const axios = require('axios');
const config = require('../config');

const client = axios.create({
  baseURL: config.USER_SERVICE_URL,
  timeout: 5000,
});

async function addToLibrary(userId, gameIds, orderId) {
  try {
    await client.post(`/internal/users/${userId}/library`, {
      game_ids: gameIds,
      order_id: orderId,
    });
    return true;
  } catch {
    console.error(`Failed to sync library for user ${userId}:`, 'User service unavailable');
    return false;
  }
}

module.exports = { addToLibrary };
