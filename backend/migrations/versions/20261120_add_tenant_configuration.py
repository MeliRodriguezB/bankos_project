"""Add institution-level transfer policies and webhook configuration."""
from alembic import op
import sqlalchemy as sa

revision = "20261120_tenant_config"
down_revision = "20261120_pin"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tenants",
        sa.Column(
            "max_transfer_amount",
            sa.Numeric(18, 2),
            nullable=False,
            server_default=sa.text("5000000.00"),
        ),
    )
    op.add_column(
        "tenants",
        sa.Column(
            "transfer_fees",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("""'{"COP":"1500.00","USD":"1.00","EUR":"1.00"}'::json"""),
        ),
    )
    op.add_column(
        "tenants",
        sa.Column(
            "transfer_fee_percent",
            sa.Numeric(7, 4),
            nullable=False,
            server_default=sa.text("0.0000"),
        ),
    )
    op.add_column(
        "tenants",
        sa.Column(
            "primary_currency",
            sa.String(3),
            nullable=False,
            server_default=sa.text("'COP'"),
        ),
    )
    op.add_column(
        "tenants",
        sa.Column(
            "supported_currencies",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("""'["COP","USD","EUR"]'::json"""),
        ),
    )
    op.add_column(
        "tenants",
        sa.Column(
            "exchange_rates",
            sa.JSON(),
            nullable=False,
            server_default=sa.text(
                """'{"COP/USD":"0.00025","USD/COP":"4000.00","EUR/COP":"4350.00","COP/EUR":"0.00023","USD/EUR":"0.92","EUR/USD":"1.09"}'::json"""
            ),
        ),
    )
    op.add_column("tenants", sa.Column("webhook_url", sa.String(500), nullable=True))


def downgrade() -> None:
    op.drop_column("tenants", "webhook_url")
    op.drop_column("tenants", "exchange_rates")
    op.drop_column("tenants", "supported_currencies")
    op.drop_column("tenants", "primary_currency")
    op.drop_column("tenants", "transfer_fee_percent")
    op.drop_column("tenants", "transfer_fees")
    op.drop_column("tenants", "max_transfer_amount")
