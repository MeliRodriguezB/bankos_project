# Matriz de cumplimiento — Hackathon BankOS

Esta matriz refleja el código de `feat/transactions` validado en el commit `ebca94a40dffb48c8a0635465b50af38aa120834` (20-11-2026). Los estados se basan en código y evidencia automatizada; no autorizan el uso de dinero real.

| Requisito | Estado | Implementación / evidencia |
|---|---|---|
| Aplicación móvil Flutter | Parcial | Incluye login, sesión, dashboard, cuentas, depósitos, retiros, transferencias e historial. Flutter CI ejecutó 26 pruebas y generó un APK Android debug. Falta validación manual en dispositivo físico y no se generó APK release firmado. |
| Backend REST FastAPI bajo `/api/v1` | Completo | Routers de autenticación, cuentas, usuarios, transacciones y configuración institucional; OpenAPI informa versión `1.0.0`. El smoke test consultó `/openapi.json` y verificó rutas v1. |
| PostgreSQL y Docker Compose raíz | Completo | `docker compose -f ../docker-compose.yml config --quiet` y `up --build -d` pasaron en CI. API y PostgreSQL/Redis quedaron saludables; el stack se apagó al terminar. Run [44715445134](https://github.com/MeliRodriguezB/bankos_project/actions/runs/44715445134). |
| Autenticación JWT | Completo | JWT firmado con usuario, tenant y membresía; cada solicitud vuelve a comprobar usuario, institución, membresía y roles activos. |
| Roles ADMIN y CUSTOMER | Completo | Los roles son propios de cada tenant. El administrador se crea mediante `BOOTSTRAP_ADMIN_EMAIL` y `BOOTSTRAP_ADMIN_PASSWORD`, sin contraseña administrativa por defecto. El smoke test autenticó un CUSTOMER y un ADMIN en ambas instituciones y actualizó su configuración. Run [44715445134](https://github.com/MeliRodriguezB/bankos_project/actions/runs/44715445134). |
| Dashboards CUSTOMER y ADMIN | Completo | El dashboard CUSTOMER muestra el nombre y la moneda principal reales del tenant. El dashboard ADMIN calcula membresías, cuentas, balances y transacciones usando el UUID institucional y excluye los datos del segundo tenant. Dos pruebas de servicio cubren estos comportamientos en el run [44715445134](https://github.com/MeliRodriguezB/bankos_project/actions/runs/44715445134). |
| Aislamiento entre dos instituciones | Completo | Seed de `cooperativa-futuro` y `neobanco-agil`. El primer tenant tiene cuentas `1002348911` y `1002348922`; el segundo tiene `8880001234` y `8880005678`, de modo que ambos permiten transferencias internas. El smoke test verificó que cada listado incluyera su destino local y excluyera la cuenta del otro tenant. Una prueba de servicio ejecuta una transferencia en el segundo tenant y comprueba que los saldos del primero no cambien. Run [44715445134](https://github.com/MeliRodriguezB/bankos_project/actions/runs/44715445134). |
| Límites, comisiones, monedas y tasas por tenant | Completo | Configuración administrativa aislada por institución; el smoke test guardó y leyó límites, comisiones, monedas soportadas y tasas distintas por tenant. Las transferencias aplican esas políticas. |
| Configuración de webhooks por tenant | Completo para configuración | `webhook_url` se valida y almacena en la configuración institucional, y el smoke test verificó su lectura/escritura independiente en ambos tenants. No se implementan firma, despacho de eventos ni reintentos de entrega; esos elementos no deben darse por disponibles. |
| Depósitos, retiros y transferencias | Completo en prototipo | Operaciones con validación de cuenta, saldo, PIN cuando aplica, atomicidad e idempotencia. Los depósitos son simulados y se deshabilitan en producción. |
| Idempotencia de 24 horas o más | Completo | La clave única se conserva en PostgreSQL sin expiración automática y se acota por tenant/usuario. Repetir la misma solicitud devuelve el movimiento existente; reutilizar la clave con otro payload se rechaza. Una prueba retrocede `created_at` 25 horas y confirma que el retry devuelve el movimiento original sin volver a debitar. |
| Conversión multimoneda | Completo en demo | Utiliza tasas y comisiones configuradas por tenant. En producción se rechaza la conversión hasta integrar un proveedor fiable de tasas en tiempo real. |
| Historial paginado y filtrable | Completo | API filtra por cuenta/tipo y pagina por `page`/`page_size`; Flutter consume esos parámetros y permite cargar más movimientos. |
| `X-Correlation-ID` | Completo | Middleware valida o genera el identificador y lo devuelve en respuestas exitosas y errores; los movimientos guardan el mismo ID que aparece en el header. Una prueba de ruta cubre IDs generados y enviados por el cliente. |
| Errores estandarizados | Completo | Envoltura uniforme para HTTP, validación y errores inesperados con código y correlation ID. |
| Rate limiting Redis | Completo en stack local | Middleware aplica ventanas por IP a login, transacciones y API general. Redis quedó saludable en Compose. Dos pruebas verifican `INCR`, expiración de 60 segundos y respuesta 429 con `X-Correlation-ID`. Existe fallback local si Redis no está disponible, que no sustituye el límite distribuido. Run [44715445134](https://github.com/MeliRodriguezB/bankos_project/actions/runs/44715445134). |
| Auditoría append-only | Completo | Listener ORM y trigger PostgreSQL. El smoke test intentó UPDATE y DELETE directos; ambos fueron rechazados y el registro permaneció intacto. Run [44715445134](https://github.com/MeliRodriguezB/bankos_project/actions/runs/44715445134). |
| Pruebas backend | Completo en CI | 36 pruebas pasaron en el run [44715445134](https://github.com/MeliRodriguezB/bankos_project/actions/runs/44715445134), además de los smoke tests de Compose, roles/tenants/configuración y trigger append-only. Incluye seed idempotente que conserva saldos y estado de cuentas al reiniciar. |
| Pruebas Flutter API/UI | Completo en CI | 26 pruebas pasaron en el run [44715445144](https://github.com/MeliRodriguezB/bankos_project/actions/runs/44715445144): widgets de login/dashboard y ciclo de llave idempotente en transferencias, además de repositorio API para transferencias, depósitos, retiros, paginación/filtros e errores estandarizados. `flutter analyze --no-fatal-infos` terminó correctamente con 37 diagnósticos informativos. |
| APK Android | Completo en CI | `flutter build apk --debug` pasó tras reintentar el job por un HTTP 429 transitorio de Maven Central. Artefacto `bankos-android-debug`, ID `14619328063`, run [44715445144](https://github.com/MeliRodriguezB/bankos_project/actions/runs/44715445144). Validación física pendiente; es build debug, no release firmado. |
| Flutter Web MOCK | Completo como build; despliegue bloqueado | `flutter build web --release --dart-define=BANKOS_DEMO_MODE=true` y la carga del artefacto `bankos-web-mock-demo` pasaron; ID `14619551838`, run [44715445285](https://github.com/MeliRodriguezB/bankos_project/actions/runs/44715445285). El workflow completo terminó en fallo únicamente en `Configure GitHub Pages`. La compilación fuerza MOCK y no se conecta a un backend público. |
| GitHub Pages | Bloqueado | El build web y su artefacto terminaron correctamente, pero `actions/configure-pages` no pudo crear el sitio: `Get Pages site failed: Not Found` y `Create Pages site failed: Resource not accessible by integration`. La conexión disponible tiene `push=true` y `admin=false`; no puede habilitar el sitio. Hace falta que un administrador abra Settings → Pages → Build and deployment y seleccione **GitHub Actions** como source. La URL de Pages no se considera verificada. |
| Backend público | Bloqueado por infraestructura | No hay proveedor de hosting, dominio ni secretos de despliegue configurados. El backend solo se validó localmente en CI mediante Docker Compose. |
| Operación bancaria real | Bloqueado / fuera de alcance | No desplegar ni conectar fondos reales. Faltan proveedor de pagos, tasas fiables, seguridad operativa, cumplimiento, observabilidad y controles de producción. |

## Ejecución local

```bash
cp .env.example .env
docker compose up --build
```

Swagger: `http://localhost:8000/docs`

Seed local de backend: tenant `cooperativa-futuro` o `neobanco-agil`, usuario `carlos@fintech.com`, contraseña `123456`, PIN transaccional `1234`. Son credenciales exclusivamente de desarrollo. Para probar administración, define `BOOTSTRAP_ADMIN_EMAIL` y `BOOTSTRAP_ADMIN_PASSWORD` en el entorno antes de iniciar Compose; no existe un administrador con contraseña predeterminada.

Para ejecutar Flutter contra el backend local, compila con una URL alcanzable desde el dispositivo:

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<HOST-ALCANZABLE>:8000/api/v1
```

El modo MOCK usa datos ficticios y sirve solo para demostrar la interfaz. No representa saldos ni operaciones bancarias reales.
