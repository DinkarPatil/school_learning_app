from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import StaticPool

_engine: AsyncEngine | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None


def _normalise_url(url: str) -> str:
    if url.startswith("postgres://"):
        return "postgresql+asyncpg://" + url.removeprefix("postgres://")
    if url.startswith("postgresql://"):
        return "postgresql+asyncpg://" + url.removeprefix("postgresql://")
    if url.startswith("sqlite://") and ":memory:" in url:
        return "sqlite+aiosqlite:///:memory:"
    if url.startswith("sqlite:///"):
        return "sqlite+aiosqlite:///" + url.removeprefix("sqlite:///")
    return url


def create_engine(url: str) -> AsyncEngine:
    normalised = _normalise_url(url)
    if ":memory:" in normalised:
        return create_async_engine(
            normalised,
            poolclass=StaticPool,
            connect_args={"check_same_thread": False},
        )
    return create_async_engine(normalised, pool_pre_ping=True)


def configure(url: str) -> AsyncEngine:
    global _engine, _session_factory
    _engine = create_engine(url)
    _session_factory = async_sessionmaker(
        _engine, expire_on_commit=False, class_=AsyncSession
    )
    return _engine


def get_engine() -> AsyncEngine:
    if _engine is None:
        raise RuntimeError("The database engine has not been configured.")
    return _engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    if _session_factory is None:
        raise RuntimeError("The database engine has not been configured.")
    return _session_factory


async def get_session() -> AsyncIterator[AsyncSession]:
    async with get_session_factory()() as session:
        yield session


@asynccontextmanager
async def session_scope() -> AsyncIterator[AsyncSession]:
    async with get_session_factory()() as session:
        yield session


async def create_schema() -> None:
    from app import models  # noqa: F401
    from app.db.base import metadata

    async with get_engine().begin() as connection:
        await connection.run_sync(metadata.create_all)


async def dispose_engine() -> None:
    global _engine, _session_factory
    if _engine is not None:
        await _engine.dispose()
    _engine = None
    _session_factory = None
