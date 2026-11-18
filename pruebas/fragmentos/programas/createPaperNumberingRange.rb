# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.paper_numbering_ranges.create_paper_numbering_range(
  {
    resolution_number: '18764000004521',
    prefix: 'TP',
    from: 1,
    to: 5000,
    valid_from: '2026-01-15',
    valid_to: '2028-01-15'
  },
  # idempotency_key: 'VENTA-2026-000123' # opcional: si falta, el SDK pone una y la repite en los reintentos
)
pp resultado.to_hash
