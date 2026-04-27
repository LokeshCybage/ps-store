const axios = require('axios');
const config = require('../config');

const client = axios.create({
  baseURL: config.CATALOG_SERVICE_URL,
  timeout: 5000,
});

async function getGame(gameId) {
  try {
    const { data } = await client.get(`/internal/games/${gameId}`);
    return data;
  } catch {
    return null;
  }
}

module.exports = { getGame };
