from __future__ import annotations

from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

_LANGUAGES = ("en", "hi", "mr")


def _validate_language(value: str) -> str:
    normalised = value.strip().lower()
    if normalised not in _LANGUAGES:
        raise ValueError(f"language must be one of {', '.join(_LANGUAGES)}")
    return normalised


class SignupRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    email: EmailStr
    password: str = Field(min_length=10, max_length=200)
    preferred_language: str = "en"
    display_name: str | None = Field(default=None, max_length=80)

    @field_validator("preferred_language")
    @classmethod
    def _language(cls, value: str) -> str:
        return _validate_language(value)


class LoginRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    email: EmailStr
    password: str = Field(min_length=1, max_length=200)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1, max_length=4096)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=1, max_length=4096)


class VerifyEmailRequest(BaseModel):
    token: str = Field(min_length=1, max_length=4096)


class RequestPasswordResetRequest(BaseModel):
    email: EmailStr


class ConfirmPasswordResetRequest(BaseModel):
    token: str = Field(min_length=1, max_length=4096)
    new_password: str = Field(min_length=10, max_length=200)


class SetPinRequest(BaseModel):
    pin: str = Field(min_length=4, max_length=8)
    current_pin: str | None = Field(default=None, max_length=8)


class VerifyPinRequest(BaseModel):
    pin: str = Field(min_length=4, max_length=8)


class ParentAccountResponse(BaseModel):
    id: str
    email: EmailStr
    preferred_language: str
    email_verified: bool
    created_at: datetime


class TokenPairResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    refresh_expires_in: int


class SignupResponse(TokenPairResponse):
    account: ParentAccountResponse


class LoginResponse(TokenPairResponse):
    account: ParentAccountResponse


class LogoutResponse(BaseModel):
    revoked: bool


class MessageResponse(BaseModel):
    message: str


class VerifyEmailResponse(BaseModel):
    verified: bool
    email: EmailStr


class PinStatusResponse(BaseModel):
    pin_set: bool


class PinVerifyResponse(BaseModel):
    valid: bool


LanguageCode = Annotated[str, Field(min_length=2, max_length=3)]
