from datetime import datetime, timedelta, timezone
from typing import Any, Optional
import jwt
from app.core.config import settings

ALGORITHM = "HS256"


def create_access_token(
    data: dict[str, Any],
    expires_delta: Optional[timedelta] = None
) -> str:
    """
    Genera un token JWT firmado criptográficamente.
    Incluye los claims obligatorios para multitenancy:
    - sub (user_id)
    - tenant_id
    - role
    - email
    """
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> dict[str, Any]:
    """
    Decodifica y valida la firma y expiración del token JWT.
    Lanza jwt.PyJWTError si el token es inválido o ha expirado.
    """
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
