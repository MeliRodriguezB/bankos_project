import uuid
from typing import Optional
from fastapi import APIRouter, Depends, Header, Query, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_db, get_current_user
from app.core.config import settings
from app.modules.transactions.schemas import (
    TransferRequest,
    DepositRequest,
    WithdrawRequest,
    TransferQuoteRequest,
    TransferQuoteResponse,
    TransactionResponse,
    TransactionHistoryResponse,
)
from app.modules.transactions.service import TransactionService

router = APIRouter(prefix="/transactions", tags=["Financial Transactions"])


@router.post(
    "/quote",
    response_model=TransferQuoteResponse,
    summary="Cotizar transferencia y pre-desglose",
    description="Calcula el desglose previo de comisión, tasa de cambio y monto recibido antes de autorizar la transferencia."
)
def get_quote(
    quote_data: TransferQuoteRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return TransactionService.calculate_quote(
        db=db,
        tenant_id=current_user["tenant_id"],
        user_id=current_user["user_id"],
        source_account_id=quote_data.source_account_id,
        destination_account_number=quote_data.destination_account_number,
        amount=quote_data.amount,
    )


@router.post(
    "/transfers",
    response_model=TransactionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Ejecutar transferencia con idempotencia y doble factor",
    description="Realiza la transferencia atómica aplicando comisión y conversión si aplica. Exige encabezado Idempotency-Key."
)
def create_transfer(
    transfer_data: TransferRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
    idempotency_key: str = Header(..., alias="Idempotency-Key", min_length=8, max_length=100),
    x_correlation_id: Optional[str] = Header(None, alias="X-Correlation-ID"),
):
    correlation_id = x_correlation_id or f"corr-{uuid.uuid4()}"
    key = idempotency_key.strip()
    if not key:
        from fastapi import HTTPException
        raise HTTPException(status_code=422, detail="Idempotency-Key no puede estar vacío.")

    return TransactionService.process_transfer(
        db=db,
        tenant_id=current_user["tenant_id"],
        user_id=current_user["user_id"],
        data=transfer_data,
        idempotency_key=key,
        correlation_id=correlation_id,
    )


@router.post(
    "/deposits",
    response_model=TransactionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Abonar fondos a una cuenta propia",
    description="Incrementa el saldo de una cuenta activa con registro de auditoría e idempotencia."
)
def create_deposit(
    deposit_data: DepositRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
    idempotency_key: str = Header(..., alias="Idempotency-Key", min_length=8, max_length=100),
    x_correlation_id: Optional[str] = Header(None, alias="X-Correlation-ID"),
):
    if not settings.SIMULATED_DEPOSITS_ENABLED:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Los depósitos simulados están deshabilitados. Configure un proveedor de pagos para recibir fondos.",
        )

    correlation_id = x_correlation_id or f"corr-{uuid.uuid4()}"
    key = idempotency_key.strip()
    if not key:
        from fastapi import HTTPException
        raise HTTPException(status_code=422, detail="Idempotency-Key no puede estar vacío.")

    return TransactionService.process_deposit(
        db=db,
        tenant_id=current_user["tenant_id"],
        user_id=current_user["user_id"],
        data=deposit_data,
        idempotency_key=key,
        correlation_id=correlation_id,
    )


@router.post(
    "/withdrawals",
    response_model=TransactionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Retirar fondos con autorización por PIN",
    description="Debita fondos validando saldo suficiente y el PIN del usuario."
)
def create_withdrawal(
    withdraw_data: WithdrawRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
    idempotency_key: str = Header(..., alias="Idempotency-Key", min_length=8, max_length=100),
    x_correlation_id: Optional[str] = Header(None, alias="X-Correlation-ID"),
):
    correlation_id = x_correlation_id or f"corr-{uuid.uuid4()}"
    key = idempotency_key.strip()
    if not key:
        from fastapi import HTTPException
        raise HTTPException(status_code=422, detail="Idempotency-Key no puede estar vacío.")

    return TransactionService.process_withdrawal(
        db=db,
        tenant_id=current_user["tenant_id"],
        user_id=current_user["user_id"],
        data=withdraw_data,
        idempotency_key=key,
        correlation_id=correlation_id,
    )


@router.get(
    "",
    response_model=TransactionHistoryResponse,
    summary="Consultar historial de transacciones",
    description="Obtiene los movimientos del usuario autenticado en su tenant con paginación y filtros por cuenta y tipo."
)
def get_transactions_history(
    account_id: Optional[str] = Query(None, description="Filtrar por cuenta específica"),
    type: Optional[str] = Query(None, description="Filtrar por tipo: TRANSFER, DEPOSIT, WITHDRAWAL"),
    page: int = Query(1, ge=1, description="Número de página"),
    page_size: int = Query(20, ge=1, le=100, description="Registros por página"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return TransactionService.get_history(
        db=db,
        tenant_id=current_user["tenant_id"],
        user_id=current_user["user_id"],
        account_id=account_id,
        tx_type=type,
        page=page,
        page_size=page_size,
    )
