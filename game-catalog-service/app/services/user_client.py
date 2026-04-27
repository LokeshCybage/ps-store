import httpx

from app.config import USER_SERVICE_URL


async def validate_admin(user_id: str) -> bool:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{USER_SERVICE_URL}/internal/users/{user_id}/validate")
            resp.raise_for_status()
            data = resp.json()
            return data.get("is_admin", False) is True
    except Exception:
        return False
