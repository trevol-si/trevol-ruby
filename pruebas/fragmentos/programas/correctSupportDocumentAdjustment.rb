# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.support_document_adjustments.correct_support_document_adjustment(
  'sda_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b',
  {
    external_id: 'OC-991-ANULA',
    concept: '2',
    description: 'Anulación: la compra de leche se registró dos veces en el ERP',
    support_document: { id: 'sd_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b' },
    items: [
      {
        description: 'Leche cruda',
        unit: 'LTR',
        quantity: '120',
        unit_price: '1800'
      }
    ]
  },
  # idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
)
pp resultado.to_hash
