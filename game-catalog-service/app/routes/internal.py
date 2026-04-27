from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func as sa_func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.game import Game, Review
from app.schemas.game import GameBatchRequest, GameInternal

router = APIRouter()


def _attach_internal_ratings(game_out, db: Session, game_id):
    """Attach avg_rating and review_count to a GameInternal response."""
    result = db.query(
        sa_func.avg(Review.rating).label("avg_rating"),
        sa_func.count(Review.id).label("review_count"),
    ).filter(Review.game_id == game_id).first()
    game_out.avg_rating = (
        round(float(result.avg_rating), 1) if result.avg_rating else None
    )
    game_out.review_count = result.review_count or 0
    return game_out


def _attach_internal_ratings_bulk(game_outs: list, db: Session):
    """Attach ratings for a list of GameInternal in one query."""
    if not game_outs:
        return game_outs

    game_ids = [g.id for g in game_outs]
    rows = (
        db.query(
            Review.game_id,
            sa_func.avg(Review.rating).label("avg_rating"),
            sa_func.count(Review.id).label("review_count"),
        )
        .filter(Review.game_id.in_(game_ids))
        .group_by(Review.game_id)
        .all()
    )
    rating_map = {
        row.game_id: (round(float(row.avg_rating), 1), row.review_count)
        for row in rows
    }

    for g in game_outs:
        if g.id in rating_map:
            g.avg_rating, g.review_count = rating_map[g.id]
        else:
            g.avg_rating = None
            g.review_count = 0
    return game_outs


@router.get("/internal/games/{game_id}", response_model=GameInternal)
def get_game_internal(game_id: UUID, db: Session = Depends(get_db)):
    game = db.query(Game).filter(Game.id == game_id).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")
    result = GameInternal.model_validate(game)
    _attach_internal_ratings(result, db, game_id)
    return result


@router.post("/internal/games/batch", response_model=list[GameInternal])
def get_games_batch(body: GameBatchRequest, db: Session = Depends(get_db)):
    uuid_ids = []
    for gid in body.game_ids:
        try:
            uuid_ids.append(UUID(gid))
        except ValueError:
            continue

    if not uuid_ids:
        return []

    games = db.query(Game).filter(Game.id.in_(uuid_ids)).all()
    game_outs = [GameInternal.model_validate(g) for g in games]
    _attach_internal_ratings_bulk(game_outs, db)
    return game_outs
