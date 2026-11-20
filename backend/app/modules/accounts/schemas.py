from datetime import datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field, field_serializer


class AccountBase(BaseModel):
    """Atributos comunes para la gestión de cuentas."""
    alias: Optional[str] = Field(None, max_length=100, description="Nombre o alias personalizado")
    currency: str = Field(..., min_length=3, max_length=3, description="Código de divisa ISO 4217")


class AccountCreate(AccountBase):
    """Esquema para crear una nueva cuenta."""
    account_number: str = Field(..., min_length=6, max_length=20, description="Número de cuenta único")
    initial_balance: Decimal = Field(default=Decimal("0.00"), ge=0, description="Saldo inicial depositado")
    user_id: Optional[str] = Field(None, description="ID del titular (opcional si es para el usuario actual)")


class AccountResponse(BaseModel):
    """
    Esquema público de una cuenta bancaria.
    
    Decisión de diseño:
    El campo 'balance' se serializa siempre como String (ej. '1500000.50')
    para evitar que los parsers JSON en frontend lo conviertan a un float binario con pérdidas de precisión.
    """
    id: str
    account_number: str
    account_number_masked: str
    alias: Optional[str] = None
    balance: str
    currency: str
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("balance", mode="plain")
    def serialize_balance(self, value: Decimal | str) -> str:
        if isinstance(value, Decimal):
            return f"{value:.2f}"
        return str(value)


class AccountDetailResponse(AccountResponse):
    """Información extendida para la vista de detalle de la cuenta."""
    tenant_id: str
    user_id: str
    updated_at: datetime


class CurrencyBalanceSummary(BaseModel):
    """Resumen de saldo total agrupado por divisa."""
    currency: str
    total_balance: str
    active_accounts_count: int


class DashboardUser(BaseModel):
    """Información del usuario autenticado para el encabezado del dashboard."""
    id: str
    name: str
    email: str


class DashboardTenant(BaseModel):
    """Información de la institución a la que pertenece el usuario."""
    id: str
    name: str
    primary_currency: str


class DashboardResponse(BaseModel):
    """
    Respuesta unificada para la pantalla principal de la aplicación móvil.
    Agrupa en una sola petición HTTP:
    - Identidad del usuario y tenant
    - Subtotales por divisa (sin mezclar monedas)
    - Listado de cuentas operativas
    """
    user: DashboardUser
    tenant: DashboardTenant
    balances_by_currency: list[CurrencyBalanceSummary]
    accounts: list[AccountResponse]


class TenantAdminAccountResponse(AccountResponse):
    """Cuenta institucional con datos básicos del titular, visible para ADMIN del tenant."""
    user_id: str
    owner_name: str
    owner_email: str


class TenantAdminCurrencyBalance(BaseModel):
    """Saldo institucional agrupado por moneda; nunca mezcla divisas."""
    currency: str
    total_balance: str
    active_accounts_count: int


class TenantAdminTransactionSummary(BaseModel):
    """Conteo y volumen de operaciones agrupados por estado y divisa."""
    status: str
    count: int
    currency: str
    total_amount: str


class TenantAdminDashboardResponse(BaseModel):
    """Indicadores agregados exclusivos del tenant del administrador."""
    tenant_id: str
    tenant_name: str
    active_memberships: int
    total_accounts: int
    active_accounts: int
    inactive_accounts: int
    balances_by_currency: list[TenantAdminCurrencyBalance]
    transactions_total: int
    transactions_by_status_currency: list[TenantAdminTransactionSummary]
