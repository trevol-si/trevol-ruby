# frozen_string_literal: true

require 'ayudas'

# La llave de administración (tva_test_… / tva_live_…): tipo y entorno del prefijo, la empresa del cliente o de `with_company`, las
# cabeceras Trevol-Company y Trevol-Environment (solo con una tva_ y solo en las rutas de una empresa), el recurso `account` y que la
# llave no se cuele en ningún texto.
class AdministracionTest < Minitest::Test
  include Ayudas::ConServidor
  include Ayudas

  OPENAPI = Ayudas.datos('openapi.json')
  OTRA_EMPRESA = "com_#{'9' * 32}"
  CUENTA = %w[retrieveAccount listAccountCompanies createAccountCompany retrieveAccountCompany listAccountCompanyApiKeys
              createAccountCompanyApiKey revokeAccountCompanyApiKey listAccountDianDocuments listAccountRadianEvents listAccountRequests].freeze

  # El ejemplo de la respuesta 2xx de una operación, tal como lo trae la especificación pública.
  def ejemplo_respuesta(ruta, metodo)
    r = OPENAPI['paths'][ruta][metodo]['responses'].find { |codigo, _| codigo.start_with?('2') }.last
    c = r['content']['application/json']
    c['example'] || c['examples'].values.first['value']
  end

  def compania = ejemplo_respuesta('/account/companies', 'post')

  def cabeceras(b, i = 0) = b.peticiones[i][:cabeceras]

  def sin_cabeceras_de_empresa(c)
    refute c.key?('trevol-company'), c.inspect
    refute c.key?('trevol-environment'), c.inspect
  end

  # --- La llave ---

  def test_tva_test_y_tva_live_dan_el_entorno_y_key_type_account
    t = Trevol::Client.new(ADMIN_TEST)
    assert_equal [:test, :account, nil], [t.environment, t.key_type, t.company]
    assert_equal [:live, :account], [Trevol::Client.new(ADMIN_LIVE).environment, Trevol::Client.new(ADMIN_LIVE).key_type]
    assert_equal [:test, :api], [Trevol::Client.new(LLAVE_TEST).environment, Trevol::Client.new(LLAVE_TEST).key_type]
    assert_equal :live, Trevol::Client.new(LLAVE_LIVE).environment
  end

  def test_una_tva_con_espacios_alrededor_sirve_y_se_manda_sin_ellos
    b = banco(json(200, ejemplo_respuesta('/account', 'get')), llave: "  #{ADMIN_LIVE}\n")
    b.trevol.account.retrieve_account
    assert_equal "Bearer #{ADMIN_LIVE}", cabeceras(b)['authorization']
  end

  def test_lee_una_tva_de_trevol_api_key
    anterior = ENV.fetch('TREVOL_API_KEY', nil)
    ENV['TREVOL_API_KEY'] = ADMIN_LIVE
    assert_equal %i[live account], [Trevol::Client.new.environment, Trevol::Client.new.key_type]
  ensure
    anterior ? ENV['TREVOL_API_KEY'] = anterior : ENV.delete('TREVOL_API_KEY')
  end

  def test_una_tva_mal_formada_es_configurationerror_que_nombra_los_cuatro_prefijos_y_no_trae_la_llave
    malas = ["tva_test_#{'c3' * 31}", "tva_prod_#{'c3' * 32}", "tva_test_#{'C3' * 32}", "tva_live_#{'c3' * 33}", "tvx_test_#{'c3' * 32}",
             "TVA_TEST_#{'c3' * 32}", "tva-test-#{'c3' * 32}", "tva_test_#{'c3' * 32}x"]
    malas.each do |mala|
      e = assert_raises(Trevol::ConfigurationError, mala) { Trevol::Client.new(mala) }
      refute_includes e.message, mala
      refute_includes e.message, 'c3' * 8
      %w[tvl_test_ tvl_live_ tva_test_ tva_live_].each { |p| assert_includes e.message, p }
      assert_includes e.message, 'https://platform.trevol.si/llaves y la de administración en https://platform.trevol.si/administracion'
    end
  end

  def test_environment_sigue_siendo_solo_una_asercion_tambien_con_una_tva
    assert_equal :test, Trevol::Client.new(ADMIN_TEST, environment: :test).environment
    assert_equal :live, Trevol::Client.new(ADMIN_LIVE, environment: 'live').environment
    e = assert_raises(Trevol::ConfigurationError) { Trevol::Client.new(ADMIN_TEST, environment: :live) }
    assert_includes e.message, 'tva_test_'
    refute_includes e.message, 'c3' * 32
    e = assert_raises(Trevol::ConfigurationError) { Trevol::Client.new(LLAVE_LIVE, environment: :test) }
    assert_includes e.message, 'tvl_live_'
  end

  # --- La empresa ---

  def test_company_en_el_cliente_se_valida_y_se_guarda
    assert_equal EMPRESA, Trevol::Client.new(ADMIN_TEST, company: EMPRESA).company
    assert_equal EMPRESA, Trevol::Client.new(ADMIN_TEST, company: " #{EMPRESA} ").company
    ["com_#{'3F0C1A2B' * 4}", "inv_#{HEX}", "com_#{'0' * 31}", "com_#{'0' * 33}", 'com_', '', 123, :com_x].each do |mala|
      assert_raises(Trevol::ConfigurationError, mala.inspect) { Trevol::Client.new(ADMIN_TEST, company: mala) }
    end
  end

  def test_company_o_with_company_con_una_tvl_es_configurationerror
    e = assert_raises(Trevol::ConfigurationError) { Trevol::Client.new(LLAVE_TEST, company: EMPRESA) }
    assert_includes e.message, 'tva_'
    assert_includes e.message, 'tvl_'
    refute_includes e.message, 'a1' * 32
    e = assert_raises(Trevol::ConfigurationError) { Trevol::Client.new(LLAVE_LIVE).with_company(EMPRESA) }
    assert_includes e.message, 'llave de administración'
  end

  def test_with_company_mal_formada_es_configurationerror
    t = Trevol::Client.new(ADMIN_TEST)
    [nil, '', "COM_#{HEX}", "com_#{HEX}0", 42].each do |mala|
      assert_raises(Trevol::ConfigurationError, mala.inspect) { t.with_company(mala) }
    end
  end

  def test_tva_con_company_manda_trevol_company_y_trevol_environment_en_una_ruta_de_empresa
    b = banco(json(200, DOCUMENTO), llave: ADMIN_TEST, company: EMPRESA)
    b.trevol.invoices.retrieve_invoice(ID_DOC)
    c = cabeceras(b)
    assert_equal "Bearer #{ADMIN_TEST}", c['authorization']
    assert_equal EMPRESA, c['trevol-company']
    assert_equal 'test', c['trevol-environment']
    assert_empty c.keys.grep(/\Ax-trevol-/) # la marca interna con que viaja la empresa no sale a la red
  end

  def test_con_tva_live_trevol_environment_es_live
    b = banco(json(201, DOCUMENTO), llave: ADMIN_LIVE, company: EMPRESA)
    b.trevol.invoices.create_invoice(ENTRADA_FACTURA)
    c = cabeceras(b)
    assert_equal [EMPRESA, 'live'], [c['trevol-company'], c['trevol-environment']]
    refute_nil c['idempotency-key'] # lo demás del transporte sigue igual
  end

  def test_tva_sin_empresa_en_una_ruta_de_empresa_es_configurationerror_antes_de_mandar_nada
    b = banco(json(200, DOCUMENTO), llave: ADMIN_TEST)
    e = assert_raises(Trevol::ConfigurationError) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    assert_includes e.message, 'with_company'
    assert_includes e.message, 'company:'
    refute_includes e.message, 'c3' * 32
    assert_raises(Trevol::ConfigurationError) { b.trevol.invoices.create_invoice(ENTRADA_FACTURA) }
    assert_raises(Trevol::ConfigurationError) { b.trevol.general.retrieve_company }
    assert_empty b.peticiones
    assert_empty b.esperas # no es un error que se reintente
  end

  def test_tva_sin_empresa_no_se_salva_poniendo_la_cabecera_a_mano
    b = banco(json(200, DOCUMENTO), llave: ADMIN_TEST)
    assert_raises(Trevol::ConfigurationError) do
      b.trevol.invoices.retrieve_invoice(ID_DOC, header_params: { 'Trevol-Company' => EMPRESA, 'Trevol-Environment' => 'test' })
    end
    assert_empty b.peticiones
  end

  def test_la_empresa_del_cliente_gana_a_la_que_se_ponga_a_mano_y_el_ambiente_es_siempre_el_de_la_llave
    b = banco(json(200, DOCUMENTO), llave: ADMIN_TEST, company: EMPRESA)
    b.trevol.invoices.retrieve_invoice(ID_DOC, header_params: { 'Trevol-Company' => OTRA_EMPRESA, 'Trevol-Environment' => 'live' })
    assert_equal [EMPRESA, 'test'], [cabeceras(b)['trevol-company'], cabeceras(b)['trevol-environment']]
  end

  def test_una_tvl_nunca_manda_trevol_company_ni_trevol_environment
    b = banco(json(200, DOCUMENTO), json(200, DOCUMENTO))
    b.trevol.invoices.retrieve_invoice(ID_DOC)
    b.trevol.invoices.retrieve_invoice(ID_DOC, header_params: { 'Trevol-Company' => EMPRESA, 'trevol-environment' => 'test' })
    2.times { |i| sin_cabeceras_de_empresa(cabeceras(b, i)) }
  end

  def test_con_una_tvl_las_operaciones_de_account_son_configurationerror_sin_llamar
    llamadas = {
      'retrieve_account' => ->(a) { a.retrieve_account },
      'list_account_companies' => ->(a) { a.list_account_companies(limit: 2) },
      'create_account_company' => ->(a) { a.create_account_company({ nit: '900373427', name: 'DISTRIBUIDORA LOS ANDES SAS' }) },
      'retrieve_account_company' => ->(a) { a.retrieve_account_company(EMPRESA) },
      'list_account_company_api_keys' => ->(a) { a.list_account_company_api_keys(EMPRESA) },
      'create_account_company_api_key' => ->(a) { a.create_account_company_api_key(EMPRESA, { name: 'ERP', permissions: 'read' }) },
      'revoke_account_company_api_key' => ->(a) { a.revoke_account_company_api_key(EMPRESA, "key_#{HEX}") },
      'list_account_dian_documents' => ->(a) { a.list_account_dian_documents(company: EMPRESA) },
      'list_account_radian_events' => ->(a) { a.list_account_radian_events(code: '030') },
      'list_account_requests' => ->(a) { a.list_account_requests(limit: 10) }
    }
    assert_equal CUENTA.map { |op| op.gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase }.sort, llamadas.keys.sort
    [LLAVE_TEST, LLAVE_LIVE].each do |llave|
      b = banco(json(200, ejemplo_respuesta('/account', 'get')), llave: llave)
      llamadas.each do |metodo, llamar|
        e = assert_raises(Trevol::ConfigurationError, metodo) { llamar.call(b.trevol.account) }
        assert_includes e.message, "trevol.account.#{metodo} no se puede llamar con una llave de empresa (tvl_…)"
        assert_includes e.message, 'tva_test_… o tva_live_…'
        refute_includes e.message, llave
      end
      assert_empty b.peticiones
      assert_empty b.esperas # no es un error que se reintente
    end
  end

  def test_con_una_tvl_una_ruta_de_account_que_la_tabla_no_conoce_tambien_se_niega_sin_llamar
    b = banco(json(200, {}))
    e = assert_raises(Trevol::ConfigurationError) do
      b.trevol.instance_variable_get(:@api_client).call_api(:GET, '/account/algo_nuevo', header_params: {}, return_type: 'Object')
    end
    assert_includes e.message, 'GET /v1/account/algo_nuevo'
    assert_empty b.peticiones
  end

  def test_las_rutas_de_account_y_health_no_llevan_las_cabeceras_aunque_haya_empresa
    respuestas = [json(200, ejemplo_respuesta('/account', 'get')), json(200, { status: 'ok' })]
    b = banco(*respuestas, llave: ADMIN_LIVE, company: EMPRESA)
    b.trevol.account.retrieve_account
    b.trevol.general.get_health
    2.times { |i| sin_cabeceras_de_empresa(cabeceras(b, i)) }
    assert_equal %w[/v1/account /v1/health], b.peticiones.map { |p| p[:ruta] }
  end

  def test_las_rutas_de_account_sirven_sin_empresa
    b = banco(json(200, ejemplo_respuesta('/account', 'get')), llave: ADMIN_TEST)
    info = b.trevol.account.retrieve_account
    assert_equal 'account_key_info', info.object
    sin_cabeceras_de_empresa(cabeceras(b))
  end

  # --- with_company ---

  def test_with_company_da_un_cliente_derivado_que_comparte_el_transporte_y_no_toca_el_original
    b = banco(json(200, DOCUMENTO), llave: ADMIN_TEST, company: EMPRESA)
    t = b.trevol
    otra = t.with_company(OTRA_EMPRESA)
    refute_same t, otra
    assert_equal [EMPRESA, OTRA_EMPRESA], [t.company, otra.company]
    assert_equal [:test, :account, t.api_version], [otra.environment, otra.key_type, otra.api_version]
    assert_same t.instance_variable_get(:@api_client), otra.instance_variable_get(:@api_client) # misma configuración y conexión
    refute_same t.invoices, otra.invoices
    otra.invoices.retrieve_invoice(ID_DOC)
    t.invoices.retrieve_invoice(ID_DOC)
    assert_equal [OTRA_EMPRESA, EMPRESA], b.peticiones.map { |p| p[:cabeceras]['trevol-company'] }
  end

  def test_with_company_desde_un_cliente_sin_empresa
    b = banco(json(200, DOCUMENTO), llave: ADMIN_LIVE)
    b.trevol.with_company(" #{EMPRESA}").invoices.retrieve_invoice(ID_DOC)
    assert_equal [EMPRESA, 'live'], [cabeceras(b)['trevol-company'], cabeceras(b)['trevol-environment']]
    assert_nil b.trevol.company
    assert_raises(Trevol::ConfigurationError) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    assert_equal 1, b.peticiones.size
  end

  def test_with_company_y_los_reintentos_mandan_la_misma_empresa_en_cada_intento
    b = banco(problema(503, 'dian_unavailable', { retryable: true }), json(201, DOCUMENTO), llave: ADMIN_TEST)
    b.trevol.with_company(EMPRESA).invoices.create_invoice(ENTRADA_FACTURA)
    assert_equal 2, b.peticiones.size
    assert_equal [EMPRESA], b.peticiones.map { |p| p[:cabeceras]['trevol-company'] }.uniq
    assert_equal 1, b.peticiones.map { |p| p[:cabeceras]['idempotency-key'] }.uniq.size
  end

  def test_with_company_en_hilos_distintos_no_mezcla_empresas
    b = banco(json(200, DOCUMENTO), llave: ADMIN_TEST)
    empresas = Array.new(6) { |i| format('com_%032x', i + 1) }
    empresas.map { |id| Thread.new { b.trevol.with_company(id).invoices.retrieve_invoice(ID_DOC) } }.each(&:join)
    assert_equal empresas.sort, b.peticiones.map { |p| p[:cabeceras]['trevol-company'] }.sort
  end

  # --- El recurso account ---

  def test_el_recurso_account_tiene_las_diez_operaciones
    t = Trevol::Client.new(ADMIN_TEST)
    assert_kind_of TrevolGenerado::AccountApi, t.account
    CUENTA.each { |op| assert_respond_to t.account, op.gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase }
    cuenta = TrevolGenerado::Tablas::OPERACIONES.select { |o| o[:recurso] == 'Account' }
    assert_equal CUENTA.sort, cuenta.map { |o| o[:operation_id] }.sort
    assert(cuenta.all? { |o| o[:llave] == 'administracion' })
  end

  def test_la_tabla_dice_que_llave_admite_cada_operacion_igual_que_los_datos_compartidos
    datos = Ayudas.datos('operaciones.json').to_h { |o| [o['operationId'], o['llave']] }
    tabla = TrevolGenerado::Tablas::OPERACIONES.to_h { |o| [o[:operation_id], o[:llave]] }
    assert_equal datos, tabla
    assert_equal({ 'administracion' => 10, 'api_o_administracion' => 148, 'ninguna' => 1 }, tabla.values.tally)
  end

  def test_una_ruta_que_la_tabla_no_conoce_se_clasifica_por_su_forma
    l = ->(ruta) { Trevol::Transporte.llave_de(nil, ruta) }
    assert_equal %w[administracion administracion ninguna api_o_administracion api_o_administracion],
                 [l.call('/account'), l.call('/account/algo_nuevo'), l.call('/health'), l.call('/accounting'), l.call('/algo_nuevo')]
  end

  def test_crea_una_empresa_con_idempotency_key_y_sin_cabeceras_de_empresa
    b = banco(json(201, compania), llave: ADMIN_LIVE)
    c = b.trevol.account.create_account_company({ nit: '901234567', name: 'FERRETERÍA EL ROBLE SAS' })
    assert_equal %w[pending 7], [c.status, c.check_digit]
    assert_equal 'not_started', c.onboarding.step
    p = b.peticiones[0]
    assert_equal ['POST', '/v1/account/companies'], [p[:metodo], p[:ruta]]
    assert_equal({ 'nit' => '901234567', 'name' => 'FERRETERÍA EL ROBLE SAS' }, JSON.parse(p[:cuerpo]))
    assert_equal '00000000-0000-4000-8000-000000000001', p[:cabeceras]['idempotency-key']
    sin_cabeceras_de_empresa(p[:cabeceras])
  end

  def test_crea_una_llave_de_empresa_con_la_clave_de_la_persona_y_el_token_llega_una_vez
    cuerpo = ejemplo_respuesta('/account/companies/{id}/api_keys', 'post')
    b = banco(json(201, cuerpo), json(201, cuerpo.merge('token' => nil), { 'Idempotent-Replayed' => 'true' }), llave: ADMIN_TEST)
    k = b.trevol.account.create_account_company_api_key(EMPRESA, { name: 'ERP de la bodega', permissions: 'write' }, idempotency_key: 'ERP-1')
    assert_match(/\Atvl_test_/, k.token)
    k2, _estado, cab = b.trevol.account.create_account_company_api_key_with_http_info(EMPRESA, { name: 'ERP de la bodega', permissions: 'write' },
                                                                                      idempotency_key: 'ERP-1')
    assert_nil k2.token
    assert_equal 'true', cab['idempotent-replayed']
    assert_equal ["/v1/account/companies/#{EMPRESA}/api_keys"] * 2, b.peticiones.map { |p| p[:ruta] }
    assert_equal %w[ERP-1 ERP-1], b.peticiones.map { |p| p[:cabeceras]['idempotency-key'] }
  end

  # Al repetirla con la misma Idempotency-Key la API devuelve la llave con token null: un reintento a ciegas perdería el token.
  def test_crear_una_llave_de_empresa_no_se_reintenta_ante_un_5xx_ni_un_corte_y_si_ante_un_429
    op = TrevolGenerado::Tablas::OPERACIONES.find { |o| o[:operation_id] == 'createAccountCompanyApiKey' }
    assert_equal [true, 'solo_429'], [op[:idempotente], op[:reintento]]
    entrada = { name: 'ERP de la bodega', permissions: 'write' }
    a = banco(problema(503, 'dian_unavailable', { retryable: true }), llave: ADMIN_TEST)
    e = assert_raises(Trevol::DianUnavailableError) { a.trevol.account.create_account_company_api_key(EMPRESA, entrada) }
    refute_nil e.idempotency_key
    assert_equal 1, a.peticiones.size
    assert_empty a.esperas
    b = banco(CORTAR, llave: ADMIN_TEST)
    assert_raises(Trevol::APIConnectionError) { b.trevol.account.create_account_company_api_key(EMPRESA, entrada) }
    assert_equal 1, b.peticiones.size
    cuerpo = ejemplo_respuesta('/account/companies/{id}/api_keys', 'post')
    c = banco(problema(429, 'rate_limited', { retryable: true, limit: 'api_keys' }, { 'Retry-After' => '2' }), json(201, cuerpo), llave: ADMIN_TEST)
    k = c.trevol.account.create_account_company_api_key(EMPRESA, entrada)
    assert_match(/\Atvl_test_/, k.token)
    assert_equal 2, c.peticiones.size
    assert_equal [2.0], c.esperas
    assert_equal 1, c.peticiones.map { |p| p[:cabeceras]['idempotency-key'] }.uniq.size
  end

  def test_revocar_es_delete_sin_idempotency_key_y_solo_se_reintenta_con_429
    revocada = ejemplo_respuesta('/account/companies/{id}/api_keys/{key_id}', 'delete')
    b = banco(problema(503, 'internal_error', { retryable: true }), json(200, revocada), llave: ADMIN_TEST)
    assert_raises(Trevol::InternalServerError) { b.trevol.account.revoke_account_company_api_key(EMPRESA, "key_#{HEX}") }
    assert_equal 1, b.peticiones.size
    p = b.peticiones[0]
    assert_equal ['DELETE', "/v1/account/companies/#{EMPRESA}/api_keys/key_#{HEX}"], [p[:metodo], p[:ruta]]
    refute p[:cabeceras].key?('idempotency-key')
    b2 = banco(problema(429, 'rate_limited', { limit: 'api_keys' }, { 'Retry-After' => '1' }), json(200, revocada), llave: ADMIN_TEST)
    assert_equal 'revoked', b2.trevol.account.revoke_account_company_api_key(EMPRESA, "key_#{HEX}").status
    assert_equal 2, b2.peticiones.size
  end

  def test_las_consultas_de_la_cuenta_pasan_sus_filtros
    lista = { object: 'list', data: [], has_more: false, next_cursor: nil }
    b = banco(json(200, lista), llave: ADMIN_TEST)
    b.trevol.account.list_account_dian_documents(company: "#{EMPRESA},#{OTRA_EMPRESA}", direction: 'received', issued_from: '2026-11-01', limit: 5)
    ruta = b.peticiones[0][:ruta]
    assert ruta.start_with?('/v1/account/dian_documents?'), ruta
    q = URI.decode_www_form(ruta.split('?', 2).last).to_h
    assert_equal({ 'company' => "#{EMPRESA},#{OTRA_EMPRESA}", 'direction' => 'received', 'issued_from' => '2026-11-01', 'limit' => '5' }, q)
    sin_cabeceras_de_empresa(cabeceras(b))
  end

  # --- Paginación ---

  def test_paginate_recorre_las_empresas_de_la_cuenta
    a = compania.merge('id' => EMPRESA)
    c = compania.merge('id' => OTRA_EMPRESA)
    b = banco(json(200, { object: 'list', data: [a], has_more: true, next_cursor: EMPRESA }),
              json(200, { object: 'list', data: [c], has_more: false, next_cursor: nil }), llave: ADMIN_LIVE, company: EMPRESA)
    t = b.trevol
    empresas = t.paginate { |cursor| t.account.list_account_companies(limit: 1, status: 'pending', starting_after: cursor) }.to_a
    assert_equal [EMPRESA, OTRA_EMPRESA], empresas.map(&:id)
    assert_kind_of TrevolGenerado::AccountCompany, empresas.first
    assert_equal '/v1/account/companies?limit=1&status=pending', b.peticiones[0][:ruta]
    assert_equal "/v1/account/companies?limit=1&starting_after=#{EMPRESA}&status=pending", b.peticiones[1][:ruta]
    2.times { |i| sin_cabeceras_de_empresa(cabeceras(b, i)) }
  end

  def test_paginate_recorre_las_llaves_de_una_empresa
    llave = ejemplo_respuesta('/account/companies/{id}/api_keys', 'get')['data'].first
    b = banco(json(200, { object: 'list', data: [llave], has_more: true, next_cursor: llave['id'] }),
              json(200, { object: 'list', data: [], has_more: false, next_cursor: nil }), llave: ADMIN_TEST)
    t = b.trevol
    ids = t.paginate { |cursor| t.account.list_account_company_api_keys(EMPRESA, status: 'active', starting_after: cursor) }.map(&:id).to_a
    assert_equal [llave['id']], ids
    assert_equal "/v1/account/companies/#{EMPRESA}/api_keys?starting_after=#{llave['id']}&status=active", b.peticiones[1][:ruta]
  end

  def test_paginate_en_una_ruta_de_empresa_con_with_company_lleva_la_empresa_en_cada_pagina
    b = banco(json(200, { object: 'list', data: [{ id: 'inv_1' }], has_more: true, next_cursor: 'inv_1' }),
              json(200, { object: 'list', data: [{ id: 'inv_2' }], has_more: false, next_cursor: nil }), llave: ADMIN_TEST)
    e = b.trevol.with_company(EMPRESA)
    assert_equal %w[inv_1 inv_2], e.paginate { |cursor| e.invoices.list_invoices(starting_after: cursor) }.map(&:id).to_a
    assert_equal [EMPRESA, EMPRESA], b.peticiones.map { |p| p[:cabeceras]['trevol-company'] }
    assert_equal %w[test test], b.peticiones.map { |p| p[:cabeceras]['trevol-environment'] }
  end

  # --- Errores nuevos ---

  def test_company_exists_es_conflicterror_con_la_empresa_en_problem
    b = banco(problema(409, 'company_exists', { company: compania }), llave: ADMIN_LIVE)
    e = assert_raises(Trevol::ConflictError) { b.trevol.account.create_account_company({ nit: '901234567' }) }
    assert_equal ['company_exists', 409], [e.code, e.status]
    assert_equal compania['id'], e.problem[:company][:id]
    assert_equal '00000000-0000-4000-8000-000000000001', e.idempotency_key
    assert_equal 1, b.peticiones.size
  end

  def test_key_limit_reached_es_conflicterror_y_no_se_reintenta
    b = banco(problema(409, 'key_limit_reached'), llave: ADMIN_TEST)
    e = assert_raises(Trevol::ConflictError) { b.trevol.account.create_account_company_api_key(EMPRESA, { name: 'x', permissions: 'read' }) }
    assert_equal 'key_limit_reached', e.code
    assert_equal 1, b.peticiones.size
  end

  def test_company_limit_reached_es_ratelimiterror_y_no_espera_una_hora
    b = banco(problema(429, 'company_limit_reached', { retryable: true, limit: 'hour', retry_after: 3600 }, { 'Retry-After' => '3600' }),
              llave: ADMIN_LIVE)
    e = assert_raises(Trevol::RateLimitError) { b.trevol.account.create_account_company({ nit: '901234567' }) }
    assert_equal ['company_limit_reached', 429, 3600.0, 'hour'], [e.code, e.status, e.retry_after, e.problem[:limit]]
    assert e.retryable?
    assert_empty b.esperas
    assert_equal 1, b.peticiones.size
  end

  def test_environment_mismatch_y_scope_list_son_permissiondeniederror_con_reason
    b = banco(problema(403, 'permission_denied', { reason: 'environment_mismatch' }), llave: ADMIN_TEST, company: EMPRESA)
    e = assert_raises(Trevol::PermissionDeniedError) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    assert_equal 'environment_mismatch', e.problem[:reason]
    b2 = banco(problema(403, 'permission_denied', { reason: 'scope_list', required_permission: 'companies:write' }), llave: ADMIN_LIVE)
    e2 = assert_raises(Trevol::PermissionDeniedError) { b2.trevol.account.create_account_company({ nit: '901234567' }) }
    assert_equal %w[scope_list companies:write], [e2.problem[:reason], e2.problem[:required_permission]]
  end

  # --- La llave nunca en un texto ---

  def test_la_tva_no_aparece_en_inspect_to_s_errores_ni_en_la_configuracion
    b = banco(problema(401, 'invalid_api_key'), CORTAR, llave: ADMIN_LIVE, company: EMPRESA, max_retries: 0)
    t = b.trevol
    otra = t.with_company(OTRA_EMPRESA)
    e = assert_raises(Trevol::AuthenticationError) { t.invoices.retrieve_invoice(ID_DOC) }
    red = assert_raises(Trevol::APIConnectionError) { t.account.retrieve_account }
    envoltura = otra.invoices.api_client
    textos = [t.inspect, t.to_s, otra.inspect, "#{otra}", envoltura.inspect, envoltura.to_s, t.instance_variable_get(:@api_client).config.inspect,
              e.to_s, e.message, e.inspect, e.full_message, e.problem.inspect, e.headers.inspect,
              red.to_s, red.message, red.inspect, red.full_message, red.cause.inspect]
    textos.each do |x|
      refute_includes x, ADMIN_LIVE
      refute_includes x, 'd4' * 16
    end
    assert_includes t.inspect, 'key_type=:account'
    assert_includes otra.inspect, OTRA_EMPRESA
  end

  def test_las_opciones_del_transporte_no_muestran_la_tva
    o = Trevol::Transporte::Opciones.new(llave: ADMIN_TEST, tipo_llave: :account, entorno: :test, api_version: 'x')
    [o.inspect, o.to_s].each { |x| refute_includes x, 'c3' * 16 }
  end
end
