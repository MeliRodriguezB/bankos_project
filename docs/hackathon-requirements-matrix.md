# Matriz de cumplimiento — Hackathon BankOS

Esta matriz describe el alcance del prototipo en la rama `feat/transactions`. Los estados deben actualizarse únicamente con evidencia de pruebas o despliegue.

| Requisito | Estado | Implementación / evidencia |
|---|---|---|
| Aplicación móvil Flutter | Parcial | Cliente Flutter con login, sesión, dashboard, cuentas, depósitos, retiros, transferencias e historial. El APK debe validarse en CI y probarse en dispositivo. |
| Backend REST FastAPI bajo `/api/v1` | Implementado | Routers de autenticación, cuentas, usuarios, transacciones y configuración de tenant. |
| PostgreSQL y Docker Compose raíz | Implementado | `docker-compose.yml` en raíz; API, PostgreSQL y Redis. |
| Autenticación JWT con tenant, usuario y rol | Implementado | Login por `tenant_slug`; validación de usuario, tenant, membresía y roles activos. |
| Roles ADMIN y CUSTOMER | Parcial | CUSTOMER en seed; ADMIN disponible mediante bootstrap de variables de entorno. |
| Aislamiento entre dos tenants | Implementado | Seed crea dos instituciones, membresía de demostración en ambas y cuentas separadas por tenant. |
| Configuración por tenant | Parcial | API para límite, comisiones fijas/porcentuales, moneda principal, monedas soportadas, tasas y URL de webhook. La entrega real de webhooks aún no está implementada. |
| Depósitos, retiros y transferencias | Implementado en prototipo | Servicios de transacción y pantallas Flutter conectadas a repositorios API. Los depósitos son simulados. |
| Idempotencia y reintentos | Implementado en prototipo | Clave obligatoria, restricción única por tenant/usuario y pruebas para evitar doble débito en reintentos. |
| Transferencia multimoneda | Implementado en prototipo | Tasas configurables por tenant, comisión fija y porcentaje. Tasas estáticas solo en entorno de demostración. |
| Límite de transferencia | Implementado | `max_transfer_amount` validado en cotización y ejecución. |
| Historial paginado y filtrable | Implementado | Filtros por cuenta y tipo, paginación en API y carga incremental en Flutter. |
| X-Correlation-ID | Parcial | Se acepta y persiste en movimientos; si falta, el backend genera uno. Falta propagarlo uniformemente en todos los errores. |
| Rate limiting | Implementado en prototipo | Redis por IP: 10 login/min, 30 transacciones/min, 120 solicitudes API/min; fallback local si Redis no responde. |
| Auditoría inmutable | Parcial | Registros append-only mediante listeners ORM y trigger PostgreSQL de migración. Debe validarse en PostgreSQL real. |
| Documentación API v1 | Implementado | OpenAPI/Swagger y documentación de contratos y configuración tenant. |
| Pruebas de transacciones | En validación | Casos añadidos para atomicidad, idempotencia, payload distinto, límites, aislamiento, comisiones, multimoneda, depósitos, retiros, PIN y auditoría. |
| Despliegue público web | En validación | Workflow GitHub Pages en modo MOCK, sin backend público ni dinero real. Requiere Pages habilitado en GitHub. |
| Despliegue backend público | Bloqueado por infraestructura | No hay proveedor, dominio ni credenciales de hosting configurados. |
| Operación bancaria real | Fuera de alcance | No custodiar fondos reales; requiere proveedor de pagos, tasas fiables, seguridad, cumplimiento y operación formal. |

## Comandos de ejecución local

```bash
cp .env.example .env
docker compose up --build -d
docker compose ps
```

Swagger: `http://localhost:8000/docs`

La app Flutter en modo API debe compilarse con una URL alcanzable desde el dispositivo:

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<HOST-ALCANZABLE>:8000/api/v1
```

El modo MOCK es una demostración visual con datos ficticios. Para validar transacciones persistentes, usa el backend local y una base de datos PostgreSQL.
