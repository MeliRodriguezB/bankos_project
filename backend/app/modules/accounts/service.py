from decimal import Decimal
from uuid import UUID
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, cast, String

from app.modules.accounts.models import Account
from app.modules.accounts.schemas import (
    AccountCreate,
    AccountResponse,
    CurrencyBalanceSummary,
    DashboardResponse,
    DashboardUser,
    DashboardTenant,
)
from app.modules.tenants.models import TenantMembership
from app.modules.users.models import User
from app.modules.transactions.models import Transaction
from app.modules.accounts.schemas import TenantAdminCurrencyBalance, TenantAdminTransactionSummary, TenantAdminDashboardResponse
from app.modules.tenants.models import Tenant


class AccountService:
    """Servicios de cuentas con aislamiento obligatorio por institución y titular."""

    @staticmethod
    def get_accounts_for_user(
        db: Session, tenant_id: str, user_id: str, include_inactive: bool = True
    ) -> list[Account]:
        query = db.query(Account).filter(
            Account.tenant_id == tenant_id,
            Account.user_id == user_id,
        )
        if not include_inactive:
            query = query.filter(Account.status == "ACTIVE")
        return query.order_by(Account.created_at.desc()).all()

    @staticmethod
    def get_account_by_id(
        db: Session, account_id: str, tenant_id: str, user_id: str
    ) -> Account:
        account = db.query(Account).filter(
            Account.id == account_id,
            Account.tenant_id == tenant_id,
            Account.user_id == user_id,
        ).first()
        if not account:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="La cuenta solicitada no existe o no tienes autorización para consultarla.",
            )
        return account

    @staticmethod
    def create_account(
        db: Session, tenant_id: str, user_id: str, data: AccountCreate
    ) -> Account:
        """Crea cuenta solo para un titular con membresía activa en el mismo tenant."""
        target_user_id = data.user_id or user_id
        membership = db.query(TenantMembership).filter(
            TenantMembership.tenant_id == UUID(tenant_id),
            TenantMembership.user_id == UUID(target_user_id),
            TenantMembership.status == "ACTIVE",
        ).first()
        if not membership:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="El titular no tiene una membresía activa en esta institución.",
            )

        existing = db.query(Account).filter(
            Account.tenant_id == tenant_id,
            Account.account_number == data.account_number,
        ).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="El número de cuenta ya está registrado en esta institución.",
            )

        account = Account(
            account_number=data.account_number,
            alias=data.alias,
            tenant_id=tenant_id,
            user_id=target_user_id,
            balance=data.initial_balance,
            currency=data.currency.upper(),
            status="ACTIVE",
        )
        db.add(account)
        db.commit()
        db.refresh(account)
        return account

    @staticmethod
    def deactivate_account(
        db: Session, account_id: str, tenant_id: str, user_id: str
    ) -> Account:
        account = AccountService.get_account_by_id(db, account_id, tenant_id, user_id)
        account.status = "INACTIVE"
        db.commit()
        db.refresh(account)
        return account

    @staticmethod
    def get_dashboard_summary(
        db: Session, tenant_id: str, user_id: str, user_name: str, user_email: str
    ) -> DashboardResponse:
        accounts = AccountService.get_accounts_for_user(
            db, tenant_id, user_id, include_inactive=True
        )
        currency_totals: dict[str, dict] = {}
        for account in accounts:
            currency_totals.setdefault(
                account.currency, {"total": Decimal("0.00"), "count": 0}
            )
            if account.status == "ACTIVE":
                currency_totals[account.currency]["total"] += account.balance
                currency_totals[account.currency]["count"] += 1

        balances_summary = [
            CurrencyBalanceSummary(
                currency=currency,
                total_balance=f"{values['total']:.2f}",
                active_accounts_count=values["count"],
            )
            for currency, values in sorted(currency_totals.items())
        ]
        if not balances_summary:
            balances_summary.append(
                CurrencyBalanceSummary(
                    currency="COP", total_balance="0.00", active_accounts_count=0
                )
            )

        accounts_response = [
            AccountResponse(
                id=account.id,
                account_number=account.account_number,
                account_number_masked=account.account_number_masked,
                alias=account.alias,
                balance=f"{account.balance:.2f}",
                currency=account.currency,
                status=account.status,
                created_at=account.created_at,
            )
            for account in accounts
        ]
        return DashboardResponse(
            user=DashboardUser(
                id=user_id,
                name=user_name or "Usuario BankOS",
                email=user_email or "usuario@bankos.com",
            ),
            tenant=DashboardTenant(
                id=tenant_id,
                name=f"Institución {tenant_id.replace('tenant-', '').capitalize()}",
                primary_currency="COP",
            ),
            balances_by_currency=balances_summary,
            accounts=accounts_response,
        )

    @staticmethod
    def get_accounts_for_tenant_admin(db: Session, tenant_id: str) -> list[dict]:
        """Lista cuentas y titulares únicamente dentro del tenant del ADMIN autenticado."""
        rows = (
            db.query(Account, User.full_name, User.email)
            .join(User, cast(User.id, String) == Account.user_id)
            .filter(Account.tenant_id == tenant_id)
            .order_by(Account.created_at.desc())
            .all()
        )
        return [
            {
                "id": account.id,
                "account_number": account.account_number,
                "account_number_masked": account.account_number_masked,
                "alias": account.alias,
                "balance": f"{account.balance:.2f}",
                "currency": account.currency,
                "status": account.status,
                "created_at": account.created_at,
                "user_id": account.user_id,
                "owner_name": owner_name,
                "owner_email": owner_email,
            }
            for account, owner_name, owner_email in rows
        ]


    @staticmethod
    def get_tenant_admin_dashboard(db: Session, tenant_id: str) -> TenantAdminDashboardResponse:
        """Calcula métricas agregadas usando exclusivamente el tenant autenticado."""
        tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
        if not tenant:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Institución no encontrada.")

        active_memberships = db.query(TenantMembership).filter(
            TenantMembership.tenant_id == tenant_id,
            TenantMembership.status == "ACTIVE",
        ).count()

        total_accounts = db.query(Account).filter(Account.tenant_id == tenant_id).count()
        active_accounts = db.query(Account).filter(
            Account.tenant_id == tenant_id, Account.status == "ACTIVE"
        ).count()
        inactive_accounts = total_accounts - active_accounts

        balance_rows = db.query(
            Account.currency,
            func.sum(Account.balance),
            func.count(Account.id),
        ).filter(
            Account.tenant_id == tenant_id,
            Account.status == "ACTIVE",
        ).group_by(Account.currency).order_by(Account.currency).all()

        balances = [
            TenantAdminCurrencyBalance(
                currency=currency,
                total_balance=f"{(total or Decimal('0.00')):.2f}",
                active_accounts_count=count,
            )
            for currency, total, count in balance_rows
        ]

        transaction_rows = db.query(
            Transaction.status,
            Transaction.type,
            Transaction.currency,
            func.count(Transaction.id),
            func.sum(Transaction.amount),
        ).filter(
            Transaction.tenant_id == tenant_id,
        ).group_by(
            Transaction.status, Transaction.type, Transaction.currency
        ).order_by(
            Transaction.status, Transaction.type, Transaction.currency
        ).all()

        transaction_summary = [
            TenantAdminTransactionSummary(
                status=tx_status,
                type=tx_type,
                currency=currency,
                count=count,
                total_amount=f"{(total or Decimal('0.00')):.2f}",
            )
            for tx_status, tx_type, currency, count, total in transaction_rows
        ]

        transactions_total = db.query(Transaction).filter(
            Transaction.tenant_id == tenant_id
        ).count()

        return TenantAdminDashboardResponse(
            tenant_id=str(tenant.id),
            tenant_name=tenant.name,
            active_memberships=active_memberships,
            total_accounts=total_accounts,
            active_accounts=active_accounts,
            inactive_accounts=inactive_accounts,
            balances_by_currency=balances,
            transactions_total=transactions_total,
            transactions_by_status_currency=transaction_summary,
        )
