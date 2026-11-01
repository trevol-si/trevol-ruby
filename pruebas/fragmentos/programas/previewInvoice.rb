# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.invoices.preview_invoice(
  {
    external_id: 'EXP-77',
    document_type: '02',
    currency: { code: 'USD', exchange_rate: '3950.12', rate_date: '2026-10-21' },
    delivery_terms: { incoterm: 'FOB', conditions: 'Puerto de Cartagena' },
    customer: {
      document_type: '50',
      document_number: 'US123456789',
      name: 'ACME INC',
      country: 'US',
      city: 'Miami',
      region: 'Florida',
      postal_code: '33131',
      address: '200 S Biscayne Blvd'
    },
    items: [
      {
        description: 'Consultoría',
        quantity: '1',
        unit_price: '1000',
        taxes: [{ code: '01', excluded: true }]
      }
    ],
    payment: { form: 'credit', term_days: 30 }
  }
)
pp resultado.to_hash
