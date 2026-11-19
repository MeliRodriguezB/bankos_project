from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app.core.dependencies import get_current_user


def test_missing_bearer_token_is_rejected():
    try:
        get_current_user(credentials=None, db=None)
    except HTTPException as exc:
        assert exc.status_code == 401
        assert exc.headers["WWW-Authenticate"] == "Bearer"
    else:
        raise AssertionError("Una request sin token debe ser rechazada")


def test_invalid_jwt_is_rejected(monkeypatch):
    def invalid_token(_token):
        raise ValueError("invalid token")

    monkeypatch.setattr("app.core.dependencies.decode_access_token", invalid_token)
    credentials = HTTPAuthorizationCredentials(
        scheme="Bearer",
        credentials="not-a-valid-jwt",
    )

    try:
        get_current_user(credentials=credentials, db=None)
    except HTTPException as exc:
        assert exc.status_code == 401
    else:
        raise AssertionError("Un JWT inválido debe ser rechazado")


def test_openapi_registers_all_api_modules():
    from app.main import app

    paths = {route.path for route in app.routes}
    assert "/health" in paths
    assert "/api/v1/auth/login" in paths
    assert "/api/v1/auth/me" in paths
    assert "/api/v1/accounts" in paths
    assert "/api/v1/dashboard" in paths
    assert "/api/v1/transactions" in paths
    assert "/api/v1/transactions/transfers" in paths
    assert "/api/v1/transactions/deposits" in paths
    assert "/api/v1/transactions/withdrawals" in paths
