# frozen_string_literal: true

require_relative 'errors'

module Trevol
  # La llave de la API: su formato y el entorno que se deduce de su prefijo (docs/api/43 §2.6.1).
  module Llave
    FORMATO = /\Atvl_(test|live)_[0-9a-f]{64}\z/

    module_function

    # Valida la llave y devuelve su entorno: `:test` (habilitación de la DIAN) o `:live` (producción). El mensaje NUNCA incluye la llave.
    def entorno(llave)
      m = llave.is_a?(String) ? FORMATO.match(llave.strip) : nil
      raise ConfigurationError, 'La llave de la API no tiene el formato esperado (tvl_test_… o tvl_live_… con 64 caracteres hexadecimales). ' \
                                'Créala en https://platform.trevol.si/llaves y pásala completa o define TREVOL_API_KEY.' unless m

      m[1].to_sym
    end
  end
end
