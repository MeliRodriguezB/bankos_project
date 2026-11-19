from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings


# Crea el motor de SQLAlchemy usando la URL configurada para PostgreSQL.
# pool_pre_ping comprueba que la conexión siga disponible antes de reutilizarla.
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
)

# Fábrica de sesiones: cada solicitud podrá obtener su propia sesión.
SessionLocal = sessionmaker(
    bind=engine,
    class_=Session,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
)


def get_db() -> Generator[Session, None, None]:
    """Entrega una sesión de base de datos y la cierra al terminar."""
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()
