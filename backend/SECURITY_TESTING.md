# Verificación de seguridad del backend BankOS

Esta rama añade comprobaciones de autenticación en base de datos, control de idempotencia y pruebas automatizadas.

## Administrador institucional opcional

No se crea ningún administrador con contraseña conocida o predeterminada. Para habilitar el endpoint `POST /api/v1/accounts`, define en un archivo `.env` ubicado en la raíz del repositorio:

```dotenv
BOOTSTRAP_ADMIN_EMAIL=admin@example.test
BOOTSTRAP_ADMIN_PASSWORD=REEMPLAZA_POR_UNA_CLAVE_LARGA_Y_UNICA
```

Configura ambos valores. Al iniciar en `ENVIRONMENT=development`, el seed crea o asocia ese usuario al tenant `cooperativa-futuro` con rol `ADMIN`. Si el usuario ya existe, no se cambia su contraseña.

No uses credenciales de ejemplo en producción. Guarda el archivo `.env` fuera del control de versiones.

## Reconstruir el contenedor con el código de esta rama

Desde la raíz del repositorio:

```powershell
docker compose -f infrastructure/docker-compose.yml up -d --build api
```

La imagen anterior puede mostrar únicamente `/health`. Después de reconstruir, revisa:

- `http://localhost:8000/docs`
- `http://localhost:8000/openapi.json`
- `http://localhost:8000/health`

Deben aparecer rutas de autenticación, cuentas/dashboard y transacciones, además de health.

## Pruebas automatizadas

Desde la carpeta `backend`:

```powershell
python -m pip install -r requirements.txt
python -m pytest -q
```

GitHub Actions ejecuta las mismas pruebas en cada push a esta rama y en pull requests hacia `develop`.

## Idempotencia y datos preexistentes

Al iniciar, la API crea un índice único parcial sobre `(tenant_id, user_id, idempotency_key)` para claves no nulas. Si la base de datos ya contiene claves duplicadas dentro del mismo tenant y usuario, el índice no podrá crearse y el arranque fallará deliberadamente. En ese caso, inspecciona y resuelve los duplicados antes de volver a iniciar; no borres el volumen de PostgreSQL.

Una colisión concurrente revierte la transacción contable y devuelve HTTP 409. El cliente debe reintentar con la misma clave; la siguiente solicitud encontrará el movimiento existente y validará que el payload coincida.

## Alcance de validación

Las pruebas unitarias y de registro de rutas están automatizadas. Las pruebas reales contra PostgreSQL, Redis, concurrencia simultánea, flujo Flutter y credenciales deben ejecutarse en un entorno integrado antes de desplegar o fusionar a `develop`.
