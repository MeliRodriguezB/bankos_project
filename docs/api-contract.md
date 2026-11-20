# BankOS — Contrato de API

**Versión:** 1.0.0  
**Estado:** Contrato de referencia para backend (FastAPI) y cliente móvil/web (Flutter); la validación de los cambios recientes requiere pruebas locales.

---

## 1. Objetivo y Alcance

Este documento especifica el contrato de comunicación oficial entre la aplicación cliente BankOS (desarrollada en Flutter) y el servidor backend (FastAPI + PostgreSQL + Redis).

Define con precisión:
- Convenciones de transporte y serialización de datos.
- Mecanismo de autenticación multi-inquilino (*multi-tenant*) con JWT y Argon2.
- Endpoints de consulta de saldos y cuentas bancarias multimoneda.
- Endpoints para cotización y ejecución de transacciones atómicas (transferencias, depósitos, retiros).
- Contrato estricto de **Idempotencia** (`Idempotency-Key`) para prevenir débitos duplicados.
- Tabla de tasas de cambio estáticas y comisiones bancarias.

---

## 2. Convenciones Generales

| Elemento | Convención | Detalle |
|---|---|---|
| Arquitectura | RESTful | Métodos HTTP estándar (`GET`, `POST`, `PATCH`, etc.). |
| Formato de intercambio | JSON | `Content-Type: application/json`. Codificación UTF-8. |
| Prefijo de API | `/api/v1` | Todas las rutas funcionales están versionadas bajo `/api/v1`. |
| Autenticación | Bearer Token (JWT) | Firma criptográfica con claims: `sub`, `tenant_id`, `membership_id`, `role`. |
| Fechas | ISO 8601 UTC | Ejemplo: `2026-11-19T14:30:00Z`. |
| Valores monetarios | Decimal en String | **Regla financiera crítica:** Todos los importes monetarios viajan como strings numéricos con 2 decimales (ej: `"1500000.00"`). Nunca se usan flotantes IEEE 754. En PostgreSQL se almacenan como `Numeric(18, 2)`. |

### 2.1. Direcciones Base (Entorno Local)

- **API Base:** `http://localhost:8000/api/v1`
- **Documentación Interactiva (Swagger UI):** `http://localhost:8000/docs`
- **Documentación Alternativa (ReDoc):** `http://localhost:8000/redoc`
- **Health Check:** `http://localhost:8000/health`

---

## 3. Encabezados HTTP (Headers)

| Encabezado | Requerido en | Descripción |
|---|---|---|
| `Content-Type: application/json` | En todos los `POST` y `PATCH` | Especifica que el cuerpo de la solicitud es JSON. |
| `Accept: application/json` | Todas las solicitudes | Indica que el cliente espera una respuesta JSON. |
| `Authorization: Bearer <token>` | Rutas protegidas | Envía el token JWT obtenido en el login. El servidor extrae el `tenant_id` y `user_id` de los claims. |
| `X-Correlation-ID` | Opcional (Recomendado) | Identificador UUID para trazabilidad distribuida entre cliente y microservicios. Si no se envía, el backend genera uno automáticamente. |
| `Idempotency-Key` | Obligatorio en operaciones financieras | UUID único por intento de operación. Evita dobles débitos en caídas de red o reintentos de usuario. |

---

## 4. Estructura Estándar de Errores

El backend responde con la estructura estándar de FastAPI y detalles claros para el cliente:

```json
{
  "detail": "Descripción legible del error o motivo del rechazo."
}
```

### Códigos de Respuesta HTTP Utilizados

| Código | Nombre | Escenario |
|---|---|---|
| `200 OK` | Solicitud exitosa | Consultas (`GET`) y logins exitosos. |
| `201 Created` | Recurso creado | Transferencias, depósitos, retiros y apertura de cuentas. |
| `400 Bad Request` | Error de negocio | Saldo insuficiente, cuenta inactiva o divisa incompatible. |
| `401 Unauthorized` | No autenticado | Token ausente, vencido o PIN de 2FA inválido. |
| `403 Forbidden` | Prohibido | Intento de acceder a cuentas de otro tenant o usuario. |
| `404 Not Found` | No encontrado | Cuenta, transacción o usuario inexistente. |
| `409 Conflict` | Conflicto de Idempotencia | Reutilización de una `Idempotency-Key` con un payload diferente. |
| `422 Unprocessable Entity` | Error de validación | Formato JSON incorrecto o datos faltantes. |
| `500 Internal Server Error` | Error de servidor | Fallo inesperado con rollback de transacción asegurado. |

---

## 5. Módulo de Autenticación (`/auth`)

### 5.1. Iniciar Sesión Multitenant

Valida las credenciales contra el tenant correspondiente utilizando hash de contraseñas seguro con **Argon2id**.

- **Método:** `POST`
- **Ruta:** `/api/v1/auth/login`
- **Autenticación:** Pública

#### Solicitud (`application/json`)
```json
{
  "tenant_slug": "bancolombia",
  "email": "carlos@fintech.com",
  "password": "contraseña_segura"
}
```

#### Respuesta Exitosa (`200 OK`)
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": "usr-001",
    "name": "Carlos Rodríguez",
    "email": "carlos@fintech.com",
    "tenant_id": "tenant-coop-001",
    "membership_id": "MEM-2024-001",
    "roles": ["CUSTOMER"]
  }
}
```

### 5.2. Consultar Usuario Autenticado

Obtiene los datos del perfil activo directamente decodificados desde el JWT.

- **Método:** `GET`
- **Ruta:** `/api/v1/auth/me`
- **Autenticación:** `Bearer <JWT>`

#### Respuesta Exitosa (`200 OK`)
```json
{
  "user": {
    "id": "usr-001",
    "name": "Carlos Rodríguez",
    "email": "carlos@fintech.com",
    "tenant_id": "tenant-coop-001",
    "membership_id": "MEM-2024-001",
    "roles": ["CUSTOMER"]
  }
}
```

---

### 5.3. Verificar Administrador Global

Verifica el privilegio de administración global directamente contra la base de datos. Un rol `ADMIN` de una institución no equivale a `PlatformAdmin`.

- **Método:** `GET`
- **Ruta:** `/api/v1/users/me/platform-admin`
- **Autenticación:** `Bearer <JWT>`

#### Respuesta
```json
{ "is_platform_admin": true }
```

### 5.4. Consultar Branding del Tenant

Devuelve la identidad visual del tenant asociado al token actual. El endpoint no acepta IDs de otros bancos, evitando consultas cruzadas.

- **Método:** `GET`
- **Ruta:** `/api/v1/users/me/bank-branding`
- **Autenticación:** `Bearer <JWT>`

#### Respuesta
```json
{
  "tenant_name": "Bancolombia",
  "primary_color": "#FFD600",
  "secondary_color": "#FFFFFF",
  "accent_color": "#F2B900"
}
```

### 5.5. Tenants de Demostración

| Institución | `tenant_slug` |
|---|---|
| Bancolombia | `bancolombia` |
| Banco Popular | `banco-popular` |
| Nequi | `nequi` |
| Nu | `nu` |

---
## 6. Módulo de Cuentas y Dashboard (`/accounts`, `/dashboard`)

### 6.1. Consultar Resumen Financiero (Dashboard)

Agrupa y desglosa los saldos por cada moneda de forma aislada para evitar mezclar divisas (ej. pesos colombianos y dólares).

- **Método:** `GET`
- **Ruta:** `/api/v1/dashboard`
- **Autenticación:** `Bearer <JWT>`

#### Respuesta Exitosa (`200 OK`)
```json
{
  "user_name": "Carlos Rodríguez",
  "user_email": "carlos@fintech.com",
  "tenant_id": "tenant-coop-001",
  "balances_by_currency": {
    "COP": "4700000.00",
    "USD": "1250.00"
  },
  "accounts_count": 4,
  "accounts": [
    {
      "id": "acc-001",
      "account_number": "CU-1002003001",
      "account_number_masked": "•••• 3001",
      "alias": "Cuenta Corriente Principal",
      "balance": "3200000.00",
      "currency": "COP",
      "status": "ACTIVE",
      "created_at": "2026-11-19T10:00:00Z"
    },
    {
      "id": "acc-002",
      "account_number": "AH-2003004002",
      "account_number_masked": "•••• 4002",
      "alias": "Fondo de Emergencia",
      "balance": "1500000.00",
      "currency": "COP",
      "status": "ACTIVE",
      "created_at": "2026-11-19T10:00:00Z"
    },
    {
      "id": "acc-003",
      "account_number": "US-3004005003",
      "account_number_masked": "•••• 5003",
      "alias": "Ahorros Dólares",
      "balance": "1250.00",
      "currency": "USD",
      "status": "ACTIVE",
      "created_at": "2026-11-19T10:00:00Z"
    }
  ]
}
```

### 6.2. Listar Cuentas del Usuario

- **Método:** `GET`
- **Ruta:** `/api/v1/accounts`
- **Autenticación:** `Bearer <JWT>`

Devuelve un arreglo `AccountResponse[]` con todas las cuentas asociadas al usuario autenticado.

### 6.3. Detalle de una Cuenta Específica

- **Método:** `GET`
- **Ruta:** `/api/v1/accounts/{account_id}`
- **Autenticación:** `Bearer <JWT>`

#### Respuesta Exitosa (`200 OK`)
```json
{
  "id": "acc-001",
  "account_number": "CU-1002003001",
  "account_number_masked": "•••• 3001",
  "alias": "Cuenta Corriente Principal",
  "balance": "3200000.00",
  "currency": "COP",
  "status": "ACTIVE",
  "created_at": "2026-11-19T10:00:00Z",
  "updated_at": "2026-11-19T14:00:00Z",
  "tenant_id": "tenant-coop-001",
  "user_id": "usr-001"
}
```

### 6.4. Desactivar Cuenta (Borrado Lógico / Soft Delete)

Cambia el estado de la cuenta a `INACTIVE` para revocar futuras transacciones sin eliminar el historial contable de la base de datos.

- **Método:** `PATCH`
- **Ruta:** `/api/v1/accounts/{account_id}/deactivate`
- **Autenticación:** `Bearer <JWT>`

#### Respuesta Exitosa (`200 OK`)
Devuelve el objeto de la cuenta con `"status": "INACTIVE"`.

---

## 7. Módulo de Transacciones Financieras (`/transactions`)

### 7.1. Pre-Cotización de Transferencia (Quote Breakdown)

Permite al cliente calcular y presentar al usuario la comisión y la conversión cambiaria **antes** de solicitar el PIN de confirmación.

- **Método:** `POST`
- **Ruta:** `/api/v1/transactions/quote`
- **Autenticación:** `Bearer <JWT>`

#### Solicitud (`application/json`)
```json
{
  "source_account_id": "acc-001",
  "destination_account_number": "CU-1002003002",
  "amount": "50000.00"
}
```

#### Respuesta Exitosa (`200 OK`)
```json
{
  "source_currency": "COP",
  "destination_currency": "COP",
  "amount_debited": "51500.00",
  "amount_credited": "50000.00",
  "fee_applied": "1500.00",
  "exchange_rate": "1.000000",
  "requires_conversion": false
}
```

### 7.2. Ejecutar Transferencia Atómica con Idempotencia y PIN

Ejecuta el débito y crédito atómico en una única transacción de base de datos (`ACID`). Valida el segundo factor (PIN de 4 dígitos) y respeta la clave de idempotencia.

- **Método:** `POST`
- **Ruta:** `/api/v1/transactions/transfers`
- **Autenticación:** `Bearer <JWT>`
- **Headers Obligatorios:** `Idempotency-Key: <UUID>`

#### Solicitud (`application/json`)
```json
{
  "source_account_id": "acc-001",
  "destination_account_number": "CU-1002003002",
  "amount": "50000.00",
  "pin": "1234",
  "description": "Pago mensual de arriendo"
}
```

#### Respuesta Exitosa (`201 Created`)
```json
{
  "id": "tx-e946a382-7485-48b0-a54e-984447472019",
  "type": "TRANSFER",
  "amount": "50000.00",
  "fee": "1500.00",
  "total_debited": "51500.00",
  "currency": "COP",
  "source_account_id": "acc-001",
  "destination_account_id": "acc-002",
  "status": "COMPLETED",
  "exchange_rate": "1.000000",
  "description": "Pago mensual de arriendo",
  "correlation_id": "corr-uuid-001",
  "created_at": "2026-11-19T14:15:00Z"
}
```

### 7.3. Abonar Fondos (Depósito)

- **Método:** `POST`
- **Ruta:** `/api/v1/transactions/deposits`
- **Autenticación:** `Bearer <JWT>`
- **Headers Obligatorios:** `Idempotency-Key: <UUID>`

#### Solicitud
```json
{
  "account_id": "acc-001",
  "amount": "100000.00",
  "description": "Depósito en sucursal"
}
```

### 7.4. Retirar Fondos con PIN

- **Método:** `POST`
- **Ruta:** `/api/v1/transactions/withdrawals`
- **Autenticación:** `Bearer <JWT>`
- **Headers Obligatorios:** `Idempotency-Key: <UUID>`

#### Solicitud
```json
{
  "account_id": "acc-001",
  "amount": "30000.00",
  "pin": "1234",
  "description": "Retiro en cajero automático"
}
```

### 7.5. Consultar Historial Paginado de Transacciones

- **Método:** `GET`
- **Ruta:** `/api/v1/transactions`
- **Autenticación:** `Bearer <JWT>`

#### Parámetros de Consulta (Query Params)

| Parámetro | Tipo | Descripción |
|---|---|---|
| `account_id` | `string` | Filtrar por cuenta específica (Opcional). |
| `type` | `string` | Filtrar por tipo: `TRANSFER`, `DEPOSIT`, `WITHDRAWAL` (Opcional). |
| `limit` | `int` | Cantidad de elementos por página (Por defecto: 20, Máx: 100). |
| `offset` | `int` | Desplazamiento para paginación (Por defecto: 0). |

#### Respuesta Exitosa (`200 OK`)
```json
{
  "items": [
    {
      "id": "tx-001",
      "type": "TRANSFER",
      "amount": "50000.00",
      "fee": "1500.00",
      "total_debited": "51500.00",
      "currency": "COP",
      "source_account_id": "acc-001",
      "destination_account_id": "acc-002",
      "status": "COMPLETED",
      "exchange_rate": "1.000000",
      "description": "Transferencia entre cuentas",
      "correlation_id": "corr-seed-001",
      "created_at": "2026-11-19T11:00:00Z"
    }
  ],
  "total": 1,
  "limit": 20,
  "offset": 0
}
```

---

## 8. Contrato de Idempotencia

Para proteger contra duplicaciones por fallas de red o múltiples clics del usuario:

1. **Ámbito de la clave:** El backend asocia la clave con la tupla `(tenant_id, user_id, idempotency_key)`.
2. **Reintento Idéntico (Replay):** Si el servidor recibe una clave ya procesada con el mismo payload exacto, responde con el mismo código HTTP (200/201) y el resultado original en caché, **sin alterar nuevamente los balances ni generar una segunda transacción contable**.
3. **Colisión de Parámetros (Collision):** Si el servidor detecta la misma clave con un cuerpo o monto distinto, rechaza inmediatamente con `409 Conflict`.

---

## 9. Tasas de Cambio y Tarifas Estáticas

El cálculo de comisiones y conversiones se efectúa exclusivamente en el backend bajo la siguiente tabla estática:

### 9.1. Tasas de Cambio

| Moneda Origen | Moneda Destino | Tasa Multiplicadora | Equivalencia |
|---|---|---|---|
| `COP` | `USD` | `0.00025` | 1 USD = 4,000 COP |
| `USD` | `COP` | `4000.00` | 1 USD = 4,000 COP |
| `EUR` | `COP` | `4350.00` | 1 EUR = 4,350 COP |
| `COP` | `EUR` | `0.00023` | - |
| `USD` | `EUR` | `0.92` | - |
| `EUR` | `USD` | `1.09` | - |

### 9.2. Tarifas Bancarias Fijas por Transacción

| Moneda de la Cuenta Origen | Comisión Fija Aplicada |
|---|---|
| `COP` | `$1,500.00 COP` |
| `USD` | `$1.00 USD` |
| `EUR` | `€1.00 EUR` |

---

## 10. Control de Versiones

| Versión | Fecha | Autor / Equipo | Descripción de Cambios |
|---|---|---|---|
| `0.1.0` | 2026-11-19 | Persona 1 & 2 | Propuesta inicial del contrato de API y rutas previstas. |
| `0.2.0` | 2026-11-19 | Persona 1 | Incorporación de `tenant_slug` al login y claims de membresía. |
| `1.0.0` | 2026-11-19 | Integración Unificada | **Versión definitiva implementada.** Se documentan todas las rutas activas de FastAPI (`/auth`, `/dashboard`, `/accounts`, `/transactions`), el esquema de cotización previa (`/quote`), validación de PIN 2FA, idempotencia con Redis/DB y contratos reales de respuesta validados con pruebas en Flutter y Backend. |
