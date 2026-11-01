# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.credit_notes.correct_credit_note(
  'cn_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b',
  {
    external_id: 'DEV-2026-000045',
    concept: '1',
    description: 'Devolución de una unidad por empaque dañado',
    invoice: { id: 'inv_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b' },
    items: [
      {
        description: 'Café especial 500 g',
        code: 'CAF-500',
        unit: '94',
        quantity: '1',
        unit_price: '32000',
        taxes: [{ code: '01', rate: '19' }]
      }
    ]
  },
  # idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
)
pp resultado.to_hash
