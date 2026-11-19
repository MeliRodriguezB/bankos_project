
from functools import lru_cache

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Identifica el entorno en el que se ejecuta la aplicación
    ENVIRONMENT: str = "development"

    # Dirección de conexión a PostgreSQL
    DATABASE_URL: str = (
        "postgresql+psycopg://bankos_user:bankos_dev_password"
        "@localhost:5432/bankos_db"
    )

    # Dirección de conexión a Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # Clave temporal para desarrollo; deberá configurarse de forma segura
    # antes de implementar autenticación o desplegar en producción
    SECRET_KEY: str = "bankos-development-secret-change-before-production"

    # Tiempo de duración del token de acceso, expresado en minutos
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # Bootstrap administrativo opcional: definir ambos secretos en el entorno.
    BOOTSTRAP_ADMIN_EMAIL: str | None = None
    BOOTSTRAP_ADMIN_PASSWORD: str | None = None

    # Permite leer las variables definidas en el entorno
    model_config = SettingsConfigDict(
        case_sensitive=True,
        extra="ignore"
    )

    @model_validator(mode="after")
    def validate_production_secrets(self):
        if self.ENVIRONMENT.lower() == "production":
            if (
                self.SECRET_KEY == "bankos-development-secret-change-before-production"
                or len(self.SECRET_KEY) < 32
            ):
                raise ValueError(
                    "En producción SECRET_KEY debe ser una clave propia de al menos 32 caracteres."
                )
        if bool(self.BOOTSTRAP_ADMIN_EMAIL) != bool(self.BOOTSTRAP_ADMIN_PASSWORD):
            raise ValueError(
                "BOOTSTRAP_ADMIN_EMAIL y BOOTSTRAP_ADMIN_PASSWORD deben configurarse juntos."
            )
        return self


# Evita crear varias instancias de configuración innecesariamente
@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
