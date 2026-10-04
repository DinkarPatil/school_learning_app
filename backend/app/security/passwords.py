from __future__ import annotations

import hashlib
import secrets
from typing import Final

from argon2 import PasswordHasher, Type
from argon2.exceptions import InvalidHashError, VerifyMismatchError

_hasher: Final[PasswordHasher] = PasswordHasher(
    time_cost=3,
    memory_cost=65_536,
    parallelism=4,
    hash_len=32,
    salt_len=16,
    type=Type.ID,
)


class PasswordPolicyError(ValueError):
    """The supplied secret does not meet the minimum policy."""


def hash_secret(secret: str) -> str:
    return _hasher.hash(secret)


def verify_secret(secret: str, stored_hash: str) -> bool:
    try:
        return _hasher.verify(stored_hash, secret)
    except (VerifyMismatchError, InvalidHashError):
        return False


def needs_rehash(stored_hash: str) -> bool:
    try:
        return _hasher.check_needs_rehash(stored_hash)
    except InvalidHashError:
        return True


def dummy_verify() -> None:
    """Spends comparable work to a real verification for unknown accounts."""
    try:
        _hasher.verify(_DUMMY_HASH, "not-a-real-password")
    except (VerifyMismatchError, InvalidHashError):
        return


_DUMMY_HASH = _hasher.hash("a-password-that-no-one-can-guess")


def validate_password_strength(password: str) -> None:
    if len(password) < 10:
        raise PasswordPolicyError("Password must be at least 10 characters.")
    if len(password) > 200:
        raise PasswordPolicyError("Password must be at most 200 characters.")
    if not any(character.islower() for character in password):
        raise PasswordPolicyError("Password must include a lowercase letter.")
    if not any(character.isupper() for character in password):
        raise PasswordPolicyError("Password must include an uppercase letter.")
    if not any(character.isdigit() for character in password):
        raise PasswordPolicyError("Password must include a digit.")


def validate_pin_format(pin: str) -> None:
    if not pin.isdigit():
        raise PasswordPolicyError("PIN must contain digits only.")
    if len(pin) < 4 or len(pin) > 8:
        raise PasswordPolicyError("PIN must be between 4 and 8 digits.")


def generate_opaque_token(byte_length: int = 32) -> str:
    return secrets.token_urlsafe(byte_length)


def hash_opaque_token(token: str) -> str:
    return _sha256_hex(token)


def _sha256_hex(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()
