# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.numbering_requests.mark_numbering_request_submitted(
  'nreq_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b'
)
pp resultado.to_hash
