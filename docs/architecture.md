# BankOS — Arquitectura técnica

**Versión:** 1.0  
**Estado:** Propuesta técnica de referencia  
**Stack:** Flutter · FastAPI · PostgreSQL · Redis · Docker

## 1. Objetivo
BankOS es un prototipo bancario digital multi-tenant (BaaS). La arquitectura separa cliente, lógica de negocio y persistencia para facilitar mantenimiento, pruebas y trabajo paralelo.

Este documento describe la arquitectura objetivo; no implica que todas las capas o controles estén implementados actualmente.

## 2. Decisiones principales

| Área | Decisión | Justificación |
|---|---|---|
| Arquitectura | Monolito modular | Menor complejidad de despliegue para el alcance académico. |
| Cliente | Flutter, organización feature-first | Reutilización de código entre plataformas. |
| API | FastAPI REST bajo /api/v1 | Contrato explícito y OpenAPI automático. |
| Persistencia | PostgreSQL | Integridad relacional y transacciones ACID. |
| ORM | SQLAlchemy | Modelado y acceso a datos. |
| Validación | Pydantic | Validación de solicitudes y respuestas. |
| Caché/idempotencia | Redis | Apoyo a operaciones temporales y reintentos. |
| Entorno | Docker Compose | Entorno reproducible. |
| Seguridad | JWT y Argon2id | Autenticación y hash de contraseñas. |

## 3. Vista de contexto

~~~mermaid
flowchart LR
    U[Usuario] --> F[Flutter Client]
    F -->|HTTPS / JSON / JWT| A[FastAPI REST API]
    A --> S[Servicios de dominio]
    S --> R[Acceso a datos / SQLAlchemy]
    R --> P[(PostgreSQL)]
    A --> C[(Redis)]
~~~

## 4. Backend: responsabilidades
- **Router:** recibe HTTP, aplica dependencias y define respuestas/status codes.
- **Schemas:** valida y serializa contratos.
- **Service:** aplica reglas de negocio sin depender de HTTP.
- **Repository / acceso a datos:** encapsula consultas y persistencia.
- **Models:** entidades ORM y relaciones.

Estructura de referencia (adaptable a lo existente):

~~~text
backend/app/
├── core/                 # Configuración, seguridad, dependencias
├── db/                   # Engine, sesiones, Base
├── modules/
│   ├── auth/
│   ├── tenants/
│   ├── users/
│   ├── roles/
│   ├── accounts/
│   └── transactions/
└── main.py               # App, middleware y routers
~~~

No crear capas adicionales por formalidad: mantener la estructura actual y refactorizar cuando aporte valor.

## 5. Frontend Flutter
Organización feature-first:

~~~text
lib/
├── core/
│   ├── network/           # ApiClient, errores e interceptores
│   ├── theme/
│   ├── utils/
│   └── widgets/
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── accounts/
│   └── transactions/
├── app.dart
└── main.dart
~~~

Separación gradual dentro de features:
- presentation: screens, widgets y estado.
- domain: entidades/reglas cuando la complejidad lo requiera.
- data: DTOs, fuentes de datos y repositorios concretos.

La UI no debe implementar reglas financieras ni acceder directamente a SQL.

## 6. Flujo de una transferencia
1. Flutter valida formato y campos.
2. Solicita cotización al backend.
3. Backend valida cuentas, tenant, monedas, saldo y tarifa.
4. Flutter muestra desglose y solicita PIN.
5. Flutter envía la operación con JWT e Idempotency-Key.
6. Backend revalida y ejecuta débito/crédito dentro de una transacción.
7. Si todo es correcto, confirma; si falla, revierte.
8. Flutter refresca dashboard e historial y muestra resultado.

## 7. Seguridad y multi-tenancy
- Derivar tenant activo de identidad/membresía validada en backend; nunca confiar en tenant_id del cliente para autorizar.
- Filtrar y validar todas las consultas por tenant.
- Validar firma y expiración de JWT.
- Almacenar hashes de contraseñas, nunca contraseñas en texto plano.
- Validar PIN en backend y evitar registrarlo en logs.
- En operaciones financieras validar saldo, estado, permisos, moneda y límites.
- Mantener datos demo separados de credenciales reales.
- Configurar CORS por ambiente; no usar wildcard en producción.
- No versionar secretos ni archivos .env.

## 8. Ambientes

| Ambiente | Uso |
|---|---|
| Local | Desarrollo con Docker Compose y datos demo. |
| CI | Análisis, pruebas y builds automatizados sin secretos reales. |
| Staging (futuro) | Integración previa a entrega con datos sintéticos. |
| Producción (fuera de alcance) | Servicio real con HTTPS, secretos administrados, monitoreo y controles reforzados. |

## 9. Antes de producción
BankOS es un prototipo académico, no una plataforma autorizada para fondos reales. Se requeriría revisión de seguridad, CORS restrictivo, gestión de secretos, auditoría, antifraude, límites, backups, monitoreo, pruebas de concurrencia y cumplimiento regulatorio.
