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
        # En modo desarrollo, si no hay token aún porque Persona 1 está desarrollando el login,
        # proveemos un usuario mock por defecto para que Persona 2 y 3 puedan avanzar y probar.
        if settings.ENVIRONMENT == "development":
            return {
                "user_id": "usr-dev-101",
                "email": "carlos.mendoza@banco-demo.com",
                "name": "Carlos Mendoza",
                "tenant_id": "tenant-coop-01",
                "role": "cliente"
            }
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
