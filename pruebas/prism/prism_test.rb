# frozen_string_literal: true

# Contra Prism (servidor simulado desde docs/api/openapi.json, docs/api/43 §2.10.2):
#
#   sdks/herramientas/prism.sh -- bash -c 'cd sdks/ruby && bundle exec rake prism'
#
# Prism valida cada petición contra la especificación PÚBLICA: si el SDK serializa mal un cuerpo, olvida una cabecera o la Idempotency-Key,
# responde 4xx y la prueba falla (el motivo viene en la cabecera `sl-violations`, que el error conserva).
require 'ayudas'

class PrismTest < Minitest::Test
  URL = ENV.fetch('TREVOL_PRISM_URL', nil)
  LLAVE = ENV['TREVOL_API_KEY'] || "tvl_test_#{'a1' * 32}"
  OPERACIONES = Ayudas.datos('operaciones.json')

  def setup
    skip "necesita Prism: sdks/herramientas/prism.sh -- bash -c 'cd sdks/ruby && bundle exec rake prism'" unless URL
    @t = Trevol::Client.new(LLAVE, base_url: URL, max_retries: 0)
  end

  def ejemplo(op, nombre = nil)
    ejemplos = OPERACIONES.find { |o| o['operationId'] == op }['ejemplos']
    (nombre ? ejemplos.find { |e| e['nombre'] == nombre } : ejemplos.first)['valor']
  end

  def con_violaciones
    yield
  rescue Trevol::Error => e
    v = e.headers.to_h.transform_keys(&:downcase)['sl-violations']
    flunk "Prism rechazó la petición (#{e.status}): #{v}" if v
    raise
  end

  def prefer(valor) = { header_params: { 'Prefer' => valor } }

  def test_crea_una_factura_201_con_el_cuerpo_de_ejemplo
    doc = con_violaciones { @t.invoices.create_invoice(ejemplo('createInvoice')) }
    assert_equal 'invoice', doc.object
  end

  def test_crea_una_nota_credito_y_calcula_un_preview
    nc = con_violaciones { @t.credit_notes.create_credit_note(ejemplo('createCreditNote')) }
    p = con_violaciones { @t.invoices.preview_invoice(ejemplo('previewInvoice')) }
    refute_nil nc
    assert_equal 'preview', p.object
    refute_nil p.totals
  end

  def test_corrige_una_factura_rechazada_con_put
    refute_nil con_violaciones { @t.invoices.correct_invoice("inv_#{'0' * 32}", ejemplo('correctInvoice')) }
  end

  def test_lista_facturas_y_eventos_e_itera_con_tope_de_3
    [-> (c) { @t.invoices.list_invoices(limit: 2, starting_after: c) }, -> (c) { @t.events.list_events(starting_after: c) }].each do |pagina|
      vistos = con_violaciones { @t.paginate(&pagina).first(3).map(&:id) } # Prism repite siempre la misma página con has_more=true (C8)
      refute_empty vistos
    end
  end

  def test_descarga_pdf_xml_zip_y_respuesta_dian_los_bytes_llegan_y_el_tipo_es_el_correcto
    id = "inv_#{'0' * 32}"
    %i[download_invoice_pdf download_invoice_xml download_invoice_zip download_invoice_dian_response].each do |op|
      archivo = con_violaciones { @t.invoices.public_send(op, id) }
      assert_operator File.size(archivo.path), :>, 0, op.to_s
      archivo.close!
    end
    archivo, estado, cabeceras = @t.invoices.download_invoice_pdf_with_http_info(id)
    assert_equal 200, estado
    assert_includes cabeceras['content-type'], 'application/pdf'
    archivo.close!
  end

  def test_prefer_code_422_sobre_un_evento_radian_es_preconditionerror_tacit_acceptance_not_due
    e = assert_raises(Trevol::PreconditionError) do
      @t.radian_events.create_radian_event(ejemplo('createRadianEvent', 'tacita'), prefer('code=422, example=tacita'))
    end
    assert_equal 'tacit_acceptance_not_due', e.code
    assert_equal 422, e.status
  end

  def test_prefer_code_409_sobre_un_evento_radian_es_conflicterror
    e = assert_raises(Trevol::ConflictError) do
      @t.radian_events.create_radian_event(ejemplo('createRadianEvent', 'acuse'), prefer('code=409, example=duplicado'))
    end
    assert_equal 409, e.status
    assert_match(/\Arev_/, e.problem[:existing_id])
  end

  def test_prefer_code_429_es_un_error_con_status_429_retryable_y_la_clave
    e = assert_raises(Trevol::Error) { @t.invoices.create_invoice(ejemplo('createInvoice'), prefer('code=429')) }
    assert_equal 429, e.status
    assert e.retryable?
    refute_nil e.idempotency_key
  end

  def test_crea_un_endpoint_de_webhooks_y_manda_la_prueba_202
    ep = con_violaciones { @t.webhook_endpoints.create_webhook_endpoint(ejemplo('createWebhookEndpoint')) }
    entrega = con_violaciones { @t.webhook_endpoints.test_webhook_endpoint("we_#{'0' * 32}") }
    assert_equal 'webhook_endpoint', ep.object
    refute_nil entrega
  end

  def test_company_y_acquirer_devuelven_modelos_no_void
    c = con_violaciones { @t.general.retrieve_company }
    a = con_violaciones { @t.general.retrieve_dian_acquirer('31', '900373591') }
    assert_equal 'company', c.object
    assert_equal 'acquirer', a.object
  end

  def test_reintenta_contra_prism_con_la_misma_clave_y_agota_con_el_error_del_503
    esperas = []
    t = Trevol::Client.new(LLAVE, base_url: URL, max_retries: 1, internos: { dormir: ->(s) { esperas << s } })
    e = assert_raises(Trevol::Error) { t.invoices.create_invoice(ejemplo('createInvoice'), { idempotency_key: 'PRUEBA-PRISM-1' }.merge(prefer('code=503'))) }
    assert_equal 503, e.status
    assert_equal 'PRUEBA-PRISM-1', e.idempotency_key
    assert_equal 1, esperas.size
  end
end
