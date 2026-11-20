import re
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
from app.modules.users.router import router as users_router
from app.modules.tenants.router import router as tenants_router
from app.core.rate_limit import RateLimitMiddleware
from app.core.error_handlers import register_exception_handlers


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

        # 2. Cada institución mantiene sus propios roles CUSTOMER y ADMIN.
        roles_by_tenant = {}
        for tenant in (tenant1, tenant2):
            role_customer = db.query(Role).filter(
                Role.tenant_id == tenant.id,
                Role.code == "CUSTOMER"
            ).first()
            if not role_customer:
                role_customer = Role(
                    tenant_id=tenant.id,
                    code="CUSTOMER",
                    name="Cliente Bancario",
                    is_system=True
                )
                db.add(role_customer)
                db.flush()

            role_admin = db.query(Role).filter(
                Role.tenant_id == tenant.id,
                Role.code == "ADMIN"
            ).first()
            if not role_admin:
                role_admin = Role(
                    tenant_id=tenant.id,
                    code="ADMIN",
                    name="Administrador institucional",
                    is_system=True
                )
                db.add(role_admin)
                db.flush()

            roles_by_tenant[str(tenant.id)] = {
                "CUSTOMER": role_customer,
                "ADMIN": role_admin,
            }

        # 3. Usuario Carlos Mendoza
        user1 = db.query(User).filter(User.email == "carlos@fintech.com").first()
        if not user1:
            user1 = User(
                email="carlos@fintech.com",
                password_hash=hash_password("123456"),
                transaction_pin_hash=hash_password("1234"),
                transaction_pin_failed_attempts=0,
                full_name="Carlos Mendoza",
                is_active=True
            )
            db.add(user1)
            db.flush()
        elif not user1.transaction_pin_hash:
            # PIN débil únicamente para facilitar la demostración local.
            user1.transaction_pin_hash = hash_password("1234")
            user1.transaction_pin_failed_attempts = 0

        # 4. Carlos tiene una membresía CUSTOMER explícita en ambos tenants.
        for tenant in (tenant1, tenant2):
            membership = db.query(TenantMembership).filter(
                TenantMembership.tenant_id == tenant.id,
                TenantMembership.user_id == user1.id
            ).first()
            if not membership:
                membership = TenantMembership(
                    tenant_id=tenant.id,
                    user_id=user1.id,
                    status="ACTIVE"
                )
                db.add(membership)
                db.flush()
            elif membership.status != "ACTIVE":
                membership.status = "ACTIVE"

            customer_role = roles_by_tenant[str(tenant.id)]["CUSTOMER"]
            assignment = db.execute(
                membership_roles.select().where(
                    membership_roles.c.tenant_id == tenant.id,
                    membership_roles.c.membership_id == membership.id,
                    membership_roles.c.role_id == customer_role.id,
                )
            ).first()
            if not assignment:
                db.execute(membership_roles.insert().values(
                    tenant_id=tenant.id,
                    membership_id=membership.id,
                    role_id=customer_role.id,
                ))

        # Bootstrap opcional: el mismo administrador puede operar en ambos tenants.
        # Nunca se crea una contraseña administrativa predeterminada.
        if settings.BOOTSTRAP_ADMIN_EMAIL and settings.BOOTSTRAP_ADMIN_PASSWORD:
            admin_email = settings.BOOTSTRAP_ADMIN_EMAIL.strip().lower()
            admin_user = db.query(User).filter(
                User.email.ilike(admin_email)
            ).first()
            if not admin_user:
                admin_user = User(
                    email=admin_email,
                    password_hash=hash_password(settings.BOOTSTRAP_ADMIN_PASSWORD),
                    full_name="Administrador institucional",
                    is_active=True,
                )
                db.add(admin_user)
                db.flush()

            for tenant in (tenant1, tenant2):
                admin_membership = db.query(TenantMembership).filter(
                    TenantMembership.tenant_id == tenant.id,
                    TenantMembership.user_id == admin_user.id,
                ).first()
                if not admin_membership:
                    admin_membership = TenantMembership(
                        tenant_id=tenant.id,
                        user_id=admin_user.id,
                        status="ACTIVE",
                    )
                    db.add(admin_membership)
                    db.flush()
                elif admin_membership.status != "ACTIVE":
                    admin_membership.status = "ACTIVE"

                admin_role = roles_by_tenant[str(tenant.id)]["ADMIN"]
                assignment = db.execute(
                    membership_roles.select().where(
                        membership_roles.c.tenant_id == tenant.id,
                        membership_roles.c.membership_id == admin_membership.id,
                        membership_roles.c.role_id == admin_role.id,
                    )
                ).first()
                if not assignment:
                    db.execute(membership_roles.insert().values(
                        tenant_id=tenant.id,
                        membership_id=admin_membership.id,
                        role_id=admin_role.id,
                    ))

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
                "user_id": str(user1.id),
                "balance": Decimal("99999999.00"),
                "currency": "COP",
                "status": "ACTIVE",
            },
        ]

        for acc_data in accounts_to_seed:
            existing = db.query(Account).filter(Account.id == acc_data["id"]).first()
            if existing is None:
                db.add(Account(**acc_data))
                continue

            # Seed data is insert-only: restarting the API must never reset a
            # customer's balance or reactivate an account changed during a demo.
            identity_fields = ("tenant_id", "user_id", "account_number", "currency")
            if any(
                getattr(existing, field) != acc_data[field]
                for field in identity_fields
            ):
                raise RuntimeError(
                    f"La cuenta demo {acc_data['id']} ya existe con otra identidad."
                )

        # 6. Seed independent history for each institution only when that
        # tenant has no movements yet. Never overwrite balances on restart.
        history_seeds = (
            (
                tenant1,
                "acc-901",
                Decimal("2500000.00"),
                Decimal("50000.00"),
                "Apertura y depósito inicial",
                "Retiro en cajero automático",
            ),
            (
                tenant2,
                "acc-tenant2-01",
                Decimal("100000000.00"),
                Decimal("1.00"),
                "Apertura y depósito inicial",
                "Retiro de prueba",
            ),
        )
        for tenant, account_id, deposit_amount, withdrawal_amount, deposit_note, withdrawal_note in history_seeds:
            tx_count = db.query(Transaction).filter(
                Transaction.tenant_id == str(tenant.id),
                Transaction.user_id == str(user1.id),
            ).count()
            if tx_count == 0:
                db.add_all([
                    Transaction(
                        tenant_id=str(tenant.id),
                        user_id=str(user1.id),
                        destination_account_id=account_id,
                        type="DEPOSIT",
                        amount=deposit_amount,
                        currency="COP",
                        converted_amount=deposit_amount,
                        destination_currency="COP",
                        exchange_rate=Decimal("1.000000"),
                        fee_amount=Decimal("0.00"),
                        status="COMPLETED",
                        description=deposit_note,
                    ),
                    Transaction(
                        tenant_id=str(tenant.id),
                        user_id=str(user1.id),
                        source_account_id=account_id,
                        type="WITHDRAWAL",
                        amount=withdrawal_amount,
                        currency="COP",
                        converted_amount=withdrawal_amount,
                        destination_currency="COP",
                        exchange_rate=Decimal("1.000000"),
                        fee_amount=Decimal("0.00"),
                        status="COMPLETED",
                        description=withdrawal_note,
                    ),
                ])

        db.commit()
    except Exception as e:
        db.rollback()
        raise RuntimeError(f"Error seeding database: {e}") from e
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        Base.metadata.create_all(bind=engine)
        # Índice único para impedir dobles movimientos incluso ante solicitudes simultáneas.
        # Si ya existen claves duplicadas, el arranque falla para no operar sin esta garantía.
        with engine.begin() as connection:
            connection.execute(text("""
                CREATE UNIQUE INDEX IF NOT EXISTS uq_transactions_idempotency_scope
                ON financial_transactions (tenant_id, user_id, idempotency_key)
                WHERE idempotency_key IS NOT NULL
            """))
        if settings.ENVIRONMENT == "development":
            seed_database()
    except Exception as e:
        raise RuntimeError(f"No fue posible inicializar el esquema de BankOS: {e}") from e
    yield


app = FastAPI(
    title="BankOS API — Multitenant Banking Platform",
    description="API REST completa para la plataforma financiera BankOS (Auth, Accounts, Transactions).",
    version="1.0.0",
    lifespan=lifespan,
)

register_exception_handlers(app)

# Limita autenticación y operaciones financieras por IP usando Redis.
app.add_middleware(RateLimitMiddleware, redis_url=settings.REDIS_URL)

# Middleware de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Correlation-ID"],
)

# Cada solicitud recibe un identificador trazable y lo devuelve en la respuesta.
@app.middleware("http")
async def correlation_id_middleware(request, call_next):
    supplied_id = request.headers.get("X-Correlation-ID", "").strip()
    correlation_id = (
        supplied_id
        if re.fullmatch(r"[A-Za-z0-9._:-]{1,100}", supplied_id)
        else str(uuid.uuid4())
    )
    request.state.correlation_id = correlation_id
    response = await call_next(request)
    response.headers["X-Correlation-ID"] = correlation_id
    return response


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
app.include_router(users_router, prefix="/api/v1")
app.include_router(tenants_router, prefix="/api/v1")
