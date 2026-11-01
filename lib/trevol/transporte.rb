# frozen_string_literal: true

require 'faraday'
require 'securerandom'
require_relative 'errors'

module Trevol
  # El transporte: lo que hace que las llamadas se comporten igual en los 7 SDK (docs/api/43 §2.6.2 a §2.6.5).
  #
  # Es un middleware de Faraday (el punto de extensión del código generado): pone las cabeceras y la Idempotency-Key, reintenta y convierte
  # toda respuesta que no es 2xx en un error tipado que atraviesa el código generado sin envolverse (`ApiClient#call_api` solo atrapa
  # `Faraday::TimeoutError` y `Faraday::ConnectionFailed`, y convierte en `ApiError` lo que le llega como respuesta).
  class Transporte < Faraday::Middleware
    ESTADOS_REINTENTABLES = [429, 500, 502, 503, 504].freeze
    CODES_EN_CURSO = %w[request_in_progress previous_event_pending].freeze
    PROBLEMA = 'application/problem+json'
    ACCEPT = {
      'pdf' => "application/pdf, #{PROBLEMA}", 'xml' => "application/xml, #{PROBLEMA}", 'zip' => "application/zip, #{PROBLEMA}"
    }.tap { |h| h.default = "application/json, #{PROBLEMA}" }.freeze
    CLAVE_VALIDA = /\A[!-~]{1,255}\z/

    # Qué pasó en un intento: `tipo` :respuesta (con `estado`) o :red (sin respuesta). `retry_after` en segundos, ya resuelto.
    Resultado = Struct.new(:tipo, :estado, :code, :retryable, :retry_after, keyword_init: true)
    Decision = Struct.new(:reintentar, :espera, :motivo)

    # Lo que necesita el middleware. La llave nunca sale en un inspect.
    Opciones = Struct.new(:llave, :api_version, :user_agent, :max_reintentos, :max_retry_after, :ruta_base, :dormir, :azar, :uuid, :ahora, keyword_init: true) do
      def inspect = "#<Trevol::Transporte::Opciones api_version=#{api_version.inspect} max_reintentos=#{max_reintentos.inspect}>"
      alias_method :to_s, :inspect
    end

    class << self
      # La espera propia antes del intento siguiente: 0,5 · 2^(intento−1), con tope de 8 s, por un factor al azar en [0,75; 1].
      def espera_propia(intento, azar)
        [0.5 * (2**(intento - 1)), 8.0].min * (0.75 + (0.25 * azar))
      end

      # Función PURA: ¿se reintenta y cuánto se espera? Las mismas reglas y los mismos casos (`pruebas/datos/transporte.json`) en los 7 SDK.
      def decidir(intento:, reintento:, max_reintentos:, max_retry_after:, azar:, resultado:)
        r = resultado
        return Decision.new(false, nil, 'exito') if r.tipo == :respuesta && r.estado && r.estado >= 200 && r.estado < 300

        reintentable =
          if r.tipo == :red
            reintento == 'seguro'
          elsif reintento == 'solo_429'
            r.estado == 429
          elsif r.estado == 402
            false
          else
            ESTADOS_REINTENTABLES.include?(r.estado) || CODES_EN_CURSO.include?(r.code) || r.retryable == true
          end
        return Decision.new(false, nil, nil) unless reintentable
        return Decision.new(false, nil, 'agotado') if intento > max_reintentos

        propia = espera_propia(intento, azar)
        pedida = r.tipo == :respuesta && r.retry_after && r.retry_after.positive? ? r.retry_after : 0.0
        return Decision.new(false, nil, 'retry_after_excede') if pedida > max_retry_after

        Decision.new(true, [pedida, propia].max, nil)
      end

      def validar_clave(clave)
        return if clave.is_a?(String) && CLAVE_VALIDA.match?(clave)

        raise ConfigurationError, 'La idempotency_key debe tener de 1 a 255 caracteres ASCII visibles (sin espacios).'
      end

      # La operación (tablas) de un método y una ruta SIN el prefijo /v1. Las rutas fijas ganan a las plantillas
      # (GET /radian_events/tacit_acceptance frente a GET /radian_events/{id}).
      def operacion(metodo, ruta)
        indices[:exactas]["#{metodo} #{ruta}"] ||
          indices[:plantillas].find { |o, re| o[:metodo] == metodo && re.match?(ruta) }&.first
      end

      private

      def indices
        @indices ||= begin
          exactas = {}
          plantillas = []
          TrevolGenerado::Tablas::OPERACIONES.each do |o|
            if o[:ruta].include?('{')
              plantillas << [o, Regexp.new("\\A#{Regexp.escape(o[:ruta]).gsub(/\\\{[a-z_]+\\\}/, '[^/]+')}\\z")]
            else
              exactas["#{o[:metodo]} #{o[:ruta]}"] = o
            end
          end
          { exactas: exactas, plantillas: plantillas }
        end
      end
    end

    def initialize(app, opciones)
      super(app)
      @o = opciones
    end

    def call(env)
      metodo = env.method.to_s.upcase
      ruta = env.url.path
      ruta = ruta.delete_prefix(@o.ruta_base) unless @o.ruta_base.to_s.empty?
      op = self.class.operacion(metodo, ruta)
      reintento = op ? op[:reintento] : (metodo == 'GET' ? 'seguro' : 'solo_429')

      # La Idempotency-Key: una por llamada, la misma en todos los reintentos.
      clave = nil
      if op && op[:idempotente]
        dada = env.request_headers['Idempotency-Key']
        if dada.nil?
          clave = @o.uuid.call
        else
          self.class.validar_clave(dada)
          clave = dada
        end
        env.request_headers['Idempotency-Key'] = clave
      else
        env.request_headers.delete('Idempotency-Key')
      end
      h = env.request_headers
      h['Authorization'] = "Bearer #{@o.llave}"
      h['Trevol-Version'] = @o.api_version
      h['User-Agent'] = @o.user_agent
      h['Accept'] = ACCEPT[op && op[:binario]]

      cuerpo_pedido = env.body
      destino = env.request.on_data # descarga en flujo: se junta por intento y solo la 2xx llega a quien la pidió
      intento = 0
      loop do
        intento += 1
        env.body = cuerpo_pedido
        trozos = []
        env.request.on_data = proc { |trozo, *| trozos << trozo.dup } if destino
        respuesta = nil
        causa = nil
        begin
          respuesta = @app.call(env)
        rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
          causa = e
        end

        if respuesta
          estado = respuesta.status
          if estado >= 200 && estado < 300
            if destino
              total = 0
              trozos.each { |t| total += t.bytesize; destino.call(t, total) }
              env.request.on_data = destino
            end
            return respuesta
          end
          texto = respuesta.body.to_s
          texto = trozos.join if texto.empty? && !trozos.empty?
          error = Errores.de_respuesta(estado, texto.dup.force_encoding('UTF-8').scrub, respuesta.headers, clave, @o.ahora.call)
          decision = self.class.decidir(
            intento: intento, reintento: reintento, max_reintentos: @o.max_reintentos, max_retry_after: @o.max_retry_after, azar: @o.azar.call,
            resultado: Resultado.new(tipo: :respuesta, estado: estado, code: error.code, retryable: error.retryable, retry_after: error.retry_after)
          )
          raise error unless decision.reintentar
        else
          decision = self.class.decidir(
            intento: intento, reintento: reintento, max_reintentos: @o.max_reintentos, max_retry_after: @o.max_retry_after, azar: @o.azar.call,
            resultado: Resultado.new(tipo: :red)
          )
          unless decision.reintentar
            raise APIConnectionError.new("No pude conectar con la API de Trevol (#{causa.message.to_s[0, 200]}).", idempotency_key: clave), cause: causa
          end
        end
        @o.dormir.call(decision.espera || 0.0)
      end
    end
  end
end
