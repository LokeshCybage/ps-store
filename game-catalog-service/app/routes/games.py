from typing import Optional
from uuid import UUID

import jwt
from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import func as sa_func
from sqlalchemy.orm import Session, joinedload

from app.config import JWT_SECRET
from app.database import get_db
from app.models.game import Category, Game, Review
from app.schemas.game import (
    CategoryOut,
    FeaturedResponse,
    GameCreate,
    GameDetail,
    GameOut,
    GameUpdate,
    ReviewCreate,
    ReviewOut,
)
from app.services.order_client import get_game_stats, get_popular_game_ids
from app.services.user_client import validate_admin

router = APIRouter()


def _attach_ratings(game_out, db: Session, game_id):
    """Compute and attach avg_rating and review_count to a game schema."""
    result = db.query(
        sa_func.avg(Review.rating).label("avg_rating"),
        sa_func.count(Review.id).label("review_count"),
    ).filter(Review.game_id == game_id).first()
    game_out.avg_rating = (
        round(float(result.avg_rating), 1) if result.avg_rating else None
    )
    game_out.review_count = result.review_count or 0
    return game_out


def _attach_ratings_bulk(game_outs: list, db: Session):
    """Attach avg_rating and review_count for a list of games in one query."""
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


def _extract_user_id(authorization: str) -> str:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    token = authorization[7:]
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token: missing sub claim")
        return user_id
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


@router.get("/health")
def health_check():
    return {"status": "healthy", "service": "game-catalog-service"}


@router.get("/api/categories", response_model=list[CategoryOut])
def list_categories(db: Session = Depends(get_db)):
    return db.query(Category).order_by(Category.name).all()


@router.get("/api/games/featured", response_model=FeaturedResponse)
async def featured_games(db: Session = Depends(get_db)):
    deals = (
        db.query(Game)
        .options(joinedload(Game.category))
        .filter(Game.sale_price.isnot(None))
        .limit(10)
        .all()
    )

    trending: list[Game] = []
    popular_ids = await get_popular_game_ids()
    if popular_ids:
        try:
            uuid_ids = [UUID(gid) for gid in popular_ids[:10]]
            trending = (
                db.query(Game)
                .options(joinedload(Game.category))
                .filter(Game.id.in_(uuid_ids))
                .all()
            )
        except (ValueError, Exception):
            trending = []

    deal_outs = [GameOut.model_validate(g) for g in deals]
    trend_outs = [GameOut.model_validate(g) for g in trending]
    _attach_ratings_bulk(deal_outs, db)
    _attach_ratings_bulk(trend_outs, db)
    return FeaturedResponse(deals=deal_outs, trending=trend_outs)


@router.get("/api/games", response_model=list[GameOut])
def list_games(
    category: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    platform: Optional[str] = Query(None),
    on_sale: Optional[bool] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    query = db.query(Game).options(joinedload(Game.category))

    if category:
        query = query.join(Category).filter(Category.name.ilike(f"%{category}%"))

    if search:
        query = query.filter(
            Game.title.ilike(f"%{search}%") | Game.description.ilike(f"%{search}%")
        )

    if platform:
        query = query.filter(Game.platform.ilike(f"%{platform}%"))

    if on_sale:
        query = query.filter(Game.sale_price.isnot(None))

    offset = (page - 1) * limit
    games = query.order_by(Game.created_at.desc()).offset(offset).limit(limit).all()
    game_outs = [GameOut.model_validate(g) for g in games]
    _attach_ratings_bulk(game_outs, db)
    return game_outs


@router.get(
    "/api/games/{game_id}/reviews", response_model=list[ReviewOut]
)
def get_game_reviews(
    game_id: UUID,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    """Get paginated reviews for a game, ordered by newest first."""
    game = db.query(Game).filter(Game.id == game_id).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")

    offset = (page - 1) * limit
    reviews = (
        db.query(Review)
        .filter(Review.game_id == game_id)
        .order_by(Review.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return [ReviewOut.model_validate(r) for r in reviews]


@router.post(
    "/api/games/{game_id}/reviews",
    response_model=ReviewOut,
    status_code=201,
)
def create_review(
    game_id: UUID,
    review_data: ReviewCreate,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
):
    """Submit a review for a game (one per user per game)."""
    user_id_str = _extract_user_id(authorization)
    token = authorization[7:]
    payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    username = payload.get("username", "Anonymous")

    game = db.query(Game).filter(Game.id == game_id).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")

    if review_data.rating < 1 or review_data.rating > 5:
        raise HTTPException(
            status_code=400, detail="Rating must be between 1 and 5"
        )

    existing = (
        db.query(Review)
        .filter(
            Review.game_id == game_id,
            Review.user_id == UUID(user_id_str),
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=409,
            detail="You have already reviewed this game",
        )

    review = Review(
        game_id=game_id,
        user_id=UUID(user_id_str),
        username=username,
        rating=review_data.rating,
        review_text=review_data.review_text,
    )
    db.add(review)
    db.commit()
    db.refresh(review)
    return ReviewOut.model_validate(review)


@router.get("/api/games/{game_id}", response_model=GameDetail)
async def get_game(game_id: UUID, db: Session = Depends(get_db)):
    game = (
        db.query(Game)
        .options(joinedload(Game.category))
        .filter(Game.id == game_id)
        .first()
    )
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")

    stats = await get_game_stats(str(game_id))
    result = GameDetail.model_validate(game)
    result.purchase_count = stats.get("purchase_count", 0)
    _attach_ratings(result, db, game_id)

    recent_reviews = (
        db.query(Review)
        .filter(Review.game_id == game_id)
        .order_by(Review.created_at.desc())
        .limit(20)
        .all()
    )
    result.reviews = [ReviewOut.model_validate(r) for r in recent_reviews]
    return result


@router.post("/api/games", response_model=GameOut, status_code=201)
async def create_game(
    game_data: GameCreate,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
):
    user_id = _extract_user_id(authorization)
    is_admin = await validate_admin(user_id)
    if not is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")

    cat = db.query(Category).filter(Category.id == game_data.category_id).first()
    if not cat:
        raise HTTPException(status_code=400, detail="Invalid category_id")

    game = Game(**game_data.model_dump())
    db.add(game)
    db.commit()
    db.refresh(game)

    return db.query(Game).options(joinedload(Game.category)).filter(Game.id == game.id).first()


@router.put("/api/games/{game_id}", response_model=GameOut)
async def update_game(
    game_id: UUID,
    game_data: GameUpdate,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
):
    user_id = _extract_user_id(authorization)
    is_admin = await validate_admin(user_id)
    if not is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")

    game = db.query(Game).filter(Game.id == game_id).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")

    update_fields = game_data.model_dump(exclude_unset=True)
    if "category_id" in update_fields:
        cat = db.query(Category).filter(Category.id == update_fields["category_id"]).first()
        if not cat:
            raise HTTPException(status_code=400, detail="Invalid category_id")

    for key, value in update_fields.items():
        setattr(game, key, value)

    db.commit()
    db.refresh(game)

    return db.query(Game).options(joinedload(Game.category)).filter(Game.id == game.id).first()


@router.delete("/api/games/{game_id}", status_code=204)
async def delete_game(
    game_id: UUID,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
):
    user_id = _extract_user_id(authorization)
    is_admin = await validate_admin(user_id)
    if not is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")

    game = db.query(Game).filter(Game.id == game_id).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")

    db.delete(game)
    db.commit()
    return None
