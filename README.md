# BankOS

BankOS es un proyecto de aplicación bancaria con una arquitectura cliente-servidor. El cliente móvil se desarrolla con Flutter y el backend expone una API REST construida con FastAPI.

> **Estado del proyecto:** documentación y estructura inicial en desarrollo. Las funcionalidades descritas como objetivos no se consideran implementadas hasta que existan sus endpoints, lógica y pruebas correspondientes.

## Tecnologías

- **Frontend:** Flutter y Dart.
- **Backend:** Python y FastAPI.
- **Base de datos:** PostgreSQL.
- **Caché y soporte de operaciones:** Redis.
- **Contenedores:** Docker y Docker Compose.

## Arquitectura general

La aplicación Flutter consume los endpoints HTTP de FastAPI e intercambia información en formato JSON. El backend centraliza las reglas de negocio, la autenticación, la autorización y el acceso a los datos. PostgreSQL se utiliza para la persistencia y Redis para mecanismos de apoyo como idempotencia y limitación de solicitudes, según la configuración que se implemente.

## Estructura del repositorio

La estructura puede evolucionar a medida que avance el desarrollo. Las rutas principales previstas son:

- `lib/`: código de la aplicación Flutter.
- `backend/app/`: aplicación y módulos del backend.
- `backend/requirements.txt`: dependencias de Python.
- `backend/Dockerfile`: imagen del backend.
- `infrastructure/docker-compose.yml`: servicios de desarrollo.
- `docs/api-contract.md`: contrato inicial de la API.

## Requisitos

- Git.
- Docker Desktop con integración WSL 2 (en Windows).
- Docker Compose.
- Flutter SDK para ejecutar el cliente móvil.

## Ejecución del entorno de backend

Desde la raíz del repositorio, en una terminal:

```bash
git switch develop
git pull origin develop
docker compose -f infrastructure/docker-compose.yml up --build -d
docker compose -f infrastructure/docker-compose.yml ps
```

Para consultar los registros del servicio de API:

```bash
docker compose -f infrastructure/docker-compose.yml logs -f api
```

La configuración local prevista expone la documentación de FastAPI en:

- Swagger UI: http://localhost:8080/docs
- ReDoc: http://localhost:8080/redoc
- Health check: http://localhost:8080/health

Estas direcciones dependen del mapeo de puertos definido en el archivo Compose. Si el puerto publicado es diferente, se debe ajustar la URL.

Para detener los contenedores sin eliminar los volúmenes de datos:

```bash
docker compose -f infrastructure/docker-compose.yml down
```

Evita usar `down -v` si necesitas conservar los datos locales de PostgreSQL.

## Documentación

Consulta [Contrato inicial de API](docs/api-contract.md) para conocer los endpoints propuestos, formatos de solicitud y respuesta, códigos HTTP y responsabilidades entre frontend y backend.

## Flujo de trabajo Git

- `main`: rama estable.
- `develop`: rama de integración.
- `feature/nombre-descriptivo`: ramas para desarrollar funcionalidades.

Se recomienda crear ramas de funcionalidad desde `develop` y entregar los cambios mediante Pull Request hacia `develop`. Evita realizar cambios directamente sobre `main`.

## Seguridad y configuración

- No publiques contraseñas, tokens, claves privadas ni archivos `.env` con secretos reales.
- Usa variables de entorno para la configuración sensible.
- Los valores de desarrollo no deben reutilizarse en producción.
- Las operaciones financieras deben validarse en el backend; las validaciones del cliente no sustituyen las reglas del servidor.

## Alcance de esta documentación

Este README describe la arquitectura y el procedimiento de desarrollo previsto. No afirma que todas las funcionalidades bancarias, conexiones externas o controles de seguridad estén terminados. Su estado debe verificarse contra el código y las pruebas del proyecto.

