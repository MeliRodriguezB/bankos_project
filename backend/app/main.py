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
from app.modules.users.models import User, PlatformAdmin
from app.modules.admin.models import BankConfiguration, Currency, BankExchangeRate
from app.modules.roles.models import Role, membership_roles
from app.modules.accounts.models import Account
from app.modules.transactions.models import Transaction

# Importar enrutadores
from app.modules.auth.router import router as auth_router
from app.modules.accounts.router import router as accounts_router
from app.modules.transactions.router import router as transactions_router
from app.modules.users.router import router as users_router
from app.modules.admin.router import router as admin_router


def seed_database():
    """
    Inicializa de forma 100% idempotente los datos de demostración para el reto BankOS:
    - Cuatro instituciones financieras colombianas (tenants) independientes.
    - Usuario de prueba (Carlos Mendoza) con credenciales seguras (Argon2).
    - Membresías y roles.
    - Cuentas en múltiples divisas (COP, USD) y una desactivada (soft delete).
    - Historial de transacciones previas.
    """
    db = SessionLocal()
    try:
        # 1. Tenants: bancos reales para la demostración multitenant.
        # Migramos los tenants de demostración existentes para conservar sus IDs y relaciones.
        def get_or_migrate_tenant(slug, name, legacy_slug=None):
            tenant = db.query(Tenant).filter(Tenant.slug == slug).first()
            if tenant is None and legacy_slug:
                tenant = db.query(Tenant).filter(Tenant.slug == legacy_slug).first()
            if tenant is None:
                tenant = Tenant(name=name, slug=slug, status="ACTIVE")
                db.add(tenant)
                db.flush()
            else:
                tenant.name = name
                tenant.slug = slug
                tenant.status = "ACTIVE"
            return tenant

        tenant1 = get_or_migrate_tenant("bancolombia", "Bancolombia", "cooperativa-futuro")
        tenant2 = get_or_migrate_tenant("banco-popular", "Banco Popular", "neobanco-agil")
        tenant3 = get_or_migrate_tenant("nequi", "Nequi")
        tenant4 = get_or_migrate_tenant("nu", "Nu")

        # Branding por institución: el dashboard utilizará estas paletas.
        bank_branding = [
            (tenant1, "#007A4B", "#FFFFFF", "#19A86B"),  # Bancolombia
            (tenant2, "#B5121B", "#FFFFFF", "#E34A50"),  # Banco Popular
            (tenant3, "#DA0081", "#FFFFFF", "#F35BB0"),  # Nequi
            (tenant4, "#820AD1", "#FFFFFF", "#B66CE6"),  # Nu
        ]
        for tenant, primary, secondary, accent in bank_branding:
            config = db.query(BankConfiguration).filter(
                BankConfiguration.tenant_id == tenant.id
            ).first()
            if config is None:
                db.add(BankConfiguration(
                    tenant_id=tenant.id,
                    primary_color=primary,
                    secondary_color=secondary,
                    accent_color=accent,
                ))
            else:
                config.primary_color = primary
                config.secondary_color = secondary
                config.accent_color = accent

        # Seed de divisas base para la configuración global.
        base_currencies = [
            ("COP", "Peso colombiano", "$"),
            ("USD", "Dólar estadounidense", "US$"),
            ("EUR", "Euro", "€"),
        ]
        for code, name, symbol in base_currencies:
            if not db.query(Currency).filter(Currency.code == code).first():
                db.add(Currency(code=code, name=name, symbol=symbol, is_active=True))

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

        role_admin = db.query(Role).filter(
            Role.tenant_id == tenant1.id,
            Role.code == "ADMIN"
        ).first()
        if not role_admin:
            role_admin = Role(
                tenant_id=tenant1.id,
                code="ADMIN",
                name="Administrador institucional",
                is_system=True
            )
            db.add(role_admin)
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

        # El usuario de demostración puede ingresar a los cuatro tenants.
        # Se crea un rol CUSTOMER independiente por institución (los roles son tenant-scoped).
        for tenant in (tenant2, tenant3, tenant4):
            customer_role = db.query(Role).filter(
                Role.tenant_id == tenant.id,
                Role.code == "CUSTOMER",
            ).first()
            if customer_role is None:
                customer_role = Role(
                    tenant_id=tenant.id,
                    code="CUSTOMER",
                    name="Cliente Bancario",
                    is_system=True,
                )
                db.add(customer_role)
                db.flush()

            demo_membership = db.query(TenantMembership).filter(
                TenantMembership.tenant_id == tenant.id,
                TenantMembership.user_id == user1.id,
            ).first()
            if demo_membership is None:
                demo_membership = TenantMembership(
                    tenant_id=tenant.id,
                    user_id=user1.id,
                    status="ACTIVE",
                )
                db.add(demo_membership)
                db.flush()

            role_assignment = db.execute(
                membership_roles.select().where(
                    membership_roles.c.tenant_id == tenant.id,
                    membership_roles.c.membership_id == demo_membership.id,
                    membership_roles.c.role_id == customer_role.id,
                )
            ).first()
            if role_assignment is None:
                db.execute(membership_roles.insert().values(
                    tenant_id=tenant.id,
                    membership_id=demo_membership.id,
                    role_id=customer_role.id,
                ))

        # Bootstrap administrativo opcional: nunca se crea una contraseña predeterminada.
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

            admin_membership = db.query(TenantMembership).filter(
                TenantMembership.tenant_id == tenant1.id,
                TenantMembership.user_id == admin_user.id,
            ).first()
            if not admin_membership:
                admin_membership = TenantMembership(
                    tenant_id=tenant1.id,
                    user_id=admin_user.id,
                    status="ACTIVE",
                )
                db.add(admin_membership)
                db.flush()
            elif admin_membership.status != "ACTIVE":
                admin_membership.status = "ACTIVE"

            # Registrar también como administrador global de la plataforma.
            platform_admin = db.query(PlatformAdmin).filter(
                PlatformAdmin.user_id == admin_user.id
            ).first()
            if platform_admin is None:
                db.add(PlatformAdmin(user_id=admin_user.id, is_active=True))
            elif not platform_admin.is_active:
                platform_admin.is_active = True

            assignment = db.execute(
                membership_roles.select().where(
                    membership_roles.c.tenant_id == tenant1.id,
                    membership_roles.c.membership_id == admin_membership.id,
                    membership_roles.c.role_id == role_admin.id,
                )
            ).first()
            if not assignment:
                db.execute(membership_roles.insert().values(
                    tenant_id=tenant1.id,
                    membership_id=admin_membership.id,
                    role_id=role_admin.id,
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
                "alias": "Cuenta Banco Popular",
                "tenant_id": str(tenant2.id),
                "user_id": str(uuid.uuid4()),
                "balance": Decimal("99999999.00"),
                "currency": "COP",
                "status": "ACTIVE",
            },
            {
                "id": "acc-nequi-01",
                "account_number": "7770001234",
                "alias": "Cuenta Nequi",
                "tenant_id": str(tenant3.id),
                "user_id": str(user1.id),
                "balance": Decimal("1250000.00"),
                "currency": "COP",
                "status": "ACTIVE",
            },
            {
                "id": "acc-nu-01",
                "account_number": "6660001234",
                "alias": "Cuenta Nu",
                "tenant_id": str(tenant4.id),
                "user_id": str(user1.id),
                "balance": Decimal("820000.00"),
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

# Middleware de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
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
app.include_router(users_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")
