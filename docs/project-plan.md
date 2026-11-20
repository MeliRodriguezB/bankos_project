# BankOS — Alcance, MVP y plan de trabajo

**Versión:** 1.0 · **Tipo:** Prototipo académico

## 1. Objetivo
Construir un prototipo bancario digital multi-tenant que demuestre autenticación, consulta de cuentas y balances por moneda, operaciones básicas con validaciones, historial e aislamiento institucional.

## 2. MVP (primera versión demostrable)

### Incluido
- Identificación de institución.
- Inicio de sesión y sesión autenticada.
- Dashboard y consulta de cuentas.
- Depósitos y retiros de demostración.
- Cotización y transferencias.
- PIN de confirmación para operaciones aplicables.
- Historial paginado.
- Modo MOCK/API para demostración.
- Validación de datos y manejo de errores.

### Fuera de alcance
- Conexión con bancos reales.
- Procesamiento externo de pagos.
- KYC/AML real.
- Tarjetas.
- Push notifications.
- Créditos, préstamos o scoring.
- Tasas de cambio en tiempo real.
- Operaciones con dinero real.

## 3. Criterios de aceptación

| ID | Criterio | Evidencia esperada |
|---|---|---|
| MVP-01 | Login en institución válida | Flujo de login y errores. |
| MVP-02 | Recursos protegidos requieren sesión | Token y endpoint protegido. |
| MVP-03 | Balances agrupados por moneda | COP/USD separados. |
| MVP-04 | Consulta de cuentas y detalle | UI y respuesta API. |
| MVP-05 | Operaciones validan datos y reglas | Casos positivos y negativos. |
| MVP-06 | Transferencia muestra cotización | Desglose antes de confirmación. |
| MVP-07 | Reintento idempotente no duplica | Prueba de replay. |
| MVP-08 | Historial paginado | UI y respuesta paginada. |
| MVP-09 | Aislamiento entre tenants | Prueba cruzada de acceso. |
| MVP-10 | Ejecución local reproducible | README y Docker Compose. |

## 4. Plan de trabajo

### Sprint 0 — Base
- Repositorio, Docker y API inicial.
- Documentación del contrato.
- CI y estructura base.
- **Cierre:** confirmar checks y estado del baseline.

### Sprint 1 — Validación e integración
- Revisar estructura de frontend y backend.
- Validar health, login, dashboard, accounts y transactions.
- Confirmar ejecución reproducible.
- Comparar contrato con OpenAPI.
- Registrar defectos como Issues.
- **Entregable:** baseline y matriz de endpoints verificados.

### Sprint 2 — Flujos principales
- Login, sesión y logout.
- Dashboard y cuentas.
- Quote, transfer, deposit y withdrawal.
- Historial y navegación tras operación.
- Casos negativos y reintentos.
- **Entregable:** flujo de demo end-to-end.

### Sprint 3 — Calidad y entrega
- Pruebas de regresión.
- Revisión de configuración de seguridad de demo.
- Corrección de defectos prioritarios.
- Capturas/video de demostración.
- Actualizar documentación.
- **Entregable:** demo y reporte de pruebas.

## 5. MoSCoW

| Prioridad | Elementos |
|---|---|
| Must | Login, dashboard, cuentas, transferencia, historial, API y ejecución local. |
| Should | Depósitos/retiros, cotización, aislamiento multi-tenant e idempotencia verificadas. |
| Could | Accesibilidad, animaciones, filtros/reportes adicionales. |
| Won't (MVP) | Bancos reales, pagos externos y crédito. |

## 6. Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| API y UI desalineadas | Contrato versionado y revisión OpenAPI. |
| Cambios simultáneos | Branches, PR y asignación de archivos/tareas. |
| Operación duplicada | Idempotency key y pruebas de reintento. |
| Datos cruzados entre tenants | Validación backend y pruebas de aislamiento. |
| Entorno difícil de replicar | Docker Compose y README. |
| Alcance excesivo | Priorizar MVP y diferir extras. |

## 7. Demo sugerida (5–7 minutos)
1. Objetivo BaaS y multi-tenancy.
2. Login con institución de prueba.
3. Dashboard y balances por moneda.
4. Detalle de cuentas.
5. Cotización y transferencia con PIN.
6. Historial.
7. Swagger, Docker y arquitectura.
8. Límites del prototipo.

## 8. Definition of Done
- Criterios de aceptación cumplidos.
- Código compila y pasa análisis.
- Pruebas relevantes pasan.
- Sin secretos en repositorio.
- Documentación actualizada si cambia contrato/comportamiento.
- PR revisado.
- CI verde antes de integrar.
