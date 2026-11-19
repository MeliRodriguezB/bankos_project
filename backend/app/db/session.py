from collections.abc import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

# pool_pre_ping=True verifica que la conexión con PostgreSQL siga viva antes de usarla,
# evitando errores por conexiones caídas en entornos de contenedores o redes inestables.
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    echo=settings.ENVIRONMENT == "development",
)

# Fábrica de sesiones: cada solicitud obtiene su propia sesión transaccional aislada.
SessionLocal = sessionmaker(
    bind=engine,
    class_=Session,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
)


def get_db() -> Generator[Session, None, None]:
    """Entrega una sesión de base de datos y garantiza cerrarla al terminar."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
