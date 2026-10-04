from __future__ import annotations

from enum import StrEnum


class ErrorCode(StrEnum):
    VALIDATION_FAILED = "validation_failed"
    INVALID_CREDENTIALS = "invalid_credentials"
    EMAIL_ALREADY_REGISTERED = "email_already_registered"
    EMAIL_NOT_VERIFIED = "email_not_verified"
    INVALID_TOKEN = "invalid_token"
    TOKEN_EXPIRED = "token_expired"
    TOKEN_REVOKED = "token_revoked"
    RATE_LIMITED = "rate_limited"
    NOT_FOUND = "not_found"
    FORBIDDEN = "forbidden"
    CONFLICT = "conflict"
    PIN_REQUIRED = "pin_required"
    INVALID_PIN = "invalid_pin"
    WEAK_PASSWORD = "weak_password"
    BILLING_DISABLED = "billing_disabled"


class ParentSafeMessage(StrEnum):
    GENERIC = "Something went wrong. Please try again."
    INVALID_CREDENTIALS = "We could not sign you in. Please check and try again."
    EMAIL_ALREADY_REGISTERED = "That email is already registered. Try signing in."
    EMAIL_NOT_VERIFIED = "Please confirm your email address first."
    INVALID_TOKEN = "That link is not valid any more. Please start again."
    TOKEN_EXPIRED = "That link has expired. Please start again."
    RATE_LIMITED = "Too many tries. Please wait a little and try again."
    WEAK_PASSWORD = "Please choose a stronger password."
    PIN_REQUIRED = "A grown-up PIN is needed for this."
    INVALID_PIN = "That PIN is not right."
    FORBIDDEN = "This belongs to another family account."
    NOT_FOUND = "We could not find that."
