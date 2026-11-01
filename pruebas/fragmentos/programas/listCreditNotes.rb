# Generado por sdks/herramientas/fragmentos.mjs: el fragmento de la documentación, apuntando a Prism. No editar.
require 'trevol'

trevol = Trevol::Client.new(base_url: ENV.fetch('TREVOL_PRISM_URL'), max_retries: 0) # lee TREVOL_API_KEY

trevol.paginate { |cursor| trevol.credit_notes.list_credit_notes(limit: 100, starting_after: cursor) }.each do |item|
  puts item.id
end
