from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_db, get_current_user
from app.modules.accounts.schemas import (
    AccountCreate,
    AccountResponse,
    AccountDetailResponse,
    DashboardResponse,
)
from app.modules.accounts.service import AccountService

router = APIRouter(tags=["Accounts & Dashboard"])


@router.get(
    "/dashboard",
    response_model=DashboardResponse,
    summary="Consultar resumen financiero del dashboard",
    description="Devuelve el balance total por moneda, el conteo de cuentas y el listado de cuentas del usuario en su tenant."
)
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


@router.get(
    "/accounts",
    response_model=list[AccountResponse],
    summary="Listar cuentas bancarias del usuario autenticado",
    description="Devuelve todas las cuentas (activas e inactivas) que pertenecen al usuario dentro de su institución (tenant)."
)
def get_accounts(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    accounts = AccountService.get_accounts_for_user(
        db=db,
        tenant_id=current_user["tenant_id"],
        user_id=current_user["user_id"],
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


@router.get(
    "/accounts/{account_id}",
    response_model=AccountDetailResponse,
    summary="Consultar el detalle de una cuenta bancaria",
    description="Devuelve la información detallada de una cuenta específica garantizando que pertenezca al usuario y tenant autenticado."
)
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
    summary="Crear una nueva cuenta bancaria",
    description="Crea una cuenta en el tenant del usuario actual. Solo disponible para administradores o proceso de apertura."
)
def create_account(
    data: AccountCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
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


@router.patch(
    "/accounts/{account_id}/deactivate",
    response_model=AccountResponse,
    summary="Desactivar una cuenta (Borrado Lógico / Soft Delete)",
    description="Cambia el estado de la cuenta a INACTIVE para impedir transacciones futuras sin borrar el registro de la BD."
)
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
