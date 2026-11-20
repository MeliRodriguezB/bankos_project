from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_db, get_current_user, require_roles
from app.modules.accounts.schemas import (
    AccountCreate,
    AccountResponse,
    AccountDetailResponse,
    DashboardResponse,
    TenantAdminAccountResponse,
    TenantAdminDashboardResponse,
)
from app.modules.accounts.service import AccountService

router = APIRouter(tags=["Accounts & Dashboard"])


@router.get("/dashboard", response_model=DashboardResponse, summary="Consultar resumen financiero del dashboard")
def get_dashboard(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return AccountService.get_dashboard_summary(
        db=db,
        tenant_id=current_user["tenant_id"],
        user_id=current_user["user_id"],
        user_name=current_user.get("name", "Usuario"),
        user_email=current_user.get("email", ""),
    )


@router.get("/accounts", response_model=list[AccountResponse], summary="Listar cuentas del usuario autenticado")
def get_accounts(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    accounts = AccountService.get_accounts_for_user(
        db=db, tenant_id=current_user["tenant_id"], user_id=current_user["user_id"]
    )
    return [
        AccountResponse(
            id=acc.id,
            account_number=acc.account_number,
            account_number_masked=acc.account_number_masked,
            alias=acc.alias,
            balance=f"{acc.balance:.2f}",
            currency=acc.currency,
            status=acc.status,
            created_at=acc.created_at,
        )
        for acc in accounts
    ]


@router.get("/accounts/{account_id}", response_model=AccountDetailResponse)
def get_account_detail(
    account_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    acc = AccountService.get_account_by_id(
        db=db,
        account_id=account_id,
        tenant_id=current_user["tenant_id"],
        user_id=current_user["user_id"],
    )
    return AccountDetailResponse(
        id=acc.id,
        account_number=acc.account_number,
        account_number_masked=acc.account_number_masked,
        alias=acc.alias,
        balance=f"{acc.balance:.2f}",
        currency=acc.currency,
        status=acc.status,
        created_at=acc.created_at,
        tenant_id=acc.tenant_id,
        user_id=acc.user_id,
        updated_at=acc.updated_at,
    )


@router.post(
    "/accounts",
    response_model=AccountResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear una cuenta bancaria (solo ADMIN)",
)
def create_account(
    data: AccountCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles("ADMIN")),
):
    acc = AccountService.create_account(
        db=db,
        tenant_id=current_user["tenant_id"],
        user_id=current_user["user_id"],
        data=data,
    )
    return AccountResponse(
        id=acc.id,
        account_number=acc.account_number,
        account_number_masked=acc.account_number_masked,
        alias=acc.alias,
        balance=f"{acc.balance:.2f}",
        currency=acc.currency,
        status=acc.status,
        created_at=acc.created_at,
    )


@router.patch("/accounts/{account_id}/deactivate", response_model=AccountResponse)
def deactivate_account(
    account_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    acc = AccountService.deactivate_account(
        db=db,
        account_id=account_id,
        tenant_id=current_user["tenant_id"],
        user_id=current_user["user_id"],
    )
    return AccountResponse(
        id=acc.id,
        account_number=acc.account_number,
        account_number_masked=acc.account_number_masked,
        alias=acc.alias,
        balance=f"{acc.balance:.2f}",
        currency=acc.currency,
        status=acc.status,
        created_at=acc.created_at,
    )


@router.get(
    "/admin/accounts",
    response_model=list[TenantAdminAccountResponse],
    summary="Listar cuentas de la institución (solo ADMIN)",
)
def get_tenant_accounts_admin(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles("ADMIN")),
):
    """La consulta se limita al tenant del administrador autenticado."""
    return AccountService.get_accounts_for_tenant_admin(
        db=db,
        tenant_id=current_user["tenant_id"],
    )


@router.get(
    "/admin/dashboard",
    response_model=TenantAdminDashboardResponse,
    summary="Consultar métricas institucionales (solo ADMIN)",
)
def get_tenant_admin_dashboard(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles("ADMIN")),
):
    """Métricas agregadas de la institución del administrador autenticado."""
    return AccountService.get_tenant_admin_dashboard(
        db=db,
        tenant_id=current_user["tenant_id"],
    )
