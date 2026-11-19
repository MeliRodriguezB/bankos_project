from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings

# pool_pre_ping=True verifica que la conexión con PostgreSQL siga viva antes de usarla,
# evitando errores por conexiones caídas en entornos de contenedores o redes inestables.
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    echo=settings.ENVIRONMENT == "development",
)

# Sesiones de base de datos no autocommit por defecto para garantizar
# que cada operación financiera defina explícitamente sus límites de transacción (commit o rollback).
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)
