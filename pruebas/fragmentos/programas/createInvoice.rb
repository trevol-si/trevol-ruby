# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.invoices.create_invoice(
  {
    external_id: 'VENTA-2026-000123',
    customer: {
      document_type: '31',
      document_number: '900123456',
      name: 'COMERCIALIZADORA ANDINA SAS',
      person_type: 'legal',
      email: 'facturacion@comercializadoraandina.example',
      address: 'Calle 72 # 10-34, Oficina 501',
      municipality_code: '11001'
    },
    items: [
      {
        code: 'LIC-ANUAL',
        description: 'Licencia anual de software',
        quantity: '2',
        unit_price: '150000',
        taxes: [{ code: '01', rate: '19' }]
      },
      {
        code: 'SOP-MES',
        description: 'Soporte técnico mensual',
        quantity: '1',
        unit_price: '80000',
        taxes: [{ code: '01', rate: '19' }]
      }
    ],
    payment: { form: 'credit', term_days: 30 },
    notes: ['Gracias por su compra']
  },
  # idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
)
pp resultado.to_hash
