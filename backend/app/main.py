
from fastapi import FastAPI

from app.core.config import settings


# Instancia principal de la API
app = FastAPI(
    title="BankOS API",
    description="API REST para la plataforma financiera BankOS",
    version="1.0.0"
)


# Endpoint básico para comprobar que la API está funcionando
@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "ok",
        "application": "BankOS",
        "environment": settings.ENVIRONMENT
    }
