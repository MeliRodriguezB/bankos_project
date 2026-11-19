from typing import Generator, Optional, Callable
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.session import SessionLocal

security_bearer = HTTPBearer(auto_error=False)


def get_db() -> Generator[Session, None, None]:
    """Abre una sesión por petición y la cierra siempre al finalizar."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
) -> dict:
    """Obtiene la identidad y el contexto multitenant exclusivamente del JWT."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciales de autenticación no válidas o expiradas.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # No existe bypass de autenticación, ni siquiera en desarrollo.
    if credentials is None:
        raise credentials_exception

    try:
        payload = decode_access_token(credentials.credentials)
        user_id = payload.get("sub") or payload.get("user_id")
        tenant_id = payload.get("tenant_id")
        membership_id = payload.get("membership_id")
        roles = payload.get("roles") or [payload.get("role", "CUSTOMER")]

        if not user_id or not tenant_id or not membership_id:
            raise credentials_exception
        if not isinstance(roles, list) or not all(isinstance(role, str) for role in roles):
            raise credentials_exception

        return {
            "user_id": str(user_id),
            "tenant_id": str(tenant_id),
            "membership_id": str(membership_id),
            "role": roles[0] if roles else "CUSTOMER",
            "roles": [role.upper() for role in roles],
            "email": payload.get("email", ""),
            "name": payload.get("name", "Usuario"),
        }
    except jwt.PyJWTError:
        raise credentials_exception


def require_roles(*allowed_roles: str) -> Callable:
    """Crea una dependencia que exige al menos uno de los roles indicados."""
    allowed = {role.upper() for role in allowed_roles}

    def role_checker(current_user: dict = Depends(get_current_user)) -> dict:
        user_roles = set(current_user.get("roles", []))
        if not user_roles.intersection(allowed):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para realizar esta operación.",
            )
        return current_user

    return role_checker
