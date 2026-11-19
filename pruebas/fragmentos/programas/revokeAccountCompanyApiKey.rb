# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.account.revoke_account_company_api_key(
  'id_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b',
  'id_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b'
)
pp resultado.to_hash
