from typing import Generator, Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import decode_access_token
from app.db.session import SessionLocal

security_bearer = HTTPBearer(auto_error=False)


def get_db() -> Generator[Session, None, None]:
    """
    Inyector de dependencia para la sesión de base de datos.
    Abre una conexión al inicio del request y garantiza que se cierre
    al finalizar (incluso si ocurre un error), evitando fugas de conexiones en el pool.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
) -> dict:
    """
    Extrae, valida y autentica el contexto del usuario y del tenant desde el JWT.
    
    Regla crítica de seguridad multitenant:
    Ningún cliente puede elegir su tenant_id arbitrariamente en la URL o cuerpo.
    El tenant_id proviene de forma inviolable del payload firmado en el token.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciales de autenticación no válidas o expiradas.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not credentials:
        # En modo desarrollo, si la petición se prueba sin token, se enlaza al usuario de demostración
        # real con sus cuentas activas en la BD (Carlos Mendoza en Cooperativa Futuro).
        if settings.ENVIRONMENT == "development":
            db = SessionLocal()
            try:
                from app.modules.users.models import User
                from app.modules.tenants.models import Tenant
                user = db.query(User).filter(User.email == "carlos@fintech.com").first()
                tenant = db.query(Tenant).filter(Tenant.slug == "cooperativa-futuro").first()
                if user and tenant:
                    return {
                        "user_id": str(user.id),
                        "email": user.email,
                        "name": user.full_name,
                        "tenant_id": str(tenant.id),
                        "role": "CUSTOMER",
                        "roles": ["CUSTOMER"],
                    }
            finally:
                db.close()
        raise credentials_exception

    try:
        payload = decode_access_token(credentials.credentials)
        user_id: Optional[str] = payload.get("sub") or payload.get("user_id")
        tenant_id: Optional[str] = payload.get("tenant_id")
        role: Optional[str] = payload.get("role", "cliente")
        email: Optional[str] = payload.get("email", "")
        name: Optional[str] = payload.get("name", "Usuario")

        if not user_id or not tenant_id:
            raise credentials_exception

        return {
            "user_id": user_id,
            "tenant_id": tenant_id,
            "role": role,
            "email": email,
            "name": name,
        }
    except jwt.PyJWTError:
        raise credentials_exception
