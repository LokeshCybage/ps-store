import { useNavigate } from 'react-router-dom';
import StarRating from './StarRating';
import './GameCard.css';

function getImageUrl(game) {
  if (game.image_url) return game.image_url;
  const encodedTitle = encodeURIComponent(game.title || 'Game').replace(/%20/g, '+');
  return `https://placehold.co/400x500/1a1a2e/ffffff?text=${encodedTitle}`;
}

function formatPrice(price) {
  if (price == null) return '';
  return `$${Number(price).toFixed(2)}`;
}

export default function GameCard({ game }) {
  const navigate = useNavigate();

  const handleClick = () => {
    navigate(`/games/${game.id}`);
  };

  const isFree = game.is_free || game.price === 0;
  const onSale = game.sale_price != null && game.sale_price < game.price;

  return (
    <div className="game-card" onClick={handleClick}>
      <div className="game-card-image-wrapper">
        <img
          src={getImageUrl(game)}
          alt={game.title}
          className="game-card-image"
          loading="lazy"
        />
        {game.platform && (
          <div className="game-card-platforms">
            {(Array.isArray(game.platform) ? game.platform : game.platform.split(',')).map((p) => (
              <span key={p.trim()} className="platform-badge">{p.trim()}</span>
            ))}
          </div>
        )}
      </div>
      <div className="game-card-info">
        <h3 className="game-card-title">{game.title}</h3>
        {game.avg_rating != null && (
          <div className="game-card-rating">
            <StarRating rating={game.avg_rating} size="small" />
            <span className="rating-count">({game.review_count})</span>
          </div>
        )}
        <div className="game-card-price">
          {isFree ? (
            <span className="price-free">Free</span>
          ) : onSale ? (
            <>
              <span className="price-original">{formatPrice(game.price)}</span>
              <span className="price-sale">{formatPrice(game.sale_price)}</span>
            </>
          ) : (
            <span className="price-current">{formatPrice(game.price)}</span>
          )}
        </div>
      </div>
    </div>
  );
}
