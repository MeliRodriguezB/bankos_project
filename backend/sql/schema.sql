-- =========================================================
-- BANKOS - ESQUEMA RELACIONAL INICIAL
-- Motor: PostgreSQL
-- Alcance: identidad, multi-tenancy y operaciones financieras
-- =========================================================

-- UUIDs generados por PostgreSQL.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------
-- 1. CATÁLOGO DE MONEDAS
-- ---------------------------------------------------------

CREATE TABLE currencies (
    code VARCHAR(3) PRIMARY KEY,
    name VARCHAR(60) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Datos iniciales para desarrollo y pruebas.
INSERT INTO currencies (code, name) VALUES
    ('COP', 'Peso colombiano'),
    ('USD', 'Dólar estadounidense'),
    ('EUR', 'Euro')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------
-- 2. INSTITUCIONES (TENANTS)
-- ---------------------------------------------------------

CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(120) NOT NULL,
    slug VARCHAR(80) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'INACTIVE')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 3. USUARIOS
-- Una identidad puede pertenecer a varias instituciones.
-- El correo se consulta sin distinguir mayúsculas/minúsculas.
-- ---------------------------------------------------------

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uq_users_email_lower
    ON users (LOWER(email));

-- ---------------------------------------------------------
-- 4. ADMINISTRADORES GLOBALES DE BANKOS
-- No son roles que una institución pueda asignar.
-- ---------------------------------------------------------

CREATE TABLE platform_admins (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 5. MEMBRESÍAS
-- Relacionan usuarios con instituciones.
-- ---------------------------------------------------------

CREATE TABLE tenant_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'INVITED', 'SUSPENDED', 'INACTIVE')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_membership_tenant_user
        UNIQUE (tenant_id, user_id),

    -- Clave candidata para relaciones que deben respetar el tenant.
    CONSTRAINT uq_membership_tenant_id
        UNIQUE (tenant_id, id)
);

-- ---------------------------------------------------------
-- 6. ROLES POR INSTITUCIÓN
-- Cada tenant administra sus propios roles.
-- ---------------------------------------------------------

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    code VARCHAR(50) NOT NULL,
    name VARCHAR(80) NOT NULL,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_roles_tenant_code
        UNIQUE (tenant_id, code),

    CONSTRAINT uq_roles_tenant_id
        UNIQUE (tenant_id, id)
);

-- ---------------------------------------------------------
-- 7. PERMISOS
-- Catálogo global de acciones posibles.
-- ---------------------------------------------------------

CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(80) NOT NULL UNIQUE,
    description TEXT
);

INSERT INTO permissions (code, description) VALUES
    ('USERS.READ', 'Consultar usuarios de la institución'),
    ('USERS.CREATE', 'Registrar usuarios en la institución'),
    ('USERS.UPDATE', 'Actualizar usuarios de la institución'),
    ('ROLES.MANAGE', 'Gestionar roles de la institución'),
    ('CUSTOMERS.READ', 'Consultar clientes'),
    ('CUSTOMERS.CREATE', 'Registrar clientes'),
    ('ACCOUNTS.READ', 'Consultar cuentas'),
    ('TRANSACTIONS.READ', 'Consultar transacciones'),
    ('TRANSACTIONS.CREATE', 'Crear operaciones financieras'),
    ('AUDIT.READ', 'Consultar registros de auditoría')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------
-- 8. PERMISOS ASIGNADOS A ROLES
-- ---------------------------------------------------------

CREATE TABLE role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id),
    permission_id UUID NOT NULL REFERENCES permissions(id),

    PRIMARY KEY (role_id, permission_id)
);

-- ---------------------------------------------------------
-- 9. ROLES ASIGNADOS A MEMBRESÍAS
-- Las claves compuestas impiden asignar a una membresía
-- un rol perteneciente a otra institución.
-- ---------------------------------------------------------

CREATE TABLE membership_roles (
    tenant_id UUID NOT NULL,
    membership_id UUID NOT NULL,
    role_id UUID NOT NULL,

    PRIMARY KEY (membership_id, role_id),

    CONSTRAINT fk_mr_membership
        FOREIGN KEY (tenant_id, membership_id)
        REFERENCES tenant_memberships (tenant_id, id),

    CONSTRAINT fk_mr_role
        FOREIGN KEY (tenant_id, role_id)
        REFERENCES roles (tenant_id, id)
);

-- ---------------------------------------------------------
-- 10. CLIENTES BANCARIOS
-- El vínculo con users es opcional: puede existir un cliente
-- sin acceso digital habilitado.
-- ---------------------------------------------------------

CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID REFERENCES users(id),
    customer_number VARCHAR(40) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    identification_type VARCHAR(20),
    identification_number VARCHAR(40),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'BLOCKED', 'INACTIVE')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_customer_tenant_number
        UNIQUE (tenant_id, customer_number),

    CONSTRAINT uq_customer_tenant_id
        UNIQUE (tenant_id, id)
);

-- ---------------------------------------------------------
-- 11. CUENTAS
-- balance es un saldo de consulta; los asientos contables
-- constituyen el registro histórico de los movimientos.
-- ---------------------------------------------------------

CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    account_number VARCHAR(40) NOT NULL,
    currency_code VARCHAR(3) NOT NULL REFERENCES currencies(code),
    balance NUMERIC(20, 4) NOT NULL DEFAULT 0
        CHECK (balance >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'BLOCKED', 'CLOSED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_account_tenant_number
        UNIQUE (tenant_id, account_number),

    CONSTRAINT uq_account_tenant_id
        UNIQUE (tenant_id, id),

    -- Permite validar que el asiento use la moneda de la cuenta.
    CONSTRAINT uq_account_tenant_id_currency
        UNIQUE (tenant_id, id, currency_code),

    CONSTRAINT fk_account_customer
        FOREIGN KEY (tenant_id, customer_id)
        REFERENCES customers (tenant_id, id)
);

-- ---------------------------------------------------------
-- 12. TRANSACCIONES
-- La clave de idempotencia es única dentro de cada tenant.
-- request_hash permite detectar reintentos con otro contenido.
-- ---------------------------------------------------------

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    created_by_membership_id UUID,
    type VARCHAR(20) NOT NULL
        CHECK (type IN (
            'DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'ADJUSTMENT'
        )),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN (
            'PENDING', 'POSTED', 'FAILED', 'REVERSED'
        )),
    idempotency_key VARCHAR(120),
    request_hash VARCHAR(128),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_transaction_tenant_id
        UNIQUE (tenant_id, id),

    CONSTRAINT fk_transaction_membership
        FOREIGN KEY (tenant_id, created_by_membership_id)
        REFERENCES tenant_memberships (tenant_id, id)
);

CREATE UNIQUE INDEX uq_transaction_idempotency
    ON transactions (tenant_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- ---------------------------------------------------------
-- 13. ASIENTOS CONTABLES
-- Una operación puede tener varios débitos y créditos.
-- El servicio financiero deberá garantizar que los débitos
-- y créditos coincidan por moneda antes de confirmar.
-- ---------------------------------------------------------

CREATE TABLE transaction_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    transaction_id UUID NOT NULL,
    account_id UUID NOT NULL,
    direction VARCHAR(6) NOT NULL
        CHECK (direction IN ('DEBIT', 'CREDIT')),
    amount NUMERIC(20, 4) NOT NULL
        CHECK (amount > 0),
    currency_code VARCHAR(3) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_entry_transaction
        FOREIGN KEY (tenant_id, transaction_id)
        REFERENCES transactions (tenant_id, id),

    CONSTRAINT fk_entry_account_currency
        FOREIGN KEY (tenant_id, account_id, currency_code)
        REFERENCES accounts (tenant_id, id, currency_code)
);

-- ---------------------------------------------------------
-- 14. AUDITORÍA
-- No almacenar contraseñas, tokens ni PIN en metadata.
-- ---------------------------------------------------------

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    actor_user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(80) NOT NULL,
    entity_id UUID,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 15. ÍNDICES PARA CONSULTAS FRECUENTES
-- ---------------------------------------------------------

CREATE INDEX idx_memberships_user
    ON tenant_memberships (user_id);

CREATE INDEX idx_customers_tenant
    ON customers (tenant_id);

CREATE INDEX idx_accounts_customer
    ON accounts (tenant_id, customer_id);

CREATE INDEX idx_transactions_tenant_date
    ON transactions (tenant_id, created_at DESC);

CREATE INDEX idx_entries_transaction
    ON transaction_entries (tenant_id, transaction_id);

CREATE INDEX idx_entries_account
    ON transaction_entries (tenant_id, account_id);

CREATE INDEX idx_audit_tenant_date
    ON audit_logs (tenant_id, created_at DESC);
