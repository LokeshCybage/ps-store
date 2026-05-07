import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { catalogAPI, orderApi, userApi } from '../api';
import { useAuth } from '../context/AuthContext';
import StarRating from '../components/StarRating';
import './GameDetail.css';

function getImageUrl(game) {
  if (game.image_url) return game.image_url;
  const encodedTitle = encodeURIComponent(game.title || 'Game').replace(/%20/g, '+');
  return `https://placehold.co/600x750/1a1a2e/ffffff?text=${encodedTitle}`;
}

function timeAgo(dateStr) {
  const now = new Date();
  const date = new Date(dateStr);
  const diffMs = now - date;
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
  if (diffDays < 1) return 'Today';
  if (diffDays === 1) return '1 day ago';
  if (diffDays < 30) return `${diffDays} days ago`;
  const diffMonths = Math.floor(diffDays / 30);
  if (diffMonths === 1) return '1 month ago';
  if (diffMonths < 12) return `${diffMonths} months ago`;
  return `${Math.floor(diffMonths / 12)} year(s) ago`;
}

export default function GameDetail() {
  const { id } = useParams();
  const { isAuthenticated, user } = useAuth();
  const [game, setGame] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [message, setMessage] = useState(null);

  const [reviewRating, setReviewRating] = useState(5);
  const [reviewText, setReviewText] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    setLoading(true);
    catalogAPI
      .get(`/api/games/${id}`)
      .then((res) => setGame(res.data))
      .catch((err) => setError(err.response?.data?.message || 'Failed to load game'))
      .finally(() => setLoading(false));
  }, [id]);

  const showMessage = (text, isError = false) => {
    setMessage({ text, isError });
    setTimeout(() => setMessage(null), 3000);
  };

  const handleAddToCart = async () => {
    if (!isAuthenticated) return;
    try {
      await orderApi.post('/api/cart', { game_id: game.id });
      showMessage('Added to cart!');
    } catch (err) {
      showMessage(err.response?.data?.message || 'Failed to add to cart', true);
    }
  };

  const handleAddToWishlist = async () => {
    if (!isAuthenticated) return;
    try {
      await userApi.post('/api/wishlist', { game_id: game.id });
      showMessage('Added to wishlist!');
    } catch (err) {
      showMessage(err.response?.data?.message || 'Failed to add to wishlist', true);
    }
  };

  const handleSubmitReview = async (e) => {
    e.preventDefault();
    if (!isAuthenticated) return;
    setSubmitting(true);
    try {
      await catalogAPI.post(`/api/games/${id}/reviews`, {
        game_id: id,
        rating: reviewRating,
        review_text: reviewText || null,
      });
      showMessage('Review submitted!');
      setReviewText('');
      setReviewRating(5);
      const res = await catalogAPI.get(`/api/games/${id}`);
      setGame(res.data);
    } catch (err) {
      const detail = err.response?.data?.detail || 'Failed to submit review';
      showMessage(detail, true);
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) return <div className="detail-page"><div className="loading-spinner">Loading...</div></div>;
  if (error) return <div className="detail-page"><div className="error-message">{error}</div></div>;
  if (!game) return null;

  const isFree = game.is_free || game.price === 0;
  const onSale = game.sale_price != null && game.sale_price < game.price;
  const reviews = game.reviews || [];
  const alreadyReviewed = isAuthenticated && user && reviews.some(
    (r) => r.user_id === user.sub
  );

  return (
    <div className="detail-page">
      <div className="detail-container">
        <div className="detail-image-section">
          <img
            src={getImageUrl(game)}
            alt={game.title}
            className="detail-image"
          />
        </div>

        <div className="detail-info-section">
          <h1 className="detail-title">{game.title}</h1>

          {game.publisher && (
            <p className="detail-publisher">{game.publisher}</p>
          )}

          {game.avg_rating != null && (
            <div className="detail-rating-summary">
              <StarRating rating={game.avg_rating} size="large" />
              <span className="detail-review-count">
                ({game.review_count} {game.review_count === 1 ? 'review' : 'reviews'})
              </span>
            </div>
          )}

          <div className="detail-meta">
            {game.platform && (
              <div className="detail-platforms">
                {(Array.isArray(game.platform) ? game.platform : game.platform.split(',')).map((p) => (
                  <span key={p.trim()} className="detail-platform-badge">{p.trim()}</span>
                ))}
              </div>
            )}
            {game.release_date && (
              <span className="detail-release">
                Released: {new Date(game.release_date).toLocaleDateString()}
              </span>
            )}
            {game.category && (
              <span className="detail-category">{typeof game.category === 'object' ? game.category.name : game.category}</span>
            )}
          </div>

          <div className="detail-price-section">
            {isFree ? (
              <span className="detail-price-free">Free</span>
            ) : onSale ? (
              <div className="detail-price-row">
                <span className="detail-price-original">${Number(game.price).toFixed(2)}</span>
                <span className="detail-price-sale">${Number(game.sale_price).toFixed(2)}</span>
              </div>
            ) : (
              <span className="detail-price-current">${Number(game.price).toFixed(2)}</span>
            )}
          </div>

          {game.purchase_count != null && (
            <p className="detail-purchases">{game.purchase_count.toLocaleString()} people purchased</p>
          )}

          {game.description && (
            <div className="detail-description">
              <p>{game.description}</p>
            </div>
          )}

          {message && (
            <div className={`detail-message ${message.isError ? 'error' : 'success'}`}>
              {message.text}
            </div>
          )}

          {isAuthenticated ? (
            <div className="detail-actions">
              <button className="btn-add-cart" onClick={handleAddToCart}>
                Add to Cart
              </button>
              <button className="btn-wishlist" onClick={handleAddToWishlist}>
                Add to Wishlist
              </button>
            </div>
          ) : (
            <div className="detail-login-prompt">
              <Link to="/login" className="btn-login-prompt">
                Sign in to purchase
              </Link>
            </div>
          )}
        </div>
      </div>

      <div className="reviews-section">
        <h2 className="reviews-heading">
          Player Reviews
          {game.review_count > 0 && (
            <span className="reviews-heading-count">({game.review_count})</span>
          )}
        </h2>

        {isAuthenticated && !alreadyReviewed && (
          <form className="review-form" onSubmit={handleSubmitReview}>
            <h3 className="review-form-title">Write a Review</h3>
            <div className="review-form-rating">
              <label>Your Rating:</label>
              <div className="rating-selector">
                {[1, 2, 3, 4, 5].map((star) => (
                  <button
                    key={star}
                    type="button"
                    className={`rating-star-btn ${star <= reviewRating ? 'active' : ''}`}
                    onClick={() => setReviewRating(star)}
                  >
                    &#9733;
                  </button>
                ))}
              </div>
            </div>
            <textarea
              className="review-form-text"
              placeholder="Share your thoughts about this game..."
              value={reviewText}
              onChange={(e) => setReviewText(e.target.value)}
              rows={3}
            />
            <button
              type="submit"
              className="review-form-submit"
              disabled={submitting}
            >
              {submitting ? 'Submitting...' : 'Submit Review'}
            </button>
          </form>
        )}

        {alreadyReviewed && (
          <p className="review-already-submitted">You have already reviewed this game.</p>
        )}

        {reviews.length === 0 ? (
          <p className="reviews-empty">No reviews yet. Be the first to review this game!</p>
        ) : (
          <div className="reviews-list">
            {reviews.map((review) => (
              <div key={review.id} className="review-card">
                <div className="review-card-header">
                  <span className="review-username">{review.username}</span>
                  <StarRating rating={review.rating} size="small" showValue={false} />
                  <span className="review-date">{timeAgo(review.created_at)}</span>
                </div>
                {review.review_text && (
                  <p className="review-text">{review.review_text}</p>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
