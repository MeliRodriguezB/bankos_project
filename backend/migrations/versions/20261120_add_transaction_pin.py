"""Add personal transaction PIN security fields."""
from alembic import op

revision = "20261120_pin"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS transaction_pin_hash TEXT NULL")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS transaction_pin_failed_attempts INTEGER NOT NULL DEFAULT 0")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS transaction_pin_locked_until TIMESTAMPTZ NULL")


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS transaction_pin_locked_until")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS transaction_pin_failed_attempts")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS transaction_pin_hash")
