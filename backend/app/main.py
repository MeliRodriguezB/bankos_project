from contextlib import asynccontextmanager
from decimal import Decimal
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db.base import Base
from app.db.session import engine, SessionLocal
from app.modules.accounts.models import Account
from app.modules.accounts.router import router as accounts_router


def seed_initial_development_data():
    """
    Inicializa datos de prueba controlados para desarrollo local y demos.
    Crea dos instituciones (tenants) independientes para demostrar
    el aislamiento estricto exigido por los jueces del reto.
    """
    db = SessionLocal()
    try:
        # Verificar si ya existen cuentas
        count = db.query(Account).count()
        if count == 0:
            # Tenant 1: Cooperativa Futuro (COP y USD)
            acc1 = Account(
                id="acc-901",
                account_number="1002348911",
                alias="Cuenta de Ahorros Principal",
                tenant_id="tenant-coop-01",
                user_id="usr-dev-101",
                balance=Decimal("2450000.00"),
                currency="COP",
                status="ACTIVE",
            )
            acc2 = Account(
                id="acc-902",
                account_number="1002348922",
                alias="Fondo de Emergencia",
                tenant_id="tenant-coop-01",
                user_id="usr-dev-101",
                balance=Decimal("450000.00"),
                currency="COP",
                status="ACTIVE",
            )
            acc3 = Account(
                id="acc-903",
                account_number="2005541100",
                alias="Ahorro Dólares",
                tenant_id="tenant-coop-01",
                user_id="usr-dev-101",
                balance=Decimal("350.00"),
                currency="USD",
                status="ACTIVE",
            )
            acc_inactive = Account(
                id="acc-904",
                account_number="1002348999",
                alias="Cuenta Antigua Desactivada",
                tenant_id="tenant-coop-01",
                user_id="usr-dev-101",
                balance=Decimal("0.00"),
                currency="COP",
                status="INACTIVE",  # Ejemplo de borrado lógico
            )

            # Tenant 2: Neobanco Ágil (Aislamiento: el usuario del tenant 1 NUNCA debe ver esto)
            acc_tenant2 = Account(
                id="acc-tenant2-01",
                account_number="8880001234",
                alias="Cuenta de Otra Institución",
                tenant_id="tenant-neobank-02",
                user_id="usr-other-202",
                balance=Decimal("99999999.00"),
                currency="COP",
                status="ACTIVE",
            )

            db.add_all([acc1, acc2, acc3, acc_inactive, acc_tenant2])
            db.commit()
    except Exception as e:
        db.rollback()
        print(f"Error seeding development data: {e}")
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Crear tablas al iniciar si no existen
    try:
        Base.metadata.create_all(bind=engine)
        if settings.ENVIRONMENT == "development":
            seed_initial_development_data()
    except Exception as e:
        print(f"Advertencia al conectar o crear tablas: {e}")
    yield


app = FastAPI(
    title="BankOS API",
    description="API REST Multitenant para la plataforma financiera BankOS",
    version="1.0.0",
    lifespan=lifespan,
)

# Configuración de CORS para permitir peticiones desde la app Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Endpoint de verificación de salud
@app.get("/health", tags=["Health"])
def health_check():
    """Devuelve el estado básico de disponibilidad de la API."""
    return {
        "status": "ok",
        "application": "BankOS",
        "environment": settings.ENVIRONMENT,
    }

# Registro del enrutador de cuentas y dashboard bajo el prefijo /api/v1 acordado
app.include_router(accounts_router, prefix="/api/v1")
