# frozen_string_literal: true

require 'ayudas'

class ClienteTest < Minitest::Test
  include Ayudas::ConServidor
  include Ayudas

  def test_authorization_trevol_version_fija_user_agent_y_ninguna_x_trevol
    b = banco(json(200, DOCUMENTO))
    b.trevol.invoices.retrieve_invoice(ID_DOC)
    c = b.peticiones[0][:cabeceras]
    assert_equal "Bearer #{LLAVE_TEST}", c['authorization']
    assert_equal '2026-10-22', c['trevol-version']
    assert_equal '2026-10-22', Trevol::API_VERSION
    assert_match(%r{\Atrevol-ruby/#{Regexp.escape(Trevol::VERSION)} \(ruby \d+\.\d+\.\d+; \+https://platform\.trevol\.si/docs\)\z}, c['user-agent'])
    assert_equal 'application/json, application/problem+json', c['accept']
    assert_empty c.keys.grep(/\Ax-trevol-/)
    assert_empty(c.keys & %w[trevol-empresa trevol-entorno trevol-escenario])
  end

  def test_api_version_es_configurable_y_viaja_en_cada_peticion
    b = banco(json(200, DOCUMENTO), api_version: '2026-10-21')
    2.times { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    assert_equal %w[2026-10-21 2026-10-21], b.peticiones.map { |p| p[:cabeceras]['trevol-version'] }
  end

  def test_el_accept_de_una_descarga_es_el_del_archivo_y_los_bytes_llegan_intactos
    binario = [37, 80, 68, 70, 0, 255, 1, 2].pack('C*')
    b = banco(Respuesta.new(estado: 200, crudo: binario, tipo: 'application/pdf', cabeceras: {}))
    pdf = b.trevol.invoices.download_invoice_pdf(ID_DOC)
    assert_equal 'application/pdf, application/problem+json', b.peticiones[0][:cabeceras]['accept']
    assert_equal binario, File.binread(pdf.path)
    assert_equal "/v1/invoices/#{ID_DOC}/pdf", b.peticiones[0][:ruta]
  ensure
    pdf&.close!
  end

  def test_una_descarga_que_falla_da_el_error_tipado_y_un_reintento_no_mezcla_los_cuerpos
    binario = 'PDF-VALIDO'
    b = banco(problema(503, 'file_unavailable', { retryable: true }), Respuesta.new(estado: 200, crudo: binario, tipo: 'application/pdf', cabeceras: {}))
    pdf = b.trevol.invoices.download_invoice_pdf(ID_DOC)
    assert_equal binario, File.binread(pdf.path) # los bytes del error del primer intento no se cuelan en el archivo
    assert_equal 2, b.peticiones.size
    b2 = banco(problema(409, 'file_unavailable'))
    e = assert_raises(Trevol::ConflictError) { b2.trevol.invoices.download_invoice_pdf(ID_DOC) }
    assert_equal 'file_unavailable', e.code
  ensure
    pdf&.close!
  end

  def test_la_llave_live_se_usa_tal_cual
    b = banco(json(200, DOCUMENTO), llave: LLAVE_LIVE)
    b.trevol.invoices.retrieve_invoice(ID_DOC)
    assert_equal "Bearer #{LLAVE_LIVE}", b.peticiones[0][:cabeceras]['authorization']
    assert_equal :live, b.trevol.environment
  end

  def test_una_cabecera_prefer_de_la_persona_pasa
    b = banco(json(200, DOCUMENTO))
    b.trevol.invoices.retrieve_invoice(ID_DOC, header_params: { 'Prefer' => 'code=404' })
    assert_equal 'code=404', b.peticiones[0][:cabeceras]['prefer']
  end

  def test_tvl_test_es_test_y_tvl_live_es_live
    assert_equal :test, Trevol::Client.new(LLAVE_TEST).environment
    assert_equal :live, Trevol::Client.new(LLAVE_LIVE).environment
  end

  def test_lee_trevol_api_key_si_no_se_pasa
    anterior = ENV.fetch('TREVOL_API_KEY', nil)
    ENV['TREVOL_API_KEY'] = LLAVE_LIVE
    assert_equal :live, Trevol::Client.new.environment
    ENV['TREVOL_API_KEY'] = ''
    assert_raises(Trevol::ConfigurationError) { Trevol::Client.new }
    ENV.delete('TREVOL_API_KEY')
    assert_raises(Trevol::ConfigurationError) { Trevol::Client.new }
  ensure
    anterior ? ENV['TREVOL_API_KEY'] = anterior : ENV.delete('TREVOL_API_KEY')
  end

  def test_mal_formada_es_configurationerror_sin_red_y_sin_la_llave_en_el_mensaje
    ["tvl_test_abc", "tvl_prod_#{'a1' * 32}", "sk_live_#{'a1' * 32}", "tvl_test_#{'A1' * 32}", "tvl_test_#{'a1' * 33}", "tvl_test_#{'zz' * 32}", 12_345].each do |mala|
      e = assert_raises(Trevol::ConfigurationError) { Trevol::Client.new(mala) }
      refute_includes e.message, mala.to_s
    end
    assert_raises(Trevol::ConfigurationError) { Trevol::Client.new('   ') }
  end

  def test_environment_que_no_coincide_es_configurationerror_antes_de_llamar
    e = assert_raises(Trevol::ConfigurationError) { Trevol::Client.new(LLAVE_TEST, environment: :live) }
    assert_includes e.message, 'live'
    assert_raises(Trevol::ConfigurationError) { Trevol::Client.new(LLAVE_LIVE, environment: 'test') }
    assert_equal :test, Trevol::Client.new(LLAVE_TEST, environment: :test).environment
  end

  def test_ni_inspect_ni_to_s_ni_las_opciones_muestran_la_llave
    t = Trevol::Client.new(LLAVE_TEST)
    [t.inspect, t.to_s, t.instance_variable_get(:@api_client).config.inspect].each { |x| refute_includes x, 'a1' * 32 }
    opciones = Trevol::Transporte::Opciones.new(llave: LLAVE_TEST, api_version: 'x')
    refute_includes opciones.inspect, 'a1' * 32
  end

  def test_faraday_no_reintenta_por_su_cuenta
    # C14: el SDK es el único que reintenta; con max_retries 0 una caída es UN intento y no se agrega faraday-retry.
    b = banco(CORTAR, max_retries: 0)
    assert_raises(Trevol::APIConnectionError) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    assert_equal 1, b.peticiones.size
    refute defined?(Faraday::Retry), 'no debe cargarse faraday-retry'
  end

  def test_cada_etiqueta_de_openapi_sdk_json_tiene_su_recurso_en_el_cliente
    etiquetas = Ayudas.datos('tags.json')
    assert_equal etiquetas, TrevolGenerado::Tablas::ETIQUETAS
    t = Trevol::Client.new(LLAVE_TEST)
    etiquetas.each { |e| assert_respond_to t, e.gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase, e } # si la API suma un recurso, esto falla hasta agregarlo
  end

  def test_cada_operation_id_existe_como_metodo_en_su_recurso
    t = Trevol::Client.new(LLAVE_TEST)
    TrevolGenerado::Tablas::OPERACIONES.each do |o|
      recurso = o[:recurso].gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase
      assert_respond_to t.public_send(recurso), o[:operation_id].gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase, o[:operation_id]
    end
  end
end
