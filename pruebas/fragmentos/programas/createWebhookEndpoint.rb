# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.webhook_endpoints.create_webhook_endpoint(
  {
    url: 'https://tu-servidor.co/webhooks/trevol',
    description: 'Producción: facturación',
    events: ['invoice.accepted', 'invoice.rejected', 'credit_note.accepted']
  }
)
pp resultado.to_hash
