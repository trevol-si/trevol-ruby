# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.webhook_endpoints.update_webhook_endpoint(
  'we_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b',
  {
    description: 'Pausado mientras migramos el servidor',
    status: 'paused'
  }
)
pp resultado.to_hash
