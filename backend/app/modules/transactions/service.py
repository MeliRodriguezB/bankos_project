import json
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc
from sqlalchemy.exc import IntegrityError

from app.modules.accounts.models import Account
from app.modules.transactions.models import Transaction
from app.modules.users.service import UserService
from app.core.config import settings
from app.modules.transactions.schemas import (
    TransferRequest,
    DepositRequest,
    WithdrawRequest,
    TransferQuoteResponse,
    TransactionResponse,
    TransactionHistoryResponse,
)


class TransactionService:
    """
    Motor financiero y de transacciones multimoneda para BankOS.
    
    Implementa:
    1. Idempotencia estricta por tenant_id + user_id.
    2. Atomicidad ACID: Débito y Crédito se confirman juntos o se revierten juntos.
    3. Conversión de divisas con tabla de tasas estáticas por institución.
    4. Aplicación de comisiones fijas/porcentuales parametrizadas.
    5. Validación de autorización por PIN (doble factor).
    """

    # Tabla estática de tasas de cambio (Base: divisa origen -> destino)
    EXCHANGE_RATES = {
        ("COP", "USD"): Decimal("0.00025"),   # 1 USD = 4,000 COP
        ("USD", "COP"): Decimal("4000.00"),
        ("EUR", "COP"): Decimal("4350.00"),
        ("COP", "EUR"): Decimal("0.00023"),
        ("USD", "EUR"): Decimal("0.92"),
        ("EUR", "USD"): Decimal("1.09"),
    }

    # Comisiones fijas por institución
    FIXED_FEES = {
        "COP": Decimal("1500.00"),
        "USD": Decimal("1.00"),
        "EUR": Decimal("1.00"),
    }

    @classmethod
    def get_exchange_rate(cls, from_currency: str, to_currency: str) -> Decimal:
        from_curr = from_currency.upper()
        to_curr = to_currency.upper()
        if from_curr == to_curr:
            return Decimal("1.000000")
        rate = cls.EXCHANGE_RATES.get((from_curr, to_curr))
        if rate is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"No existe una tasa de cambio configurada para {from_curr}/{to_curr}.",
            )
        if settings.ENVIRONMENT.lower() == "production":
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="La conversión de divisas requiere un proveedor de tasas de cambio en tiempo real.",
            )
        return rate

    @classmethod
    def calculate_quote(
        cls,
        db: Session,
        tenant_id: str,
        user_id: str,
        source_account_id: str,
        destination_account_number: str,
        amount: Decimal
    ) -> TransferQuoteResponse:
        """Calcula el desglose financiero exacto antes de confirmar la transferencia."""
        # 1. Validar cuenta origen
        source_acc = db.query(Account).filter(
            Account.id == source_account_id,
            Account.tenant_id == tenant_id,
            Account.user_id == user_id
        ).first()

        if not source_acc or source_acc.status != "ACTIVE":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La cuenta de origen no existe o se encuentra inactiva."
            )

        # 2. Validar cuenta destino en el mismo tenant
        dest_acc = db.query(Account).filter(
            Account.account_number == destination_account_number,
            Account.tenant_id == tenant_id
        ).first()

        if not dest_acc or dest_acc.status != "ACTIVE":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"La cuenta destino '{destination_account_number}' no existe o no está activa en esta institución."
            )

        fee = cls.FIXED_FEES.get(source_acc.currency, Decimal("0.00"))
        rate = cls.get_exchange_rate(source_acc.currency, dest_acc.currency)
        total_debited = amount + fee
        amount_to_credit = (amount * rate).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

        return TransferQuoteResponse(
            source_currency=source_acc.currency,
            destination_currency=dest_acc.currency,
            amount_to_debit=f"{amount:.2f}",
            fee_amount=f"{fee:.2f}",
            total_debited=f"{total_debited:.2f}",
            exchange_rate=f"{rate:.6f}",
            amount_to_credit=f"{amount_to_credit:.2f}",
            has_currency_conversion=(source_acc.currency != dest_acc.currency),
            destination_account_masked=dest_acc.account_number_masked,
        )

    @classmethod
    def process_transfer(
        cls,
        db: Session,
        tenant_id: str,
        user_id: str,
        data: TransferRequest,
        idempotency_key: str,
        correlation_id: str
    ) -> TransactionResponse:
        """
        Ejecuta una transferencia atómica con control de idempotencia y conversión multimoneda.
        """
        # Validar PIN también en reintentos idempotentes.
        UserService.verify_transaction_pin(db, user_id, data.pin)

        # --- 1. Verificación de Idempotencia ---
        if idempotency_key:
            existing_tx = db.query(Transaction).filter(
                Transaction.tenant_id == tenant_id,
                Transaction.user_id == user_id,
                Transaction.idempotency_key == idempotency_key
            ).first()

            if existing_tx:
                destination = db.query(Account).filter(
                    Account.account_number == data.destination_account_number,
                    Account.tenant_id == tenant_id,
                ).first()
                same_request = (
                    existing_tx.type == "TRANSFER"
                    and existing_tx.source_account_id == data.source_account_id
                    and existing_tx.destination_account_id == (destination.id if destination else None)
                    and existing_tx.amount == data.amount
                    and existing_tx.currency == data.currency.upper()
                    and existing_tx.description == (
                        data.description or (
                            f"Transferencia a cuenta {destination.account_number_masked}"
                            if destination else None
                        )
                    )
                )
                if not same_request:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="La Idempotency-Key ya fue utilizada con datos diferentes.",
                    )
                return cls._to_response(existing_tx)

        # --- 3. Validación de Cuentas y Aislamiento Multitenant ---
        source_acc = db.query(Account).filter(
            Account.id == data.source_account_id,
            Account.tenant_id == tenant_id,
            Account.user_id == user_id
        ).with_for_update().first()

        if not source_acc or source_acc.status != "ACTIVE":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La cuenta origen no existe o se encuentra inactiva."
            )

        dest_acc = db.query(Account).filter(
            Account.account_number == data.destination_account_number,
            Account.tenant_id == tenant_id
        ).with_for_update().first()

        if not dest_acc or dest_acc.status != "ACTIVE":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La cuenta destino no existe o no está habilitada en esta institución."
            )

        if source_acc.id == dest_acc.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La cuenta destino no puede ser la misma cuenta de origen."
            )

        if data.currency.upper() != source_acc.currency.upper():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="La divisa solicitada no coincide con la divisa de la cuenta origen.",
            )

        # --- 4. Cálculo de Comisión y Conversión de Divisas ---
        fee = cls.FIXED_FEES.get(source_acc.currency, Decimal("0.00"))
        rate = cls.get_exchange_rate(source_acc.currency, dest_acc.currency)
        total_to_debit = data.amount + fee
        amount_to_credit = (data.amount * rate).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

        # --- 5. Validación de Saldo Disponible en Backend ---
        if source_acc.balance < total_to_debit:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Fondos insuficientes. Saldo disponible: {source_acc.balance} {source_acc.currency}. Requerido con comisión: {total_to_debit} {source_acc.currency}."
            )

        # --- 6. Ejecución Atómica (ACID Transaction) ---
        try:
            source_acc.balance -= total_to_debit
            dest_acc.balance += amount_to_credit

            tx = Transaction(
                tenant_id=tenant_id,
                user_id=user_id,
                source_account_id=source_acc.id,
                destination_account_id=dest_acc.id,
                type="TRANSFER",
                amount=data.amount,
                currency=source_acc.currency,
                converted_amount=amount_to_credit,
                destination_currency=dest_acc.currency,
                exchange_rate=rate,
                fee_amount=fee,
                status="COMPLETED",
                idempotency_key=idempotency_key,
                correlation_id=correlation_id,
                description=data.description or f"Transferencia a cuenta {dest_acc.account_number_masked}",
            )
            db.add(tx)
            db.commit()
            db.refresh(tx)
            return cls._to_response(tx)

        except IntegrityError:
            # La restricción única resuelve la carrera entre solicitudes concurrentes.
            # Se revierte todo el débito/crédito; el cliente puede reintentar la misma clave.
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="La clave de idempotencia acaba de procesarse. Reintenta con la misma clave.",
            )
        except Exception as e:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error en la transacción contable: {str(e)}"
            )

    @classmethod
    def process_deposit(
        cls,
        db: Session,
        tenant_id: str,
        user_id: str,
        data: DepositRequest,
        idempotency_key: str,
        correlation_id: str
    ) -> TransactionResponse:
        """Abona fondos a una cuenta bancaria del usuario."""
        if idempotency_key:
            existing = db.query(Transaction).filter(
                Transaction.tenant_id == tenant_id,
                Transaction.user_id == user_id,
                Transaction.idempotency_key == idempotency_key
            ).first()
            if existing:
                same_request = (
                    existing.type == "DEPOSIT"
                    and existing.destination_account_id == data.account_id
                    and existing.amount == data.amount
                    and existing.currency == data.currency.upper()
                    and existing.description == (data.description or "Depósito de fondos")
                )
                if not same_request:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="La Idempotency-Key ya fue utilizada con datos diferentes.",
                    )
                return cls._to_response(existing)

        account = db.query(Account).filter(
            Account.id == data.account_id,
            Account.tenant_id == tenant_id,
            Account.user_id == user_id
        ).with_for_update().first()

        if not account or account.status != "ACTIVE":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La cuenta seleccionada no existe o no se encuentra activa."
            )

        if data.currency.upper() != account.currency.upper():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="La divisa solicitada no coincide con la divisa de la cuenta.",
            )

        try:
            account.balance += data.amount
            tx = Transaction(
                tenant_id=tenant_id,
                user_id=user_id,
                destination_account_id=account.id,
                type="DEPOSIT",
                amount=data.amount,
                currency=account.currency,
                converted_amount=data.amount,
                destination_currency=account.currency,
                exchange_rate=Decimal("1.000000"),
                fee_amount=Decimal("0.00"),
                status="COMPLETED",
                idempotency_key=idempotency_key,
                correlation_id=correlation_id,
                description=data.description or "Depósito de fondos",
            )
            db.add(tx)
            db.commit()
            db.refresh(tx)
            return cls._to_response(tx)
        except IntegrityError:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="La clave de idempotencia acaba de procesarse. Reintenta con la misma clave.",
            )
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail="No fue posible completar la operación.")

    @classmethod
    def process_withdrawal(
        cls,
        db: Session,
        tenant_id: str,
        user_id: str,
        data: WithdrawRequest,
        idempotency_key: str,
        correlation_id: str
    ) -> TransactionResponse:
        """Debita fondos de una cuenta bancaria."""
        # Validar PIN también en reintentos idempotentes.
        UserService.verify_transaction_pin(db, user_id, data.pin)

        if idempotency_key:
            existing = db.query(Transaction).filter(
                Transaction.tenant_id == tenant_id,
                Transaction.user_id == user_id,
                Transaction.idempotency_key == idempotency_key
            ).first()
            if existing:
                same_request = (
                    existing.type == "WITHDRAWAL"
                    and existing.source_account_id == data.account_id
                    and existing.amount == data.amount
                    and existing.currency == data.currency.upper()
                    and existing.description == (data.description or "Retiro de efectivo")
                )
                if not same_request:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="La Idempotency-Key ya fue utilizada con datos diferentes.",
                    )
                return cls._to_response(existing)

        account = db.query(Account).filter(
            Account.id == data.account_id,
            Account.tenant_id == tenant_id,
            Account.user_id == user_id
        ).with_for_update().first()

        if not account or account.status != "ACTIVE":
            raise HTTPException(status_code=400, detail="Cuenta inválida o inactiva.")

        if data.currency.upper() != account.currency.upper():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="La divisa solicitada no coincide con la divisa de la cuenta.",
            )

        if account.balance < data.amount:
            raise HTTPException(status_code=400, detail="Saldo insuficiente para realizar el retiro.")

        try:
            account.balance -= data.amount
            tx = Transaction(
                tenant_id=tenant_id,
                user_id=user_id,
                source_account_id=account.id,
                type="WITHDRAWAL",
                amount=data.amount,
                currency=account.currency,
                exchange_rate=Decimal("1.000000"),
                fee_amount=Decimal("0.00"),
                status="COMPLETED",
                idempotency_key=idempotency_key,
                correlation_id=correlation_id,
                description=data.description or "Retiro de efectivo",
            )
            db.add(tx)
            db.commit()
            db.refresh(tx)
            return cls._to_response(tx)
        except IntegrityError:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="La clave de idempotencia acaba de procesarse. Reintenta con la misma clave.",
            )
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail="No fue posible completar la operación.")

    @classmethod
    def get_history(
        cls,
        db: Session,
        tenant_id: str,
        user_id: str,
        account_id: Optional[str] = None,
        tx_type: Optional[str] = None,
        page: int = 1,
        page_size: int = 20
    ) -> TransactionHistoryResponse:
        """Consulta paginada del historial de transacciones del usuario en su tenant."""
        query = db.query(Transaction).filter(
            Transaction.tenant_id == tenant_id,
            Transaction.user_id == user_id
        )

        if account_id:
            query = query.filter(
                (Transaction.source_account_id == account_id) |
                (Transaction.destination_account_id == account_id)
            )

        if tx_type:
            query = query.filter(Transaction.type == tx_type.upper())

        total = query.count()
        offset = (page - 1) * page_size
        items = query.order_by(desc(Transaction.created_at)).offset(offset).limit(page_size).all()

        return TransactionHistoryResponse(
            items=[cls._to_response(t) for t in items],
            page=page,
            page_size=page_size,
            total=total
        )

    @classmethod
    def _to_response(cls, tx: Transaction) -> TransactionResponse:
        return TransactionResponse(
            id=tx.id,
            type=tx.type,
            amount=f"{tx.amount:.2f}",
            currency=tx.currency,
            fee_amount=f"{tx.fee_amount:.2f}",
            exchange_rate=f"{tx.exchange_rate:.6f}",
            converted_amount=f"{tx.converted_amount:.2f}" if tx.converted_amount else None,
            destination_currency=tx.destination_currency,
            source_account_id=tx.source_account_id,
            destination_account_id=tx.destination_account_id,
            status=tx.status,
            idempotency_key=tx.idempotency_key,
            correlation_id=tx.correlation_id,
            description=tx.description,
            created_at=tx.created_at,
        )
