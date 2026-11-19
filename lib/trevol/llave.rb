# frozen_string_literal: true

require_relative 'errors'

module Trevol
  # La llave: su formato, su tipo y el entorno que se deducen de su prefijo (docs/api/43 §2.6.1).
  #
  # - `tvl_test_…` / `tvl_live_…`: la llave de UNA empresa (tipo `:api`).
  # - `tva_test_…` / `tva_live_…`: la llave de administración de una cuenta (tipo `:account`); en las rutas de una empresa va con
  #   `Trevol-Company` y `Trevol-Environment`, que pone el SDK.
  module Llave
    FORMATO = /\A(tvl|tva)_(test|live)_[0-9a-f]{64}\z/
    EMPRESA = /\Acom_[0-9a-f]{32}\z/
    TIPOS = { 'tvl' => :api, 'tva' => :account }.freeze

    Datos = Struct.new(:tipo, :entorno)

    module_function

    # Valida la llave y devuelve su tipo (`:api` o `:account`) y su entorno (`:test`, habilitación de la DIAN, o `:live`, producción).
    # El mensaje NUNCA incluye la llave.
    def analizar(llave)
      m = llave.is_a?(String) ? FORMATO.match(llave.strip) : nil
      unless m
        raise ConfigurationError, 'La llave de la API no tiene el formato esperado (tvl_test_…, tvl_live_…, tva_test_… o tva_live_… con 64 ' \
                                  'caracteres hexadecimales). La de una empresa se crea en https://platform.trevol.si/llaves y la de ' \
                                  'administración en https://platform.trevol.si/administracion; pásala completa o define TREVOL_API_KEY.'
      end

      Datos.new(TIPOS.fetch(m[1]), m[2].to_sym)
    end

    # El entorno de la llave (`:test` o `:live`).
    def entorno(llave) = analizar(llave).entorno

    # Valida el id de una empresa (`com_` y 32 caracteres hexadecimales en minúscula) y lo devuelve sin espacios alrededor.
    def empresa(company)
      id = company.is_a?(String) ? company.strip : nil
      return id if id && EMPRESA.match?(id)

      raise ConfigurationError, 'company debe ser el id de una empresa de tu cuenta: com_ seguido de 32 caracteres hexadecimales en minúscula.'
    end
  end
end
