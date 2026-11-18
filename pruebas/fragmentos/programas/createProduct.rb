# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.products.create_product(
  {
    external_id: 'ERP-SKU-CAF500',
    code: 'CAF-500',
    name: 'Café especial tostado 500 g',
    unit: '94',
    unit_price: '32000',
    taxes: [{ code: '01', rate: '5' }]
  },
  # idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
)
pp resultado.to_hash
