# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.equivalent_documents.correct_equivalent_document(
  'pos_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b',
  {
    external_id: 'TIQ-1',
    customer: { final_consumer: true },
    pos: {
      register: {
        plate: 'CJ-01',
        location: 'Local 1, Jamundí',
        cashier: 'PEREZ ANA',
        type: 'Caja principal'
      }
    },
    numbering: { prefix: 'POS2' },
    payment: { form: 'cash', methods: [{ code: '10' }] },
    items: [
      {
        description: 'Gaseosa 400 ml',
        code: 'GAS-1',
        unit: '94',
        quantity: '2',
        unit_price: '3000',
        taxes: [{ code: '01', rate: '19' }]
      },
      {
        description: 'Almuerzo',
        unit: '94',
        quantity: '1',
        unit_price: '18000'
      }
    ]
  },
  # idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
)
pp resultado.to_hash
