# frozen_string_literal: true

require 'json'
require 'time'

module Trevol
  # La base de todos los errores del SDK (docs/api/43 §2.6.5): un `rescue Trevol::Error` ya lo atrapa todo.
  #
  # Toda respuesta que no es 2xx llega como una subclase, según el `code` del problem+json (el mismo vocabulario que
  # https://platform.trevol.si/docs/errores). Ninguna lleva la llave ni las cabeceras de la PETICIÓN.
  class Error < StandardError
    # @return [Integer, nil] el estado HTTP (nil si no hubo respuesta)
    attr_reader :status
    # @return [String, nil] el `code` del problem+json
    attr_reader :code
    attr_reader :type, :title, :detail, :request_id, :retryable, :retry_after, :idempotency_key, :problem, :headers
    # @return [Array<Hash>] las `errors[]` de un 422: `{field:, pointer:, message:}`
    attr_reader :errors

    # rubocop:disable Metrics/ParameterLists
    def initialize(message = nil, status: nil, code: nil, type: nil, title: nil, detail: nil, request_id: nil, retryable: nil,
                   retry_after: nil, errors: [], idempotency_key: nil, problem: nil, headers: {})
      super(message)
      @status = status
      @code = code
      @type = type
      @title = title
      @detail = detail
      @request_id = request_id
      @retryable = retryable
      @retry_after = retry_after # segundos
      @errors = errors
      # La Idempotency-Key de la llamada: úsala para reintentar más tarde con la MISMA clave.
      @idempotency_key = idempotency_key
      # El cuerpo problem+json completo, con los campos extra (existing_id, reason, document, rules…), con claves símbolo.
      @problem = problem
      # Las cabeceras de la RESPUESTA.
      @headers = headers
    end
    # rubocop:enable Metrics/ParameterLists

    def retryable? = retryable == true

    # Clase, code, estado, detalle y request_id; nunca la llave ni cabeceras de la petición.
    def to_s
      partes = [self.class.name.to_s.split('::').last]
      partes << code if code
      partes << "HTTP #{status}" if status
      cola = request_id ? " [request_id=#{request_id}]" : ''
      "#{partes.join(' ')}: #{detail || title || super}#{cola}"
    end

    def inspect = "#<#{self.class} code=#{code.inspect} status=#{status.inspect} request_id=#{request_id.inspect}>"
  end

  class AuthenticationError < Error; end
  class PermissionDeniedError < Error; end
  class NotFoundError < Error; end
  class InvalidRequestError < Error; end
  class IdempotencyError < Error; end
  # 422 `validation_error`: `errors` dice qué campo (`pointer`) y por qué.
  class ValidationError < Error; end
  class ConflictError < Error; end
  class PreconditionError < Error; end
  # 422 `dian_rejected`: `problem[:document]` trae el documento y `problem[:rules]` las reglas que la DIAN aplicó.
  class DianRejectedError < Error; end
  class BalanceError < Error; end
  class RateLimitError < Error; end
  class DianUnavailableError < Error; end
  class InternalServerError < Error; end
  # No hubo respuesta: red, DNS, TLS o tiempo agotado. Lleva la `idempotency_key` para reintentar sin duplicar.
  class APIConnectionError < Error; end
  # Mal uso del SDK, antes de llamar: llave mal formada, entorno que no coincide. Nunca incluye la llave.
  class ConfigurationError < Error; end

  # La firma, la fecha o las cabeceras de un webhook no son válidas. `reason`: :firma, :fecha, :cabeceras o :cuerpo.
  class WebhookVerificationError < Error
    attr_reader :reason

    def initialize(message, reason)
      super(message)
      @reason = reason
    end
  end

  # Convierte una respuesta que no es 2xx en su error tipado. @api private
  module Errores
    RECORTE = 2048

    CLASES = {
      'AuthenticationError' => AuthenticationError, 'PermissionDeniedError' => PermissionDeniedError, 'NotFoundError' => NotFoundError,
      'InvalidRequestError' => InvalidRequestError, 'IdempotencyError' => IdempotencyError, 'ValidationError' => ValidationError,
      'ConflictError' => ConflictError, 'PreconditionError' => PreconditionError, 'DianRejectedError' => DianRejectedError,
      'BalanceError' => BalanceError, 'RateLimitError' => RateLimitError, 'DianUnavailableError' => DianUnavailableError,
      'InternalServerError' => InternalServerError
    }.freeze

    module_function

    def numero(valor)
      return nil if valor == true || valor == false || valor.nil?

      n = valor.is_a?(String) ? Float(valor.strip, exception: false) : valor
      n.is_a?(Numeric) && n.finite? && n >= 0 ? n.to_f : nil
    end

    # El valor de `Retry-After`: segundos o una fecha HTTP. nil si no está o no se entiende.
    def leer_retry_after(valor, ahora = Time.now)
      return nil if valor.nil? || valor.to_s.strip.empty?

      n = numero(valor)
      return n if n

      fecha = Time.httpdate(valor.to_s.strip)
      [(fecha - ahora).ceil, 0].max.to_f
    rescue ArgumentError
      nil
    end

    # El cuerpo se lee como un mapa TOLERANTE (nunca con el modelo generado: un `code` nuevo o un campo que falta no puede romper el
    # manejo de errores).
    def de_respuesta(estado, texto, cabeceras, idempotency_key, ahora = Time.now)
      cab = cabeceras.to_h.transform_keys { |k| k.to_s.downcase }
      cuerpo = begin
        j = JSON.parse(texto.to_s, symbolize_names: true)
        j.is_a?(Hash) ? j : nil
      rescue JSON::ParserError
        nil
      end
      cadena = ->(clave) { cuerpo && cuerpo[clave].is_a?(String) ? cuerpo[clave] : nil }
      code = cadena.call(:code)
      detail = cadena.call(:detail)
      title = cadena.call(:title)
      errores = cuerpo && cuerpo[:errors].is_a?(Array) ? cuerpo[:errors].grep(Hash).map { |x| { field: nil, pointer: nil, message: nil }.merge(x) } : []
      retryable = cuerpo && [true, false].include?(cuerpo[:retryable]) ? cuerpo[:retryable] : nil
      retry_after = leer_retry_after(cab['retry-after'], ahora) || numero(cuerpo && cuerpo[:retry_after])
      mensaje = detail || title || (cuerpo ? "La API respondió #{estado}" : "La API respondió #{estado} sin problem+json")
      nombre = if code
                 TrevolGenerado::Tablas::CLASE_POR_CODE[code] # un code que el SDK no conoce (la API sumó uno) da la base, nunca rompe
               else
                 TrevolGenerado::Tablas::CLASE_POR_ESTADO[estado.to_s] || (estado >= 500 ? TrevolGenerado::Tablas::CLASE_POR_ESTADO['5xx'] : nil)
               end
      clase = CLASES.fetch(nombre, Error)
      clase.new(
        mensaje, status: estado, code: code, type: cadena.call(:type), title: title,
                 detail: cuerpo ? detail : (texto.to_s.strip[0, RECORTE].then { |t| t.empty? ? nil : t }),
                 request_id: cadena.call(:request_id) || cab['request-id'], retryable: retryable, retry_after: retry_after,
                 errors: errores, idempotency_key: idempotency_key, problem: cuerpo, headers: cabeceras.to_h
      )
    end
  end
end
