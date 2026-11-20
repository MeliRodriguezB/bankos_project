import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)


def _correlation_id(request: Request) -> str | None:
    return getattr(request.state, "correlation_id", None) or request.headers.get(
        "X-Correlation-ID"
    )


def _response_headers(correlation_id: str | None, extra: dict | None = None) -> dict:
    headers = dict(extra or {})
    if correlation_id:
        headers["X-Correlation-ID"] = correlation_id
    return headers


def register_exception_handlers(app: FastAPI) -> None:
    """Devuelve errores de API con una envoltura consistente y trazable."""

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_exception(request: Request, exc: StarletteHTTPException):
        message = (
            exc.detail
            if isinstance(exc.detail, str)
            else "La solicitud no pudo completarse."
        )
        correlation_id = _correlation_id(request)
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": {
                    "code": f"HTTP_{exc.status_code}",
                    "message": message,
                    "correlation_id": correlation_id,
                }
            },
            headers=_response_headers(correlation_id, exc.headers),
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_exception(request: Request, exc: RequestValidationError):
        correlation_id = _correlation_id(request)
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
                    "correlation_id": correlation_id,
                    "fields": fields,
                }
            },
            headers=_response_headers(correlation_id),
        )

    @app.exception_handler(Exception)
    async def handle_unexpected_exception(request: Request, exc: Exception):
        correlation_id = _correlation_id(request)
        logger.exception(
            "Unhandled API exception (correlation_id=%s)", correlation_id
        )
        return JSONResponse(
            status_code=500,
            content={
                "error": {
                    "code": "INTERNAL_SERVER_ERROR",
                    "message": "No fue posible completar la solicitud.",
                    "correlation_id": correlation_id,
                }
            },
            headers=_response_headers(correlation_id),
        )
