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
    assert "/api/v1/tenant/config" in paths



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

def test_production_rejects_simulated_deposits():
    from pydantic import ValidationError
    from app.core.config import Settings

    try:
        Settings(
            ENVIRONMENT="production",
            SECRET_KEY="production-secret-key-with-more-than-32-characters",
            SIMULATED_DEPOSITS_ENABLED=True,
        )
    except ValidationError:
        pass
    else:
        raise AssertionError("Los depósitos simulados deben bloquearse en producción")


def test_production_accepts_deposits_disabled():
    from app.core.config import Settings

    config = Settings(
        ENVIRONMENT="production",
        SECRET_KEY="production-secret-key-with-more-than-32-characters",
        SIMULATED_DEPOSITS_ENABLED=False,
    )
    assert config.SIMULATED_DEPOSITS_ENABLED is False

def test_static_exchange_rates_are_rejected_in_production(monkeypatch):
    from fastapi import HTTPException
    from app.modules.transactions.service import TransactionService
    from app.core.config import settings

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    try:
        TransactionService.get_exchange_rate("COP", "USD")
    except HTTPException as exc:
        assert exc.status_code == 503
    else:
        raise AssertionError("Las tasas estáticas no deben utilizarse en producción")


def test_unknown_exchange_pair_is_rejected():
    from fastapi import HTTPException
    from app.modules.transactions.service import TransactionService

    try:
        TransactionService.get_exchange_rate("COP", "GBP")
    except HTTPException as exc:
        assert exc.status_code == 422
    else:
        raise AssertionError("No se debe asumir una tasa 1:1 para divisas no configuradas")




def test_tenant_configuration_schema_rejects_invalid_exchange_rate():
    from pydantic import ValidationError
    from app.modules.tenants.schemas import TenantConfigUpdate

    try:
        TenantConfigUpdate(exchange_rates={"COP/USD": "0"})
    except ValidationError:
        pass
    else:
        raise AssertionError("Las tasas de cambio deben ser positivas")


def test_tenant_configuration_schema_accepts_fee_and_transfer_limit():
    from decimal import Decimal
    from app.modules.tenants.schemas import TenantConfigUpdate

    config = TenantConfigUpdate(
        max_transfer_amount=Decimal("2500000.00"),
        transfer_fees={"COP": Decimal("1000.00")},
        transfer_fee_percent=Decimal("0.0100"),
        primary_currency="cop",
        supported_currencies=["cop", "usd"],
        exchange_rates={"COP/USD": Decimal("0.00025")},
    )
    assert config.primary_currency == "COP"
    assert config.supported_currencies == ["COP", "USD"]
    assert config.transfer_fee_percent == Decimal("0.0100")
