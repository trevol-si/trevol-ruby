# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.customers.create_customer(
  {
    external_id: 'ERP-CLI-0042',
    document_type: '31',
    document_number: '900373427',
    name: 'DISTRIBUIDORA LOS ANDES SAS',
    person_type: 'legal',
    tax_responsibilities: ['O-13'],
    email: 'facturacion@distribuidoralosandes.example',
    phone: '6045550142',
    address: 'Carrera 43A # 1-50, Oficina 302',
    city: 'Medellín',
    municipality_code: '05001',
    defaults: {
      payment_form: 'credit',
      term_days: 30,
      payment_method: '47',
      withholding_agent: true
    }
  },
  # idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
)
pp resultado.to_hash
