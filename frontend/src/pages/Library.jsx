import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { userApi } from '../api';
import './Library.css';

function getThumbUrl(game) {
  if (game.image_url) return game.image_url;
  const encodedTitle = encodeURIComponent(game.title || 'Game').replace(/%20/g, '+');
  return `https://placehold.co/400x500/1a1a2e/ffffff?text=${encodedTitle}`;
}

export default function Library() {
  const [games, setGames] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    userApi
      .get('/api/library')
      .then((res) => setGames(res.data.games || res.data || []))
      .catch((err) => setError(err.response?.data?.message || 'Failed to load library'))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div className="library-page"><div className="loading-spinner">Loading...</div></div>;
  if (error) return <div className="library-page"><div className="error-message">{error}</div></div>;

  return (
    <div className="library-page">
      <h1 className="library-heading">My Library</h1>

      {games.length === 0 ? (
        <div className="library-empty">
          <p>No games in your library yet. Start shopping!</p>
          <Link to="/browse" className="library-browse-link">Browse Games</Link>
        </div>
      ) : (
        <div className="library-grid">
          {games.map((game) => {
            const gameId = game.game_id || game.id;
            return (
              <Link key={gameId} to={`/games/${gameId}`} className="library-card">
                <div className="library-card-image-wrapper">
                  <img
                    src={getThumbUrl(game)}
                    alt={game.title}
                    className="library-card-image"
                    loading="lazy"
                  />
                  <span className="owned-badge">Owned</span>
                </div>
                <div className="library-card-info">
                  <h3 className="library-card-title">{game.title}</h3>
                  {game.platform && (
                    <span className="library-card-platform">
                      {Array.isArray(game.platform) ? game.platform.join(', ') : game.platform}
                    </span>
                  )}
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
