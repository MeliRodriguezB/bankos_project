# BankOS — Auditoría de coherencia API

**Fecha de revisión:** 2026-11-20  
**Base revisada:** rama `develop`  
**Método:** comparación del contrato `docs/api-contract.md` con routers FastAPI en `backend/app/modules`.

> Revisión estática de código y documentación. No sustituye pruebas HTTP ejecutadas ni pruebas de integración.

## Resultado

Los routers de autenticación, cuentas y transacciones muestran los siguientes endpoints. La documentación del contrato requiere algunos ajustes para describir el comportamiento actual de manera exacta.

## 1. Endpoints identificados en routers

| Método | Ruta | Estado observado |
|---|---|---|
| POST | `/api/v1/auth/login` | Implementado en auth router |
| GET | `/api/v1/auth/me` | Implementado en auth router |
| GET | `/api/v1/dashboard` | Implementado en accounts router |
| GET | `/api/v1/accounts` | Implementado |
| GET | `/api/v1/accounts/{account_id}` | Implementado |
| POST | `/api/v1/accounts` | Implementado; falta confirmar restricciones de rol mediante revisión del service |
| PATCH | `/api/v1/accounts/{account_id}/deactivate` | Implementado |
| POST | `/api/v1/transactions/quote` | Implementado |
| POST | `/api/v1/transactions/transfers` | Implementado |
| POST | `/api/v1/transactions/deposits` | Implementado |
| POST | `/api/v1/transactions/withdrawals` | Implementado |
| GET | `/api/v1/transactions` | Implementado |

## 2. Discrepancias y verificaciones pendientes

### API-AUD-01 — Paginación del historial

- **Contrato:** describe parámetros `limit` y `offset`.
- **Router:** recibe `page` y `page_size`.
- **Acción:** actualizar el contrato a `page` y `page_size`, o cambiar implementación si se decide conservar limit/offset. Mantener una única convención.

### API-AUD-02 — Idempotency-Key no es obligatorio en el router

- **Contrato:** indica que el encabezado es obligatorio en operaciones financieras.
- **Router:** acepta `Optional[str]`; si no se envía, genera una clave automáticamente (`idem-<uuid>`).
- **Acción:** decidir si la obligatoriedad se aplica en el backend. Para comportamiento idempotente frente a reintentos del cliente, se recomienda requerir el encabezado y devolver error de validación cuando falte, en vez de generar una nueva clave por cada reintento.

### API-AUD-03 — Creación de cuentas

- **Contrato revisado:** no documenta con suficiente detalle el endpoint `POST /api/v1/accounts`.
- **Router:** endpoint presente, recibe `AccountCreate` y crea una cuenta usando tenant/user del JWT.
- **Acción:** agregar contrato de solicitud, respuesta, permisos y restricciones del service. No asumir que cualquier usuario está autorizado solo por la descripción del router.

### API-AUD-04 — Status codes y respuestas

- **Contrato:** enumera varios status codes de negocio.
- **Router:** confirma rutas y response models, pero no permite verificar por sí solo qué errores exactos emiten los services.
- **Acción:** comprobar exceptions y códigos HTTP de los services antes de afirmar que todos los códigos listados están implementados.

### API-AUD-05 — CORS

- **Código revisado:** `allow_origins=["*"]`, `allow_credentials=True`.
- **Acción:** configuración aceptable solo para entorno local controlado; restringir orígenes explícitos antes de despliegue. No presentar esta configuración como lista para producción.

## 3. Qué se verificó

- Se inspeccionaron los routers de autenticación, cuentas/dashboard y transacciones.
- Se confirmaron las rutas y parámetros declarados directamente en los routers.
- La revisión no ejecutó llamadas HTTP ni pruebas de backend.
- No se revisaron aún en profundidad los services, schemas, migrations ni tests.

## 4. Siguiente revisión

1. Revisar schemas y services de auth, accounts y transactions.
2. Corregir contrato API según comportamiento real.
3. Ejecutar pruebas backend y Flutter.
4. Capturar evidencia de cada flujo de MVP.
5. Actualizar README para que las afirmaciones de estado estén respaldadas por checks reproducibles.

## 5. Criterio de presentación

Usar las etiquetas **implementado**, **verificado por código**, **verificado por pruebas** y **pendiente** con precisión. Una ruta registrada en FastAPI no demuestra que un flujo end-to-end esté funcionando.
