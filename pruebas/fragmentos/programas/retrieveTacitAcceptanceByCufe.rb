# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.radian_events.retrieve_tacit_acceptance_by_cufe(
  'abababababababababababababababababababababababababababababababababababababababababababababababab'
)
pp resultado.to_hash
