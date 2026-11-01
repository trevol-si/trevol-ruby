# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.radian_events.create_radian_event(
  {
    external_id: 'ERP-ACUSE-DA1234',
    event_code: '030',
    invoice: {
      cufe: 'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
      number: 'DA1234',
      type: '01',
      issuer: {
        nit: '900373427',
        check_digit: 3,
        document_type: '31',
        name: 'DISTRIBUIDORA LOS ANDES SAS'
      }
    }
  },
  # idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
)
pp resultado.to_hash
