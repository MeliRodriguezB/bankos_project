

# BankOS — Contrato inicial de API

**Versión:** 0.1.0  
**Estado:** Propuesta inicial para integración  


## 1. Objetivo

Este documento establece las convenciones iniciales de comunicación entre la aplicación móvil BankOS, desarrollada con Flutter, y el backend construido con FastAPI.

Su objetivo es definir una estructura común para los endpoints, las solicitudes, las respuestas, los errores y las responsabilidades de cada componente.

Este contrato deberá actualizarse a medida que se implementen y validen las funcionalidades.

## 2. Convenciones generales

| Elemento | Convención |
|---|---|
| Arquitectura | REST |
| Formato de intercambio | JSON |
| Codificación | UTF-8 |
| Protocolo | HTTPS en producción |
| Prefijo de API | `/api/v1` |
| Autenticación | Bearer Token (JWT) |
| Fechas | ISO 8601 en UTC |
| Valores monetarios | Cadenas decimales para evitar imprecisiones de punto flotante |

### 2.1. URL base

Entorno local:

```text
http://localhost:8080/api/v1
```

Documentación interactiva:

- Swagger UI: `http://localhost:8080/docs`
- ReDoc: `http://localhost:8080/redoc`

**Importante:** cuando Flutter se ejecute en un dispositivo físico, `localhost` hará referencia al propio dispositivo, no al computador donde se ejecuta FastAPI. En ese caso se deberá utilizar la dirección IP local del computador y verificar que el dispositivo pueda acceder a ella.

## 3. Encabezados HTTP

Las solicitudes deberán utilizar los siguientes encabezados según corresponda:

| Encabezado | Uso |
|---|---|
| `Content-Type: application/json` | Indica que el cuerpo de la solicitud está en JSON. |
| `Accept: application/json` | Indica que el cliente espera una respuesta JSON. |
| `Authorization: Bearer <token>` | Envía el token de autenticación para rutas protegidas. |
| `X-Correlation-ID` | Identificador para rastrear una solicitud entre servicios. |
| `Idempotency-Key` | Identificador único para evitar duplicar operaciones financieras. |

El backend deberá generar un identificador de correlación cuando el cliente no lo proporcione.

El contexto de usuario y organización deberá obtenerse del token validado en el servidor. El cliente no debe poder seleccionar libremente el identificador de organización para acceder a información de otra organización.

## 4. Estructura estándar de errores

Las respuestas de error deberán mantener una estructura consistente:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "La solicitud contiene datos inválidos.",
    "details": [
      {
        "field": "amount",
        "message": "Debe ser mayor que cero."
      }
    ],
    "correlation_id": "uuid"
  }
}
```

### 4.1. Códigos HTTP

| Código | Significado | Uso |
|---|---|---|
| 200 | OK | Solicitud procesada correctamente. |
| 201 | Created | Recurso creado correctamente. |
| 204 | No Content | Operación exitosa sin contenido de respuesta. |
| 400 | Bad Request | Solicitud incorrecta. |
| 401 | Unauthorized | Falta autenticación o el token no es válido. |
| 403 | Forbidden | El usuario no tiene permisos suficientes. |
| 404 | Not Found | Recurso inexistente o no accesible. |
| 409 | Conflict | Conflicto de estado o de idempotencia. |
| 422 | Unprocessable Entity | Error de validación de los datos. |
| 429 | Too Many Requests | Se superó el límite de solicitudes. |
| 500 | Internal Server Error | Error inesperado del servidor. |

## 5. Autenticación y usuarios

### 5.1. Inicio de sesión

**Endpoint propuesto:**

```http
POST /api/v1/auth/login
```

Solicitud:

```json
{
  "email": "usuario@ejemplo.com",
  "password": "contraseña"
}
```

Respuesta propuesta:

```json
{
  "access_token": "jwt_access_token",
  "token_type": "bearer",
  "expires_in": 1800,
  "user": {
    "id": "user-id",
    "name": "Nombre del usuario",
    "email": "usuario@ejemplo.com",
    "tenant_id": "tenant-id",
    "roles": [
      "CUSTOMER"
    ]
  }
}
```

Los valores anteriores son ilustrativos. El tiempo de expiración y la estructura definitiva deberán establecerse en la implementación.

### 5.2. Consultar usuario autenticado

**Endpoint propuesto:**

```http
GET /api/v1/auth/me
```

Requiere autenticación.

Permite obtener la información del usuario correspondiente al token enviado.

## 6. Panel principal

### 6.1. Consultar resumen financiero

**Endpoint propuesto:**

```http
GET /api/v1/dashboard
```

Requiere autenticación.

Su finalidad es proporcionar un resumen de la información financiera del usuario autenticado.

La respuesta podrá incluir:

- Saldo total por moneda.
- Cuentas disponibles.
- Movimientos recientes.
- Resumen de operaciones.

Los saldos deben agruparse por moneda. No se deben sumar directamente valores expresados en monedas diferentes.

## 7. Cuentas bancarias

### 7.1. Consultar cuentas

```http
GET /api/v1/accounts
```

Permite consultar las cuentas a las que tiene acceso el usuario autenticado.

### 7.2. Consultar una cuenta específica

```http
GET /api/v1/accounts/{account_id}
```

Respuesta ilustrativa:

```json
{
  "id": "account-id",
  "account_number_masked": "****1234",
  "currency": "COP",
  "balance": "1500000.00",
  "status": "ACTIVE"
}
```

El backend deberá validar que la cuenta pertenezca al usuario y al contexto de organización autorizado.

## 8. Operaciones financieras

Las operaciones financieras deberán procesarse exclusivamente en el backend. Flutter podrá recopilar los datos y mostrar los resultados, pero no será responsable de calcular ni modificar saldos.

Todas las operaciones deberán validar, como mínimo:

- Existencia de las cuentas.
- Propiedad y permisos del usuario.
- Estado de las cuentas.
- Moneda y monto solicitado.
- Saldo disponible cuando corresponda.
- Límites de operación.
- Autorización mediante PIN u otro mecanismo definido.
- Prevención de operaciones duplicadas.

### 8.1. Depósitos

```http
POST /api/v1/transactions/deposits
```

Solicitud ilustrativa:

```json
{
  "account_id": "account-id",
  "amount": "100000.00",
  "currency": "COP",
  "pin": "1234"
}
```

### 8.2. Retiros

```http
POST /api/v1/transactions/withdrawals
```

Solicitud ilustrativa:

```json
{
  "account_id": "account-id",
  "amount": "50000.00",
  "currency": "COP",
  "pin": "1234"
}
```

### 8.3. Transferencias

```http
POST /api/v1/transactions/transfers
```

Solicitud ilustrativa:

```json
{
  "source_account_id": "source-account-id",
  "destination_account_id": "destination-account-id",
  "amount": "75000.00",
  "currency": "COP",
  "pin": "1234"
}
```

Las transferencias deberán ejecutarse como una operación atómica: el débito y el crédito deben confirmarse juntos o revertirse juntos si ocurre un error.

El PIN no debe almacenarse en texto plano ni incluirse en registros de aplicación.

### 8.4. Idempotencia

Las solicitudes que creen operaciones financieras deberán incluir:

```http
Idempotency-Key: identificador-unico
```

El backend deberá garantizar que una misma clave no produzca varias operaciones financieras.

- Misma clave y mismo contenido: devolver el resultado original.
- Misma clave y contenido diferente: responder con `409 Conflict`.

El mecanismo deberá persistir de manera segura para evitar duplicaciones incluso ante reintentos o interrupciones.

## 9. Historial de transacciones

**Endpoint propuesto:**

```http
GET /api/v1/transactions
```

Parámetros de consulta previstos:

| Parámetro | Descripción |
|---|---|
| `account_id` | Filtrar por cuenta. |
| `type` | Filtrar por tipo de operación. |
| `from` | Fecha inicial. |
| `to` | Fecha final. |
| `page` | Número de página. |
| `page_size` | Cantidad de resultados por página. |

Respuesta ilustrativa:

```json
{
  "items": [
    {
      "id": "transaction-id",
      "type": "TRANSFER",
      "amount": "75000.00",
      "currency": "COP",
      "status": "COMPLETED",
      "created_at": "2026-11-19T10:00:00Z"
    }
  ],
  "page": 1,
  "page_size": 20,
  "total": 1
}
```

Los filtros y la paginación deberán validarse en el backend.

## 10. Comisiones y conversión de moneda

Las comisiones y conversiones deberán calcularse en el backend, nunca confiar en valores calculados o enviados por el cliente.

Se deberán definir antes de implementar estas funcionalidades:

- Monedas permitidas.
- Precisión decimal por moneda.
- Reglas de redondeo.
- Fuente y vigencia de las tasas de cambio.
- Momento en que se fija la tasa de cambio.
- Reglas y valores de las comisiones.

Cualquier tasa estática utilizada durante pruebas deberá identificarse como un valor de demostración, no como una tasa financiera real.

## 11. Seguridad y auditoría

El backend deberá contemplar:

- Validación de JWT en rutas protegidas.
- Control de acceso basado en roles y permisos.
- Aislamiento de datos entre organizaciones (tenant).
- Validación de propiedad de las cuentas.
- Protección de credenciales y secretos mediante variables de entorno.
- Registro de auditoría de operaciones relevantes.
- Limitación de solicitudes para reducir abusos.
- Manejo seguro de errores sin exponer información interna.

Si se incorporan webhooks, deberán contar con un mecanismo de autenticación, validación de origen y política de reintentos.

## 12. Responsabilidades por componente

| Componente | Responsabilidades |
|---|---|
| Flutter | Interfaz, navegación, formularios, validaciones de experiencia de usuario y consumo de la API. |
| FastAPI | Endpoints, autenticación, autorización, reglas financieras y validaciones de negocio. |
| PostgreSQL | Persistencia de usuarios, cuentas, transacciones y registros relacionados. |
| Redis | Soporte para idempotencia, caché o limitación de solicitudes, según el diseño definitivo. |

La interfaz puede validar campos para mejorar la experiencia, pero el backend siempre deberá repetir las validaciones necesarias para garantizar la integridad y seguridad.

## 13. Acuerdos pendientes

Antes de considerar este contrato definitivo, se deben acordar los siguientes puntos:

1. Tipo de identificadores para usuarios, cuentas y transacciones (UUID o enteros).
2. Modelo de usuarios, roles y organizaciones.
3. Tipos y estados permitidos para las transacciones.
4. Política de autenticación, expiración y renovación de tokens.
5. Mecanismo de autorización de operaciones (PIN u otro).
6. Monedas, precisión decimal y reglas de redondeo.
7. Límites de operaciones y comisiones.
8. Formato definitivo de paginación y filtros.
9. Estrategia de almacenamiento y expiración de claves de idempotencia.

## 14. Control de cambios

| Versión | Descripción |
|---|---|
| 0.1.0 | Creación de la propuesta inicial del contrato de API. |

---



