import uuid
from contextlib import asynccontextmanager
from decimal import Decimal
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.core.config import settings
from app.core.security import hash_password
from app.db.base import Base
from app.db.session import engine, SessionLocal

# Importar modelos ORM
from app.modules.tenants.models import Tenant, TenantMembership
from app.modules.users.models import User
from app.modules.roles.models import Role, membership_roles
from app.modules.accounts.models import Account
from app.modules.transactions.models import Transaction

# Importar enrutadores
from app.modules.auth.router import router as auth_router
from app.modules.accounts.router import router as accounts_router
from app.modules.transactions.router import router as transactions_router


def seed_database():
    """
    Inicializa de forma 100% idempotente los datos de demostración para el reto BankOS:
    - Dos instituciones financieras (tenants) independientes.
    - Usuario de prueba (Carlos Mendoza) con credenciales seguras (Argon2).
    - Membresías y roles.
    - Cuentas en múltiples divisas (COP, USD) y una desactivada (soft delete).
    - Historial de transacciones previas.
    """
    db = SessionLocal()
    try:
        # 1. Tenants
        tenant1 = db.query(Tenant).filter(Tenant.slug == "cooperativa-futuro").first()
        if not tenant1:
            tenant1 = Tenant(
                name="Cooperativa Financiera Futuro",
                slug="cooperativa-futuro",
                status="ACTIVE"
            )
            db.add(tenant1)
            db.flush()

        tenant2 = db.query(Tenant).filter(Tenant.slug == "neobanco-agil").first()
        if not tenant2:
            tenant2 = Tenant(
                name="Neobanco Ágil",
                slug="neobanco-agil",
                status="ACTIVE"
            )
            db.add(tenant2)
            db.flush()

        # 2. Roles
        role_customer = db.query(Role).filter(
            Role.tenant_id == tenant1.id,
            Role.code == "CUSTOMER"
        ).first()
        if not role_customer:
            role_customer = Role(
                tenant_id=tenant1.id,
                code="CUSTOMER",
                name="Cliente Bancario",
                is_system=True
            )
            db.add(role_customer)
            db.flush()

        # 3. Usuario Carlos Mendoza
        user1 = db.query(User).filter(User.email == "carlos@fintech.com").first()
        if not user1:
            user1 = User(
                email="carlos@fintech.com",
                password_hash=hash_password("123456"),
                full_name="Carlos Mendoza",
                is_active=True
            )
            db.add(user1)
            db.flush()

        # 4. Membresía de Carlos en Cooperativa Futuro
        membership1 = db.query(TenantMembership).filter(
            TenantMembership.tenant_id == tenant1.id,
            TenantMembership.user_id == user1.id
        ).first()
        if not membership1:
            membership1 = TenantMembership(
                tenant_id=tenant1.id,
                user_id=user1.id,
                status="ACTIVE"
            )
            db.add(membership1)
            db.flush()

            db.execute(
                membership_roles.insert().values(
                    tenant_id=tenant1.id,
                    membership_id=membership1.id,
                    role_id=role_customer.id
                )
            )

        # 5. Cuentas bancarias verificadas por account_number
        accounts_to_seed = [
            {
                "id": "acc-901",
                "account_number": "1002348911",
                "alias": "Cuenta de Ahorros Principal",
                "tenant_id": str(tenant1.id),
                "user_id": str(user1.id),
                "balance": Decimal("2450000.00"),
                "currency": "COP",
                "status": "ACTIVE",
            },
            {
                "id": "acc-902",
                "account_number": "1002348922",
                "alias": "Fondo de Emergencia",
                "tenant_id": str(tenant1.id),
                "user_id": str(user1.id),
                "balance": Decimal("450000.00"),
                "currency": "COP",
                "status": "ACTIVE",
            },
            {
                "id": "acc-903",
                "account_number": "2005541100",
                "alias": "Ahorro Dólares",
                "tenant_id": str(tenant1.id),
                "user_id": str(user1.id),
                "balance": Decimal("350.00"),
                "currency": "USD",
                "status": "ACTIVE",
            },
            {
                "id": "acc-904",
                "account_number": "1002348999",
                "alias": "Cuenta Nómina Desactivada",
                "tenant_id": str(tenant1.id),
                "user_id": str(user1.id),
                "balance": Decimal("0.00"),
                "currency": "COP",
                "status": "INACTIVE",
            },
            {
                "id": "acc-tenant2-01",
                "account_number": "8880001234",
                "alias": "Cuenta Neobanco Ágil",
                "tenant_id": str(tenant2.id),
                "user_id": str(uuid.uuid4()),
                "balance": Decimal("99999999.00"),
                "currency": "COP",
                "status": "ACTIVE",
            },
        ]

        for acc_data in accounts_to_seed:
            existing = db.query(Account).filter(Account.id == acc_data["id"]).first()
            if existing:
                existing.tenant_id = acc_data["tenant_id"]
                existing.user_id = acc_data["user_id"]
                existing.balance = acc_data["balance"]
                existing.status = acc_data["status"]
                existing.currency = acc_data["currency"]
            else:
                db.add(Account(**acc_data))

        # 6. Historial inicial
        tx_count = db.query(Transaction).filter(Transaction.user_id == str(user1.id)).count()
        if tx_count == 0:
            tx1 = Transaction(
                tenant_id=str(tenant1.id),
                user_id=str(user1.id),
                destination_account_id="acc-901",
                type="DEPOSIT",
                amount=Decimal("2500000.00"),
                currency="COP",
                converted_amount=Decimal("2500000.00"),
                destination_currency="COP",
                exchange_rate=Decimal("1.000000"),
                fee_amount=Decimal("0.00"),
                status="COMPLETED",
                description="Apertura y depósito inicial",
            )
            tx2 = Transaction(
                tenant_id=str(tenant1.id),
                user_id=str(user1.id),
                source_account_id="acc-901",
                type="WITHDRAWAL",
                amount=Decimal("50000.00"),
                currency="COP",
                converted_amount=Decimal("50000.00"),
                destination_currency="COP",
                exchange_rate=Decimal("1.000000"),
                fee_amount=Decimal("0.00"),
                status="COMPLETED",
                description="Retiro en cajero automático",
            )
            db.add_all([tx1, tx2])

        db.commit()
    except Exception as e:
        db.rollback()
        print(f"Error seeding database: {e}")
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        Base.metadata.create_all(bind=engine)
        if settings.ENVIRONMENT == "development":
            seed_database()
    except Exception as e:
        print(f"Advertencia al conectar o crear tablas: {e}")
    yield


app = FastAPI(
    title="BankOS API — Multitenant Banking Platform",
    description="API REST completa para la plataforma financiera BankOS (Auth, Accounts, Transactions).",
    version="1.0.0",
    lifespan=lifespan,
)

# Middleware de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Endpoint de comprobación de salud
@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "ok",
        "application": "BankOS",
        "environment": settings.ENVIRONMENT,
    }

# Registrar los tres módulos bajo el prefijo unificado /api/v1
app.include_router(auth_router, prefix="/api/v1")
app.include_router(accounts_router, prefix="/api/v1")
app.include_router(transactions_router, prefix="/api/v1")
