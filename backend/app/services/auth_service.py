from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.db.base import utc_now
from app.models import ChildProfile, ParentAccount, RefreshToken, new_id
from app.schemas.auth import LoginRequest, SignupRequest
from app.security import passwords, tokens
from app.security.tokens import TokenError


class AuthError(Exception):
    def __init__(self, code: str, http_status: int = 400) -> None:
        super().__init__(code)
        self.code = code
        self.http_status = http_status


@dataclass(frozen=True, slots=True)
class AuthenticatedSession:
    account: ParentAccount
    access_token: str
    refresh_token: str
    access_expires_in: int
    refresh_expires_in: int


def _pair(account: ParentAccount, settings: Settings) -> tuple[str, str, str, str]:
    access = tokens.issue_access_token(subject=account.id, settings=settings)
    refresh = tokens.issue_refresh_token(
        subject=account.id, family=tokens.new_token_family(), settings=settings
    )
    return access.token, refresh.token, refresh.family, refresh.jti


async def _store_refresh_token(
    session: AsyncSession,
    *,
    account_id: str,
    token_id: str,
    family: str,
    expires_at: datetime,
) -> None:
    session.add(
        RefreshToken(
            id=token_id,
            parent_account_id=account_id,
            token_family=family,
            expires_at=expires_at,
        )
    )


async def create_account(
    session: AsyncSession,
    request: SignupRequest,
    settings: Settings,
) -> tuple[ParentAccount, str, str]:
    email = request.email.lower()
    existing = await session.scalar(
        select(ParentAccount).where(ParentAccount.email == email)
    )
    if existing is not None:
        raise AuthError("email_already_registered", 409)

    try:
        passwords.validate_password_strength(request.password)
    except passwords.PasswordPolicyError as error:
        raise AuthError("weak_password", 422) from error

    account = ParentAccount(
        id=new_id(),
        email=email,
        password_hash=passwords.hash_secret(request.password),
        preferred_language=request.preferred_language,
        email_verified=False,
    )
    session.add(account)

    if request.display_name:
        session.add(
            ChildProfile(
                id=new_id(),
                parent_account_id=account.id,
                display_name=request.display_name.strip(),
                avatar_id="star",
                preferred_language=request.preferred_language,
                age_band=None,
            )
        )

    access_token, refresh_token, family, refresh_jti = _pair(account, settings)
    await _store_refresh_token(
        session,
        account_id=account.id,
        token_id=refresh_jti,
        family=family,
        expires_at=utc_now() + timedelta(seconds=settings.refresh_token_ttl_seconds),
    )
    await session.commit()
    await session.refresh(account)
    return account, access_token, refresh_token


async def authenticate(
    session: AsyncSession, request: LoginRequest, settings: Settings
) -> tuple[ParentAccount, str, str]:
    email = request.email.lower()
    account = await session.scalar(
        select(ParentAccount).where(ParentAccount.email == email)
    )
    if account is None:
        passwords.dummy_verify()
        raise AuthError("invalid_credentials", 401)

    if not passwords.verify_secret(request.password, account.password_hash):
        raise AuthError("invalid_credentials", 401)

    if passwords.needs_rehash(account.password_hash):
        account.password_hash = passwords.hash_secret(request.password)

    access_token, refresh_token, family, refresh_jti = _pair(account, settings)
    await _store_refresh_token(
        session,
        account_id=account.id,
        token_id=refresh_jti,
        family=family,
        expires_at=utc_now() + timedelta(seconds=settings.refresh_token_ttl_seconds),
    )
    await session.commit()
    return account, access_token, refresh_token


async def _revoke_family(
    session: AsyncSession, family: str, *, except_token_id: str | None = None
) -> int:
    result = await session.execute(
        select(RefreshToken).where(
            RefreshToken.token_family == family,
            RefreshToken.revoked_at.is_(None),
        )
    )
    revoked = 0
    now = utc_now()
    for record in result.scalars().all():
        if except_token_id is not None and record.id == except_token_id:
            continue
        record.revoked_at = now
        revoked += 1
    return revoked


async def rotate_refresh_token(
    session: AsyncSession, refresh_token: str, settings: Settings
) -> tuple[ParentAccount, str, str]:
    try:
        decoded = tokens.decode_token(
            refresh_token, expected_type="refresh", settings=settings
        )
    except TokenError as error:
        raise AuthError("invalid_token", 401) from error

    record = await session.scalar(
        select(RefreshToken).where(RefreshToken.id == decoded.jti)
    )
    if record is None:
        raise AuthError("invalid_token", 401)

    if record.revoked_at is not None:
        await _revoke_family(session, record.token_family)
        await session.commit()
        raise AuthError("token_revoked", 401)

    if decoded.family is None or decoded.family != record.token_family:
        raise AuthError("invalid_token", 401)

    if record.expires_at <= utc_now():
        record.revoked_at = utc_now()
        await session.commit()
        raise AuthError("token_expired", 401)

    account = await session.scalar(
        select(ParentAccount).where(ParentAccount.id == record.parent_account_id)
    )
    if account is None:
        raise AuthError("invalid_token", 401)

    new_access = tokens.issue_access_token(subject=account.id, settings=settings)
    rotated = tokens.issue_refresh_token(
        subject=account.id, family=record.token_family, settings=settings
    )
    record.revoked_at = utc_now()
    record.replaced_by_id = rotated.jti
    await _store_refresh_token(
        session,
        account_id=account.id,
        token_id=rotated.jti,
        family=record.token_family,
        expires_at=utc_now() + timedelta(seconds=settings.refresh_token_ttl_seconds),
    )
    await session.commit()
    return account, new_access.token, rotated.token


async def revoke_refresh_token(
    session: AsyncSession, refresh_token: str, settings: Settings
) -> bool:
    try:
        decoded = tokens.decode_token(
            refresh_token, expected_type="refresh", settings=settings
        )
    except TokenError:
        return False

    record = await session.scalar(
        select(RefreshToken).where(RefreshToken.id == decoded.jti)
    )
    if record is None or record.revoked_at is not None:
        return False
    record.revoked_at = utc_now()
    await session.commit()
    return True
