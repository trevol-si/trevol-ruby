# frozen_string_literal: true

require 'ayudas'
require 'base64'
require 'openssl'

class WebhookTest < Minitest::Test
  VECTORES = Ayudas.datos('webhooks.json')
  CASOS = VECTORES['casos']
  OK = CASOS.find { |c| c['nombre'] == 'valido' }

  def verificador(secreto, ahora) = Trevol::Webhook.new(secreto, ahora: -> { ahora })

  def test_la_tolerancia_es_de_5_minutos
    assert_equal 300, VECTORES['tolerancia']
    assert_equal 300, Trevol::Webhook::TOLERANCIA
  end

  CASOS.each_with_index do |caso, i|
    define_method("test_vectores_de_pruebas_datos_webhooks_json_#{i}_#{caso['nombre'].gsub(/\W+/, '_')[0, 50]}") do
      wh = verificador(caso['secreto'], caso['ahora'])
      if caso['valido']
        e = wh.verify(caso['cuerpo'], caso['cabeceras'])
        assert_equal caso['evento']['id'], e.id
        assert_equal caso['evento']['type'], e.type.to_s
      else
        err = assert_raises(Trevol::WebhookVerificationError) { wh.verify(caso['cuerpo'], caso['cabeceras']) }
        assert_equal caso['motivo'].to_sym, err.reason
      end
    end
  end

  def test_cabeceras_de_cualquier_caja_valores_en_lista_y_formato_rack
    wh = verificador(OK['secreto'], OK['ahora'])
    c = OK['cabeceras']
    assert wh.verify(OK['cuerpo'], { 'Webhook-Id' => c['webhook-id'], 'WEBHOOK-TIMESTAMP' => [c['webhook-timestamp']], 'webhook-signature' => c['webhook-signature'] }).id
    assert wh.verify(OK['cuerpo'], { 'HTTP_WEBHOOK_ID' => c['webhook-id'], 'HTTP_WEBHOOK_TIMESTAMP' => c['webhook-timestamp'], 'HTTP_WEBHOOK_SIGNATURE' => c['webhook-signature'] }).id
    assert wh.verify(OK['cuerpo'], c.to_a).id # una lista de pares
  end

  def test_un_cuerpo_ya_parseado_se_rechaza_diciendo_como_leer_el_crudo
    e = assert_raises(Trevol::WebhookVerificationError) { verificador(OK['secreto'], OK['ahora']).verify(JSON.parse(OK['cuerpo']), OK['cabeceras']) }
    assert_match(/CRUDO/, e.message)
    assert_includes e.message, 'raw_post'
    assert_equal :cuerpo, e.reason
  end

  def test_un_secreto_vacio_o_con_basura_es_configurationerror_y_no_se_filtra
    ['', '   ', 'whsec_'].each { |malo| assert_raises(Trevol::ConfigurationError) { Trevol::Webhook.new(malo) } }
    e = assert_raises(Trevol::ConfigurationError) { Trevol::Webhook.new('whsec_@@@@@') }
    refute_includes e.message, '@@@'
  end

  def test_event_data_da_el_modelo_segun_el_type_y_un_type_nuevo_da_nil
    wh = verificador(OK['secreto'], OK['ahora'])
    e = wh.verify(OK['cuerpo'], OK['cabeceras'])
    d = wh.event_data(e)
    assert_instance_of TrevolGenerado::DocumentEventData, d
    assert_equal 'accepted', d.status
    e.type = 'invoice.archived'
    assert_nil wh.event_data(e)
  end

  def test_el_mensaje_de_un_rechazo_no_incluye_el_secreto
    e = assert_raises(Trevol::WebhookVerificationError) { verificador(OK['secreto'], OK['ahora']).verify("#{OK['cuerpo']} ", OK['cabeceras']) }
    refute_includes e.message, OK['secreto'][6..]
  end
end
