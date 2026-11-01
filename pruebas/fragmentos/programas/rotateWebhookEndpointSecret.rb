# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.webhook_endpoints.rotate_webhook_endpoint_secret(
  'we_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b',
  { grace_period_hours: 24 }
)
pp resultado.to_hash
