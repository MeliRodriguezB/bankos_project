import uuid
from datetime import datetime, timezone
from decimal import Decimal
from sqlalchemy import (
    Column,
    String,
    Numeric,
    DateTime,
    Index,
)
from app.db.base import Base


class Account(Base):
    """
    Modelo ORM para cuentas bancarias en BankOS.
    
    Decisiones de diseño:
    1. Aislamiento Multitenant: La columna 'tenant_id' es obligatoria y está indexada junto a 'user_id'
       y 'account_number' para búsquedas de alta velocidad y evitar cruces de datos entre instituciones.
    2. Precisión Financiera: 'balance' utiliza Numeric(18, 2) en base de datos (y Decimal en Python)
       para erradicar errores de redondeo de punto flotante.
    3. Soft Delete: El campo 'status' almacena 'ACTIVE', 'INACTIVE' o 'BLOCKED'. Nunca se ejecuta
       un DELETE físico en base de datos para preservar la integridad de transacciones y auditoría.
    """
    __tablename__ = "accounts"

    id = Column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        doc="Identificador interno único (UUID)"
    )

    account_number = Column(
        String(20),
        nullable=False,
        doc="Número de cuenta bancaria visible/formal"
    )

    alias = Column(
        String(100),
        nullable=True,
        doc="Nombre descriptivo de la cuenta asignado por el usuario o banco (ej. 'Cuenta Nómina')"
    )

    tenant_id = Column(
        String(50),
        nullable=False,
        index=True,
        doc="Identificador de la institución financiera dueña del registro (aislamiento multitenant)"
    )

    user_id = Column(
        String(50),
        nullable=False,
        index=True,
        doc="Identificador del usuario titular de la cuenta"
    )

    balance = Column(
        Numeric(precision=18, scale=2),
        nullable=False,
        default=Decimal("0.00"),
        doc="Saldo contable actual en unidades decimales exactas"
    )

    currency = Column(
        String(3),
        nullable=False,
        default="COP",
        doc="Código ISO 4217 de la divisa (ej. COP, USD, EUR)"
    )

    status = Column(
        String(20),
        nullable=False,
        default="ACTIVE",
        doc="Estado de la cuenta: ACTIVE (operativa), INACTIVE (desactivada/borrado lógico), BLOCKED (bloqueada)"
    )

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        doc="Fecha y hora de creación de la cuenta en UTC"
    )

    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
        doc="Fecha y hora de última actualización en UTC"
    )

    # Índices compuestos para garantizar consultas ultra-rápidas y aislamiento estricto
    __table_args__ = (
        Index("idx_accounts_tenant_user", "tenant_id", "user_id"),
        Index("idx_accounts_tenant_number", "tenant_id", "account_number", unique=True),
    )

    @property
    def account_number_masked(self) -> str:
        """
        Enmascara el número de cuenta para proteger la privacidad del usuario en pantallas.
        Ejemplo: '1002348911' -> '•••• 8911'
        """
        if not self.account_number or len(self.account_number) < 4:
            return "••••"
        return f"•••• {self.account_number[-4:]}"
