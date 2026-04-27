from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    created_at: datetime


class GameCreate(BaseModel):
    title: str
    description: Optional[str] = None
    price: Decimal
    sale_price: Optional[Decimal] = None
    image_url: Optional[str] = None
    platform: str
    category_id: UUID
    publisher: Optional[str] = None
    release_date: Optional[date] = None
    is_free: bool = False


class GameUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    price: Optional[Decimal] = None
    sale_price: Optional[Decimal] = None
    image_url: Optional[str] = None
    platform: Optional[str] = None
    category_id: Optional[UUID] = None
    publisher: Optional[str] = None
    release_date: Optional[date] = None
    is_free: Optional[bool] = None


class ReviewCreate(BaseModel):
    game_id: UUID
    rating: int
    review_text: Optional[str] = None


class ReviewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    game_id: UUID
    user_id: UUID
    username: str
    rating: int
    review_text: Optional[str] = None
    created_at: datetime


class GameOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    description: Optional[str] = None
    price: Decimal
    sale_price: Optional[Decimal] = None
    image_url: Optional[str] = None
    platform: str
    category_id: UUID
    publisher: Optional[str] = None
    release_date: Optional[date] = None
    is_free: bool
    created_at: datetime
    category: Optional[CategoryOut] = None
    avg_rating: Optional[float] = None
    review_count: int = 0


class GameDetail(GameOut):
    purchase_count: int = 0
    reviews: list[ReviewOut] = []


class GameInternal(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    description: Optional[str] = None
    price: Decimal
    sale_price: Optional[Decimal] = None
    image_url: Optional[str] = None
    platform: str
    publisher: Optional[str] = None
    is_free: bool
    avg_rating: Optional[float] = None
    review_count: int = 0


class GameBatchRequest(BaseModel):
    game_ids: list[str]


class FeaturedResponse(BaseModel):
    deals: list[GameOut]
    trending: list[GameOut]
