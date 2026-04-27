const { Router } = require('express');
const auth = require('../middleware/auth');
const cartModel = require('../models/cart');
const catalogClient = require('../services/catalogClient');

const router = Router();

router.use(auth);

router.get('/', async (req, res) => {
  try {
    const rawItems = await cartModel.getCartItems(req.user.userId);
    const items = rawItems.map((item) => ({
      id: item.id,
      game_id: item.game_id,
      title: item.game_title,
      price: parseFloat(item.game_price),
      added_at: item.added_at,
    }));
    const total = items.reduce((sum, item) => sum + item.price, 0);
    res.json({ items, total: parseFloat(total.toFixed(2)), item_count: items.length });
  } catch (err) {
    console.error('Get cart error:', err.message);
    res.status(500).json({ error: 'Failed to retrieve cart' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { game_id } = req.body;
    if (!game_id) {
      return res.status(400).json({ error: 'game_id is required' });
    }

    const game = await catalogClient.getGame(game_id);
    if (!game) {
      return res.status(404).json({ error: 'Game not found' });
    }

    const price = game.sale_price != null ? game.sale_price : game.price;
    const item = await cartModel.addCartItem(req.user.userId, game_id, game.title, price);

    if (item) {
      return res.status(201).json(item);
    }
    res.json({ message: 'Game already in cart' });
  } catch (err) {
    console.error('Add to cart error:', err.message);
    res.status(500).json({ error: 'Failed to add item to cart' });
  }
});

router.delete('/:gameId', async (req, res) => {
  try {
    await cartModel.removeCartItem(req.user.userId, req.params.gameId);
    res.status(204).send();
  } catch (err) {
    console.error('Remove cart item error:', err.message);
    res.status(500).json({ error: 'Failed to remove item from cart' });
  }
});

router.delete('/', async (req, res) => {
  try {
    await cartModel.clearCart(req.user.userId);
    res.status(204).send();
  } catch (err) {
    console.error('Clear cart error:', err.message);
    res.status(500).json({ error: 'Failed to clear cart' });
  }
});

module.exports = router;
