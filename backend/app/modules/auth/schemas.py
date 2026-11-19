from typing import Optional
from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    """
    Solicitud de inicio de sesión multitenant.
    Requiere obligatoriamente el identificador de la institución (tenant_slug)
    para aislar las credenciales dentro del contexto de esa entidad bancaria.
    """
    tenant_slug: str = Field(..., description="Slug o código identificador de la institución (ej. cooperativa-futuro)")
    email: str = Field(..., description="Correo electrónico del usuario")
    password: str = Field(..., min_length=4, description="Contraseña de acceso")


class AuthUser(BaseModel):
    id: str
    name: str
    email: str
    tenant_id: str
    membership_id: Optional[str] = None
    roles: list[str] = Field(default_factory=lambda: ["CUSTOMER"])


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int = 1800
    user: AuthUser


class UserMeResponse(BaseModel):
    user: AuthUser
