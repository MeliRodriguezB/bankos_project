from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


def register_exception_handlers(app: FastAPI) -> None:
    """Devuelve errores de API con una envoltura consistente y trazable."""

    @app.exception_handler(HTTPException)
    async def handle_http_exception(request: Request, exc: HTTPException):
        message = exc.detail if isinstance(exc.detail, str) else "La solicitud no pudo completarse."
        correlation_id = request.headers.get("X-Correlation-ID")
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": {
                    "code": f"HTTP_{exc.status_code}",
                    "message": message,
                    "correlation_id": correlation_id,
                }
            },
            headers=exc.headers,
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_exception(request: Request, exc: RequestValidationError):
        fields = [
            {
                "field": ".".join(str(part) for part in error.get("loc", ())),
                "message": error.get("msg", "Valor inválido."),
            }
            for error in exc.errors()
        ]
        return JSONResponse(
            status_code=422,
            content={
                "error": {
                    "code": "VALIDATION_ERROR",
                    "message": "La solicitud no cumple el contrato de la API.",
                    "correlation_id": request.headers.get("X-Correlation-ID"),
                    "fields": fields,
                }
            },
        )
