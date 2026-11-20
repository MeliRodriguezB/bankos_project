import logging
import time
from collections import defaultdict

from fastapi import Request
from fastapi.responses import JSONResponse
from redis.asyncio import Redis
from redis.exceptions import RedisError
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.responses import Response

logger = logging.getLogger(__name__)


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Aplica límites por IP y ventana de un minuto usando Redis compartido."""

    def __init__(self, app, redis_url: str):
        super().__init__(app)
        self.redis = Redis.from_url(
            redis_url,
            decode_responses=True,
            socket_connect_timeout=0.25,
            socket_timeout=0.25,
        )
        self.local_counters: dict[str, int] = defaultdict(int)
        self.local_window = int(time.time() // 60)

    @staticmethod
    def _policy(path: str) -> tuple[str, int] | None:
        if path == "/api/v1/auth/login":
            return "login", 10
        if path.startswith("/api/v1/transactions"):
            return "transactions", 30
        if path.startswith("/api/v1"):
            return "api", 120
        return None

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        policy = self._policy(request.url.path)
        if policy is None:
            return await call_next(request)

        bucket, limit = policy
        client_ip = request.client.host if request.client else "unknown"
        window = int(time.time() // 60)
        key = f"bankos:rate:{bucket}:{client_ip}:{window}"

        try:
            count = await self.redis.incr(key)
            if count == 1:
                await self.redis.expire(key, 60)
        except RedisError:
            # Mantiene una protección básica local si Redis no está disponible.
            logger.warning("Redis rate limiter unavailable; using process-local fallback.")
            if window != self.local_window:
                self.local_counters.clear()
                self.local_window = window
            self.local_counters[key] += 1
            count = self.local_counters[key]

        if count > limit:
            correlation_id = request.headers.get("X-Correlation-ID", "")
            return JSONResponse(
                status_code=429,
                content={
                    "error": {
                        "code": "RATE_LIMIT_EXCEEDED",
                        "message": "Has superado el límite de solicitudes. Intenta nuevamente en un minuto.",
                        "correlation_id": correlation_id or None,
                    }
                },
                headers={"Retry-After": "60"},
            )

        return await call_next(request)
