from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any, Final, Literal

import jwt
from jwt.exceptions import InvalidTokenError

from app.config import Settings

ACCESS_TOKEN_TYPE: Final = "access"
REFRESH_TOKEN_TYPE: Final = "refresh"


class TokenError(ValueError):
    """The token is missing, malformed, expired, or of the wrong type."""


@dataclass(frozen=True, slots=True)
class IssuedToken:
    token: str
    jti: str
    family: str
    issued_at: datetime
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class DecodedToken:
    subject: str
    jti: str
    family: str | None
    token_type: str
    issued_at: datetime
    expires_at: datetime


def _now() -> datetime:
    return datetime.now(UTC)


def _encode(
    *,
    subject: str,
    jti: str,
    token_type: str,
    ttl_seconds: int,
    settings: Settings,
    family: str | None = None,
) -> IssuedToken:
    issued_at = _now()
    expires_at = issued_at + timedelta(seconds=ttl_seconds)
    claims: dict[str, Any] = {
        "sub": subject,
        "jti": jti,
        "typ": token_type,
        "iss": settings.issuer,
        "iat": int(issued_at.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    if family is not None:
        claims["fam"] = family
    token = jwt.encode(
        claims, settings.signing_secret, algorithm="HS256", headers={"typ": "JWT"}
    )
    return IssuedToken(
        token=token,
        jti=jti,
        family=family or "",
        issued_at=issued_at,
        expires_at=expires_at,
    )


def issue_access_token(*, subject: str, settings: Settings) -> IssuedToken:
    return _encode(
        subject=subject,
        jti=uuid.uuid4().hex,
        token_type=ACCESS_TOKEN_TYPE,
        ttl_seconds=settings.access_token_ttl_seconds,
        settings=settings,
    )


def issue_refresh_token(
    *, subject: str, family: str, settings: Settings
) -> IssuedToken:
    return _encode(
        subject=subject,
        jti=uuid.uuid4().hex,
        token_type=REFRESH_TOKEN_TYPE,
        ttl_seconds=settings.refresh_token_ttl_seconds,
        settings=settings,
        family=family,
    )


def new_token_family() -> str:
    return uuid.uuid4().hex


def decode_token(
    token: str,
    *,
    expected_type: Literal["access", "refresh"],
    settings: Settings,
) -> DecodedToken:
    if not token:
        raise TokenError("Token is missing.")
    try:
        claims = jwt.decode(
            token,
            settings.signing_secret,
            algorithms=["HS256"],
            issuer=settings.issuer,
            options={"require": ["exp", "iat", "sub", "jti", "typ"]},
        )
    except InvalidTokenError as error:
        raise TokenError("Token is not valid.") from error

    token_type = claims.get("typ")
    if token_type != expected_type:
        raise TokenError("Token is of the wrong type.")

    subject = claims.get("sub")
    jti = claims.get("jti")
    if not isinstance(subject, str) or not isinstance(jti, str):
        raise TokenError("Token is missing required claims.")

    expires_at = datetime.fromtimestamp(int(claims["exp"]), tz=UTC)
    issued_at = datetime.fromtimestamp(int(claims["iat"]), tz=UTC)
    family = claims.get("fam")

    return DecodedToken(
        subject=subject,
        jti=jti,
        family=family if isinstance(family, str) else None,
        token_type=token_type,
        issued_at=issued_at,
        expires_at=expires_at,
    )
