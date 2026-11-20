from datetime import datetime
from uuid import UUID

from sqlalchemy import Boolean, DateTime, ForeignKey, Numeric, String, UniqueConstraint, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class BankConfiguration(Base):
    __tablename__ = "bank_configurations"

    tenant_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("tenants.id"), primary_key=True
    )
    primary_color: Mapped[str] = mapped_column(String(7), nullable=False, default="#145DA0")
    secondary_color: Mapped[str] = mapped_column(String(7), nullable=False, default="#FFFFFF")
    accent_color: Mapped[str] = mapped_column(String(7), nullable=False, default="#F4B942")
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class Currency(Base):
    __tablename__ = "currencies"

    code: Mapped[str] = mapped_column(String(3), primary_key=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    symbol: Mapped[str] = mapped_column(String(8), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))


class BankExchangeRate(Base):
    __tablename__ = "bank_exchange_rates"
    __table_args__ = (
        UniqueConstraint("tenant_id", "from_currency", "to_currency", name="uq_bank_exchange_rate_pair"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    tenant_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("tenants.id"), nullable=False, index=True
    )
    from_currency: Mapped[str] = mapped_column(String(3), ForeignKey("currencies.code"), nullable=False)
    to_currency: Mapped[str] = mapped_column(String(3), ForeignKey("currencies.code"), nullable=False)
    rate: Mapped[float] = mapped_column(Numeric(18, 6), nullable=False)
    fee_amount: Mapped[float] = mapped_column(Numeric(18, 2), nullable=False, server_default=text("0"))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )
