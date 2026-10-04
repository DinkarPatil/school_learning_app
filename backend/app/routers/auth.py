from __future__ import annotations

from fastapi import APIRouter, FastAPI, Request
from fastapi.responses import JSONResponse

from app.config import Settings
from app.dependencies import (
    CurrentAccount,
    SessionDep,
    SettingsDep,
    enforce_rate_limit,
    reset_rate_limit,
)
from app.schemas.auth import (
    LoginRequest,
    LoginResponse,
    LogoutRequest,
    LogoutResponse,
    ParentAccountResponse,
    RefreshRequest,
    SignupRequest,
    SignupResponse,
    TokenPairResponse,
)
from app.schemas.errors import ErrorCode, ParentSafeMessage
from app.services import auth_service
from app.services.auth_service import AuthError

router = APIRouter(prefix="/auth", tags=["auth"])


def _account_payload(account: object) -> ParentAccountResponse:
    return ParentAccountResponse.model_validate(account, from_attributes=True)


def _pair_response(
    access_token: str, refresh_token: str, settings: Settings
) -> TokenPairResponse:
    return TokenPairResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_ttl_seconds,
        refresh_expires_in=settings.refresh_token_ttl_seconds,
    )


@router.post("/signup", response_model=SignupResponse, status_code=201)
async def signup(
    payload: SignupRequest,
    request: Request,
    session: SessionDep,
    settings: SettingsDep,
) -> SignupResponse:
    enforce_rate_limit(
        request,
        scope="signup",
        attempts=settings.login_rate_limit_attempts,
        window_seconds=settings.login_rate_limit_window_seconds,
    )
    account, access_token, refresh_token = await auth_service.create_account(
        session, payload, settings
    )
    return SignupResponse(
        **_pair_response(access_token, refresh_token, settings).model_dump(),
        account=_account_payload(account),
    )


@router.post("/login", response_model=LoginResponse)
async def login(
    request: Request,
    payload: LoginRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> LoginResponse:
    enforce_rate_limit(
        request,
        scope="login",
        attempts=settings.login_rate_limit_attempts,
        window_seconds=settings.login_rate_limit_window_seconds,
    )
    account, access_token, refresh_token = await auth_service.authenticate(
        session, payload, settings
    )
    reset_rate_limit(request, scope="login")
    return LoginResponse(
        **_pair_response(access_token, refresh_token, settings).model_dump(),
        account=_account_payload(account),
    )


@router.post("/refresh", response_model=TokenPairResponse)
async def refresh(
    payload: RefreshRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> TokenPairResponse:
    account, access_token, refresh_token = await auth_service.rotate_refresh_token(
        session, payload.refresh_token, settings
    )
    del account
    return _pair_response(access_token, refresh_token, settings)


@router.post("/logout", response_model=LogoutResponse)
async def logout(
    payload: LogoutRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> LogoutResponse:
    revoked = await auth_service.revoke_refresh_token(
        session, payload.refresh_token, settings
    )
    return LogoutResponse(revoked=revoked)


@router.get("/me", response_model=ParentAccountResponse)
async def me(account: CurrentAccount) -> ParentAccountResponse:
    return _account_payload(account)


def install_auth_error_handlers(application: FastAPI) -> None:
    @application.exception_handler(AuthError)
    async def _handle_auth_error(_request: Request, error: AuthError) -> JSONResponse:
        try:
            code = ErrorCode(error.code)
        except ValueError:
            code = ErrorCode.VALIDATION_FAILED
        message = ParentSafeMessage.__members__.get(code.name)
        if message is None:
            message = ParentSafeMessage.GENERIC
        return JSONResponse(
            status_code=error.http_status,
            content={"code": code.value, "message": message.value},
        )
