# trevol (Ruby)

SDK de Ruby para la **API de Trevol**: facturación electrónica, documento soporte, documento equivalente, nómina electrónica y eventos
RADIAN ante la DIAN (Colombia). Documentación: <https://platform.trevol.si/docs>.

> **In English.** Ruby SDK for the Trevol API (Colombian e-invoicing, DIAN). Ruby ≥ 3.3, Faraday 2. Typed models and API clients generated from
> the OpenAPI spec (OpenAPI Generator, module `TrevolGenerado`), plus a thin hand-written layer (module `Trevol`): automatic `Idempotency-Key`
> (the same one on retries), retries with exponential backoff honouring `Retry-After`, typed errors by problem+json `code`, environment inferred
> from the key prefix (`tvl_test_` = DIAN test environment, `tvl_live_` = production), pinned `Trevol-Version`, Standard Webhooks signature
> verification, cursor pagination with `Enumerator::Lazy` and PDF/XML/ZIP downloads. Docs are in Spanish like the API.

**Versión 0.1.0** — API `2026-10-22`. Licencia MIT.

## Instalación

```sh
gem install trevol          # o, en tu Gemfile: gem 'trevol'
```

Necesita Ruby 3.3 o más nuevo. Depende de [Faraday](https://lostisland.github.io/faraday/) 2 y de la gema abierta
[`standardwebhooks`](https://rubygems.org/gems/standardwebhooks) (MIT).

## Uso

La llave de la API se crea en la consola de desarrolladores (<https://platform.trevol.si/llaves>) y se guarda en el entorno de tu **servidor**:
`TREVOL_API_KEY`. Una llave `tvl_test_…` llama a la habilitación de la DIAN; una `tvl_live_…`, a producción. El SDK deduce el entorno del
prefijo (`trevol.environment`).

```ruby
require 'trevol'

trevol = Trevol::Client.new # lee TREVOL_API_KEY; tvl_test_… → trevol.environment == :test

begin
  factura = trevol.invoices.create_invoice(
    {
      external_id: 'VENTA-2026-000123',
      customer: { final_consumer: true },
      items: [{ description: 'Café especial 500 g', quantity: '1', unit_price: '32000', taxes: [{ code: '01', rate: '19' }] }],
      payment: { form: 'cash', methods: [{ code: '10' }] }
    },
    idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
  )
  if factura.status == 'processing'
    # 202: la DIAN no contestó; Trevol lo termina y avisa por webhook. NO crees otro documento para la misma venta.
  end
rescue Trevol::ValidationError => e
  e.errors.each { |x| warn "#{x[:pointer]} #{x[:message]}" }
rescue Trevol::Error => e
  warn "#{e.code} #{e.request_id}"
end

# Todas las páginas de un listado, perezosamente (Enumerator::Lazy)
trevol.paginate { |cursor| trevol.invoices.list_invoices(limit: 100, starting_after: cursor) }.each do |f|
  puts "#{f.id} #{f.status}"
end

# Los archivos llegan como Tempfile (ciérralo con close! cuando termines)
pdf = trevol.invoices.download_invoice_pdf('inv_…')
```

Los nombres de los métodos son los del `operationId` de la [especificación](https://platform.trevol.si/docs/api) en `snake_case`
(`create_invoice`, `list_invoices`, `retrieve_invoice`, `correct_invoice`, `send_invoice`, `download_invoice_pdf`…). Los parámetros de ruta y
los de consulta obligatorios son posicionales; los opcionales (`limit:`, `starting_after:`, `idempotency_key:`) van con nombre. El cuerpo es un
`Hash` con las claves **iguales a las de la API** (`external_id`) o el modelo generado (`TrevolGenerado::InvoiceInput.new(...)`); los importes y
las fechas viajan como texto (`'32000.50'`, `'2026-10-31'`).

## Lo que conviene saber

### Idempotencia: manda `external_id` y tu propia clave

El SDK genera una `Idempotency-Key` por llamada y **la repite en todos los reintentos de esa llamada**. Pero si tu proceso muere y vuelves a
llamar, saldrá otra clave y, si no mandaste `external_id` (es opcional), podría duplicarse el documento. Por eso:

- manda siempre `external_id` (tu id de la venta), y
- pasa una `idempotency_key:` derivada de tu venta (`idempotency_key: 'VENTA-2026-000123'`).

Ante un `Trevol::ConflictError` con `code == 'external_id_in_use'`, el documento ya existe: usa `e.problem[:existing_id]`. Todo error lleva la
`idempotency_key` que se usó para reintentar más tarde con la misma. Un `APIConnectionError` también.

### Respuestas 202 (`processing`, `sending`, `validating`, `contingency`)

No son errores ni se reintentan: se devuelven como el modelo de la respuesta. **No crees otro documento**: espera el webhook o consulta con
`retrieve_invoice`; repetir la misma llamada con la misma `Idempotency-Key` continúa el mismo documento. El PDF y el ZIP llegan después del
`201` (evento `invoice.delivered`, o `delivery.status == 'completed'`).

### Reintentos

Hasta 2 reintentos (3 intentos) con espera creciente (0,5 s, 1 s, 2 s… con tope de 8 s y un poco de azar) ante un error de red, 429, 500,
502, 503, 504, un 409 `request_in_progress` o `previous_event_pending`, y todo problema que diga `retryable: true` (salvo el 402). Respeta
`Retry-After`; si pide más de `max_retry_after` (60 s) no espera y lanza el error con `retry_after`. Las operaciones sin `Idempotency-Key`
(crear un endpoint, `…/send`, `DELETE`) solo se reintentan con 429. Los 202 y los errores finales (400, 401, 402, 403, 404, 422 y los 409
`invalid_state`, `external_id_in_use`, `duplicate_document`) **nunca** se reintentan. El SDK no usa `faraday-retry`: es el único que reintenta.

### La versión de la API

El SDK fija `Trevol-Version: 2026-10-22` en cada petición. **Ojo:** una llave creada con la versión `2026-10-21` que empiece a usar este SDK
pasa a `2026-10-22` (el encabezado manda): recibe `202 processing` donde antes recibía `503`. Si todavía no quieres ese cambio:
`Trevol::Client.new(llave, api_version: '2026-10-21')`. Más en <https://platform.trevol.si/docs/versiones>.

### Errores tipados

`Trevol::Error` es la base; las clases salen del `code` del problem+json: `AuthenticationError`, `PermissionDeniedError`, `NotFoundError`,
`InvalidRequestError`, `IdempotencyError`, `ValidationError` (con `errors`: `field`, `pointer`, `message`), `ConflictError`,
`PreconditionError`, `DianRejectedError` (con `problem[:document]` y `problem[:rules]`), `BalanceError`, `RateLimitError`,
`DianUnavailableError` e `InternalServerError`. Un `code` que el SDK todavía no conoce llega como `Trevol::Error` con ese `code`: nunca rompe.
Además: `APIConnectionError` (no hubo respuesta), `ConfigurationError` (mal uso, antes de llamar) y `WebhookVerificationError` (`reason`: `:firma`,
`:fecha`, `:cabeceras` o `:cuerpo`). Cada error tiene `status`, `code`, `type`, `title`, `detail`, `request_id`, `retryable?`, `retry_after`,
`errors`, `idempotency_key`, `problem` (el cuerpo completo, con claves símbolo) y `headers` (los de la respuesta). Ninguno incluye tu llave.

### Webhooks

```ruby
# Rails
class WebhooksController < ActionController::API
  WH = Trevol::Webhook.new(ENV.fetch('TREVOL_WEBHOOK_SECRET')) # whsec_…

  def trevol
    evento = WH.verify(request.raw_post, request.headers) # el cuerpo CRUDO, no params
    # Deduplica por evento.id (también llega en la cabecera webhook-id): la verificación no evita repeticiones.
    datos = WH.event_data(evento) # el modelo según evento.type (p. ej. TrevolGenerado::DocumentEventData)
    head :ok
  rescue Trevol::WebhookVerificationError
    head :bad_request
  end
end
```

En Sinatra usa `request.body.read`. La firma se calcula sobre los **bytes exactos**: no uses el cuerpo ya decodificado. `verify` acepta las
cabeceras como `Hash` (cualquier caja, también el formato `HTTP_WEBHOOK_ID` de Rack) o `request.headers`; la firma esperada la calcula la gema
de Standard Webhooks, y el SDK tolera 5 minutos hacia atrás y hacia adelante en `webhook-timestamp` y compara en tiempo constante.

### Estado y cabeceras de la respuesta

Cada método tiene una variante `…_with_http_info` que devuelve `[modelo, estado, cabeceras]`:
`factura, estado, cabeceras = trevol.invoices.create_invoice_with_http_info(...)` (`cabeceras['request-id']`, `cabeceras['idempotent-replayed']`).

### Cabeceras propias por llamada

Cada método acepta `header_params: { 'X-Mi-Cabecera' => '…' }` (se mezcla con las del SDK) en su último argumento.

## Opciones

```ruby
Trevol::Client.new(
  llave,
  api_version: '2026-10-22',   # Trevol-Version en cada petición
  max_retries: 2,              # 0 los apaga
  timeout: 65,                 # segundos por intento
  max_retry_after: 60,         # segundos
  base_url: 'https://api.trevol.si/v1',
  environment: :test,          # si la llave no coincide: ConfigurationError antes de llamar
  proxy: nil                   # p. ej. 'http://proxy.miempresa.co:3128'
)
```

## Cómo está hecho

- `lib/trevol_generado/` lo escribe [OpenAPI Generator](https://openapi-generator.tech) 7.26.0 (`ruby`, Faraday) desde la especificación
  pública y **no se edita** (ver `GENERADO.md`). Para que un valor nuevo de un `enum` en lo que la API devuelve no rompa a quien ya integró,
  los modelos de respuesta se generan sin `enum`.
- Lo propio (`lib/trevol/`) vive fuera y solo usa el punto de extensión del código generado: un middleware de Faraday (`Trevol::Transporte`),
  que lanza el error tipado y reintenta. La gema también declara `base64` y `cgi` porque `standardwebhooks` 1.1.0 y el código generado los
  usan sin que Ruby 3.4/4.0 los traiga ya en la biblioteca estándar.
- Las pruebas: `bundle install && bundle exec rake test` (unitarias sin red, contra un servidor HTTP local, con los mismos casos de los demás SDK
  en `pruebas/datos/`); `TREVOL_PRISM_URL=http://127.0.0.1:4010 bundle exec rake prism` contra un servidor simulado
  (`npx @stoplight/prism-cli mock pruebas/datos/openapi.json -p 4010`) que valida cada petición contra la especificación, y que además corre
  como programa cada fragmento de código de la documentación.
- `bundle exec ruby pruebas/humo/humo.rb` es la prueba de humo **real** (solo con una llave `tvl_test_`; no emite documentos).

## Licencia

MIT © 2026 Joshua Montclair (Trevol).
