# frozen_string_literal: true

require 'logger'
require 'securerandom'
require 'rbconfig'
require_relative 'errors'
require_relative 'llave'
require_relative 'paginacion'
require_relative 'transporte'

module Trevol
  URL_BASE = 'https://api.trevol.si/v1'

  # El cliente de la API de Trevol: un recurso por etiqueta (`invoices`, `credit_notes`, …), cada uno con los métodos generados de la
  # especificación (`create_invoice`, `list_invoices`, `retrieve_invoice`…). Documentación: https://platform.trevol.si/docs
  #
  #   trevol = Trevol::Client.new # lee TREVOL_API_KEY; tvl_test_… → trevol.environment == :test
  class Client
    RECURSOS = {
      balance: TrevolGenerado::BalanceApi, credit_notes: TrevolGenerado::CreditNotesApi, debit_notes: TrevolGenerado::DebitNotesApi,
      equivalent_document_adjustments: TrevolGenerado::EquivalentDocumentAdjustmentsApi, equivalent_documents: TrevolGenerado::EquivalentDocumentsApi,
      events: TrevolGenerado::EventsApi, general: TrevolGenerado::GeneralApi, invoices: TrevolGenerado::InvoicesApi,
      payroll_adjustments: TrevolGenerado::PayrollAdjustmentsApi, payrolls: TrevolGenerado::PayrollsApi,
      radian_events: TrevolGenerado::RadianEventsApi, requests: TrevolGenerado::RequestsApi,
      support_document_adjustments: TrevolGenerado::SupportDocumentAdjustmentsApi, support_documents: TrevolGenerado::SupportDocumentsApi,
      webhook_endpoints: TrevolGenerado::WebhookEndpointsApi
    }.freeze

    RECURSOS.each_key { |nombre| attr_reader nombre }

    # @return [Symbol] :test (llave tvl_test_, habilitación de la DIAN) o :live (tvl_live_, producción)
    attr_reader :environment
    # @return [String] el valor de `Trevol-Version` que se manda en cada petición
    attr_reader :api_version

    # @param api_key [String, nil] `tvl_test_…` o `tvl_live_…`; si falta se lee `TREVOL_API_KEY`
    # @param api_version [String, nil] el valor de `Trevol-Version` en cada petición (por defecto `Trevol::API_VERSION`)
    # @param max_retries [Integer] reintentos tras el primer intento (3 intentos en total por defecto). 0 los apaga
    # @param timeout [Numeric] segundos por intento (65 por defecto, como el playground)
    # @param max_retry_after [Numeric] si `Retry-After` pide esperar más segundos que esto, no se espera: se lanza el error con `retry_after`
    # @param base_url [String] por defecto https://api.trevol.si/v1 (para un servidor simulado en las pruebas)
    # @param environment [Symbol, String, nil] :test o :live: si la llave no coincide, `ConfigurationError` ANTES de llamar
    # @param proxy [String, nil] URL de un proxy (se pasa a Faraday)
    # @param internos [Hash, nil] solo para pruebas: `dormir`, `azar`, `uuid` y `ahora`
    # rubocop:disable Metrics/ParameterLists
    def initialize(api_key = nil, api_version: nil, max_retries: 2, timeout: 65, max_retry_after: 60, base_url: URL_BASE, environment: nil,
                   proxy: nil, internos: nil)
      llave = api_key.nil? ? ENV.fetch('TREVOL_API_KEY', nil) : api_key
      if llave.nil? || llave.to_s.strip.empty?
        raise ConfigurationError, 'Falta la llave de la API: pásala a Trevol::Client.new(...) o define la variable de entorno TREVOL_API_KEY.'
      end

      @environment = Llave.entorno(llave)
      if environment && environment.to_sym != @environment
        raise ConfigurationError, "Pediste el entorno «#{environment}» pero la llave es de «#{@environment}» " \
                                  "(#{@environment == :test ? 'tvl_test_ = habilitación' : 'tvl_live_ = producción'})."
      end
      raise ConfigurationError, 'max_retries no puede ser negativo.' if max_retries.negative?

      @api_version = api_version || API_VERSION
      i = internos || {}
      base_url = base_url.chomp('/')
      opciones = Transporte::Opciones.new(
        llave: llave.to_s.strip, api_version: @api_version, user_agent: "trevol-ruby/#{VERSION} (ruby #{RUBY_VERSION}; +https://platform.trevol.si/docs)",
        max_reintentos: max_retries, max_retry_after: max_retry_after.to_f, ruta_base: URI.parse(base_url).path.chomp('/'),
        dormir: i[:dormir] || ->(s) { sleep(s) }, azar: i[:azar] || -> { rand }, uuid: i[:uuid] || -> { SecureRandom.uuid }, ahora: i[:ahora] || -> { Time.now }
      )
      config = TrevolGenerado::Configuration.new
      uri = URI.parse(base_url)
      config.scheme = uri.scheme
      config.host = uri.port && ![80, 443].include?(uri.port) ? "#{uri.host}:#{uri.port}" : uri.host
      config.base_path = uri.path
      config.timeout = timeout
      config.logger = Logger.new(nil) # el generado escribe «Temp file written…» en cada descarga; la persona decide qué hacer con el archivo
      config.proxy = proxy if proxy
      config.use(Transporte, opciones)
      config.configure_faraday_connection { |conexion| i[:conexion].call(conexion) } if i[:conexion]
      @api_client = TrevolGenerado::ApiClient.new(config)
      RECURSOS.each { |nombre, clase| instance_variable_set(:"@#{nombre}", clase.new(@api_client)) }
    end
    # rubocop:enable Metrics/ParameterLists

    # Recorre todas las páginas de un listado, perezosamente (`Enumerator::Lazy`):
    #
    #   trevol.paginate { |cursor| trevol.invoices.list_invoices(limit: 100, starting_after: cursor) }.each { |f| puts f.id }
    def paginate(&)
      Paginacion.paginar(&)
    end

    # La llave no se guarda en el objeto; un inspect nunca debe enseñar nada sensible.
    def inspect = "#<Trevol::Client environment=#{environment.inspect} api_version=#{api_version.inspect}>"
    alias_method :to_s, :inspect
  end
end
