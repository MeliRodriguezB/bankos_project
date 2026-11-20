# BankOS — Plataforma Bancaria Digital Multi-Tenant (BaaS)

BankOS es una plataforma moderna de **Banking-as-a-Service (BaaS)** con arquitectura cliente-servidor, diseñada para soportar múltiples instituciones financieras (cooperativas, neobancos y fintechs) de forma aislada, segura y escalable.

El cliente móvil y web está construido con **Flutter**, y el backend de alta concurrencia expone una API REST construida con **FastAPI**, persistencia en **PostgreSQL 16** y soporte de caché/idempotencia en **Redis 7**.

---

## 🚧 Estado del Proyecto: Prototipo funcional en validación

BankOS está preparado como prototipo demostrativo. No debe utilizarse para custodiar dinero real ni conectarse a cuentas bancarias reales. La validación automatizada y la preparación del despliegue continúan en la rama `fix/withdrawal-screen-ci`.

El proyecto cuenta con la integración de las 3 Personas de desarrollo:
1. **Persona 1 (Autenticación e Inquilinos):**
   - Identificación de tenant por `tenant_slug`.
   - Hashing criptográfico de contraseñas con **Argon2id** (`pwdlib`).
   - Generación de sesiones JWT con claims de seguridad (`sub`, `tenant_id`, `membership_id`, `role`).
   - Pantalla de login en Flutter con selector de institución, persistencia y banner de errores.
2. **Persona 2 (Dashboard y Cuentas Bancarias):**
   - Resumen multimoneda con saldos agrupados (`COP`, `USD`) sin sumas cruzadas inválidas.
   - Listado y detalle de cuentas con enmascaramiento seguro de número (`•••• 3001`).
   - Manejo completo de estados de interfaz: carga (*shimmer*), error con reintento y estado vacío.
   - Desactivación lógica de cuentas (*soft delete* / `INACTIVE`).
3. **Persona 3 (Transacciones Financieras e Historial):**
   - Transferencias atómicas ACID con reversión total (*rollback*) ante excepciones.
   - Pre-cotización de transferencias (*Quote breakdown*) con desglose previo de costos y comisiones.
   - Autorización mediante segundo factor (PIN de 4 dígitos).
   - Mecanismo de **Idempotencia** con encabezado `Idempotency-Key` para evitar cargos duplicados.
   - Conversión de divisas con tabla de tasas estáticas y comisión bancaria parametrizada.
   - Historial paginado con etiquetas visuales de costo y conversión.

---

## 🛠️ Tecnologías y Stack

- **Frontend:** Flutter 3.24+ (Dart 3.5+), Material 3, soporte Web y Desktop.
- **Backend:** Python 3.12, FastAPI, SQLAlchemy 2.0, Pydantic v2.
- **Seguridad:** Argon2id, PyJWT.
- **Base de Datos:** PostgreSQL 16 Alpine (`Numeric(18, 2)` para precisión monetaria exacta).
- **Caché y Mensajería:** Redis 7 Alpine.
- **Contenedores:** Docker y Docker Compose.

---

## 📁 Estructura del Repositorio

```text
bankos_project/
├── backend/
│   ├── app/
│   │   ├── core/               # Seguridad (Argon2, JWT), Configuración y Dependencias
│   │   ├── db/                 # Sesión de SQLAlchemy y Base declarativa
│   │   ├── modules/
│   │   │   ├── accounts/       # Modelos, esquemas, router y servicio de cuentas
│   │   │   ├── auth/           # Login, JWT claims y autenticación
│   │   │   └── transactions/   # Transferencias atómicas, idempotencia, cotización
│   │   └── main.py             # App FastAPI, CORS, eventos de ciclo de vida y Seed Data
│   ├── Dockerfile
│   └── requirements.txt
├── infrastructure/
│   └── docker-compose.yml      # Definición de servicios (api, db, redis)
├── lib/                        # Cliente Flutter
│   ├── core/                   # Tema (Material 3), formateo monetario y ApiClient
│   ├── features/
│   │   ├── auth/               # Pantalla de login y repositorio de autenticación
│   │   ├── dashboard/          # Dashboard, cuentas, widgets de saldo y tarjetas
│   │   └── transactions/       # Transferencias, diálogo de PIN, cotización e historial
│   ├── app.dart                # Configuración de MaterialApp y tema
│   └── main.dart               # Punto de entrada de la aplicación
├── test/                       # Pruebas unitarias y de widgets en Flutter
└── docs/
    └── api-contract.md         # Contrato exhaustivo de la API REST (v1.0.0)
```

---

## ⚙️ Requisitos Previos

- **Docker Desktop** (con soporte WSL 2 si estás en Windows).
- **Flutter SDK** (versión 3.24 o superior).
- **Navegador Google Chrome** (para ejecutar la versión web de Flutter).
- **Git**.

---

## 🏃‍♂️ Guía Rápida de Ejecución

### 1. Iniciar el Backend (FastAPI + PostgreSQL + Redis)

Desde la raíz del proyecto en una terminal (PowerShell o Bash):

```bash
docker compose -f infrastructure/docker-compose.yml up --build -d
```

Verifica que los tres contenedores estén saludables:

```bash
docker compose -f infrastructure/docker-compose.yml ps
```

Deberás ver los servicios `bankos_api`, `bankos_db` y `bankos_redis` en estado `running (healthy)`.

#### Enlaces Locales del Backend
- **Documentación Interactiva (Swagger UI):** [http://localhost:8000/docs](http://localhost:8000/docs)
- **Documentación ReDoc:** [http://localhost:8000/redoc](http://localhost:8000/redoc)
- **Verificación de Salud:** [http://localhost:8000/health](http://localhost:8000/health)

---

### 2. Iniciar el Cliente Frontend (Flutter)

En otra terminal, en la raíz del repositorio:

```bash
# Obtener dependencias
flutter pub get

# Ejecutar en Google Chrome
flutter run -d chrome
```

*(Si prefieres probar en Windows nativo: `flutter run -d windows`)*.

> **💡 Switch MOCK / API en la AppBar:**  
> La barra superior de la aplicación incluye un selector interactivo `MOCK / API`. Puedes usarlo en cualquier momento para alternar entre el backend real FastAPI en Docker y datos simulados locales para evaluación sin conexión.

---

## 🔐 Datos de demostración (solo desarrollo)

Al iniciar el backend con `ENVIRONMENT=development`, el proceso de seed crea un usuario y cuentas de prueba para la institución `cooperativa-futuro`:

- **Institución:** Cooperativa Financiera Futuro (`cooperativa-futuro`)
- **Correo:** `carlos@fintech.com`
- **Contraseña de demostración:** `123456`
- **Cuentas COP:** `1002348911` y `1002348922`
- **Cuenta USD:** `2005541100`

El PIN transaccional no se precarga: debe configurarse desde el flujo de seguridad de la aplicación. Los datos y credenciales anteriores son exclusivamente locales/de demostración; no deben habilitarse en un entorno público.

La segunda institución contiene una cuenta de prueba aislada, pero no se crea automáticamente un usuario final para ella. No utilizar los datos de seed como cuentas reales.

---

## 🧪 Ejecución de Pruebas Automatizadas

### Pruebas del Cliente (Flutter)
Para ejecutar la suite de 18 pruebas unitarias y de widgets (formateo de moneda, cálculo de cotización, enmascaramiento de cuentas, renderizado de tarjetas y flujos de login):

```bash
flutter test
```
El resultado vigente debe consultarse en la ejecución de GitHub Actions correspondiente al último commit; no se asume que un resultado histórico siga siendo válido.

---

## ⚠️ Límites del prototipo y despliegue

- Los depósitos son simulados y solo están habilitados fuera de producción. En producción, la configuración falla si `SIMULATED_DEPOSITS_ENABLED=true`; deben integrarse primero con un proveedor de pagos o un proceso de conciliación.
- Las tasas de cambio configuradas son de demostración. Las conversiones entre monedas se rechazan en producción hasta integrar un proveedor de tasas fiable.
- El backend de esta rama usa `create_all` al iniciar y la migración existente no constituye todavía una migración inicial completa. Antes de producción debe completarse el esquema de Alembic y ejecutar migraciones controladas.
- La infraestructura Docker Compose incluida utiliza credenciales locales de desarrollo. No exponer PostgreSQL ni Redis públicamente ni reutilizar esas contraseñas en un servidor.
- El despliegue público requiere HTTPS, secretos fuertes, CORS restringido, almacenamiento seguro de secretos, copias de seguridad y monitorización.

Para compilar Flutter contra una API desplegada, define la URL durante la compilación:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://tu-dominio.example/api/v1
```

## 🛡️ Principios Arquitectónicos y de Seguridad

1. **Aislamiento Multi-inquilino en Base de Datos:**  
   Todas las consultas a cuentas y transacciones filtran forzosamente por el `tenant_id` obtenido del JWT firmado. El cliente nunca puede forzar el inquilino en la consulta.
2. **Precisión Financiera Numérica:**  
   No se utiliza punto flotante binario (`float`) en importes contables. Se utiliza `Numeric(18, 2)` en PostgreSQL y cadenas decimales en JSON para evitar pérdidas de centavos por redondeo.
3. **Atomicidad y Consistencia (ACID):**  
   Las transferencias ejecutan el débito en la cuenta de origen y el crédito en la de destino dentro de la misma transacción relacional. Si cualquier validación o paso falla, se ejecuta un rollback completo.
4. **Idempotencia Transaccional:**  
   Toda transferencia requiere un encabezado `Idempotency-Key`. Ante reintentos con la misma clave y parámetros idénticos, se retorna el comprobante previo sin duplicar el movimiento financiero.

---

## 📖 Documentación Adicional

Para más detalles sobre los contratos de datos, códigos HTTP y payloads exactos, consulta el archivo:
- [Contrato de API REST v1.0.0](docs/api-contract.md)
