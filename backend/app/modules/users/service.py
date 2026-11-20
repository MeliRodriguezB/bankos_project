from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.modules.users.models import User


class UserService:
    PIN_MAX_ATTEMPTS = 5
    PIN_LOCK_MINUTES = 15

    @staticmethod
    def configure_transaction_pin(
        db: Session, user_id: str, current_password: str, pin: str
    ) -> dict:
        user = db.query(User).filter(User.id == UUID(user_id)).with_for_update().first()
        if user is None or not verify_password(current_password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="La contraseña actual no es correcta.",
            )

        user.transaction_pin_hash = hash_password(pin)
        user.transaction_pin_failed_attempts = 0
        user.transaction_pin_locked_until = None
        db.commit()
        return {"configured": True}

    @staticmethod
    def get_transaction_pin_status(db: Session, user_id: str) -> dict:
        user = db.query(User).filter(User.id == UUID(user_id)).first()
        if user is None:
            raise HTTPException(status_code=404, detail="Usuario no encontrado.")
        return {"configured": user.transaction_pin_hash is not None}

    @classmethod
    def verify_transaction_pin(cls, db: Session, user_id: str, pin: str) -> None:
        user = db.query(User).filter(User.id == UUID(user_id)).with_for_update().first()
        if user is None or not user.is_active:
            raise HTTPException(status_code=401, detail="Usuario no autorizado.")

        now = datetime.now(timezone.utc)
        locked_until = user.transaction_pin_locked_until
        if locked_until is not None:
            if locked_until.tzinfo is None:
                locked_until = locked_until.replace(tzinfo=timezone.utc)
            if locked_until > now:
                db.rollback()
                raise HTTPException(
                    status_code=status.HTTP_423_LOCKED,
                    detail="PIN bloqueado temporalmente. Intenta nuevamente en 15 minutos.",
                )
            user.transaction_pin_locked_until = None
            user.transaction_pin_failed_attempts = 0

        if not user.transaction_pin_hash:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Debes configurar tu PIN de transacciones antes de operar.",
            )

        if not verify_password(pin, user.transaction_pin_hash):
            user.transaction_pin_failed_attempts += 1
            if user.transaction_pin_failed_attempts >= cls.PIN_MAX_ATTEMPTS:
                user.transaction_pin_locked_until = now + timedelta(minutes=cls.PIN_LOCK_MINUTES)
            db.commit()
            if user.transaction_pin_locked_until:
                raise HTTPException(
                    status_code=status.HTTP_423_LOCKED,
                    detail="Se alcanzó el máximo de intentos. PIN bloqueado durante 15 minutos.",
                )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="El PIN de autorización ingresado es incorrecto.",
            )

        user.transaction_pin_failed_attempts = 0
        user.transaction_pin_locked_until = None
        db.commit()
