import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { orderApi } from '../api';
import './Cart.css';

function getThumbUrl(item) {
  if (item.image_url) return item.image_url;
  const encodedTitle = encodeURIComponent(item.title || 'Game').replace(/%20/g, '+');
  return `https://placehold.co/120x150/1a1a2e/ffffff?text=${encodedTitle}`;
}

export default function Cart() {
  const navigate = useNavigate();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [checkingOut, setCheckingOut] = useState(false);
  const [message, setMessage] = useState(null);

  const fetchCart = () => {
    setLoading(true);
    orderApi
      .get('/api/cart')
      .then((res) => setItems(res.data.items || res.data || []))
      .catch((err) => setError(err.response?.data?.message || 'Failed to load cart'))
      .finally(() => setLoading(false));
  };

  useEffect(fetchCart, []);

  const handleRemove = async (gameId) => {
    try {
      await orderApi.delete(`/api/cart/${gameId}`);
      setItems((prev) => prev.filter((item) => item.game_id !== gameId && item.id !== gameId));
    } catch (err) {
      setMessage({ text: err.response?.data?.message || 'Failed to remove item', isError: true });
    }
  };

  const handleCheckout = async () => {
    setCheckingOut(true);
    try {
      await orderApi.post('/api/orders/checkout');
      setMessage({ text: 'Order placed successfully!', isError: false });
      setTimeout(() => navigate('/library'), 1500);
    } catch (err) {
      setMessage({ text: err.response?.data?.message || 'Checkout failed', isError: true });
      setCheckingOut(false);
    }
  };

  const total = items.reduce((sum, item) => sum + Number(item.price || 0), 0);

  if (loading) return <div className="cart-page"><div className="loading-spinner">Loading...</div></div>;
  if (error) return <div className="cart-page"><div className="error-message">{error}</div></div>;

  return (
    <div className="cart-page">
      <h1 className="cart-heading">Shopping Cart</h1>

      {message && (
        <div className={`cart-message ${message.isError ? 'error' : 'success'}`}>
          {message.text}
        </div>
      )}

      {items.length === 0 ? (
        <div className="cart-empty">
          <p>Your cart is empty.</p>
          <Link to="/browse" className="cart-browse-link">Browse Games</Link>
        </div>
      ) : (
        <>
          <div className="cart-items">
            {items.map((item) => {
              const gameId = item.game_id || item.id;
              return (
                <div key={gameId} className="cart-item">
                  <img
                    src={getThumbUrl(item)}
                    alt={item.title}
                    className="cart-item-image"
                  />
                  <div className="cart-item-info">
                    <Link to={`/games/${gameId}`} className="cart-item-title">
                      {item.title}
                    </Link>
                  </div>
                  <div className="cart-item-price">
                    <span>${Number(item.price || 0).toFixed(2)}</span>
                  </div>
                  <button
                    className="cart-remove-btn"
                    onClick={() => handleRemove(gameId)}
                    title="Remove from cart"
                  >
                    &times;
                  </button>
                </div>
              );
            })}
          </div>

          <div className="cart-summary">
            <div className="cart-total">
              <span>Total</span>
              <span className="cart-total-price">${total.toFixed(2)}</span>
            </div>
            <button
              className="cart-checkout-btn"
              onClick={handleCheckout}
              disabled={checkingOut}
            >
              {checkingOut ? 'Processing...' : 'Checkout'}
            </button>
          </div>
        </>
      )}
    </div>
  );
}
