"""Add institution-level transfer policies and webhook configuration."""
from alembic import op

revision = "20261120_tenant_config"
down_revision = "20261120_pin"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # IF NOT EXISTS makes the migration safe after ORM metadata bootstrap.
    op.execute("""
        ALTER TABLE tenants
        ADD COLUMN IF NOT EXISTS max_transfer_amount NUMERIC(18, 2)
        NOT NULL DEFAULT 5000000.00
    """)
    op.execute("""
        ALTER TABLE tenants
        ADD COLUMN IF NOT EXISTS transfer_fees JSON NOT NULL
        DEFAULT '{"COP":"1500.00","USD":"1.00","EUR":"1.00"}'::json
    """)
    op.execute("""
        ALTER TABLE tenants
        ADD COLUMN IF NOT EXISTS transfer_fee_percent NUMERIC(7, 4)
        NOT NULL DEFAULT 0.0000
    """)
    op.execute("""
        ALTER TABLE tenants
        ADD COLUMN IF NOT EXISTS primary_currency VARCHAR(3)
        NOT NULL DEFAULT 'COP'
    """)
    op.execute("""
        ALTER TABLE tenants
        ADD COLUMN IF NOT EXISTS supported_currencies JSON NOT NULL
        DEFAULT '["COP","USD","EUR"]'::json
    """)
    op.execute("""
        ALTER TABLE tenants
        ADD COLUMN IF NOT EXISTS exchange_rates JSON NOT NULL
        DEFAULT '{"COP/USD":"0.00025","USD/COP":"4000.00","EUR/COP":"4350.00","COP/EUR":"0.00023","USD/EUR":"0.92","EUR/USD":"1.09"}'::json
    """)
    op.execute("""
        ALTER TABLE tenants
        ADD COLUMN IF NOT EXISTS webhook_url VARCHAR(500)
    """)


def downgrade() -> None:
    op.execute("ALTER TABLE tenants DROP COLUMN IF EXISTS webhook_url")
    op.execute("ALTER TABLE tenants DROP COLUMN IF EXISTS exchange_rates")
    op.execute("ALTER TABLE tenants DROP COLUMN IF EXISTS supported_currencies")
    op.execute("ALTER TABLE tenants DROP COLUMN IF EXISTS primary_currency")
    op.execute("ALTER TABLE tenants DROP COLUMN IF EXISTS transfer_fee_percent")
    op.execute("ALTER TABLE tenants DROP COLUMN IF EXISTS transfer_fees")
    op.execute("ALTER TABLE tenants DROP COLUMN IF EXISTS max_transfer_amount")
