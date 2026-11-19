import uuid
from datetime import datetime, timezone
from decimal import Decimal
from sqlalchemy import (
    Column,
    String,
    Numeric,
    DateTime,
    Index,
    Text,
)
from app.db.base import Base


class Transaction(Base):
    """
    Registro contable y de auditoría de operaciones financieras.
    
    Decisiones de diseño:
    1. Aislamiento e Idempotencia: Asociado estrictamente a 'tenant_id' y con 'idempotency_key'
       para erradicar cobros duplicados por reintentos de red.
    2. Atomicidad Financiera: Registra montos antes y después de conversión de divisas
       y el cobro exacto de comisiones.
    3. Precisión decimal sin redondeo: Numeric(18, 4) para tasas de cambio y Numeric(18, 2) para importes.
    """
    __tablename__ = "financial_transactions"

    id = Column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        doc="Identificador único de la transacción (UUID)"
    )

    tenant_id = Column(
        String(50),
        nullable=False,
        index=True,
        doc="Institución bancaria en la que ocurre la operación"
    )

    user_id = Column(
        String(50),
        nullable=False,
        index=True,
        doc="Usuario que inició la operación"
    )

    source_account_id = Column(
        String(36),
        nullable=True,
        doc="Cuenta origen de los fondos (null en depósitos externos)"
    )

    destination_account_id = Column(
        String(36),
        nullable=True,
        doc="Cuenta destino de los fondos (null en retiros en efectivo)"
    )

    type = Column(
        String(20),
        nullable=False,
        doc="Tipo de operación: TRANSFER, DEPOSIT, WITHDRAWAL"
    )

    amount = Column(
        Numeric(18, 2),
        nullable=False,
        doc="Monto original solicitado para la transacción"
    )

    currency = Column(
        String(3),
        nullable=False,
        doc="Divisa original de la operación"
    )

    converted_amount = Column(
        Numeric(18, 2),
        nullable=True,
        doc="Monto final acreditado en la cuenta destino tras aplicar la tasa de cambio"
    )

    destination_currency = Column(
        String(3),
        nullable=True,
        doc="Divisa de la cuenta destino"
    )

    exchange_rate = Column(
        Numeric(18, 6),
        nullable=False,
        default=Decimal("1.000000"),
        doc="Tasa de cambio estática aplicada por la institución"
    )

    fee_amount = Column(
        Numeric(18, 2),
        nullable=False,
        default=Decimal("0.00"),
        doc="Comisión fija o porcentual cobrada por el banco"
    )

    status = Column(
        String(20),
        nullable=False,
        default="COMPLETED",
        doc="Estado: COMPLETED, FAILED, REVERSED"
    )

    idempotency_key = Column(
        String(100),
        nullable=True,
        index=True,
        doc="UUID enviado por el cliente para garantizar idempotencia"
    )

    correlation_id = Column(
        String(100),
        nullable=True,
        doc="Identificador de correlación para trazabilidad técnica"
    )

    description = Column(
        Text,
        nullable=True,
        doc="Descripción o motivo del movimiento"
    )

    response_payload = Column(
        Text,
        nullable=True,
        doc="Cuerpo de la respuesta serializada para devolver ante reintentos idempotentes"
    )

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        doc="Fecha y hora de ejecución de la transacción en UTC"
    )

    __table_args__ = (
        Index("idx_transactions_tenant_date", "tenant_id", "created_at"),
        Index("idx_transactions_tenant_user", "tenant_id", "user_id"),
        Index("idx_transactions_idempotency", "tenant_id", "idempotency_key"),
    )
