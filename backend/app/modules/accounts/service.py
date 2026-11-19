from decimal import Decimal
from typing import Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.modules.accounts.models import Account
from app.modules.accounts.schemas import (
    AccountCreate,
    AccountResponse,
    CurrencyBalanceSummary,
    DashboardResponse,
    DashboardUser,
    DashboardTenant,
)


class AccountService:
    """
    Capa de servicio para la gestión de cuentas y agregaciones del dashboard.
    
    Regla de oro:
    Toda consulta a la base de datos INCLUYE obligatoriamente 'tenant_id' y 'user_id'
    para garantizar el aislamiento estricto entre instituciones y entre clientes.
    """

    @staticmethod
    def get_accounts_for_user(
        db: Session,
        tenant_id: str,
        user_id: str,
        include_inactive: bool = True
    ) -> list[Account]:
        """Consulta todas las cuentas del usuario autenticado en su tenant."""
        query = db.query(Account).filter(
            Account.tenant_id == tenant_id,
            Account.user_id == user_id
        )
        if not include_inactive:
            query = query.filter(Account.status == "ACTIVE")
            
        return query.order_by(Account.created_at.desc()).all()

    @staticmethod
    def get_account_by_id(
        db: Session,
        account_id: str,
        tenant_id: str,
        user_id: str
    ) -> Account:
        """
        Obtiene el detalle de una cuenta validando propiedad y pertenencia al tenant.
        Si la cuenta existe pero pertenece a otro tenant/usuario, responde 404
        para evitar que atacantes enumeren la existencia de cuentas ajenas.
        """
        account = db.query(Account).filter(
            Account.id == account_id,
            Account.tenant_id == tenant_id,
            Account.user_id == user_id
        ).first()

        if not account:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="La cuenta solicitada no existe o no tienes autorización para consultarla."
            )
        return account

    @staticmethod
    def create_account(
        db: Session,
        tenant_id: str,
        user_id: str,
        data: AccountCreate
    ) -> Account:
        """Crea una nueva cuenta bancaria para un usuario dentro del tenant."""
        # Verificar unicidad del número de cuenta dentro del mismo tenant
        existing = db.query(Account).filter(
            Account.tenant_id == tenant_id,
            Account.account_number == data.account_number
        ).first()

        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"El número de cuenta {data.account_number} ya está registrado en esta institución."
            )

        target_user_id = data.user_id if data.user_id else user_id

        account = Account(
            account_number=data.account_number,
            alias=data.alias,
            tenant_id=tenant_id,
            user_id=target_user_id,
            balance=data.initial_balance,
            currency=data.currency.upper(),
            status="ACTIVE"
        )
        db.add(account)
        db.commit()
        db.refresh(account)
        return account

    @staticmethod
    def deactivate_account(
        db: Session,
        account_id: str,
        tenant_id: str,
        user_id: str
    ) -> Account:
        """
        Borrado lógico (Soft delete):
        Desactiva la cuenta cambiando su estado a 'INACTIVE'.
        Nunca se elimina el registro de la BD para preservar el historial de transacciones.
        """
        account = AccountService.get_account_by_id(db, account_id, tenant_id, user_id)
        account.status = "INACTIVE"
        db.commit()
        db.refresh(account)
        return account

    @staticmethod
    def get_dashboard_summary(
        db: Session,
        tenant_id: str,
        user_id: str,
        user_name: str,
        user_email: str
    ) -> DashboardResponse:
        """
        Construye el resumen financiero para el inicio de la app móvil.
        Calcula los saldos totales agrupados por divisa para evitar sumar monedas distintas.
        """
        accounts = AccountService.get_accounts_for_user(
            db=db,
            tenant_id=tenant_id,
            user_id=user_id,
            include_inactive=True
        )

        # Agrupar saldos por divisa usando Decimal de forma precisa
        currency_totals: dict[str, dict] = {}
        for acc in accounts:
            curr = acc.currency
            if curr not in currency_totals:
                currency_totals[curr] = {
                    "total": Decimal("0.00"),
                    "count": 0
                }
            if acc.status == "ACTIVE":
                currency_totals[curr]["total"] += acc.balance
                currency_totals[curr]["count"] += 1

        balances_summary = [
            CurrencyBalanceSummary(
                currency=curr,
                total_balance=f"{info['total']:.2f}",
                active_accounts_count=info["count"]
            )
            for curr, info in sorted(currency_totals.items())
        ]

        # Si el usuario no tiene ninguna cuenta activa aún, mostramos al menos COP en 0.00
        if not balances_summary:
            balances_summary.append(
                CurrencyBalanceSummary(
                    currency="COP",
                    total_balance="0.00",
                    active_accounts_count=0
                )
            )

        # Mapear cuentas al formato de respuesta
        accounts_response = [
            AccountResponse(
                id=acc.id,
                account_number=acc.account_number,
                account_number_masked=acc.account_number_masked,
                alias=acc.alias,
                balance=f"{acc.balance:.2f}",
                currency=acc.currency,
                status=acc.status,
                created_at=acc.created_at
            )
            for acc in accounts
        ]

        return DashboardResponse(
            user=DashboardUser(
                id=user_id,
                name=user_name or "Usuario BankOS",
                email=user_email or "usuario@bankos.com"
            ),
            tenant=DashboardTenant(
                id=tenant_id,
                name=f"Institución {tenant_id.replace('tenant-', '').capitalize()}",
                primary_currency="COP"
            ),
            balances_by_currency=balances_summary,
            accounts=accounts_response
        )
