# frozen_string_literal: true

require 'base64'
require 'json'
require 'standardwebhooks'
require_relative 'errors'

module Trevol
  # Verificación de webhooks (docs/api/43 §2.6.9): Standard Webhooks sobre el CUERPO CRUDO (`request.raw_post`, `request.body.read`).
  #
  # La firma esperada la calcula la biblioteca abierta `standardwebhooks` (`StandardWebhooks::Webhook#sign`); la tolerancia de 5 minutos
  # (con reloj inyectable en las pruebas), las cabeceras (en cualquier caja) y la comparación en tiempo constante son de este SDK: la
  # biblioteca no deja inyectar el reloj, solo acepta cabeceras en minúsculas y entrega un Hash en vez del evento generado.
  class Webhook
    TOLERANCIA = 300 # segundos, hacia atrás y hacia adelante
    NOMBRES = %w[webhook-id webhook-timestamp webhook-signature].freeze

    # @param secret [String] el secreto del endpoint (`whsec_…`), que se muestra una sola vez al crearlo o rotarlo
    # @param ahora [#call, nil] solo para pruebas: el reloj, en segundos
    def initialize(secret, ahora: nil)
      secret = secret.to_s.strip
      raise ConfigurationError, 'Falta el secreto del webhook (whsec_…). Se muestra una sola vez al crear o rotar el endpoint.' if secret.empty? || secret == 'whsec_'

      sin_prefijo = secret.delete_prefix('whsec_')
      crudo = begin
        Base64.strict_decode64(sin_prefijo)
      rescue ArgumentError
        nil
      end
      raise ConfigurationError, 'El secreto del webhook no tiene el formato esperado (whsec_ + base64).' if crudo.nil? || crudo.empty?

      @firmador = StandardWebhooks::Webhook.new(secret)
      @ahora = ahora || -> { Time.now.to_i }
    end

    # Las tres cabeceras en minúsculas, venga lo que venga (un Hash, `request.headers`, una lista de pares, valores en arreglo).
    # La primera repetida gana.
    def self.normalizar_cabeceras(cabeceras)
      pares = cabeceras.respond_to?(:each_pair) ? cabeceras.each_pair.to_a : Array(cabeceras)
      salida = {}
      pares.each do |k, v|
        nombre = k.to_s.downcase.tr('_', '-').sub(/\Ahttp-/, '')
        v = v.first if v.is_a?(Array)
        salida[nombre] ||= v.to_s if NOMBRES.include?(nombre) && !v.nil?
      end
      salida
    end

    # Verifica la firma y la fecha de una entrega y devuelve el evento (`TrevolGenerado::Event`).
    # Lanza `Trevol::WebhookVerificationError` si algo no cuadra.
    #
    # Ojo: la verificación NO evita repeticiones dentro de los 5 minutos ni los reintentos de entrega: deduplica por `webhook-id`.
    def verify(body, headers)
      unless body.is_a?(String)
        raise WebhookVerificationError.new(
          'El cuerpo del webhook debe ser el CUERPO CRUDO (String), no un objeto ya parseado: la firma se calcula sobre los bytes exactos. ' \
          'En Rails usa request.raw_post; en Sinatra, request.body.read.', :cuerpo
        )
      end
      texto = body.dup.force_encoding('UTF-8')
      raise WebhookVerificationError.new('El cuerpo del webhook no es UTF-8.', :cuerpo) unless texto.valid_encoding?

      h = self.class.normalizar_cabeceras(headers)
      NOMBRES.each do |n|
        raise WebhookVerificationError.new("Falta la cabecera #{n}.", :cabeceras) if h[n].to_s.empty?
      end
      raise WebhookVerificationError.new('El webhook-timestamp no es un número de segundos.', :fecha) unless h['webhook-timestamp'].match?(/\A[0-9]{1,12}\z/)

      marca = h['webhook-timestamp'].to_i
      if (@ahora.call - marca).abs > TOLERANCIA
        raise WebhookVerificationError.new('La fecha del webhook está fuera de la tolerancia de 5 minutos.', :fecha)
      end

      esperada = @firmador.sign(h['webhook-id'], marca.to_s, texto).split(',', 2)[1].to_s
      coincide = false
      h['webhook-signature'].split(' ').each do |firma|
        version, valor = firma.split(',', 2)
        coincide = true if version == 'v1' && valor && StandardWebhooks.secure_compare(esperada, valor) # basta una válida (rotación del secreto)
      end
      unless coincide
        raise WebhookVerificationError.new('La firma del webhook no coincide: revisa el secreto y que el cuerpo sea el crudo, sin reescribir.', :firma)
      end

      begin
        TrevolGenerado::Event.build_from_hash(JSON.parse(texto, symbolize_names: true))
      rescue StandardError
        raise WebhookVerificationError.new('El cuerpo firmado no es un evento válido.', :cuerpo)
      end
    end

    # El `data` del evento como el modelo de su `type` (p. ej. `TrevolGenerado::DocumentEventData` para `invoice.accepted`). nil si el tipo
    # es nuevo y este SDK todavía no lo conoce: el evento no se pierde, `evento.data` sigue ahí como Hash.
    def event_data(evento)
      nombre = TrevolGenerado::Tablas::EVENTO_MODELOS[evento.type.to_s]
      return nil if nombre.nil? || evento.data.nil?

      TrevolGenerado.const_get(nombre).build_from_hash(evento.data)
    end
  end
end
