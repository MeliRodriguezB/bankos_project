from decimal import Decimal\n\nfrom fastapi import HTTPException
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

    paths = set(app.openapi().get("paths", {}).keys())
    assert "/health" in paths
    assert "/api/v1/auth/login" in paths
    assert "/api/v1/auth/me" in paths
    assert "/api/v1/accounts" in paths
    assert "/api/v1/dashboard" in paths
    assert "/api/v1/transactions" in paths
    assert "/api/v1/transactions/transfers" in paths
    assert "/api/v1/transactions/deposits" in paths
    assert "/api/v1/transactions/withdrawals" in paths
    assert "/api/v1/users/me/transaction-pin" in paths



def test_transaction_pin_schema_rejects_non_numeric_values():
    from pydantic import ValidationError
    from app.modules.users.schemas import TransactionPinSetupRequest

    try:
        TransactionPinSetupRequest(current_password="correct-horse", pin="12a4")
    except ValidationError:
        pass
    else:
        raise AssertionError("El PIN debe contener únicamente dígitos")


def test_transaction_pin_schema_accepts_four_digits():
    from app.modules.users.schemas import TransactionPinSetupRequest

    request = TransactionPinSetupRequest(current_password="correct-horse", pin="0427")
    assert request.pin == "0427"


def test_transaction_pin_hash_is_not_plaintext():
    from app.core.security import hash_password, verify_password

    hashed = hash_password("0427")
    assert hashed != "0427"
    assert verify_password("0427", hashed)
    assert not verify_password("1234", hashed)


def test_same_currency_exchange_rate_is_one():
    from app.modules.transactions.service import TransactionService

    assert TransactionService.get_exchange_rate("COP", "COP") == Decimal("1.000000")


def test_configured_exchange_rate_is_returned():
    from app.modules.transactions.service import TransactionService

    assert TransactionService.get_exchange_rate("COP", "USD") == Decimal("0.00025")


def test_unsupported_exchange_pair_is_rejected():
    from app.modules.transactions.service import TransactionService


    try:
        TransactionService.get_exchange_rate("COP", "GBP")
    except HTTPException as exc:
        assert exc.status_code == 422
    else:
        raise AssertionError("Una conversión no configurada no debe asumir tasa 1.0")
