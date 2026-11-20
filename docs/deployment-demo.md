# BankOS — demo web deployment

## Alcance

La versión web publicada desde esta rama es una **demostración de interfaz con datos simulados**. No se conecta a un backend público, no administra fondos reales y no debe utilizarse para operaciones financieras reales.

## Acceso a la demostración

1. Abre la URL de GitHub Pages del repositorio. La compilación publicada inicia automáticamente en modo **MOCK**.
3. Ingresa cualquier correo de demostración y la contraseña `123456`.
4. El dashboard también carga automáticamente las cuentas e historial simulados. Puedes cambiar manualmente entre MOCK y API desde el selector.
5. Para acciones simuladas que soliciten PIN, utiliza `1234`.

Los saldos, cuentas, tasas, depósitos, retiros y transferencias de este modo son datos ficticios y solo sirven para demostrar la interfaz y los flujos.

## Publicación

El workflow `.github/workflows/deploy-demo-web.yml` compila Flutter Web, ejecuta análisis y pruebas, y publica `build/web` en GitHub Pages cuando hay cambios en `fix/withdrawal-screen-ci`.

En la configuración del repositorio, GitHub Pages debe permitir **Deploy from a branch: GitHub Actions**. La URL esperada para un repositorio de proyecto es:

`https://meliRodriguezB.github.io/bankos_project/`

La URL solo estará activa después de que el workflow termine correctamente y GitHub Pages esté habilitado.

## Backend

Esta publicación no despliega FastAPI ni PostgreSQL. Para una versión conectada se requiere un servicio backend accesible por HTTPS, una base de datos persistente, secretos configurados en el proveedor y una URL API compilada con `--dart-define=API_BASE_URL=...`. El backend actual sigue siendo un prototipo y no está autorizado para custodiar dinero real.
