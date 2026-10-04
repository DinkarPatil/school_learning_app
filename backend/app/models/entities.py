from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, ForeignKey, Index, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

from app.db.base import UtcDateTime, metadata, utc_now


class Base(DeclarativeBase):
    metadata = metadata


def new_id() -> str:
    return uuid.uuid4().hex


class ParentAccount(Base):
    __tablename__ = "parent_accounts"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    email: Mapped[str] = mapped_column(String(320), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    preferred_language: Mapped[str] = mapped_column(String(16), nullable=False)
    email_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime, default=utc_now, onupdate=utc_now
    )

    profiles: Mapped[list[ChildProfile]] = relationship(
        back_populates="parent", cascade="all, delete-orphan", lazy="selectin"
    )


class ChildProfile(Base):
    __tablename__ = "child_profiles"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    parent_account_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("parent_accounts.id", ondelete="CASCADE"), nullable=False
    )
    display_name: Mapped[str] = mapped_column(String(64), nullable=False)
    avatar_id: Mapped[str] = mapped_column(String(32), nullable=False)
    preferred_language: Mapped[str] = mapped_column(String(16), nullable=False)
    age_band: Mapped[str | None] = mapped_column(String(16), nullable=True)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime, default=utc_now, onupdate=utc_now
    )

    parent: Mapped[ParentAccount] = relationship(back_populates="profiles")

    __table_args__ = (
        Index("ix_child_profiles_parent_account_id", "parent_account_id"),
    )


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    parent_account_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("parent_accounts.id", ondelete="CASCADE"), nullable=False
    )
    token_family: Mapped[str] = mapped_column(String(32), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(UtcDateTime, nullable=True)
    replaced_by_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utc_now)

    __table_args__ = (
        Index("ix_refresh_tokens_parent_account_id", "parent_account_id"),
        Index("ix_refresh_tokens_token_family", "token_family"),
    )


class EmailVerification(Base):
    __tablename__ = "email_verifications"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    parent_account_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("parent_accounts.id", ondelete="CASCADE"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(UtcDateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utc_now)

    __table_args__ = (
        Index("ix_email_verifications_parent_account_id", "parent_account_id"),
    )


class PasswordReset(Base):
    __tablename__ = "password_resets"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    parent_account_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("parent_accounts.id", ondelete="CASCADE"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(UtcDateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utc_now)

    __table_args__ = (
        Index("ix_password_resets_parent_account_id", "parent_account_id"),
    )


class AuditNote(Base):
    __tablename__ = "audit_notes"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    parent_account_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    event: Mapped[str] = mapped_column(String(64), nullable=False)
    detail: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utc_now)


metadata_obj = metadata
