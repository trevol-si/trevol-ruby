# frozen_string_literal: true

require 'ayudas'

class ErroresTest < Minitest::Test
  include Ayudas::ConServidor
  include Ayudas

  ESTADO = { 'AuthenticationError' => 401, 'PermissionDeniedError' => 403, 'NotFoundError' => 404, 'InvalidRequestError' => 400,
             'IdempotencyError' => 409, 'ValidationError' => 422, 'ConflictError' => 409, 'PreconditionError' => 422, 'DianRejectedError' => 422,
             'BalanceError' => 402, 'RateLimitError' => 429, 'DianUnavailableError' => 503, 'InternalServerError' => 500 }.freeze
  TODOS = Ayudas.datos('errores.json')['clases'].flat_map { |clase, codes| codes.map { |code| [clase, code] } }

  def test_cubre_los_30_code
    assert_equal 30, TODOS.size
  end

  TODOS.each do |clase, code|
    define_method("test_el_code_#{code}_va_a_#{clase}_a_traves_de_un_metodo_generado") do
      b = banco(problema(ESTADO[clase], code, { retryable: false }), max_retries: 0)
      e = assert_raises(Trevol.const_get(clase)) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
      assert_instance_of Trevol.const_get(clase), e
      assert_kind_of Trevol::Error, e
      assert_equal code, e.code
      assert_equal ESTADO[clase], e.status
      assert_equal 'req_c3c3c3c3c3c3c3c3c3c3c3c3', e.request_id
      assert_equal "https://platform.trevol.si/docs/errores##{code}", e.type
      assert_equal code, e.problem[:code]
    end
  end

  def test_el_error_no_se_envuelve_en_apierror_del_codigo_generado
    b = banco(problema(404, 'not_found'))
    e = assert_raises(Trevol::NotFoundError) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    refute_kind_of TrevolGenerado::ApiError, e
  end

  def test_un_code_desconocido_es_la_clase_base_y_no_rompe
    b = banco(problema(422, 'code_del_futuro'))
    e = assert_raises(Trevol::Error) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    assert_instance_of Trevol::Error, e
    assert_equal 'code_del_futuro', e.code
  end

  {  502 => Trevol::InternalServerError, 404 => Trevol::NotFoundError, 409 => Trevol::ConflictError, 401 => Trevol::AuthenticationError }.each do |estado, clase|
    define_method("test_una_respuesta_que_no_es_json_#{estado}_da_la_clase_por_estado_con_code_nil_y_el_cuerpo_recortado") do
      html = "<html>#{'x' * 5000}</html>"
      b = banco(Respuesta.new(estado: estado, crudo: html, tipo: 'text/html', cabeceras: {}), max_retries: 0)
      e = assert_raises(clase) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
      assert_nil e.code
      assert_equal 2048, e.detail.length
    end
  end

  def test_toma_el_request_id_de_la_cabecera_cuando_el_cuerpo_no_lo_trae
    cuerpo = { type: 'x', title: 't', status: 404, code: 'not_found', retryable: false }
    b = banco(Respuesta.new(estado: 404, cuerpo: cuerpo, cabeceras: { 'Request-Id' => 'req_d4d4d4d4d4d4d4d4d4d4d4d4' }, tipo: 'application/problem+json'))
    e = assert_raises(Trevol::NotFoundError) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    assert_equal 'req_d4d4d4d4d4d4d4d4d4d4d4d4', e.request_id
  end

  def test_validationerror_trae_errors_con_field_pointer_y_message
    b = banco(problema(422, 'validation_error', { errors: [{ field: 'items', pointer: '/items', message: 'Falta' }] }))
    e = assert_raises(Trevol::ValidationError) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    x = e.errors.first
    assert_equal ['items', '/items', 'Falta'], [x[:field], x[:pointer], x[:message]]
  end

  def test_los_campos_extra_quedan_en_problem
    b = banco(problema(409, 'external_id_in_use', { existing_id: 'inv_x' }))
    e = assert_raises(Trevol::ConflictError) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    assert_equal 'inv_x', e.problem[:existing_id]
  end

  def test_la_llave_no_aparece_en_to_s_inspect_ni_backtrace_de_ningun_error
    b = banco(problema(401, 'invalid_api_key'))
    e = assert_raises(Trevol::AuthenticationError) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    [e.to_s, e.message, e.inspect, e.full_message, e.backtrace.join, b.trevol.inspect, e.problem.inspect].each do |t|
      refute_includes t, LLAVE_TEST
      refute_includes t, 'a1' * 32
    end
    assert_includes e.to_s, 'invalid_api_key'
    assert_includes e.to_s, 'HTTP 401'
    assert_includes e.to_s, 'req_'
  end

  def test_un_fallo_de_red_es_apiconnectionerror_con_la_clave_y_se_reintenta_solo_si_es_seguro
    b = banco(CORTAR)
    e = assert_raises(Trevol::APIConnectionError) { b.trevol.invoices.create_invoice(ENTRADA_FACTURA) }
    refute_nil e.idempotency_key
    assert_equal 3, b.peticiones.size # con clave: 3 intentos
    b2 = banco(CORTAR)
    assert_raises(Trevol::APIConnectionError) { b2.trevol.webhook_endpoints.create_webhook_endpoint({ url: 'https://tu-servidor.co/h', events: ['*'] }) }
    assert_equal 1, b2.peticiones.size # sin clave: un solo intento
  end

  def test_un_429_con_retry_after_mayor_que_el_maximo_no_espera_y_lanza_el_error_con_retry_after
    b = banco(problema(429, 'rate_limited', { retryable: true }, { 'Retry-After' => '120' }))
    e = assert_raises(Trevol::RateLimitError) { b.trevol.invoices.retrieve_invoice(ID_DOC) }
    assert_equal 120.0, e.retry_after
    assert_empty b.esperas
    assert_equal 1, b.peticiones.size
  end

  def test_un_202_es_un_resultado_no_un_error_ni_un_reintento
    b = banco(json(202, { id: ID_DOC, object: 'invoice', status: 'processing' }))
    doc = b.trevol.invoices.create_invoice(ENTRADA_FACTURA)
    assert_equal 'processing', doc.status
    assert_equal 1, b.peticiones.size
  end
end
