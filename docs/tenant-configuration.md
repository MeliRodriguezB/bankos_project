# Configuración por institución (Tenant)

La configuración siempre se consulta usando el tenant derivado del JWT. El cliente no puede enviar un `tenant_id` alternativo para cambiar el contexto.

## Consultar configuración

```http
GET /api/v1/tenant/config
Authorization: Bearer <access_token>
```

Cualquier usuario autenticado de la institución puede consultar sus parámetros.

## Actualizar configuración

Solo un usuario con rol `ADMIN` puede actualizar los parámetros de su propia institución.

```http
PATCH /api/v1/tenant/config
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

Ejemplo:

```json
{
  "max_transfer_amount": 2500000.00,
  "transfer_fees": {
    "COP": 1200.00,
    "USD": 0.75
  },
  "transfer_fee_percent": 0.005,
  "primary_currency": "COP",
  "supported_currencies": ["COP", "USD"],
  "exchange_rates": {
    "COP/USD": 0.00025,
    "USD/COP": 4000.00
  },
  "webhook_url": "https://example.org/bankos/events"
}
```

## Reglas

- `max_transfer_amount` limita el monto de cada transferencia.
- `transfer_fees` define la comisión fija por moneda de origen.
- `transfer_fee_percent` aplica un porcentaje adicional expresado como fracción (0.005 = 0.5%).
- `primary_currency` debe pertenecer a `supported_currencies`.
- `exchange_rates` contiene tasas estáticas por par `ORIGEN/DESTINO` para el entorno de demostración.
- `webhook_url` se almacena como configuración institucional. La entrega HTTP de eventos a ese endpoint todavía requiere implementar un patrón outbox y validación de destino; no se realizan llamadas salientes actualmente.

Las tasas estáticas y los depósitos simulados no deben habilitarse para operaciones con dinero real. En producción, la conversión está bloqueada hasta integrar un proveedor de tasas fiable.
