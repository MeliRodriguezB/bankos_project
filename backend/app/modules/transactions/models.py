import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import Column, String, Numeric, DateTime, Index, Text, event
from app.db.base import Base


class Transaction(Base):
    """Registro contable de operaciones financieras con clave idempotente única."""
    __tablename__ = "financial_transactions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    tenant_id = Column(String(50), nullable=False, index=True)
    user_id = Column(String(50), nullable=False, index=True)
    source_account_id = Column(String(36), nullable=True)
    destination_account_id = Column(String(36), nullable=True)
    type = Column(String(20), nullable=False)
    amount = Column(Numeric(18, 2), nullable=False)
    currency = Column(String(3), nullable=False)
    converted_amount = Column(Numeric(18, 2), nullable=True)
    destination_currency = Column(String(3), nullable=True)
    exchange_rate = Column(Numeric(18, 6), nullable=False, default=Decimal("1.000000"))
    fee_amount = Column(Numeric(18, 2), nullable=False, default=Decimal("0.00"))
    status = Column(String(20), nullable=False, default="COMPLETED")
    idempotency_key = Column(String(100), nullable=True)
    correlation_id = Column(String(100), nullable=True)
    description = Column(Text, nullable=True)
    response_payload = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        Index("idx_transactions_tenant_date", "tenant_id", "created_at"),
        Index("idx_transactions_tenant_user", "tenant_id", "user_id"),
        # PostgreSQL permite múltiples NULL, pero impide repetir claves por usuario/tenant.
        Index(
            "uq_transactions_idempotency_scope",
            "tenant_id",
            "user_id",
            "idempotency_key",
            unique=True,
            postgresql_where=idempotency_key.isnot(None),
        ),
    )



@event.listens_for(Transaction, "before_update")
def prevent_transaction_update(_mapper, _connection, _target):
    """Los registros financieros son append-only y no se editan después de crearse."""
    raise ValueError("Los registros de transacciones son inmutables.")


@event.listens_for(Transaction, "before_delete")
def prevent_transaction_delete(_mapper, _connection, _target):
    """Las transacciones se conservan como evidencia de auditoría."""
    raise ValueError("Los registros de transacciones no se pueden eliminar.")
