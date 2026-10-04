from __future__ import annotations

from typing import Any

import jwt
from httpx import AsyncClient

from app.config import Settings

SIGNUP = {
    "email": "Parent@Example.com",
    "password": "StrongPass123",
    "preferred_language": "en",
    "display_name": "Aarav",
}


async def _signup(client: AsyncClient, **overrides: Any) -> dict[str, Any]:
    payload = {**SIGNUP, **overrides}
    response = await client.post("/api/v1/auth/signup", json=payload)
    assert response.status_code == 201, response.text
    body: dict[str, Any] = response.json()
    return body


async def test_signup_creates_an_unverified_parent_and_returns_tokens(
    client: AsyncClient,
) -> None:
    body = await _signup(client)

    assert body["account"]["email"] == "parent@example.com"
    assert body["account"]["email_verified"] is False
    assert body["account"]["preferred_language"] == "en"
    assert body["token_type"] == "bearer"
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["expires_in"] > 0
    assert "password" not in body["account"]
    assert "password_hash" not in body["account"]


async def test_signup_rejects_a_duplicate_email(client: AsyncClient) -> None:
    await _signup(client)

    response = await client.post("/api/v1/auth/signup", json=SIGNUP)

    assert response.status_code == 409
    assert response.json()["code"] == "email_already_registered"
    assert "already registered" in response.json()["message"]


async def test_signup_rejects_a_weak_password(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/signup", json={**SIGNUP, "password": "short1A"}
    )

    assert response.status_code == 422


async def test_signup_rejects_an_unsupported_language(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/signup", json={**SIGNUP, "preferred_language": "fr"}
    )

    assert response.status_code == 422
    assert response.json()["code"] == "validation_failed"


async def test_signup_rejects_a_malformed_email(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/signup", json={**SIGNUP, "email": "not-an-email"}
    )

    assert response.status_code == 422


async def test_login_succeeds_with_the_right_password(client: AsyncClient) -> None:
    await _signup(client)

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "parent@example.com", "password": "StrongPass123"},
    )

    assert response.status_code == 200, response.text
    assert response.json()["account"]["email"] == "parent@example.com"


async def test_login_is_case_insensitive_on_email(client: AsyncClient) -> None:
    await _signup(client)

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "PARENT@EXAMPLE.COM", "password": "StrongPass123"},
    )

    assert response.status_code == 200


async def test_login_rejects_a_wrong_password(client: AsyncClient) -> None:
    await _signup(client)

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "parent@example.com", "password": "WrongPass123"},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_credentials"


async def test_login_gives_the_same_answer_for_unknown_accounts(
    client: AsyncClient,
) -> None:
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "nobody@example.com", "password": "StrongPass123"},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_credentials"


async def test_login_is_rate_limited(client: AsyncClient, settings: Settings) -> None:
    await _signup(client)
    payload = {"email": "parent@example.com", "password": "WrongPass123"}

    statuses = [
        (await client.post("/api/v1/auth/login", json=payload)).status_code
        for _ in range(settings.login_rate_limit_attempts + 1)
    ]

    assert statuses[-1] == 429
    assert all(status == 401 for status in statuses[:-1])


async def test_refresh_rotates_the_refresh_token(client: AsyncClient) -> None:
    body = await _signup(client)

    response = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": body["refresh_token"]}
    )

    assert response.status_code == 200, response.text
    rotated = response.json()
    assert rotated["refresh_token"] != body["refresh_token"]
    assert rotated["access_token"] != body["access_token"]


async def test_a_rotated_refresh_token_cannot_be_reused(client: AsyncClient) -> None:
    body = await _signup(client)
    original = str(body["refresh_token"])

    first = await client.post("/api/v1/auth/refresh", json={"refresh_token": original})
    assert first.status_code == 200

    replay = await client.post("/api/v1/auth/refresh", json={"refresh_token": original})

    assert replay.status_code == 401
    assert replay.json()["code"] == "token_revoked"


async def test_reuse_revokes_the_whole_token_family(client: AsyncClient) -> None:
    body = await _signup(client)
    original = str(body["refresh_token"])
    rotated = (
        await client.post("/api/v1/auth/refresh", json={"refresh_token": original})
    ).json()

    await client.post("/api/v1/auth/refresh", json={"refresh_token": original})

    replay = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": rotated["refresh_token"]}
    )

    assert replay.status_code == 401
    assert replay.json()["code"] == "token_revoked"


async def test_an_access_token_cannot_be_used_to_refresh(client: AsyncClient) -> None:
    body = await _signup(client)

    response = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": body["access_token"]}
    )

    assert response.status_code == 401


async def test_refresh_rejects_a_tampered_token(
    client: AsyncClient, settings: Settings
) -> None:
    body = await _signup(client)
    forged = jwt.encode(
        {
            "sub": body["account"]["id"],
            "jti": "forged",
            "typ": "refresh",
            "iss": settings.issuer,
            "iat": 0,
            "exp": 4_102_444_800,
        },
        "a-completely-different-signing-secret-of-sufficient-length",
        algorithm="HS256",
    )

    response = await client.post("/api/v1/auth/refresh", json={"refresh_token": forged})

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_token"


async def test_logout_revokes_the_refresh_token(client: AsyncClient) -> None:
    body = await _signup(client)

    logout = await client.post(
        "/api/v1/auth/logout", json={"refresh_token": body["refresh_token"]}
    )
    assert logout.status_code == 200
    assert logout.json()["revoked"] is True

    reuse = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": body["refresh_token"]}
    )
    assert reuse.status_code == 401


async def test_logout_is_idempotent_for_unknown_tokens(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/logout", json={"refresh_token": "not-a-real-token"}
    )

    assert response.status_code == 200
    assert response.json()["revoked"] is False


async def test_me_requires_a_bearer_token(client: AsyncClient) -> None:
    response = await client.get("/api/v1/auth/me")

    assert response.status_code == 401


async def test_me_returns_the_signed_in_parent(client: AsyncClient) -> None:
    body = await _signup(client)

    response = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {body['access_token']}"},
    )

    assert response.status_code == 200
    assert response.json()["email"] == "parent@example.com"


async def test_me_rejects_a_refresh_token(client: AsyncClient) -> None:
    body = await _signup(client)

    response = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {body['refresh_token']}"},
    )

    assert response.status_code == 401


async def test_health_and_config_are_public(client: AsyncClient) -> None:
    health = await client.get("/api/v1/health")
    config = await client.get("/api/v1/config")

    assert health.json() == {"status": "ok"}
    assert config.json() == {"free_mode": True, "billing_enabled": False}


async def test_passwords_are_never_returned(client: AsyncClient) -> None:
    body = await _signup(client)
    raw = body["account"]

    assert "password" not in raw
    assert "password_hash" not in raw
    assert "argon2" not in str(raw).lower()
