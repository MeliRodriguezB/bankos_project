from fastapi import APIRouter, Depends
from uuid import UUID
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, get_db
from app.modules.users.schemas import (
    TransactionPinSetupRequest,
    TransactionPinStatusResponse,
)
from app.modules.users.service import UserService
from app.modules.users.models import PlatformAdmin
from app.modules.tenants.models import Tenant
from app.modules.admin.models import BankConfiguration

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me/transaction-pin", response_model=TransactionPinStatusResponse)
def get_transaction_pin_status(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return UserService.get_transaction_pin_status(db, current_user["user_id"])


@router.put("/me/transaction-pin", response_model=TransactionPinStatusResponse)
def configure_transaction_pin(
    data: TransactionPinSetupRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return UserService.configure_transaction_pin(
        db=db,
        user_id=current_user["user_id"],
        current_password=data.current_password,
        pin=data.pin,
    )


@router.get("/me/platform-admin")
def get_platform_admin_status(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Confirma el privilegio global consultando la base de datos, no solo el rol del tenant."""
    is_platform_admin = db.query(PlatformAdmin).filter(
        PlatformAdmin.user_id == UUID(current_user["user_id"]),
        PlatformAdmin.is_active.is_(True),
    ).first() is not None
    return {"is_platform_admin": is_platform_admin}

@router.get("/me/bank-branding")
def get_bank_branding(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Branding del tenant actual; nunca permite consultar otro tenant por ID."""
    tenant = db.query(Tenant).filter(
        Tenant.id == UUID(current_user["tenant_id"]),
    ).first()
    if tenant is None:
        return {"tenant_name": "BankOS", "primary_color": "#0284C7", "secondary_color": "#FFFFFF", "accent_color": "#10B981"}
    config = db.query(BankConfiguration).filter(
        BankConfiguration.tenant_id == tenant.id,
    ).first()
    return {
        "tenant_name": tenant.name,
        "primary_color": config.primary_color if config else "#0284C7",
        "secondary_color": config.secondary_color if config else "#FFFFFF",
        "accent_color": config.accent_color if config else "#10B981",
    }

