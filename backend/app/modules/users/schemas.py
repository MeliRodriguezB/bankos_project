from pydantic import BaseModel, Field, field_validator


class TransactionPinSetupRequest(BaseModel):
    current_password: str = Field(..., min_length=8, max_length=128)
    pin: str = Field(..., min_length=4, max_length=4)

    @field_validator("pin")
    @classmethod
    def pin_must_be_numeric(cls, value: str) -> str:
        if not value.isdigit():
            raise ValueError("El PIN debe contener exactamente cuatro dígitos.")
        return value


class TransactionPinStatusResponse(BaseModel):
    configured: bool
