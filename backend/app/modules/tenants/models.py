from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, JSON, Numeric, String, UniqueConstraint, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Tenant(Base):
    """Institución que utiliza la plataforma BankOS."""

    __tablename__ = "tenants"

    id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    slug: Mapped[str] = mapped_column(String(80), unique=True, nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default=text("'ACTIVE'")
    )
    # Parámetros comerciales configurables por institución.
    max_transfer_amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False, server_default=text("5000000.00")
    )
    transfer_fees: Mapped[dict[str, str]] = mapped_column(
        JSON,
        nullable=False,
        default=lambda: {"COP": "1500.00", "USD": "1.00", "EUR": "1.00"},
    )
    transfer_fee_percent: Mapped[Decimal] = mapped_column(
        Numeric(7, 4), nullable=False, server_default=text("0.0000")
    )
    primary_currency: Mapped[str] = mapped_column(
        String(3), nullable=False, server_default=text("'COP'")
    )
    supported_currencies: Mapped[list[str]] = mapped_column(
        JSON, nullable=False, default=lambda: ["COP", "USD", "EUR"]
    )
    exchange_rates: Mapped[dict[str, str]] = mapped_column(
        JSON,
        nullable=False,
        default=lambda: {
            "COP/USD": "0.00025",
            "USD/COP": "4000.00",
            "EUR/COP": "4350.00",
            "COP/EUR": "0.00023",
            "USD/EUR": "0.92",
            "EUR/USD": "1.09",
        },
    )
    webhook_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class TenantMembership(Base):
    """Vincula una identidad de usuario con una institución."""

    __tablename__ = "tenant_memberships"
    __table_args__ = (
        UniqueConstraint("tenant_id", "user_id", name="uq_membership_tenant_user"),
        UniqueConstraint("tenant_id", "id", name="uq_membership_tenant_id"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    tenant_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default=text("'ACTIVE'")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
