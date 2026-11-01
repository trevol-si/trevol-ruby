# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.credit_notes.preview_credit_note(
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
  }
)
pp resultado.to_hash
