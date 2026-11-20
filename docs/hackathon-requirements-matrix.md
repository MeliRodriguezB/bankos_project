# Matriz de cumplimiento — Hackathon BankOS

Esta matriz refleja la rama `feat/transactions`. Los estados se asignan según código y evidencia automatizada; no equivalen a autorización para operar dinero real.

| Requisito | Estado | Implementación / evidencia |
|---|---|---|
| Aplicación móvil Flutter | Parcial | Login, sesión, dashboard, cuentas, depósitos, retiros, transferencias e historial. CI compila APK debug y ejecuta pruebas; falta validación manual en dispositivos físicos. |
| Backend REST FastAPI bajo `/api/v1` | Completo | Routers de autenticación, cuentas, usuarios, transacciones y configuración institucional; OpenAPI 1.0.0. |
| PostgreSQL y Docker Compose raíz | Parcial | `docker-compose.yml` define API, PostgreSQL y Redis. El workflow incorpora smoke test de `docker compose up --build`; pendiente resultado del run actual. |
| Autenticación JWT | Completo | JWT firmado con usuario, tenant y membresía; se revalidan usuario, tenant, membresía y roles activos en cada solicitud. |
| Roles ADMIN y CUSTOMER | Parcial | CUSTOMER para el usuario demo; ADMIN se crea solo con `BOOTSTRAP_ADMIN_EMAIL` y `BOOTSTRAP_ADMIN_PASSWORD`, sin credenciales administrativas por defecto. |
| Aislamiento entre dos instituciones | Completo | Seed de `cooperativa-futuro` y `neobanco-agil`, membresía de demo en ambas y cuentas separadas. Las consultas financieras se filtran por tenant y titular. |
| Límites, comisiones, monedas y tasas por tenant | Completo | Configuración y validación por institución; límites y comisiones se aplican a transferencias y tasas se usan en conversión. |
| Configuración de webhooks | Parcial | Se almacena y valida `webhook_url`; no hay firma, eventos ni entrega/reintentos de webhooks implementados. |
| Depósitos, retiros y transferencias | Completo en prototipo | Operaciones atómicas con validación de cuenta, saldo y PIN cuando aplica. Los depósitos son simulados y se bloquean en producción. |
| Idempotencia de 24 horas o más | Completo | Clave única por tenant/usuario; no hay expiración automática, por lo que la protección se conserva más de 24 horas. Reintentos no repiten el débito. |
| Conversión multimoneda | Completo en demo | Usa tasas y comisiones configuradas por tenant; el backend rechaza conversión en producción sin proveedor de tasas en tiempo real. |
| Historial paginado y filtrable | Completo | API con filtros por cuenta/tipo y paginación; Flutter consume esos parámetros y presenta historial incremental. |
| `X-Correlation-ID` | Completo | Se valida/crea en middleware, se devuelve en cabecera de éxito/error, se incluye en errores y se persiste en movimientos. |
| Errores estandarizados | Completo | Envoltura uniforme para HTTP, validación y errores inesperados con código y correlation ID. |
| Rate limiting Redis | Completo en stack local | Límites por IP para login, transacciones y API; Redis compartido con fallback local documentado si Redis falla. |
| Auditoría append-only | Parcial | Listener ORM impide UPDATE/DELETE y migración crea trigger PostgreSQL. La suite actual prueba inmutabilidad ORM; falta una prueba de mutación directa contra PostgreSQL. |
| Pruebas backend | Completo en CI | 27 pruebas pasaron en run `44702096531` (20-11-2026), incluyendo límites, aislamiento, comisiones, conversión, operaciones, idempotencia, auditoría y correlation ID. |
| Pruebas Flutter API/UI | Parcial | Pruebas de modelos y mocks existentes; se añadieron pruebas del repositorio API para headers, idempotencia, filtros y errores. Pendiente resultado del workflow posterior al último commit. |
| APK Android | Parcial | Existe un artefacto debug exitoso en run `44694687030`; se debe confirmar el nuevo artefacto tras los cambios recientes. |
| Web demo | Completo como MOCK | El build usa `BANKOS_DEMO_MODE=true`; SessionGate, login y dashboard bloquean el cambio a API. No conecta a backend público ni usa fondos reales. |
| GitHub Pages | Bloqueado | El workflow compila la web, pero `actions/configure-pages` devuelve 404 porque GitHub Pages no está habilitado/configurado para el repositorio. Requiere activar Pages y seleccionar GitHub Actions en Settings → Pages. |
| Backend público | Bloqueado por infraestructura | No hay proveedor de hosting, dominio ni secretos de despliegue configurados. |
| Operación bancaria real | Fuera de alcance | No custodiar fondos reales. Se requieren proveedor de pagos, tasas fiables, seguridad, cumplimiento y operación formal. |

## Ejecución local

```bash
cp .env.example .env
docker compose up --build
```

Swagger: `http://localhost:8000/docs`

Para ejecutar la app Flutter contra el backend local, compila con una URL alcanzable desde el dispositivo:

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<HOST-ALCANZABLE>:8000/api/v1
```

El modo MOCK usa datos ficticios y sirve solo para demostrar la interfaz. No representa saldos ni operaciones bancarias reales.
