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



def test_rate_limit_policies_cover_login_transactions_and_api():
    from app.core.rate_limit import RateLimitMiddleware

    assert RateLimitMiddleware._policy("/api/v1/auth/login") == ("login", 10)
    assert RateLimitMiddleware._policy("/api/v1/transactions/transfers") == ("transactions", 30)
    assert RateLimitMiddleware._policy("/api/v1/accounts") == ("api", 120)
    assert RateLimitMiddleware._policy("/health") is None


def test_tenant_currency_policy_rejects_existing_fee_for_removed_currency():
    from decimal import Decimal
    from app.modules.tenants.router import validate_tenant_currency_policies

    try:
        validate_tenant_currency_policies(
            ["COP"], {"COP": Decimal("1000.00"), "USD": Decimal("1.00")}, {}
        )
    except HTTPException as exc:
        assert exc.status_code == 422
    else:
        raise AssertionError("No se debe conservar una comisión para una moneda deshabilitada")


def test_tenant_currency_policy_rejects_existing_rate_for_removed_currency():
    from app.modules.tenants.router import validate_tenant_currency_policies

    try:
        validate_tenant_currency_policies(
            ["COP"], {"COP": "1000.00"}, {"COP/USD": "0.00025"}
        )
    except HTTPException as exc:
        assert exc.status_code == 422
    else:
        raise AssertionError("No se debe conservar una tasa para una moneda deshabilitada")


def test_correlation_id_is_returned_for_success_and_standardized_errors():
    from fastapi.testclient import TestClient
    from app.main import app

    with TestClient(app) as client:
        success = client.get(
            "/health", headers={"X-Correlation-ID": "bankos-test-001"}
        )
        assert success.status_code == 200
        assert success.headers["X-Correlation-ID"] == "bankos-test-001"

        missing = client.get(
            "/api/v1/does-not-exist",
            headers={"X-Correlation-ID": "bankos-test-002"},
        )
        assert missing.status_code == 404
        assert missing.headers["X-Correlation-ID"] == "bankos-test-002"
        assert missing.json()["error"]["code"] == "HTTP_404"
        assert missing.json()["error"]["correlation_id"] == "bankos-test-002"


def test_tenant_config_response_serializes_uuid_as_json_string():
    from uuid import uuid4
    from decimal import Decimal
    from app.modules.tenants.schemas import TenantConfigResponse

    tenant_id = uuid4()
    response = TenantConfigResponse(
        id=tenant_id,
        name="Test Institution",
        slug="test-institution",
        status="ACTIVE",
        max_transfer_amount=Decimal("1000000.00"),
        transfer_fees={"COP": "1000.00"},
        transfer_fee_percent=Decimal("0.0050"),
        primary_currency="COP",
        supported_currencies=["COP"],
        exchange_rates={},
        webhook_url=None,
    )

    assert response.model_dump(mode="json")["id"] == str(tenant_id)



def test_transaction_audit_uses_the_same_correlation_id_as_response(monkeypatch):
    from datetime import datetime, timezone

    from fastapi.testclient import TestClient

    from app.core.dependencies import get_current_user, get_db
    from app.main import app
    from app.modules.transactions.schemas import TransactionResponse
    from app.modules.transactions.service import TransactionService

    captured_ids = []

    def fake_transfer(**kwargs):
        correlation_id = kwargs["correlation_id"]
        captured_ids.append(correlation_id)
        return TransactionResponse(
            id=f"tx-{len(captured_ids)}",
            type="TRANSFER",
            amount="10.00",
            currency="COP",
            fee_amount="0.00",
            exchange_rate="1.000000",
            status="COMPLETED",
            idempotency_key=kwargs["idempotency_key"],
            correlation_id=correlation_id,
            created_at=datetime.now(timezone.utc),
        )

    monkeypatch.setattr(
        TransactionService, "process_transfer", staticmethod(fake_transfer)
    )
    monkeypatch.setitem(
        app.dependency_overrides,
        get_current_user,
        lambda: {
            "user_id": "demo-user",
            "tenant_id": "demo-tenant",
            "roles": ["CUSTOMER"],
        },
    )
    monkeypatch.setitem(app.dependency_overrides, get_db, lambda: None)

    payload = {
        "source_account_id": "source-account",
        "destination_account_number": "1000000002",
        "amount": "10.00",
        "currency": "COP",
        "pin": "1234",
    }
    with TestClient(app) as client:
        generated = client.post(
            "/api/v1/transactions/transfers",
            json=payload,
            headers={"Idempotency-Key": "correlation-generated-001"},
        )
        supplied = client.post(
            "/api/v1/transactions/transfers",
            json=payload,
            headers={
                "Idempotency-Key": "correlation-supplied-001",
                "X-Correlation-ID": "bankos-correlation-002",
            },
        )

    assert generated.status_code == 201
    assert supplied.status_code == 201
    assert generated.headers["X-Correlation-ID"] == captured_ids[0]
    assert generated.json()["correlation_id"] == captured_ids[0]
    assert supplied.headers["X-Correlation-ID"] == "bankos-correlation-002"
    assert supplied.json()["correlation_id"] == "bankos-correlation-002"
