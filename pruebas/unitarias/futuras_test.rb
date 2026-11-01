# frozen_string_literal: true

require 'ayudas'
require 'base64'
require 'openssl'

class FuturasTest < Minitest::Test
  include Ayudas::ConServidor
  include Ayudas

  CASOS = Ayudas.datos('respuestas-futuras.json')['casos']

  CASOS.select { |c| c['operacion'] }.each_with_index do |caso, i|
    define_method("test_respuestas_del_futuro_#{i}_#{caso['nombre'].gsub(/\W+/, '_')[0, 50]}") do
      tipo = caso['estado'] >= 400 ? 'application/problem+json' : 'application/json'
      b = banco(Respuesta.new(estado: caso['estado'], cuerpo: caso['cuerpo'], cabeceras: caso['cabeceras'] || {}, tipo: tipo), max_retries: 0)
      llamar = caso['operacion'] == 'listInvoices' ? -> { b.trevol.invoices.list_invoices } : -> { b.trevol.invoices.retrieve_invoice('inv_x') }
      e = caso['esperado']
      if caso['estado'] < 400
        r = llamar.call
        if e['cantidad']
          assert_equal e['cantidad'], r.data.size
          assert_equal e['has_more'], r.has_more
        else
          assert_equal e['id'], r.id
          assert_equal e['status'], r.status
        end
      else
        x = assert_raises(Trevol::Error) { llamar.call }
        assert_equal e['clase'].sub('TrevolError', 'Error'), x.class.name.split('::').last
        assert_equal e['code'], x.code
        assert_equal e['status'], x.status
        assert_equal e['requestId'], x.request_id if e['requestId']
      end
    end
  end

  CASOS.select { |c| c['evento'] }.each_with_index do |caso, i|
    define_method("test_eventos_del_futuro_#{i}_#{caso['nombre'].gsub(/\W+/, '_')[0, 50]}") do
      clave = '0123456789abcdef0123456789abcdef'
      secreto = "whsec_#{Base64.strict_encode64(clave)}"
      ts = 1_793_491_200
      cuerpo = JSON.generate(caso['evento'])
      firma = "v1,#{Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', clave, "#{caso['evento']['id']}.#{ts}.#{cuerpo}"))}"
      wh = Trevol::Webhook.new(secreto, ahora: -> { ts })
      e = wh.verify(cuerpo, { 'webhook-id' => caso['evento']['id'], 'webhook-timestamp' => ts.to_s, 'webhook-signature' => firma })
      assert_equal caso['esperado']['type'], e.type.to_s
      assert_equal caso['esperado']['tieneModelo'], !wh.event_data(e).nil?
      assert_equal JSON.parse(JSON.generate(caso['evento']['data'])), JSON.parse(JSON.generate(e.data))
    end
  end
end
