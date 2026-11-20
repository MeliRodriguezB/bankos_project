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
from app.modules.transactions.schemas import TransferRequest
from app.modules.transactions.service import TransactionService
from app.modules.users.models import User


@pytest.fixture
def financial_db():
    engine = create_engine("sqlite:///:memory:")
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


def test_transfer_debits_and_credits_atomically(financial_db):
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
    assert source.balance == Decimal("98500.00")
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
    assert source.balance == Decimal("98500.00")
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
