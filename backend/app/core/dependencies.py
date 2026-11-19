from typing import Generator, Optional, Callable
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.session import SessionLocal
from app.modules.tenants.models import Tenant, TenantMembership
from app.modules.users.models import User
from app.modules.roles.models import Role, membership_roles

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
    db: Session = Depends(get_db),
) -> dict:
    """Valida JWT y vuelve a comprobar usuario, tenant, membresía y roles en BD."""
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciales de autenticación no válidas, revocadas o expiradas.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise unauthorized

    try:
        payload = decode_access_token(credentials.credentials)
        user_id = UUID(str(payload.get("sub") or payload.get("user_id")))
        tenant_id = UUID(str(payload.get("tenant_id")))
        membership_id = UUID(str(payload.get("membership_id")))
    except (jwt.PyJWTError, TypeError, ValueError, AttributeError):
        raise unauthorized

    membership = (
        db.query(TenantMembership)
        .join(User, User.id == TenantMembership.user_id)
        .join(Tenant, Tenant.id == TenantMembership.tenant_id)
        .filter(
            TenantMembership.id == membership_id,
            TenantMembership.user_id == user_id,
            TenantMembership.tenant_id == tenant_id,
            TenantMembership.status == "ACTIVE",
            User.is_active.is_(True),
            Tenant.status == "ACTIVE",
        )
        .first()
    )
    if membership is None:
        raise unauthorized

    roles = [
        row[0]
        for row in (
            db.query(Role.code)
            .join(membership_roles, membership_roles.c.role_id == Role.id)
            .filter(
                membership_roles.c.tenant_id == tenant_id,
                membership_roles.c.membership_id == membership_id,
                Role.tenant_id == tenant_id,
            )
            .all()
        )
    ]
    if not roles:
        roles = ["CUSTOMER"]

    return {
        "user_id": str(user_id),
        "tenant_id": str(tenant_id),
        "membership_id": str(membership_id),
        "role": roles[0],
        "roles": [role.upper() for role in roles],
        "email": payload.get("email", ""),
        "name": payload.get("name", "Usuario"),
    }


def require_roles(*allowed_roles: str) -> Callable:
    """Exige que el usuario tenga al menos uno de los roles vigentes en BD."""
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
