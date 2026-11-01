# frozen_string_literal: true

# Prueba de humo REAL en habilitación (docs/api/43 §2.10.4). NO es parte de la suite: la corre una persona, con una llave de PRUEBAS.
#
#   TREVOL_API_KEY=tvl_test_… bundle exec ruby pruebas/humo/humo.rb
#
# Solo lecturas y un preview (el SDK de Ruby NO emite). Se NIEGA a correr si la llave no es tvl_test_. TREVOL_BASE_URL (opcional) apunta a
# otro servidor, p. ej. un Prism local.
require 'base64'
require 'json'
require 'openssl'
require 'time'
require 'trevol'

llave = ENV.fetch('TREVOL_API_KEY', '')
unless llave.match?(/\Atvl_test_[0-9a-f]{64}\z/)
  warn 'humo: me niego a correr si TREVOL_API_KEY no es una llave de PRUEBAS (tvl_test_…). Nunca se prueba con tvl_live_.'
  exit 2
end

opciones = { environment: :test }
opciones[:base_url] = ENV['TREVOL_BASE_URL'] if ENV['TREVOL_BASE_URL']
trevol = Trevol::Client.new(llave, **opciones)
total = 0
fallas = 0
paso = lambda do |nombre, &bloque|
  total += 1
  detalle = bloque.call
  puts "ok   #{nombre}#{detalle.to_s.empty? ? '' : " — #{detalle}"}"
rescue StandardError => e
  fallas += 1
  puts "FALLA #{nombre} — #{e.class}: #{e.message}"
end

paso.call('get_health') { trevol.general.get_health && '' }
paso.call('retrieve_company') do
  c = trevol.general.retrieve_company
  raise "la empresa dice environment=#{c.environment}" unless c.environment == 'test'

  "#{c.name} (#{c.nit})"
end
paso.call('preview_invoice') do
  p = trevol.invoices.preview_invoice(
    external_id: 'HUMO-PREVIEW', customer: { final_consumer: true },
    items: [{ description: 'Prueba de humo del SDK de Trevol', quantity: '1', unit_price: '1000', taxes: [{ code: '01', rate: '19' }] }],
    payment: { form: 'cash', methods: [{ code: '10' }] }
  )
  "total #{p.totals && p.totals[:total]}"
end
paso.call('list_invoices + paginate (3)') do
  trevol.invoices.list_invoices(limit: 3)
  n = trevol.paginate { |c| trevol.invoices.list_invoices(limit: 3, starting_after: c) }.first(3).size
  "#{n} facturas"
end
paso.call('retrieve_invoice inexistente → NotFoundError con request_id') do
  trevol.invoices.retrieve_invoice("inv_#{'0' * 32}")
  raise 'no lanzó NotFoundError'
rescue Trevol::NotFoundError => e
  raise 'sin request_id' unless e.request_id.to_s.start_with?('req_')

  e.request_id
end
paso.call('Webhook#verify (firmado ahora, con un secreto local)') do
  clave = 'trevol-humo-secreto-de-32-bytes!'
  id = "evt_#{'1' * 32}"
  cuerpo = JSON.generate(id: id, object: 'event', type: 'webhook.test', timestamp: Time.now.utc.iso8601, environment: 'test', api_version: '2026-10-22', data: {})
  ts = Time.now.to_i
  firma = "v1,#{Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', clave, "#{id}.#{ts}.#{cuerpo}"))}"
  Trevol::Webhook.new("whsec_#{Base64.strict_encode64(clave)}").verify(cuerpo, { 'webhook-id' => id, 'webhook-timestamp' => ts.to_s, 'webhook-signature' => firma }).type
end

puts "\n#{total - fallas}/#{total} pasos bien"
exit(fallas.positive? ? 1 : 0)
