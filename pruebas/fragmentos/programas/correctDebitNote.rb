# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.debit_notes.correct_debit_note(
  'dn_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b',
  {
    external_id: 'INT-2026-000012',
    concept: '1',
    description: 'Intereses de mora de la factura de septiembre',
    invoice: { id: 'inv_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b' },
    items: [
      {
        description: 'Intereses de mora',
        unit: '94',
        quantity: '1',
        unit_price: '45000'
      }
    ]
  },
  # idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
)
pp resultado.to_hash
