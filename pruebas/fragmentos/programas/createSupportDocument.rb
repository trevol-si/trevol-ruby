# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.support_documents.create_support_document(
  {
    external_id: 'OC-991',
    seller: {
      resident: true,
      person_type: 'natural',
      document_type: '31',
      document_number: '1020304050',
      name: 'PEREZ GOMEZ ANA MARIA',
      address: 'Vereda El Silencio, finca La Esperanza',
      municipality_code: '25053',
      postal_code: '252007',
      tax_responsibilities: ['R-99-PN']
    },
    items: [
      {
        description: 'Leche cruda',
        unit: 'LTR',
        quantity: '120',
        unit_price: '1800'
      }
    ],
    payment: { form: 'cash', methods: [{ code: '10' }] },
    notes: ['Compra de la semana 42 de octubre']
  },
  # idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
)
pp resultado.to_hash
