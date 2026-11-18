# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

archivo = trevol.reports.export_documents(
  'csv',
  '2026-09-01',
  '2026-10-31'
)
puts archivo.path # un Tempfile con el CSV
