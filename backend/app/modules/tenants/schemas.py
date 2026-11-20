from decimal import Decimal
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, HttpUrl, field_validator, model_validator


class TenantConfigUpdate(BaseModel):
    max_transfer_amount: Decimal | None = Field(default=None, gt=0)
    transfer_fees: dict[str, Decimal] | None = None
    transfer_fee_percent: Decimal | None = Field(default=None, ge=0, le=Decimal("0.25"))
    primary_currency: str | None = Field(default=None, min_length=3, max_length=3)
    supported_currencies: list[str] | None = Field(default=None, min_length=1)
    exchange_rates: dict[str, Decimal] | None = None
    webhook_url: HttpUrl | None = None

    @model_validator(mode="after")
    def reject_null_policy_values(self):
        nullable_fields = {"webhook_url"}
        for field_name in self.model_fields_set - nullable_fields:
            if getattr(self, field_name) is None:
                raise ValueError(f"{field_name} no puede ser null.")
        return self

    @field_validator("primary_currency")
    @classmethod
    def normalize_primary_currency(cls, value: str | None) -> str | None:
        return value.upper() if value else value

    @field_validator("supported_currencies")
    @classmethod
    def normalize_supported_currencies(cls, values: list[str] | None) -> list[str] | None:
        if values is None:
            return values
        normalized = [value.upper() for value in values]
        if any(len(value) != 3 or not value.isalpha() for value in normalized):
            raise ValueError("Cada moneda debe usar un código ISO de tres letras.")
        if len(set(normalized)) != len(normalized):
            raise ValueError("No se permiten monedas repetidas.")
        return normalized

    @field_validator("transfer_fees")
    @classmethod
    def validate_transfer_fees(cls, values: dict[str, Decimal] | None) -> dict[str, Decimal] | None:
        if values is None:
            return values
        normalized = {currency.upper(): amount for currency, amount in values.items()}
        if any(len(currency) != 3 or amount < 0 for currency, amount in normalized.items()):
            raise ValueError("Las comisiones deben tener moneda ISO y valores no negativos.")
        return normalized

    @field_validator("exchange_rates")
    @classmethod
    def validate_exchange_rates(cls, values: dict[str, Decimal] | None) -> dict[str, Decimal] | None:
        if values is None:
            return values
        if any(
            len(pair.split("/")) != 2
            or any(len(currency) != 3 for currency in pair.split("/"))
            or rate <= 0
            for pair, rate in values.items()
        ):
            raise ValueError("Las tasas deben usar pares MONEDA/MONEDA y valores positivos.")
        return values


class TenantConfigResponse(BaseModel):
    id: str
    name: str
    slug: str
    status: str
    max_transfer_amount: Decimal
    transfer_fees: dict[str, Any]
    transfer_fee_percent: Decimal
    primary_currency: str
    supported_currencies: list[str]
    exchange_rates: dict[str, Any]
    webhook_url: str | None = None

    model_config = ConfigDict(from_attributes=True)
