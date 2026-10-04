from __future__ import annotations

from collections.abc import AsyncIterator, Iterator

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import Settings, reset_settings_cache
from app.db.session import configure, create_schema, dispose_engine
from app.dependencies import get_limiter
from app.main import create_app


@pytest.fixture
def settings() -> Settings:
    return Settings(
        environment="test",
        database_url="sqlite+aiosqlite:///:memory:",
        test_database_url="sqlite+aiosqlite:///:memory:",
        jwt_signing_secret="test-signing-secret-not-for-production",
        access_token_ttl_seconds=900,
        refresh_token_ttl_seconds=3600,
        cors_origins=[],
        login_rate_limit_attempts=5,
        login_rate_limit_window_seconds=300,
    )


@pytest.fixture(autouse=True)
def _reset_caches() -> Iterator[None]:
    reset_settings_cache()
    get_limiter().clear()
    yield
    reset_settings_cache()
    get_limiter().clear()


@pytest.fixture
async def client(settings: Settings) -> AsyncIterator[AsyncClient]:
    reset_settings_cache()
    configure(settings.database_url_for(testing=True))
    await create_schema()
    application = create_app(settings)
    transport = ASGITransport(app=application)
    async with AsyncClient(transport=transport, base_url="http://test") as http:
        async with application.router.lifespan_context(application):
            yield http
    await dispose_engine()
