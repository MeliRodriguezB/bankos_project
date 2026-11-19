from datetime import datetime, timedelta, timezone
from typing import Any, Optional
import jwt
from pwdlib import PasswordHash

from app.core.config import settings

# Algoritmo simétrico utilizado para firmar los tokens de acceso.
ALGORITHM = "HS256"

# Configuración de hashing de contraseñas con Argon2.
password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    """Genera el hash seguro de una contraseña usando Argon2."""
    return password_hash.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Compara una contraseña ingresada con su hash almacenado."""
    return password_hash.verify(plain_password, hashed_password)


def create_access_token(
    data: dict[str, Any] | str,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Crea un JWT de acceso firmado.
    Soporta recibir un dict con claims completos (sub, tenant_id, role, email)
    o un string como subject simple.
    """
    now = datetime.now(timezone.utc)
    expires_at = now + (
        expires_delta
        if expires_delta is not None
        else timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )

    if isinstance(data, dict):
        payload = data.copy()
        payload.setdefault("iat", now)
        payload["exp"] = expires_at
    else:
        payload = {
            "sub": str(data),
            "iat": now,
            "exp": expires_at,
        }

    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict[str, Any]:
    """
    Valida un JWT y devuelve sus claims; lanza excepción si es inválido o expiró.
    """
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
