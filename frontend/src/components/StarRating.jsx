import './StarRating.css';

export default function StarRating({ rating, size = 'medium', showValue = true }) {
  const stars = [];
  const rounded = Math.round(rating * 2) / 2;

  for (let i = 1; i <= 5; i++) {
    if (i <= Math.floor(rounded)) {
      stars.push(<span key={i} className="star full">&#9733;</span>);
    } else if (i - 0.5 === rounded) {
      stars.push(
        <span key={i} className="star half">
          <span className="star-bg">&#9733;</span>
          <span className="star-fg">&#9733;</span>
        </span>
      );
    } else {
      stars.push(<span key={i} className="star empty">&#9733;</span>);
    }
  }

  return (
    <span className={`star-rating star-rating--${size}`}>
      <span className="stars">{stars}</span>
      {showValue && rating != null && (
        <span className="rating-value">{Number(rating).toFixed(1)}</span>
      )}
    </span>
  );
}
