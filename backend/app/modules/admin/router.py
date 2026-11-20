from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.dependencies import get_db, get_current_user
from app.modules.tenants.models import Tenant
from app.modules.users.models import User, PlatformAdmin
from app.modules.accounts.models import Account
from app.modules.transactions.models import Transaction
from app.modules.admin.models import BankConfiguration, Currency, BankExchangeRate

router = APIRouter(prefix="/admin", tags=["Platform Admin"])


def require_platform_admin(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    admin = db.query(PlatformAdmin).filter(
        PlatformAdmin.user_id == UUID(current_user["user_id"]),
        PlatformAdmin.is_active.is_(True),
    ).first()
    if admin is None:
        raise HTTPException(status_code=403, detail="Se requiere rol de administrador global.")
    return current_user


def bank_payload(bank: Tenant, config: BankConfiguration | None = None) -> dict:
    return {
        "id": str(bank.id), "name": bank.name, "slug": bank.slug, "status": bank.status,
        "created_at": bank.created_at.isoformat() if bank.created_at else None,
        "branding": {
            "primary_color": config.primary_color if config else "#145DA0",
            "secondary_color": config.secondary_color if config else "#FFFFFF",
            "accent_color": config.accent_color if config else "#F4B942",
        },
    }


@router.get("/dashboard")
def dashboard(db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    bank_count = db.query(Tenant).count()
    active_banks = db.query(Tenant).filter(Tenant.status == "ACTIVE").count()
    users_count = db.query(User).count()
    accounts_count = db.query(Account).count()
    active_accounts = db.query(Account).filter(Account.status == "ACTIVE").count()
    transactions_count = db.query(Transaction).count()
    total_volume = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter(
        Transaction.status == "COMPLETED"
    ).scalar()
    return {
        "banks_total": bank_count, "banks_active": active_banks,
        "users_total": users_count, "accounts_total": accounts_count,
        "accounts_active": active_accounts, "transactions_total": transactions_count,
        "transaction_volume": str(total_volume or Decimal("0")),
    }


@router.get("/banks")
def list_banks(db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    banks = db.query(Tenant).order_by(Tenant.created_at.desc()).all()
    configs = {c.tenant_id: c for c in db.query(BankConfiguration).all()}
    return [bank_payload(bank, configs.get(bank.id)) for bank in banks]


@router.post("/banks", status_code=status.HTTP_201_CREATED)
def create_bank(payload: dict, db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    name = str(payload.get("name", "")).strip()
    slug = str(payload.get("slug", "")).strip().lower()
    if not name or not slug:
        raise HTTPException(status_code=422, detail="name y slug son obligatorios.")
    if db.query(Tenant).filter(Tenant.slug == slug).first():
        raise HTTPException(status_code=409, detail="El slug ya está registrado.")
    bank = Tenant(name=name, slug=slug, status="ACTIVE")
    db.add(bank)
    db.flush()
    branding = payload.get("branding") or {}
    config = BankConfiguration(
        tenant_id=bank.id,
        primary_color=branding.get("primary_color", "#145DA0"),
        secondary_color=branding.get("secondary_color", "#FFFFFF"),
        accent_color=branding.get("accent_color", "#F4B942"),
    )
    db.add(config)
    db.commit()
    db.refresh(bank)
    return bank_payload(bank, config)


@router.patch("/banks/{bank_id}")
def update_bank(bank_id: UUID, payload: dict, db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    bank = db.query(Tenant).filter(Tenant.id == bank_id).first()
    if bank is None:
        raise HTTPException(status_code=404, detail="Banco no encontrado.")
    if "name" in payload:
        name = str(payload["name"]).strip()
        if not name:
            raise HTTPException(status_code=422, detail="El nombre no puede estar vacío.")
        bank.name = name
    if "status" in payload:
        new_status = str(payload["status"]).upper()
        if new_status not in {"ACTIVE", "INACTIVE"}:
            raise HTTPException(status_code=422, detail="status debe ser ACTIVE o INACTIVE.")
        bank.status = new_status
    branding = payload.get("branding") or {}
    if branding:
        config = db.query(BankConfiguration).filter(BankConfiguration.tenant_id == bank.id).first()
        if config is None:
            config = BankConfiguration(tenant_id=bank.id)
            db.add(config)
        for key in ("primary_color", "secondary_color", "accent_color"):
            if key in branding:
                value = str(branding[key])
                if len(value) != 7 or not value.startswith("#"):
                    raise HTTPException(status_code=422, detail=f"{key} debe ser un color hexadecimal #RRGGBB.")
                setattr(config, key, value)
    db.commit()
    return bank_payload(bank, db.query(BankConfiguration).filter(BankConfiguration.tenant_id == bank.id).first())


@router.get("/banks/{bank_id}/metrics")
def bank_metrics(bank_id: UUID, db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    bank = db.query(Tenant).filter(Tenant.id == bank_id).first()
    if bank is None:
        raise HTTPException(status_code=404, detail="Banco no encontrado.")
    account_count = db.query(Account).filter(Account.tenant_id == str(bank_id)).count()
    active_count = db.query(Account).filter(Account.tenant_id == str(bank_id), Account.status == "ACTIVE").count()
    tx_query = db.query(Transaction).filter(Transaction.tenant_id == str(bank_id))
    types = db.query(Transaction.type, func.count(Transaction.id), func.coalesce(func.sum(Transaction.amount), 0)).filter(
        Transaction.tenant_id == str(bank_id), Transaction.status == "COMPLETED"
    ).group_by(Transaction.type).all()
    return {
        "bank": bank_payload(bank),
        "accounts_total": account_count,
        "accounts_active": active_count,
        "accounts_inactive": account_count - active_count,
        "transactions_total": tx_query.count(),
        "transaction_breakdown": [{"type": t, "count": n, "volume": str(v)} for t, n, v in types],
        "users_with_accounts": db.query(Account.user_id).filter(Account.tenant_id == str(bank_id)).distinct().count(),
    }


@router.get("/accounts")
def list_accounts(db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    rows = db.query(Account, Tenant.name).join(Tenant, Tenant.id == Account.tenant_id).order_by(Account.created_at.desc()).limit(500).all()
    return [{
        "id": a.id, "account_number": a.account_number_masked, "alias": a.alias,
        "bank": bank_name, "tenant_id": a.tenant_id, "user_id": a.user_id,
        "balance": str(a.balance), "currency": a.currency, "status": a.status,
    } for a, bank_name in rows]


@router.get("/currencies")
def list_currencies(db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    return [{"code": c.code, "name": c.name, "symbol": c.symbol, "is_active": c.is_active}
            for c in db.query(Currency).order_by(Currency.code).all()]


@router.post("/currencies", status_code=status.HTTP_201_CREATED)
def create_currency(payload: dict, db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    code = str(payload.get("code", "")).upper()
    name = str(payload.get("name", "")).strip()
    symbol = str(payload.get("symbol", "")).strip()
    if len(code) != 3 or not name or not symbol:
        raise HTTPException(status_code=422, detail="code ISO de 3 caracteres, name y symbol son obligatorios.")
    if db.query(Currency).filter(Currency.code == code).first():
        raise HTTPException(status_code=409, detail="La divisa ya existe.")
    currency = Currency(code=code, name=name, symbol=symbol, is_active=True)
    db.add(currency)
    db.commit()
    return {"code": currency.code, "name": currency.name, "symbol": currency.symbol, "is_active": currency.is_active}


@router.patch("/currencies/{code}")
def update_currency(code: str, payload: dict, db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    currency = db.query(Currency).filter(Currency.code == code.upper()).first()
    if currency is None:
        raise HTTPException(status_code=404, detail="Divisa no encontrada.")
    if "is_active" in payload:
        currency.is_active = bool(payload["is_active"])
    if "name" in payload:
        currency.name = str(payload["name"]).strip()
    if "symbol" in payload:
        currency.symbol = str(payload["symbol"]).strip()
    db.commit()
    return {"code": currency.code, "name": currency.name, "symbol": currency.symbol, "is_active": currency.is_active}


@router.get("/exchange-rates")
def list_rates(bank_id: UUID | None = None, db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    query = db.query(BankExchangeRate, Tenant.name).join(Tenant, Tenant.id == BankExchangeRate.tenant_id)
    if bank_id:
        query = query.filter(BankExchangeRate.tenant_id == bank_id)
    rows = query.order_by(Tenant.name, BankExchangeRate.from_currency, BankExchangeRate.to_currency).all()
    return [{
        "id": str(r.id), "tenant_id": str(r.tenant_id), "bank": bank_name,
        "from_currency": r.from_currency, "to_currency": r.to_currency,
        "rate": str(r.rate), "fee_amount": str(r.fee_amount), "updated_at": r.updated_at.isoformat(),
    } for r, bank_name in rows]


@router.put("/banks/{bank_id}/exchange-rates")
def upsert_rate(bank_id: UUID, payload: dict, db: Session = Depends(get_db), _: dict = Depends(require_platform_admin)):
    if db.query(Tenant).filter(Tenant.id == bank_id).first() is None:
        raise HTTPException(status_code=404, detail="Banco no encontrado.")
    from_code = str(payload.get("from_currency", "")).upper()
    to_code = str(payload.get("to_currency", "")).upper()
    rate = Decimal(str(payload.get("rate", "0")))
    fee = Decimal(str(payload.get("fee_amount", "0")))
    if from_code == to_code or rate <= 0 or fee < 0:
        raise HTTPException(status_code=422, detail="Par de divisas, tasa o comisión inválidos.")
    currencies = {c.code for c in db.query(Currency).filter(Currency.code.in_([from_code, to_code])).all()}
    if currencies != {from_code, to_code}:
        raise HTTPException(status_code=422, detail="Ambas divisas deben estar registradas.")
    record = db.query(BankExchangeRate).filter(
        BankExchangeRate.tenant_id == bank_id,
        BankExchangeRate.from_currency == from_code,
        BankExchangeRate.to_currency == to_code,
    ).first()
    if record is None:
        record = BankExchangeRate(tenant_id=bank_id, from_currency=from_code, to_currency=to_code, rate=rate, fee_amount=fee)
        db.add(record)
    else:
        record.rate = rate
        record.fee_amount = fee
    db.commit()
    return {"tenant_id": str(bank_id), "from_currency": from_code, "to_currency": to_code, "rate": str(rate), "fee_amount": str(fee)}
