from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, get_db
from app.modules.users.schemas import (
    TransactionPinSetupRequest,
    TransactionPinStatusResponse,
)
from app.modules.users.service import UserService
from app.modules.users.models import PlatformAdmin

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
        PlatformAdmin.user_id == current_user["user_id"],
        PlatformAdmin.is_active.is_(True),
    ).first() is not None
    return {"is_platform_admin": is_platform_admin}

