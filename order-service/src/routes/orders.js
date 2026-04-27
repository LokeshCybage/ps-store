const { Router } = require('express');
const auth = require('../middleware/auth');
const cartModel = require('../models/cart');
const orderModel = require('../models/order');
const catalogClient = require('../services/catalogClient');
const userClient = require('../services/userClient');

const router = Router();

router.use(auth);

router.post('/checkout', async (req, res) => {
  try {
    const { userId } = req.user;
    const cartItems = await cartModel.getCartItems(userId);

    if (cartItems.length === 0) {
      return res.status(400).json({ error: 'Cart is empty' });
    }

    const orderItems = [];
    for (const item of cartItems) {
      const game = await catalogClient.getGame(item.game_id);
      const price = game
        ? (game.sale_price != null ? game.sale_price : game.price)
        : parseFloat(item.game_price);
      const title = game ? game.title : item.game_title;

      orderItems.push({
        game_id: item.game_id,
        game_title: title,
        price: parseFloat(price),
      });
    }

    const total = orderItems.reduce((sum, item) => sum + item.price, 0);
    const order = await orderModel.createOrder(userId, parseFloat(total.toFixed(2)), orderItems);

    const gameIds = orderItems.map((item) => item.game_id);
    await userClient.addToLibrary(userId, gameIds, order.id);

    await cartModel.clearCart(userId);

    res.status(201).json({ order: { ...order, items: orderItems } });
  } catch (err) {
    console.error('Checkout error:', err.message);
    res.status(500).json({ error: 'Checkout failed' });
  }
});

router.get('/', async (req, res) => {
  try {
    const orders = await orderModel.getOrdersByUser(req.user.userId);
    res.json({ orders });
  } catch (err) {
    console.error('Get orders error:', err.message);
    res.status(500).json({ error: 'Failed to retrieve orders' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const order = await orderModel.getOrderById(req.params.id, req.user.userId);
    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }
    res.json(order);
  } catch (err) {
    console.error('Get order error:', err.message);
    res.status(500).json({ error: 'Failed to retrieve order' });
  }
});

module.exports = router;
