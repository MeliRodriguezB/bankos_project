from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.security import hash_password
from app.db.base import Base
from app.modules.accounts.models import Account
from app.modules.tenants.models import Tenant
from app.modules.transactions.models import Transaction
from app.modules.transactions.schemas import DepositRequest, TransferRequest, WithdrawRequest
from app.modules.transactions.service import TransactionService
from app.modules.users.models import User


@pytest.fixture
def financial_db():
    engine = create_engine("sqlite:///:memory:")
    # SQLite no soporta gen_random_uuid() como DEFAULT; las pruebas asignan UUID explícitos.
    for table in Base.metadata.tables.values():
        for column in table.columns:
            if (
                column.server_default is not None
                and "gen_random_uuid" in str(column.server_default.arg)
            ):
                column.server_default = None
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    db = session_factory()

    tenant = Tenant(
        id=uuid4(),
        name="Cooperativa de prueba",
        slug="cooperativa-prueba",
        status="ACTIVE",
        max_transfer_amount=Decimal("5000000.00"),
        transfer_fees={"COP": "1500.00", "USD": "1.00"},
        transfer_fee_percent=Decimal("0.0000"),
        primary_currency="COP",
        supported_currencies=["COP", "USD"],
        exchange_rates={"USD/COP": "4000.00", "COP/USD": "0.00025"},
    )
    user = User(
        id=uuid4(),
        email="customer@example.test",
        password_hash=hash_password("test-password"),
        transaction_pin_hash=hash_password("1234"),
        full_name="Test Customer",
        is_active=True,
    )
    db.add_all([tenant, user])
    db.flush()

    source = Account(
        id="source-account",
        account_number="1000000001",
        alias="Source",
        tenant_id=str(tenant.id),
        user_id=str(user.id),
        balance=Decimal("100000.00"),
        currency="COP",
        status="ACTIVE",
    )
    destination = Account(
        id="destination-account",
        account_number="1000000002",
        alias="Destination",
        tenant_id=str(tenant.id),
        user_id=str(user.id),
        balance=Decimal("0.00"),
        currency="COP",
        status="ACTIVE",
    )
    db.add_all([source, destination])
    db.commit()

    try:
        yield db, tenant, user, source, destination
    finally:
        db.close()
        Base.metadata.drop_all(engine)
        engine.dispose()


def _transfer(source_id: str, amount: str = "1000.00") -> TransferRequest:
    return TransferRequest(
        source_account_id=source_id,
        destination_account_number="1000000002",
        amount=Decimal(amount),
        currency="COP",
        pin="1234",
        description="Test transfer",
    )


def test_transfer_debits_amount_and_fee_and_credits_destination_atomically(financial_db):
    db, tenant, user, source, destination = financial_db

    result = TransactionService.process_transfer(
        db=db,
        tenant_id=str(tenant.id),
        user_id=str(user.id),
        data=_transfer(source.id),
        idempotency_key="test-transfer-0001",
        correlation_id="test-correlation-0001",
    )

    db.refresh(source)
    db.refresh(destination)
    assert result.status == "COMPLETED"
    # The source pays both the transfer amount (1,000) and the configured fee (1,500).
    assert source.balance == Decimal("97500.00")
    assert destination.balance == Decimal("1000.00")
    assert result.fee_amount == "1500.00"


def test_same_idempotency_key_does_not_double_charge(financial_db):
    db, tenant, user, source, destination = financial_db
    request = _transfer(source.id)

    first = TransactionService.process_transfer(
        db, str(tenant.id), str(user.id), request, "retry-transfer-0001", "corr-first"
    )
    second = TransactionService.process_transfer(
        db, str(tenant.id), str(user.id), request, "retry-transfer-0001", "corr-retry"
    )

    db.refresh(source)
    db.refresh(destination)
    assert first.id == second.id
    assert source.balance == Decimal("97500.00")
    assert destination.balance == Decimal("1000.00")


def test_same_idempotency_key_with_different_payload_is_rejected(financial_db):
    db, tenant, user, source, _ = financial_db
    first = _transfer(source.id, "1000.00")
    second = _transfer(source.id, "2000.00")

    TransactionService.process_transfer(
        db, str(tenant.id), str(user.id), first, "payload-key-0001", "corr-first"
    )
    with pytest.raises(HTTPException) as exc:
        TransactionService.process_transfer(
            db, str(tenant.id), str(user.id), second, "payload-key-0001", "corr-second"
        )

    assert exc.value.status_code == 409


def test_transfer_respects_tenant_amount_limit(financial_db):
    db, tenant, user, source, _ = financial_db
    request = _transfer(source.id, "5000001.00")

    with pytest.raises(HTTPException) as exc:
        TransactionService.process_transfer(
            db, str(tenant.id), str(user.id), request, "limit-transfer-001", "corr-limit"
        )

    assert exc.value.status_code == 422


def test_transfer_rejects_destination_from_another_tenant(financial_db):
    db, tenant, user, source, _ = financial_db
    other_tenant = Tenant(
        id=uuid4(),
        name="Other institution",
        slug="other-institution",
        status="ACTIVE",
    )
    db.add(other_tenant)
    db.flush()
    db.add(Account(
        id="foreign-account",
        account_number="9999999999",
        alias="Foreign",
        tenant_id=str(other_tenant.id),
        user_id=str(user.id),
        balance=Decimal("100000.00"),
        currency="COP",
        status="ACTIVE",
    ))
    db.commit()

    request = TransferRequest(
        source_account_id=source.id,
        destination_account_number="9999999999",
        amount=Decimal("1000.00"),
        currency="COP",
        pin="1234",
    )
    with pytest.raises(HTTPException) as exc:
        TransactionService.process_transfer(
            db, str(tenant.id), str(user.id), request, "tenant-transfer-001", "corr-tenant"
        )

    assert exc.value.status_code == 400


def test_tenant_fee_percentage_is_applied(financial_db):
    db, tenant, user, source, destination = financial_db
    tenant.transfer_fee_percent = Decimal("0.0100")
    db.commit()

    request = _transfer(source.id, "10000.00")
    result = TransactionService.process_transfer(
        db, str(tenant.id), str(user.id), request, "fee-transfer-001", "corr-fee"
    )

    db.refresh(source)
    db.refresh(destination)
    assert result.fee_amount == "1600.00"
    assert source.balance == Decimal("88400.00")
    assert destination.balance == Decimal("10000.00")


def test_transaction_audit_record_cannot_be_modified(financial_db):
    db, tenant, user, source, _ = financial_db
    TransactionService.process_transfer(
        db, str(tenant.id), str(user.id), _transfer(source.id),
        "immutable-audit-001", "corr-immutable"
    )
    transaction = db.query(Transaction).filter(
        Transaction.idempotency_key == "immutable-audit-001"
    ).one()
    transaction.description = "tampered audit record"

    with pytest.raises(ValueError, match="inmutables"):
        db.commit()
    db.rollback()


def test_multicurrency_transfer_uses_tenant_rate_and_fee(financial_db):
    db, tenant, user, _, destination = financial_db
    usd_source = Account(
        id="usd-source-account",
        account_number="2000000001",
        alias="USD source",
        tenant_id=str(tenant.id),
        user_id=str(user.id),
        balance=Decimal("100.00"),
        currency="USD",
        status="ACTIVE",
    )
    db.add(usd_source)
    db.commit()

    request = TransferRequest(
        source_account_id=usd_source.id,
        destination_account_number=destination.account_number,
        amount=Decimal("10.00"),
        currency="USD",
        pin="1234",
        description="USD to COP",
    )
    result = TransactionService.process_transfer(
        db, str(tenant.id), str(user.id), request,
        "multicurrency-transfer-001", "corr-multicurrency"
    )

    db.refresh(usd_source)
    db.refresh(destination)
    assert result.exchange_rate == "4000.000000"
    assert result.converted_amount == "40000.00"
    assert result.fee_amount == "1.00"
    assert usd_source.balance == Decimal("89.00")
    assert destination.balance == Decimal("40000.00")


def test_deposit_is_idempotent(financial_db):
    db, tenant, user, source, _ = financial_db
    request = DepositRequest(
        account_id=source.id,
        amount=Decimal("2500.00"),
        currency="COP",
        description="Test deposit",
    )

    first = TransactionService.process_deposit(
        db, str(tenant.id), str(user.id), request,
        "deposit-idempotency-001", "corr-deposit-first"
    )
    second = TransactionService.process_deposit(
        db, str(tenant.id), str(user.id), request,
        "deposit-idempotency-001", "corr-deposit-retry"
    )

    db.refresh(source)
    assert first.id == second.id
    assert source.balance == Decimal("102500.00")


def test_withdrawal_is_idempotent_and_checks_pin(financial_db):
    db, tenant, user, source, _ = financial_db
    request = WithdrawRequest(
        account_id=source.id,
        amount=Decimal("2500.00"),
        currency="COP",
        pin="1234",
        description="Test withdrawal",
    )

    first = TransactionService.process_withdrawal(
        db, str(tenant.id), str(user.id), request,
        "withdraw-idempotency-001", "corr-withdraw-first"
    )
    second = TransactionService.process_withdrawal(
        db, str(tenant.id), str(user.id), request,
        "withdraw-idempotency-001", "corr-withdraw-retry"
    )

    db.refresh(source)
    assert first.id == second.id
    assert source.balance == Decimal("97500.00")


def test_withdrawal_rejects_invalid_pin(financial_db):
    db, tenant, user, source, _ = financial_db
    request = WithdrawRequest(
        account_id=source.id,
        amount=Decimal("100.00"),
        currency="COP",
        pin="9999",
    )

    with pytest.raises(HTTPException) as exc:
        TransactionService.process_withdrawal(
            db, str(tenant.id), str(user.id), request,
            "withdraw-invalid-pin-001", "corr-invalid-pin"
        )

    assert exc.value.status_code == 401



def test_idempotency_key_remains_valid_after_more_than_24_hours(financial_db):
    db, tenant, user, source, destination = financial_db
    request = _transfer(source.id)

    first = TransactionService.process_transfer(
        db,
        str(tenant.id),
        str(user.id),
        request,
        "retry-after-24-hours-001",
        "corr-original",
    )

    # Simulate a retry arriving 25 hours after the original persisted operation.
    old_timestamp = datetime.now(timezone.utc) - timedelta(hours=25)
    db.execute(
        Transaction.__table__.update()
        .where(Transaction.id == first.id)
        .values(created_at=old_timestamp)
    )
    db.commit()

    second = TransactionService.process_transfer(
        db,
        str(tenant.id),
        str(user.id),
        request,
        "retry-after-24-hours-001",
        "corr-retry",
    )

    db.refresh(source)
    db.refresh(destination)
    assert second.id == first.id
    assert second.created_at.replace(tzinfo=timezone.utc) <= old_timestamp
    assert source.balance == Decimal("97500.00")
    assert destination.balance == Decimal("1000.00")



def test_second_tenant_transfer_uses_only_its_own_seeded_accounts(financial_db):
    db, tenant1, user, source1, destination1 = financial_db
    tenant2 = Tenant(
        id=uuid4(),
        name="Neobanco Ágil",
        slug="neobanco-agil",
        status="ACTIVE",
    )
    db.add(tenant2)
    db.flush()

    source2 = Account(
        id="tenant2-source",
        account_number="8880001234",
        alias="Cuenta Neobanco Ágil",
        tenant_id=str(tenant2.id),
        user_id=str(user.id),
        balance=Decimal("100000.00"),
        currency="COP",
        status="ACTIVE",
    )
    destination2 = Account(
        id="tenant2-destination",
        account_number="8880005678",
        alias="Cuenta secundaria Neobanco Ágil",
        tenant_id=str(tenant2.id),
        user_id=str(user.id),
        balance=Decimal("250000.00"),
        currency="COP",
        status="ACTIVE",
    )
    db.add_all([source2, destination2])
    db.commit()

    request = TransferRequest(
        source_account_id=source2.id,
        destination_account_number=destination2.account_number,
        amount=Decimal("1000.00"),
        currency="COP",
        pin="1234",
        description="Transfer within second tenant",
    )
    result = TransactionService.process_transfer(
        db,
        str(tenant2.id),
        str(user.id),
        request,
        "tenant2-transfer-001",
        "corr-tenant2-transfer",
    )

    db.refresh(source1)
    db.refresh(destination1)
    db.refresh(source2)
    db.refresh(destination2)
    assert result.status == "COMPLETED"
    assert source2.balance == Decimal("97500.00")
    assert destination2.balance == Decimal("251000.00")
    assert source1.balance == Decimal("100000.00")
    assert destination1.balance == Decimal("0.00")


def test_customer_dashboard_uses_tenant_name_and_primary_currency(financial_db):
    from app.modules.accounts.service import AccountService

    db, tenant, user, _, _ = financial_db
    tenant.primary_currency = "USD"
    db.commit()

    dashboard = AccountService.get_dashboard_summary(
        db,
        str(tenant.id),
        str(user.id),
        user.full_name,
        user.email,
    )

    assert dashboard.tenant.id == str(tenant.id)
    assert dashboard.tenant.name == "Cooperativa de prueba"
    assert dashboard.tenant.primary_currency == "USD"


def test_admin_dashboard_uses_uuid_and_excludes_other_tenant_metrics(financial_db):
    from app.modules.accounts.service import AccountService
    from app.modules.tenants.models import TenantMembership

    db, tenant, user, _, _ = financial_db
    other_tenant = Tenant(
        id=uuid4(),
        name="Otra institución",
        slug="otra-institucion",
        status="ACTIVE",
    )
    other_user = User(
        id=uuid4(),
        email="other@example.test",
        password_hash=hash_password("other-password"),
        full_name="Other Customer",
        is_active=True,
    )
    db.add_all([other_tenant, other_user])
    db.flush()

    db.add_all([
        TenantMembership(
            id=uuid4(),
            tenant_id=tenant.id,
            user_id=user.id,
            status="ACTIVE",
        ),
        TenantMembership(
            id=uuid4(),
            tenant_id=other_tenant.id,
            user_id=other_user.id,
            status="ACTIVE",
        ),
        Account(
            id="other-tenant-account",
            account_number="9000000001",
            alias="Other account",
            tenant_id=str(other_tenant.id),
            user_id=str(other_user.id),
            balance=Decimal("90000.00"),
            currency="COP",
            status="ACTIVE",
        ),
        Transaction(
            tenant_id=str(tenant.id),
            user_id=str(user.id),
            type="DEPOSIT",
            amount=Decimal("100.00"),
            currency="COP",
            status="COMPLETED",
            description="Current tenant transaction",
        ),
        Transaction(
            tenant_id=str(other_tenant.id),
            user_id=str(other_user.id),
            type="DEPOSIT",
            amount=Decimal("900.00"),
            currency="COP",
            status="COMPLETED",
            description="Other tenant transaction",
        ),
    ])
    db.commit()

    dashboard = AccountService.get_tenant_admin_dashboard(db, str(tenant.id))

    assert dashboard.tenant_id == str(tenant.id)
    assert dashboard.tenant_name == tenant.name
    assert dashboard.active_memberships == 1
    assert dashboard.total_accounts == 2
    assert dashboard.active_accounts == 2
    assert dashboard.inactive_accounts == 0
    assert dashboard.transactions_total == 1
    assert len(dashboard.transactions_by_status_currency) == 1
    assert dashboard.transactions_by_status_currency[0].total_amount == "100.00"
