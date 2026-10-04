from __future__ import annotations

import time
from collections import defaultdict, deque
from collections.abc import Awaitable, Callable
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.responses import JSONResponse

from app.config import Settings, get_settings
from app.db.session import get_session
from app.models import ParentAccount
from app.schemas.errors import ErrorCode, ParentSafeMessage
from app.security import tokens
from app.security.tokens import TokenError
from app.services.auth_service import AuthError

SessionDep = Annotated[AsyncSession, Depends(get_session)]
SettingsDep = Annotated[Settings, Depends(get_settings)]

_MAX_TRACKED_CLIENTS = 10_000


class SlidingWindowLimiter:
    """In-process sliding window limiter.

    Adequate for a single worker and for tests. A multi-worker deployment needs a
    shared store, otherwise the effective limit multiplies by the worker count.
    """

    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def check(self, key: str, *, limit: int, window_seconds: int) -> bool:
        now = time.monotonic()
        bucket = self._hits[key]
        cutoff = now - window_seconds
        while bucket and bucket[0] <= cutoff:
            bucket.popleft()
        if len(bucket) >= limit:
            return False
        bucket.append(now)
        if len(self._hits) > _MAX_TRACKED_CLIENTS:
            self._evict_idle(cutoff)
        return True

    def reset(self, key: str) -> None:
        self._hits.pop(key, None)

    def clear(self) -> None:
        self._hits.clear()

    def _evict_idle(self, cutoff: float) -> None:
        stale = [
            key
            for key, bucket in self._hits.items()
            if not bucket or bucket[-1] <= cutoff
        ]
        for key in stale:
            del self._hits[key]


_limiter = SlidingWindowLimiter()


def get_limiter() -> SlidingWindowLimiter:
    return _limiter


def client_key(request: Request, scope: str) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return f"{scope}:{forwarded.split(',')[0].strip()}"
    client = request.client
    return f"{scope}:{client.host if client else 'unknown'}"


def rate_limited_response() -> JSONResponse:
    return JSONResponse(
        status_code=429,
        content={
            "code": ErrorCode.RATE_LIMITED.value,
            "message": ParentSafeMessage.RATE_LIMITED.value,
        },
    )


RateLimitDependency = Callable[[Request], Awaitable[JSONResponse | None]]


class RateLimitExceededError(Exception):
    def __init__(self, scope: str) -> None:
        super().__init__(scope)
        self.scope = scope


def enforce_rate_limit(
    request: Request,
    *,
    scope: str,
    attempts: int,
    window_seconds: int,
) -> None:
    if not _limiter.check(
        client_key(request, scope), limit=attempts, window_seconds=window_seconds
    ):
        raise RateLimitExceededError(scope)


def reset_rate_limit(request: Request, *, scope: str) -> None:
    client = request.client
    _limiter.reset(f"{scope}:{client.host if client else 'unknown'}")


_bearer = HTTPBearer(auto_error=False)


async def require_account(
    session: SessionDep,
    settings: SettingsDep,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(_bearer)
    ] = None,
) -> ParentAccount:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AuthError("invalid_token", 401)
    try:
        decoded = tokens.decode_token(
            credentials.credentials, expected_type="access", settings=settings
        )
    except TokenError as error:
        raise AuthError("invalid_token", 401) from error

    account = await session.scalar(
        select(ParentAccount).where(ParentAccount.id == decoded.subject)
    )
    if account is None:
        raise AuthError("invalid_token", 401)
    return account


CurrentAccount = Annotated[ParentAccount, Depends(require_account)]

__all__ = [
    "CurrentAccount",
    "RateLimitExceededError",
    "SessionDep",
    "SettingsDep",
    "SlidingWindowLimiter",
    "client_key",
    "enforce_rate_limit",
    "get_limiter",
    "rate_limited_response",
    "require_account",
    "reset_rate_limit",
]
