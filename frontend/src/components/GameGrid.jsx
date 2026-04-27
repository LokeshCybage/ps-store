import GameCard from './GameCard';
import './GameGrid.css';

export default function GameGrid({ games, title }) {
  if (!games || games.length === 0) return null;

  return (
    <section className="game-grid-section">
      {title && <h2 className="game-grid-title">{title}</h2>}
      <div className="game-grid">
        {games.map((game) => (
          <GameCard key={game.id} game={game} />
        ))}
      </div>
    </section>
  );
}
