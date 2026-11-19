from datetime import datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field, field_serializer


class TransferRequest(BaseModel):
    """Solicitud de transferencia interna con verificación de doble factor (PIN)."""
    source_account_id: str = Field(..., description="ID de la cuenta origen perteneciente al usuario")
    destination_account_number: str = Field(..., description="Número de cuenta bancaria destino en la misma institución")
    amount: Decimal = Field(..., gt=Decimal("0.00"), description="Importe positivo a transferir")
    currency: str = Field(..., min_length=3, max_length=3, description="Divisa solicitada para el débito")
    pin: str = Field(..., min_length=4, max_length=4, description="PIN de 4 dígitos para autorización de doble factor")
    description: Optional[str] = Field(None, max_length=200, description="Concepto o nota de la transferencia")


class DepositRequest(BaseModel):
    """Solicitud de abono de fondos a una cuenta propia."""
    account_id: str = Field(..., description="ID de la cuenta que recibirá los fondos")
    amount: Decimal = Field(..., gt=Decimal("0.00"), description="Monto estrictamente positivo a depositar")
    currency: str = Field(..., min_length=3, max_length=3)
    description: Optional[str] = Field(None, max_length=200)


class WithdrawRequest(BaseModel):
    """Solicitud de retiro de fondos con validación de saldo y PIN."""
    account_id: str = Field(..., description="ID de la cuenta a debitar")
    amount: Decimal = Field(..., gt=Decimal("0.00"), description="Monto a retirar")
    currency: str = Field(..., min_length=3, max_length=3)
    pin: str = Field(..., min_length=4, max_length=4, description="PIN de 4 dígitos del usuario")
    description: Optional[str] = Field(None, max_length=200)


class TransferQuoteRequest(BaseModel):
    """Solicitud previa para cotizar comisiones y tasa de cambio antes de confirmar."""
    source_account_id: str
    destination_account_number: str
    amount: Decimal = Field(..., gt=Decimal("0.00"))


class TransferQuoteResponse(BaseModel):
    """Desglose financiero exacto previo a la confirmación de la transferencia."""
    source_currency: str
    destination_currency: str
    amount_to_debit: str
    fee_amount: str
    total_debited: str
    exchange_rate: str
    amount_to_credit: str
    has_currency_conversion: bool
    destination_account_masked: str


class TransactionResponse(BaseModel):
    """Representación pública inmutable de un movimiento financiero."""
    id: str
    type: str
    amount: str
    currency: str
    fee_amount: str
    exchange_rate: str
    converted_amount: Optional[str] = None
    destination_currency: Optional[str] = None
    source_account_id: Optional[str] = None
    destination_account_id: Optional[str] = None
    status: str
    idempotency_key: Optional[str] = None
    correlation_id: Optional[str] = None
    description: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("amount", "fee_amount", "exchange_rate", "converted_amount", mode="plain")
    def serialize_decimals(self, value: Decimal | str | None) -> Optional[str]:
        if value is None:
            return None
        if isinstance(value, Decimal):
            return f"{value:.2f}"
        return str(value)


class TransactionHistoryResponse(BaseModel):
    """Respuesta paginada del historial de transacciones."""
    items: list[TransactionResponse]
    page: int
    page_size: int
    total: int
