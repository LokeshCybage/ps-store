import httpx

from app.config import ORDER_SERVICE_URL


async def get_game_stats(game_id: str) -> dict:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{ORDER_SERVICE_URL}/internal/orders/games/{game_id}/stats")
            resp.raise_for_status()
            return resp.json()
    except Exception:
        return {"purchase_count": 0}


async def get_popular_game_ids() -> list[str]:
    """Fetches most-purchased game IDs from the Order Service."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(
                f"{ORDER_SERVICE_URL}/internal/orders/popular",
            )
            resp.raise_for_status()
            data = resp.json()
            games = data.get("games", [])
            return [g["game_id"] for g in games if "game_id" in g]
    except Exception:
        return []
