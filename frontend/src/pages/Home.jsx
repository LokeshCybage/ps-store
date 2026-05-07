import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { catalogAPI } from '../api';
import GameGrid from '../components/GameGrid';
import './Home.css';

export default function Home() {
  const [featured, setFeatured] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    catalogAPI
      .get('/api/games/featured')
      .then((res) => setFeatured(res.data))
      .catch((err) => setError(err.response?.data?.message || 'Failed to load featured games'))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="home-page">
      <section className="hero">
        <div className="hero-content">
          <h1 className="hero-heading">Welcome to PlayStation Store</h1>
          <p className="hero-subtitle">Explore the best games for PS5 and PS4</p>
          <Link to="/browse" className="hero-cta">Browse All Games</Link>
        </div>
      </section>

      <div className="home-content">
        {loading && <div className="loading-spinner">Loading...</div>}
        {error && <div className="error-message">{error}</div>}

        {featured?.deals?.length > 0 && (
          <GameGrid games={featured.deals} title="Featured Deals" />
        )}

        {featured?.trending?.length > 0 && (
          <GameGrid games={featured.trending} title="Trending" />
        )}
      </div>
    </div>
  );
}
