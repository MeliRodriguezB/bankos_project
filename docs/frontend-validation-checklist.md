# BankOS — Checklist de validación manual

Este checklist complementa el pipeline automatizado de Flutter. CI valida análisis estático, pruebas automatizadas y compilación; no reemplaza las pruebas de integración con backend ni las pruebas en dispositivos físicos.

## Preparación
- [ ] Clonar el repositorio y cambiar a la rama de trabajo.
- [ ] Copiar y configurar las variables de entorno necesarias sin subir secretos.
- [ ] Iniciar PostgreSQL, Redis y API con Docker Compose.
- [ ] Confirmar que `/health` y `/docs` responden.
- [ ] Ejecutar `flutter pub get` y arrancar Flutter en el dispositivo o navegador.

## Autenticación y sesión
- [ ] Login API con credenciales válidas.
- [ ] Login con credenciales incorrectas y comprobar mensaje sin exponer información sensible.
- [ ] Cambiar entre MOCK y API y comprobar que el modo seleccionado se respeta.
- [ ] Cerrar sesión y verificar que la sesión/token se elimina.
- [ ] Verificar expiración/rechazo de token y retorno al login.
- [ ] En dispositivo compatible, activar biometría, bloquear/desbloquear y probar alternativa de contraseña.

## Cuentas y dashboard
- [ ] Verificar cuentas, estados y saldos.
- [ ] Comprobar que monedas diferentes no se suman en un saldo total incorrecto.
- [ ] Probar carga, error, reintento y estado vacío.
- [ ] Confirmar aislamiento de cuentas entre instituciones/tenants.

## Transferencias
- [ ] Validar campos vacíos, cuenta destino y monto no numérico/cero/negativo.
- [ ] Solicitar cotización y comprobar monto, comisión, tasa y total.
- [ ] PIN inválido y PIN válido.
- [ ] Confirmar transferencia y comprobar actualización de saldos e historial.
- [ ] Reintentar una operación con la misma clave de idempotencia después de una respuesta incierta.
- [ ] Verificar rechazo por saldo insuficiente y cuenta destino inválida.

## Depósitos
- [ ] Validar monto vacío, inválido, cero o negativo.
- [ ] Confirmar depósito y verificar saldo/historial.
- [ ] Simular fallo de red y reintentar con la misma clave de idempotencia.
- [ ] Confirmar que no se crea un depósito duplicado.

## Historial
- [ ] Mostrar historial completo.
- [ ] Filtrar transferencias, depósitos y retiros.
- [ ] Cargar páginas adicionales.
- [ ] Actualizar mediante pull-to-refresh.
- [ ] Validar estado vacío, error y reintento.
- [ ] Confirmar fechas, moneda, comisiones y conversiones.

## Cierre de validación
- [ ] Ejecutar `flutter analyze`.
- [ ] Ejecutar `flutter test`.
- [ ] Compilar APK debug con `flutter build apk --debug`.
- [ ] Ejecutar flujos críticos en Android físico/emulador.
- [ ] Registrar resultados, dispositivo, versión y evidencia de pruebas.

> BankOS es un proyecto académico/demo. Los depósitos de la aplicación no representan movimientos de dinero real y el sistema no debe desplegarse para uso financiero real sin una revisión de seguridad, auditoría, controles operativos y pruebas de integración completas.
