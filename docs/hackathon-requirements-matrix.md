# Matriz de cumplimiento — Hackathon BankOS

Esta matriz refleja la rama `feat/transactions`. Los estados se asignan según código y evidencia automatizada; no equivalen a autorización para operar dinero real.

| Requisito | Estado | Implementación / evidencia |
|---|---|---|
| Aplicación móvil Flutter | Parcial | Login, sesión, dashboard, cuentas, depósitos, retiros, transferencias e historial. CI compila APK debug y ejecuta pruebas; falta validación manual en dispositivos físicos. |
| Backend REST FastAPI bajo `/api/v1` | Completo | Routers de autenticación, cuentas, usuarios, transacciones y configuración institucional; OpenAPI 1.0.0. |
| PostgreSQL y Docker Compose raíz | Completo | `docker compose up --build -d` validado en CI; API health y OpenAPI responden. El smoke test también autentica ambos tenants y prueba el trigger PostgreSQL. Run `44703047458`. |
| Autenticación JWT | Completo | JWT firmado con usuario, tenant y membresía; se revalidan usuario, tenant, membresía y roles activos en cada solicitud. |
| Roles ADMIN y CUSTOMER | Parcial | CUSTOMER para el usuario demo; ADMIN se crea solo con `BOOTSTRAP_ADMIN_EMAIL` y `BOOTSTRAP_ADMIN_PASSWORD`, sin credenciales administrativas por defecto. |
| Aislamiento entre dos instituciones | Completo | Seed de `cooperativa-futuro` y `neobanco-agil`. Smoke test inició sesión en ambas con el mismo usuario y verificó que cada listado excluyera la cuenta del otro tenant. Run `44703047458`. |
| Límites, comisiones, monedas y tasas por tenant | Completo | Configuración y validación por institución; límites y comisiones se aplican a transferencias y tasas se usan en conversión. |
| Configuración de webhooks | Parcial | Se almacena y valida `webhook_url`; no hay firma, eventos ni entrega/reintentos de webhooks implementados. |
| Depósitos, retiros y transferencias | Completo en prototipo | Operaciones atómicas con validación de cuenta, saldo y PIN cuando aplica. Los depósitos son simulados y se bloquean en producción. |
| Idempotencia de 24 horas o más | Completo | Clave única por tenant/usuario; no hay expiración automática, por lo que la protección se conserva más de 24 horas. Reintentos no repiten el débito. |
| Conversión multimoneda | Completo en demo | Usa tasas y comisiones configuradas por tenant; el backend rechaza conversión en producción sin proveedor de tasas en tiempo real. |
| Historial paginado y filtrable | Completo | API con filtros por cuenta/tipo y paginación; Flutter consume esos parámetros y presenta historial incremental. |
| `X-Correlation-ID` | Completo | Se valida/crea en middleware, se devuelve en cabecera de éxito/error, se incluye en errores y se persiste en movimientos. |
| Errores estandarizados | Completo | Envoltura uniforme para HTTP, validación y errores inesperados con código y correlation ID. |
| Rate limiting Redis | Completo en stack local | Límites por IP para login, transacciones y API; Redis compartido en Compose. El smoke de login funcionó sin activar el fallback local. Run `44703047458`. |
| Auditoría append-only | Completo | Listener ORM y trigger PostgreSQL. Smoke test intentó UPDATE y DELETE directos; ambos fueron rechazados y el registro permaneció intacto. Run `44703047458`. |
| Pruebas backend | Completo en CI | 27 pruebas pasaron en run `44703047458` (20-11-2026), incluyendo límites, aislamiento, comisiones, conversión, operaciones, idempotencia, auditoría y correlation ID. Además, el smoke PostgreSQL y Compose pasó. |
| Pruebas Flutter API/UI | Completo en CI | 21 pruebas pasaron en run `44702381652`: widgets de login/dashboard, modelos y repositorio API (JWT, correlation/idempotency headers, filtros de historial y errores). `flutter analyze --no-fatal-infos` pasó con 34 avisos informativos. |
| APK Android | Completo en CI | `flutter build apk --debug` pasó; artefacto `bankos-android-debug`, ID `14612614894`, run `44702381652` (79.9 MB). Validación en dispositivo físico pendiente. |
| Web demo | Completo como MOCK | El build usa `BANKOS_DEMO_MODE=true`; SessionGate, login y dashboard bloquean el cambio a API. `bankos-web-mock-demo` se generó y subió (ID `14613578206`, 14.2 MB). No conecta a backend público ni usa fondos reales. |
| GitHub Pages | Bloqueado | Build y artefacto web correctos, pero `actions/configure-pages` falla con `Get Pages site failed` / HTTP 404. El repositorio requiere habilitar Pages y seleccionar **GitHub Actions** en Settings → Pages. La conexión disponible no tiene permiso `admin`; no se puede cambiar ese ajuste desde esta ejecución. |
| Backend público | Bloqueado por infraestructura | No hay proveedor de hosting, dominio ni secretos de despliegue configurados. |
| Operación bancaria real | Fuera de alcance | No custodiar fondos reales. Se requieren proveedor de pagos, tasas fiables, seguridad, cumplimiento y operación formal. |

## Ejecución local

```bash
cp .env.example .env
docker compose up --build
```

Swagger: `http://localhost:8000/docs`

Seed local de backend: tenant `cooperativa-futuro` o `neobanco-agil`, usuario `carlos@fintech.com`, contraseña `123456`, PIN transaccional `1234`. Son credenciales exclusivamente de desarrollo. El rol ADMIN se crea solo mediante `BOOTSTRAP_ADMIN_EMAIL` y `BOOTSTRAP_ADMIN_PASSWORD`.

Para ejecutar la app Flutter contra el backend local, compila con una URL alcanzable desde el dispositivo:

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<HOST-ALCANZABLE>:8000/api/v1
```

El modo MOCK usa datos ficticios y sirve solo para demostrar la interfaz. No representa saldos ni operaciones bancarias reales.
