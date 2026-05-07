import os
import sys

import httpx
import pytest

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from app.services.order_client import get_game_stats, get_popular_game_ids
from app.services.user_client import validate_admin


class _StubResponse:
    def __init__(self, json_data, raise_error: Exception | None = None):
        self._json_data = json_data
        self._raise_error = raise_error

    def raise_for_status(self):
        if self._raise_error:
            raise self._raise_error

    def json(self):
        return self._json_data


class _StubAsyncClient:
    def __init__(self, response: _StubResponse):
        self._response = response

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def get(self, _url: str):
        return self._response


@pytest.mark.asyncio
async def test_validate_admin_true(monkeypatch):
    stub = _StubAsyncClient(_StubResponse({"is_admin": True}))
    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout=5.0: stub)

    assert await validate_admin("00000000-0000-0000-0000-000000000000") is True


@pytest.mark.asyncio
async def test_validate_admin_false_on_exception(monkeypatch):
    stub = _StubAsyncClient(_StubResponse({}, raise_error=RuntimeError("boom")))
    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout=5.0: stub)

    assert await validate_admin("00000000-0000-0000-0000-000000000000") is False


@pytest.mark.asyncio
async def test_get_game_stats_defaults_on_error(monkeypatch):
    stub = _StubAsyncClient(_StubResponse({}, raise_error=RuntimeError("boom")))
    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout=5.0: stub)

    assert await get_game_stats("00000000-0000-0000-0000-000000000000") == {"purchase_count": 0}


@pytest.mark.asyncio
async def test_get_popular_game_ids_filters_payload(monkeypatch):
    stub = _StubAsyncClient(
        _StubResponse(
            {
                "games": [
                    {"game_id": "a"},
                    {"game_id": "b"},
                    {"nope": "c"},
                ]
            }
        )
    )
    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout=5.0: stub)

    assert await get_popular_game_ids() == ["a", "b"]

