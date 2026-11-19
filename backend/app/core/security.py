from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from pwdlib import PasswordHash

from app.core.config import settings


# Algoritmo simétrico utilizado para firmar los tokens de acceso.
ALGORITHM = "HS256"

# Configuración recomendada de hash de contraseñas (Argon2).
password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    """Genera el hash seguro de una contraseña."""
    return password_hash.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Compara una contraseña ingresada con su hash almacenado."""
    return password_hash.verify(plain_password, hashed_password)


def create_access_token(
    subject: str,
    expires_delta: timedelta | None = None,
) -> str:
    """Crea un JWT de acceso asociado al identificador del usuario."""
    now = datetime.now(timezone.utc)
    expires_at = now + (
        expires_delta
        if expires_delta is not None
        else timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )

    payload: dict[str, Any] = {
        "sub": subject,
        "iat": now,
        "exp": expires_at,
    }

    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict[str, Any] | None:
    """Valida un JWT y devuelve sus claims; retorna None si no es válido."""
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[ALGORITHM],
        )
    except jwt.InvalidTokenError:
        return None

    if not payload.get("sub"):
        return None

    return payload
