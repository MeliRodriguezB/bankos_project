"""Protect the financial transaction ledger from UPDATE and DELETE."""
from alembic import op

revision = "20261120_immutable_tx"
down_revision = "20261120_tenant_config"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE OR REPLACE FUNCTION reject_financial_transaction_mutation()
        RETURNS trigger AS $$
        BEGIN
            RAISE EXCEPTION 'Financial transaction records are immutable';
        END;
        $$ LANGUAGE plpgsql
    """)
    op.execute("""
        DROP TRIGGER IF EXISTS trg_financial_transactions_immutable
        ON financial_transactions
    """)
    op.execute("""
        CREATE TRIGGER trg_financial_transactions_immutable
        BEFORE UPDATE OR DELETE ON financial_transactions
        FOR EACH ROW EXECUTE FUNCTION reject_financial_transaction_mutation()
    """)


def downgrade() -> None:
    op.execute("""
        DROP TRIGGER IF EXISTS trg_financial_transactions_immutable
        ON financial_transactions
    """)
    op.execute("DROP FUNCTION IF EXISTS reject_financial_transaction_mutation()")
