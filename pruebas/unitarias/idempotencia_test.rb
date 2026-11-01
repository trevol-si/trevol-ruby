# frozen_string_literal: true

require 'ayudas'

class IdempotenciaTest < Minitest::Test
  include Ayudas::ConServidor
  include Ayudas

  def test_genera_una_clave_y_la_repite_en_los_tres_intentos
    b = banco(problema(503, 'dian_unavailable', { retryable: true }), problema(503, 'dian_unavailable', { retryable: true }), json(201, DOCUMENTO))
    b.trevol.invoices.create_invoice(ENTRADA_FACTURA)
    claves = b.peticiones.map { |p| p[:cabeceras]['idempotency-key'] }
    assert_equal 3, claves.size
    assert_equal ['00000000-0000-4000-8000-000000000001'], claves.uniq
    assert_equal 1, b.peticiones.map { |p| p[:cuerpo] }.uniq.size # el cuerpo viaja entero en cada intento
    assert_includes b.peticiones[2][:cuerpo].delete(' '), '"external_id":"VENTA-2026-000123"'
    assert_equal 2, b.esperas.size
  end

  def test_respeta_la_clave_de_la_persona
    b = banco(json(201, DOCUMENTO))
    b.trevol.invoices.create_invoice(ENTRADA_FACTURA, idempotency_key: 'VENTA-2026-000123')
    assert_equal 'VENTA-2026-000123', b.peticiones[0][:cabeceras]['idempotency-key']
  end

  def test_una_clave_mala_se_rechaza_localmente_sin_red
    ['con espacio', 'x' * 256, 'tilde-é', ''].each do |mala|
      b = banco(json(201, DOCUMENTO))
      assert_raises(Trevol::ConfigurationError, mala) { b.trevol.invoices.create_invoice(ENTRADA_FACTURA, idempotency_key: mala) }
      assert_empty b.peticiones
    end
  end

  def test_la_lleva_el_error_para_reintentar_mas_tarde_con_la_misma
    b = banco(problema(422, 'dian_rejected'))
    e = assert_raises(Trevol::DianRejectedError) { b.trevol.invoices.create_invoice(ENTRADA_FACTURA) }
    assert_equal '00000000-0000-4000-8000-000000000001', e.idempotency_key
  end

  def test_crear_corregir_y_la_recarga_la_llevan_el_resto_no
    segun_la_ruta = lambda do |p|
      if p[:ruta].end_with?('/top_ups') then json(201, { object: 'top_up', reference: 'TRV-REC-1', amount_cop: 50_000, status: 'prepared' })
      elsif p[:ruta].end_with?('/webhook_endpoints') then json(201, { id: "we_#{'a' * 32}", object: 'webhook_endpoint', environment: 'test' })
      elsif p[:metodo] == 'POST' && p[:ruta].end_with?('/invoices') then json(201, DOCUMENTO)
      else json(200, DOCUMENTO)
      end
    end
    b = banco(segun_la_ruta)
    t = b.trevol
    t.invoices.create_invoice(ENTRADA_FACTURA)
    t.invoices.correct_invoice(ID_DOC, ENTRADA_FACTURA)
    t.balance.create_balance_top_up({ amount_cop: 50_000 })
    t.invoices.retrieve_invoice(ID_DOC)
    t.invoices.send_invoice(ID_DOC)
    t.webhook_endpoints.create_webhook_endpoint({ url: 'https://tu-servidor.co/h', events: ['*'] })
    t.invoices.preview_invoice(ENTRADA_FACTURA)
    vistas = b.peticiones.map { |p| "#{p[:metodo]} #{p[:ruta].split('?')[0]} #{p[:cabeceras].key?('idempotency-key') ? 'True' : 'False'}" }
    assert_equal ["POST /v1/invoices True", "PUT /v1/invoices/#{ID_DOC} True", 'POST /v1/balance/top_ups True', "GET /v1/invoices/#{ID_DOC} False",
                  "POST /v1/invoices/#{ID_DOC}/send False", 'POST /v1/webhook_endpoints False', 'POST /v1/invoices/preview False'], vistas
  end
end
