# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.support_document_adjustments.preview_support_document_adjustment(
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
  }
)
pp resultado.to_hash
