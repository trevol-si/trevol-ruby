# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.company_settings.update_pdf_settings(
  {
    letter_design_id: 'pdd_7d3e9a107d3e9a107d3e9a107d3e9a10',
    receipt_design_id: 'pdd_41b2c6f041b2c6f041b2c6f041b2c6f0'
  }
)
pp resultado.to_hash
