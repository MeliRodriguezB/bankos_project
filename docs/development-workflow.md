# BankOS — Flujo de trabajo del equipo

## 1. Estrategia de ramas
- main: versión estable o entregable.
- develop: integración del equipo.
- feat/nombre: nueva funcionalidad.
- fix/nombre: corrección.
- docs/nombre: documentación.

No trabajar directamente en main. Los cambios se realizan en ramas y se integran mediante Pull Request.

## 2. Commits (Conventional Commits)
- feat: add transaction history filters
- fix: prevent duplicate transfer submission
- docs: update API contract
- test: cover currency formatting
- refactor: separate transaction service
- chore: update dependencies

## 3. Flujo de tarea
1. Crear Issue con descripción y criterios de aceptación.
2. Crear rama desde develop.
3. Implementar cambios acotados.
4. Ejecutar pruebas locales.
5. Abrir PR hacia develop.
6. Revisar descripción, código y checks.
7. Integrar solo cuando CI esté verde y exista revisión.

## 4. Checklist de Pull Request
- [ ] Describe problema y solución.
- [ ] Referencia la tarea/Issue.
- [ ] Tests/análisis aplicables ejecutados.
- [ ] No contiene secretos ni archivos de entorno.
- [ ] Documentación actualizada si aplica.
- [ ] Cambios dentro del alcance.
- [ ] CI exitoso.

## 5. Comunicación
- Discord como canal de coordinación.
- Registrar avances y bloqueos.
- Comunicar bloqueos que afecten a otra tarea.
- Actualizar tareas antes de reuniones.
- Decisiones técnicas que afecten al equipo deben registrarse en Issue/documento.

## 6. Tablero
Backlog → Ready → In Progress → Review → Done.

- Cada tarea tiene responsable y criterio de aceptación.
- No iniciar tareas sin claridad de alcance.
- Limitar trabajo simultáneo por integrante.
- En Review incluir evidencia/instrucciones de prueba.

## 7. Roles iniciales (ajustables)

| Rol | Responsabilidad |
|---|---|
| Backend | API, reglas, DB, migraciones y tests backend. |
| Frontend | Flutter, UI, navegación, estado e integración API. |
| QA/Integración | Pruebas, contrato, documentación y validación de flujos. |

Roles pueden rotar, pero cada tarea debe tener un responsable claro.
