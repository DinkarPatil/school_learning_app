from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse

from app.config import Settings, get_settings
from app.db.session import configure, create_schema, dispose_engine
from app.dependencies import RateLimitExceededError, rate_limited_response
from app.routers import auth
from app.routers.auth import install_auth_error_handlers
from app.schemas.errors import ErrorCode
from app.services.auth_service import AuthError

API_PREFIX = "/api/v1"


@asynccontextmanager
async def lifespan(application: FastAPI) -> AsyncIterator[None]:
    settings: Settings = application.state.settings
    configure(settings.database_url_for(testing=settings.environment == "test"))
    if settings.environment == "test":
        await create_schema()
    yield
    await dispose_engine()


def create_app(settings: Settings | None = None) -> FastAPI:
    resolved = settings or get_settings()
    application = FastAPI(
        title="School Learning Service",
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/api/docs" if not resolved.is_production else None,
        redoc_url=None,
    )
    application.state.settings = resolved

    if resolved.cors_origins:
        application.add_middleware(
            CORSMiddleware,
            allow_origins=list(resolved.cors_origins),
            allow_credentials=False,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
            allow_headers=["Authorization", "Content-Type"],
        )

    install_auth_error_handlers(application)

    @application.exception_handler(RateLimitExceededError)
    async def _handle_rate_limit(
        _request: Request, _error: RateLimitExceededError
    ) -> JSONResponse:
        return rate_limited_response()

    @application.exception_handler(RequestValidationError)
    async def _handle_validation_error(
        _request: Request, _error: RequestValidationError
    ) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content={
                "code": ErrorCode.VALIDATION_FAILED.value,
                "message": "Please check the details you entered.",
            },
        )

    @application.get("/api/v1/health", tags=["meta"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    @application.get("/api/v1/config", tags=["meta"])
    async def client_config() -> dict[str, object]:
        return {
            "free_mode": resolved.free_mode,
            "billing_enabled": resolved.billing_enabled,
        }

    application.include_router(auth.router, prefix=API_PREFIX)
    return application


app = create_app()

__all__ = ["API_PREFIX", "AuthError", "app", "create_app", "lifespan"]
