const { Router } = require('express');
const orderModel = require('../models/order');

const router = Router();

router.get('/games/:gameId/stats', async (req, res) => {
  try {
    const purchaseCount = await orderModel.getGamePurchaseCount(req.params.gameId);
    res.json({ game_id: req.params.gameId, purchase_count: purchaseCount });
  } catch (err) {
    console.error('Game stats error:', err.message);
    res.status(500).json({ error: 'Failed to retrieve game stats' });
  }
});

router.get('/popular', async (req, res) => {
  try {
    const games = await orderModel.getPopularGames(10);
    res.json({ games });
  } catch (err) {
    console.error('Popular games error:', err.message);
    res.status(500).json({ error: 'Failed to retrieve popular games' });
  }
});

router.get('/user/:userId/stats', async (req, res) => {
  try {
    const stats = await orderModel.getUserOrderStats(req.params.userId);
    res.json({
      user_id: req.params.userId,
      order_count: stats.order_count,
      total_spent: parseFloat(stats.total_spent),
    });
  } catch (err) {
    console.error('User stats error:', err.message);
    res.status(500).json({ error: 'Failed to retrieve user stats' });
  }
});

module.exports = router;
