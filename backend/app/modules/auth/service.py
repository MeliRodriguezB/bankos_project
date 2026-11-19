from typing import Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.config import settings
from app.core.security import verify_password, create_access_token
from app.modules.tenants.models import Tenant, TenantMembership
from app.modules.users.models import User
from app.modules.roles.models import Role, membership_roles
from app.modules.auth.schemas import LoginRequest, LoginResponse, AuthUser


class AuthService:
    """
    Servicio de autenticación y autorización con aislamiento multitenant.
    
    Regla crítica del reto:
    Un usuario solo puede iniciar sesión si existe como entidad global y además
    posee una membresía ACTIVA en la institución (tenant) identificada por su slug.
    """

    @staticmethod
    def authenticate(db: Session, login_data: LoginRequest) -> LoginResponse:
        # 1. Buscar la institución por slug
        tenant = db.query(Tenant).filter(
            Tenant.slug == login_data.tenant_slug.lower(),
            Tenant.status == "ACTIVE"
        ).first()

        if not tenant:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"La institución '{login_data.tenant_slug}' no existe o se encuentra inactiva."
            )

        # 2. Buscar al usuario por correo
        user = db.query(User).filter(
            func.lower(User.email) == login_data.email.lower()
        ).first()

        if not user or not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales incorrectas o usuario deshabilitado."
            )

        # 3. Validar membresía del usuario dentro de ese tenant específico
        membership = db.query(TenantMembership).filter(
            TenantMembership.tenant_id == tenant.id,
            TenantMembership.user_id == user.id,
            TenantMembership.status == "ACTIVE"
        ).first()

        if not membership:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="El usuario no tiene una cuenta activa en esta institución bancaria."
            )

        # 4. Validar contraseña con Argon2
        if not verify_password(login_data.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales incorrectas."
            )

        # 5. Consultar roles asignados en el tenant
        assigned_roles = (
            db.query(Role.code)
            .join(membership_roles, membership_roles.c.role_id == Role.id)
            .filter(
                membership_roles.c.tenant_id == tenant.id,
                membership_roles.c.membership_id == membership.id
            )
            .all()
        )
        roles = [r[0] for r in assigned_roles] if assigned_roles else ["CUSTOMER"]

        # 6. Generar JWT firmado con los claims de aislamiento multitenant
        token_payload = {
            "sub": str(user.id),
            "user_id": str(user.id),
            "tenant_id": str(tenant.id),
            "membership_id": str(membership.id),
            "tenant_slug": tenant.slug,
            "name": user.full_name,
            "email": user.email,
            "role": roles[0],
            "roles": roles,
        }

        access_token = create_access_token(token_payload)

        return LoginResponse(
            access_token=access_token,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=AuthUser(
                id=str(user.id),
                name=user.full_name,
                email=user.email,
                tenant_id=str(tenant.id),
                membership_id=str(membership.id),
                roles=roles,
            )
        )
