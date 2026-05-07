import { useState, useEffect, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import { catalogAPI } from '../api';
import GameGrid from '../components/GameGrid';
import './Browse.css';

export default function Browse() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [games, setGames] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [totalPages, setTotalPages] = useState(1);

  const selectedCategory = searchParams.get('category') || '';
  const selectedPlatform = searchParams.get('platform') || '';
  const onSale = searchParams.get('on_sale') === 'true';
  const page = parseInt(searchParams.get('page') || '1', 10);

  const updateFilter = useCallback(
    (key, value) => {
      const params = new URLSearchParams(searchParams);
      if (value) {
        params.set(key, value);
      } else {
        params.delete(key);
      }
      if (key !== 'page') params.set('page', '1');
      setSearchParams(params);
    },
    [searchParams, setSearchParams]
  );

  useEffect(() => {
    catalogAPI
      .get('/api/categories')
      .then((res) => setCategories(res.data.categories || res.data || []))
      .catch(() => {});
  }, []);

  useEffect(() => {
    setLoading(true);
    setError(null);

    const params = {};
    if (selectedCategory) params.category = selectedCategory;
    if (selectedPlatform) params.platform = selectedPlatform;
    if (onSale) params.on_sale = true;
    params.page = page;

    catalogAPI
      .get('/api/games', { params })
      .then((res) => {
        setGames(res.data.games || res.data || []);
        setTotalPages(res.data.total_pages || 1);
      })
      .catch((err) => setError(err.response?.data?.message || 'Failed to load games'))
      .finally(() => setLoading(false));
  }, [selectedCategory, selectedPlatform, onSale, page]);

  return (
    <div className="browse-page">
      <aside className="browse-sidebar">
        <div className="filter-section">
          <h3 className="filter-heading">Categories</h3>
          <ul className="filter-list">
            <li
              className={`filter-item ${!selectedCategory ? 'active' : ''}`}
              onClick={() => updateFilter('category', '')}
            >
              All
            </li>
            {categories.map((cat) => {
              const name = typeof cat === 'string' ? cat : cat.name;
              return (
                <li
                  key={name}
                  className={`filter-item ${selectedCategory === name ? 'active' : ''}`}
                  onClick={() => updateFilter('category', name)}
                >
                  {name}
                </li>
              );
            })}
          </ul>
        </div>

        <div className="filter-section">
          <h3 className="filter-heading">Platform</h3>
          <div className="platform-filters">
            {['', 'PS5', 'PS4'].map((p) => (
              <button
                key={p}
                className={`platform-btn ${selectedPlatform === p ? 'active' : ''}`}
                onClick={() => updateFilter('platform', p)}
              >
                {p || 'All'}
              </button>
            ))}
          </div>
        </div>

        <div className="filter-section">
          <label className="sale-toggle">
            <input
              type="checkbox"
              checked={onSale}
              onChange={(e) => updateFilter('on_sale', e.target.checked ? 'true' : '')}
            />
            <span>On Sale</span>
          </label>
        </div>
      </aside>

      <main className="browse-main">
        <h1 className="browse-heading">Browse Games</h1>

        {loading && <div className="loading-spinner">Loading...</div>}
        {error && <div className="error-message">{error}</div>}

        {!loading && !error && games.length === 0 && (
          <div className="empty-state">No games found matching your filters.</div>
        )}

        {!loading && games.length > 0 && <GameGrid games={games} />}

        {!loading && totalPages > 1 && (
          <div className="pagination">
            <button
              className="pagination-btn"
              disabled={page <= 1}
              onClick={() => updateFilter('page', String(page - 1))}
            >
              Previous
            </button>
            <span className="pagination-info">
              Page {page} of {totalPages}
            </span>
            <button
              className="pagination-btn"
              disabled={page >= totalPages}
              onClick={() => updateFilter('page', String(page + 1))}
            >
              Next
            </button>
          </div>
        )}
      </main>
    </div>
  );
}
