# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

resultado = trevol.company_settings.update_company_logo(
  {
    image_base64: 'iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgAQMAAADXDu8XAAAABlBMVEX///8KZKiBydPRAAAAJ0lEQVR42mNgIAPw////AcZmQpagAcf+/////////0BDe+jlH3IAAC07DVBS46jVAAAAAElFTkSuQmCC'
  }
)
pp resultado.to_hash
