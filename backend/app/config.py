from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_UNSAFE_SECRETS = {"", "change-me", "changeme", "secret", "dev-secret"}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    environment: Literal["local", "test", "staging", "production"] = "local"
    database_url: str = "sqlite+aiosqlite:///./school_learning.db"
    test_database_url: str = "sqlite+aiosqlite:///:memory:"

    jwt_signing_secret: str = ""
    access_token_ttl_seconds: int = Field(default=900, ge=60, le=3600)
    refresh_token_ttl_seconds: int = Field(default=2_592_000, ge=3600)
    issuer: str = "school-learning"

    cors_origins: list[str] = Field(default_factory=list)

    openai_api_key: str | None = None
    openai_model: str = "gpt-4o-mini"

    free_mode: bool = True
    billing_enabled: bool = False

    login_rate_limit_attempts: int = Field(default=5, ge=1)
    login_rate_limit_window_seconds: int = Field(default=300, ge=1)
    password_reset_rate_limit_attempts: int = Field(default=3, ge=1)
    password_reset_rate_limit_window_seconds: int = Field(default=900, ge=1)

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _split_origins(cls, value: object) -> object:
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return value

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def signing_secret(self) -> str:
        secret = self.jwt_signing_secret
        if self.environment in {"local", "test"}:
            return secret or "local-development-only-signing-secret"
        if secret.strip().lower() in _UNSAFE_SECRETS:
            raise ValueError(
                "JWT_SIGNING_SECRET must be set to a strong value outside "
                "local and test environments."
            )
        return secret

    def database_url_for(self, *, testing: bool) -> str:
        return self.test_database_url if testing else self.database_url


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()


def reset_settings_cache() -> None:
    get_settings.cache_clear()
