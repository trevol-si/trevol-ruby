# frozen_string_literal: true

require 'delegate'
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
  #
  # Con una llave de administración (`tva_test_…` o `tva_live_…`), `trevol.account` maneja la cuenta y las rutas de una empresa
  # piden la empresa: `Trevol::Client.new(llave, company: 'com_…')` o, por llamada, `trevol.with_company('com_…')`.
  class Client
    SOLO_ADMINISTRACION = 'company solo aplica a una llave de administración (tva_…): una llave tvl_ ya es de una empresa.'

    # El ApiClient generado, compartido, con la empresa de un cliente: la deja en cada petición para que el transporte la convierta en
    # Trevol-Company y Trevol-Environment. Conexión, configuración y transporte son los del cliente del que sale. @api private
    class ApiClientConEmpresa < SimpleDelegator
      def initialize(api_client, empresa)
        super(api_client)
        @empresa = empresa
      end

      def call_api(http_method, path, opts = {})
        cabeceras = (opts[:header_params] || {}).merge(Transporte::MARCA_EMPRESA => @empresa)
        __getobj__.call_api(http_method, path, opts.merge(header_params: cabeceras))
      end

      def inspect = "#<Trevol::Client::ApiClientConEmpresa company=#{@empresa.inspect}>"
      alias_method :to_s, :inspect
    end

    RECURSOS = {
      account: TrevolGenerado::AccountApi,
      balance: TrevolGenerado::BalanceApi, credit_notes: TrevolGenerado::CreditNotesApi, debit_notes: TrevolGenerado::DebitNotesApi,
      equivalent_document_adjustments: TrevolGenerado::EquivalentDocumentAdjustmentsApi, equivalent_documents: TrevolGenerado::EquivalentDocumentsApi,
      events: TrevolGenerado::EventsApi, general: TrevolGenerado::GeneralApi, invoices: TrevolGenerado::InvoicesApi,
      payroll_adjustments: TrevolGenerado::PayrollAdjustmentsApi, payrolls: TrevolGenerado::PayrollsApi,
      radian_events: TrevolGenerado::RadianEventsApi, requests: TrevolGenerado::RequestsApi,
      support_document_adjustments: TrevolGenerado::SupportDocumentAdjustmentsApi, support_documents: TrevolGenerado::SupportDocumentsApi,
      webhook_endpoints: TrevolGenerado::WebhookEndpointsApi,
      customers: TrevolGenerado::CustomersApi,
      dian_documents: TrevolGenerado::DianDocumentsApi,
      dian_syncs: TrevolGenerado::DianSyncsApi,
      invoice_batches: TrevolGenerado::InvoiceBatchesApi,
      numbering_associations: TrevolGenerado::NumberingAssociationsApi,
      numbering_ranges: TrevolGenerado::NumberingRangesApi,
      numbering_requests: TrevolGenerado::NumberingRequestsApi,
      paper_numbering_ranges: TrevolGenerado::PaperNumberingRangesApi,
      products: TrevolGenerado::ProductsApi,
      radian_status: TrevolGenerado::RadianStatusApi,
      report_runs: TrevolGenerado::ReportRunsApi,
      reports: TrevolGenerado::ReportsApi,
      # 0.4.0: las listas de valores y el diseño del PDF (plantillas, diseños, ajustes y logo de la empresa).
      catalogs: TrevolGenerado::CatalogsApi,
      company_settings: TrevolGenerado::CompanySettingsApi,
      pdf_designs: TrevolGenerado::PdfDesignsApi,
      pdf_templates: TrevolGenerado::PdfTemplatesApi
    }.freeze

    RECURSOS.each_key { |nombre| attr_reader nombre }

    # @return [Symbol] :test (llave tvl_test_ o tva_test_, habilitación de la DIAN) o :live (tvl_live_ o tva_live_, producción)
    attr_reader :environment
    # @return [Symbol] :api (tvl_, la llave de una empresa) o :account (tva_, la llave de administración de una cuenta)
    attr_reader :key_type
    # @return [String, nil] la empresa (`com_…`) a la que van las rutas de una empresa con una llave de administración; nil si no hay
    attr_reader :company
    # @return [String] el valor de `Trevol-Version` que se manda en cada petición
    attr_reader :api_version

    # @param api_key [String, nil] `tvl_test_…`, `tvl_live_…`, `tva_test_…` o `tva_live_…`; si falta se lee `TREVOL_API_KEY`
    # @param api_version [String, nil] el valor de `Trevol-Version` en cada petición (por defecto `Trevol::API_VERSION`)
    # @param max_retries [Integer] reintentos tras el primer intento (3 intentos en total por defecto). 0 los apaga
    # @param timeout [Numeric] segundos por intento (65 por defecto, como el playground)
    # @param max_retry_after [Numeric] si `Retry-After` pide esperar más segundos que esto, no se espera: se lanza el error con `retry_after`
    # @param base_url [String] por defecto https://api.trevol.si/v1 (para un servidor simulado en las pruebas)
    # @param environment [Symbol, String, nil] :test o :live: si la llave no coincide, `ConfigurationError` ANTES de llamar
    # @param company [String, nil] solo con una llave de administración: la empresa (`com_…`) de las rutas de una empresa
    # @param proxy [String, nil] URL de un proxy (se pasa a Faraday)
    # @param internos [Hash, nil] solo para pruebas: `dormir`, `azar`, `uuid` y `ahora`
    # rubocop:disable Metrics/ParameterLists
    def initialize(api_key = nil, api_version: nil, max_retries: 2, timeout: 65, max_retry_after: 60, base_url: URL_BASE, environment: nil,
                   company: nil, proxy: nil, internos: nil)
      llave = api_key.nil? ? ENV.fetch('TREVOL_API_KEY', nil) : api_key
      if llave.nil? || llave.to_s.strip.empty?
        raise ConfigurationError, 'Falta la llave de la API: pásala a Trevol::Client.new(...) o define la variable de entorno TREVOL_API_KEY.'
      end

      datos = Llave.analizar(llave)
      @environment = datos.entorno
      @key_type = datos.tipo
      if environment && environment.to_s != @environment.to_s
        prefijo = @key_type == :account ? 'tva' : 'tvl'
        raise ConfigurationError, "Pediste el entorno «#{environment}» pero la llave es de «#{@environment}» " \
                                  "(#{@environment == :test ? "#{prefijo}_test_ = habilitación" : "#{prefijo}_live_ = producción"})."
      end
      unless company.nil?
        raise ConfigurationError, SOLO_ADMINISTRACION if @key_type == :api

        @company = Llave.empresa(company)
      end
      raise ConfigurationError, 'max_retries no puede ser negativo.' if max_retries.negative?

      @api_version = api_version || API_VERSION
      i = internos || {}
      base_url = base_url.chomp('/')
      opciones = Transporte::Opciones.new(
        llave: llave.to_s.strip, tipo_llave: @key_type, entorno: @environment, api_version: @api_version, user_agent: "trevol-ruby/#{VERSION} (ruby #{RUBY_VERSION}; +https://platform.trevol.si/docs)",
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
      crear_recursos
    end
    # rubocop:enable Metrics/ParameterLists

    # Un cliente igual a este para otra empresa de la cuenta (solo con una llave de administración). Es barato: comparte la llave, la
    # configuración, el transporte y la conexión; solo cambia la empresa que viaja en Trevol-Company.
    #
    #   trevol.with_company('com_3f0c1a2b3f0c1a2b3f0c1a2b3f0c1a2b').invoices.list_invoices(limit: 10)
    def with_company(company)
      raise ConfigurationError, SOLO_ADMINISTRACION if key_type == :api

      id = Llave.empresa(company)
      derivado = dup
      derivado.instance_variable_set(:@company, id)
      derivado.send(:crear_recursos)
      derivado
    end

    # Recorre todas las páginas de un listado, perezosamente (`Enumerator::Lazy`):
    #
    #   trevol.paginate { |cursor| trevol.invoices.list_invoices(limit: 100, starting_after: cursor) }.each { |f| puts f.id }
    def paginate(&)
      Paginacion.paginar(&)
    end

    # La llave no se guarda en el objeto; un inspect nunca debe enseñar nada sensible.
    def inspect
      empresa = company ? " company=#{company.inspect}" : ''
      "#<Trevol::Client environment=#{environment.inspect} key_type=#{key_type.inspect}#{empresa} api_version=#{api_version.inspect}>"
    end
    alias_method :to_s, :inspect

    private

    # Un recurso por etiqueta, sobre el ApiClient compartido; con una empresa, a través de la envoltura que la deja en cada petición.
    def crear_recursos
      cliente = company ? ApiClientConEmpresa.new(@api_client, company) : @api_client
      RECURSOS.each { |nombre, clase| instance_variable_set(:"@#{nombre}", clase.new(cliente)) }
    end
  end
end
