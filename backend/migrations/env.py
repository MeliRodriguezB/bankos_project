from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.core.config import settings
from app.db.base import Base

# Importar los módulos registra sus tablas en Base.metadata.
# A medida que agreguemos módulos, deberán importarse aquí también.
from app.modules.tenants import models as tenant_models  # noqa: F401
from app.modules.users import models as user_models  # noqa: F401
from app.modules.roles import models as role_models  # noqa: F401


config = context.config

# Configura el sistema de logs definido en alembic.ini.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Alembic utilizará la URL de conexión centralizada de BankOS.
# Se escapan los porcentajes para evitar interpolaciones del ConfigParser.
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL.replace("%", "%%"))

# Metadatos que Alembic comparará con la base de datos.
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Genera SQL de migración sin abrir una conexión a la base de datos."""
    url = config.get_main_option("sqlalchemy.url")

    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Ejecuta migraciones utilizando una conexión real a PostgreSQL."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
