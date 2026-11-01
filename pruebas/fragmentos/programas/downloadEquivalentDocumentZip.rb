# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

archivo = trevol.equivalent_documents.download_equivalent_document_zip(
  'pos_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b'
)
puts archivo.path # un Tempfile con el ZIP
