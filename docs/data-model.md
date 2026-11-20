# BankOS — Modelo de datos

**Versión:** 1.0 · **Motor:** PostgreSQL  
**Base:** esquema SQL del repositorio

## 1. Objetivo
Definir entidades principales para identidad, aislamiento institucional, cuentas y operaciones financieras.

## 2. Entidades

| Entidad | Propósito |
|---|---|
| currencies | Catálogo de monedas COP, USD y EUR. |
| tenants | Instituciones que usan BankOS. |
| users | Identidades globales. |
| platform_admins | Administradores globales. |
| tenant_memberships | Relación usuario-institución y estado. |
| roles | Roles definidos por institución. |
| permissions | Catálogo de acciones permitidas. |
| role_permissions | Asociación permisos-roles. |
| membership_roles | Roles asignados a membresías. |
| customers | Cliente bancario de una institución; acceso digital opcional. |
| accounts | Cuentas de clientes y moneda. |
| transactions | Operaciones de negocio. |
| transaction_entries | Débitos/créditos de una operación. |
| audit_logs | Registro de acciones relevantes. |

## 3. Diagrama ER simplificado

~~~mermaid
erDiagram
    USERS ||--o{ TENANT_MEMBERSHIPS : belongs_to
    TENANTS ||--o{ TENANT_MEMBERSHIPS : has
    TENANTS ||--o{ ROLES : defines
    TENANT_MEMBERSHIPS ||--o{ MEMBERSHIP_ROLES : assigned
    ROLES ||--o{ MEMBERSHIP_ROLES : grants
    ROLES ||--o{ ROLE_PERMISSIONS : includes
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : mapped
    TENANTS ||--o{ CUSTOMERS : owns
    USERS o|--o{ CUSTOMERS : digital_access
    CUSTOMERS ||--o{ ACCOUNTS : owns
    CURRENCIES ||--o{ ACCOUNTS : denominates
    TENANTS ||--o{ TRANSACTIONS : records
    TENANT_MEMBERSHIPS o|--o{ TRANSACTIONS : initiated
    TRANSACTIONS ||--o{ TRANSACTION_ENTRIES : contains
    ACCOUNTS ||--o{ TRANSACTION_ENTRIES : posts
    TENANTS ||--o{ AUDIT_LOGS : records
    USERS o|--o{ AUDIT_LOGS : acts
~~~

## 4. Relaciones y reglas
- Un usuario puede pertenecer a varias instituciones mediante tenant_memberships.
- Cada institución administra sus roles; los códigos son únicos por tenant.
- Una membresía puede tener varios roles y un rol varias membresías.
- Un cliente pertenece a un tenant y puede asociarse opcionalmente a un usuario.
- Las cuentas pertenecen a un cliente y usan una moneda definida.
- Las transacciones pertenecen a un tenant y pueden asociarse a la membresía que las inicia.
- Una transacción se compone de asientos; cada asiento identifica cuenta, dirección, monto y moneda.
- Las relaciones compuestas tenant/id deben impedir asociaciones entre instituciones.
- Idempotencia evita duplicar operaciones en reintentos.
- La auditoría nunca debe guardar contraseñas, tokens ni PIN.

## 5. Reglas financieras
1. Usar tipos decimales exactos; no float para dinero.
2. Las cuentas no deben quedar con saldo negativo.
3. Débitos y créditos deben balancearse según moneda y reglas de operación.
4. Transferencias atómicas: ambas partes se confirman o ninguna.
5. Una operación fallida no debe dejar movimientos parciales.
6. Validar estado de cuentas antes de operar.
7. Mantener consistencia entre saldo y asientos.

## 6. Alcance
El esquema incluye entidades extensibles para roles, permisos, clientes, asientos y auditoría. La presencia de una entidad en el esquema no implica que su funcionalidad esté completamente expuesta en la API; validar por módulo y pruebas.
