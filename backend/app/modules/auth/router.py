from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_db, get_current_user
from app.modules.auth.schemas import LoginRequest, LoginResponse, UserMeResponse, AuthUser
from app.modules.auth.service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/login",
    response_model=LoginResponse,
    status_code=status.HTTP_200_OK,
    summary="Inicio de sesión multitenant",
    description="Autentica a un usuario dentro del contexto de una institución específica y devuelve el JWT firmado con claims de aislamiento."
)
def login(
    login_data: LoginRequest,
    db: Session = Depends(get_db)
):
    return AuthService.authenticate(db=db, login_data=login_data)


@router.get(
    "/me",
    response_model=UserMeResponse,
    summary="Consultar usuario autenticado",
    description="Devuelve el perfil del usuario actual extraído de forma segura de los claims del token JWT."
)
def get_me(
    current_user: dict = Depends(get_current_user)
):
    return UserMeResponse(
        user=AuthUser(
            id=current_user["user_id"],
            name=current_user.get("name", "Usuario"),
            email=current_user.get("email", ""),
            tenant_id=current_user["tenant_id"],
            membership_id=current_user.get("membership_id"),
            roles=current_user.get("roles", [current_user.get("role", "CUSTOMER")]),
        )
    )
