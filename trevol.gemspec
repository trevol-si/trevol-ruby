# frozen_string_literal: true

require_relative 'lib/trevol_generado/tablas'

Gem::Specification.new do |s|
  s.name = 'trevol'
  s.version = TrevolGenerado::Tablas::VERSION
  s.summary = 'SDK de Ruby para la API de Trevol (facturación electrónica y demás documentos ante la DIAN, Colombia)'
  s.description = 'Cliente de la API de Trevol: Idempotency-Key automática, reintentos con espera creciente, errores tipados, ' \
                  'entorno deducido de la llave, paginación con iteradores, descargas de PDF/XML/ZIP y verificación de webhooks (Standard Webhooks).'
  s.authors = ['Trevol']
  s.homepage = 'https://platform.trevol.si/docs'
  s.license = 'MIT'
  s.metadata = {
    'homepage_uri' => 'https://platform.trevol.si/docs',
    'source_code_uri' => 'https://github.com/trevol-si/trevol-ruby',
    'changelog_uri' => 'https://github.com/trevol-si/trevol-ruby/blob/main/CHANGELOG.md',
    'rubygems_mfa_required' => 'true'
  }
  s.required_ruby_version = '>= 3.2'

  s.add_runtime_dependency 'base64' # standardwebhooks 1.1.0 lo usa sin declararlo y desde Ruby 3.4 ya no es parte de la biblioteca estándar
  s.add_runtime_dependency 'cgi' # el código generado hace require 'cgi'; en Ruby 4.0 ya no viene en la biblioteca estándar
  s.add_runtime_dependency 'faraday', '~> 2.0'
  s.add_runtime_dependency 'faraday-multipart', '~> 1.0'
  s.add_runtime_dependency 'marcel', '~> 1.0'
  s.add_runtime_dependency 'standardwebhooks', '~> 1.1'

  s.add_development_dependency 'minitest', '~> 5.20'
  s.add_development_dependency 'rake', '~> 13.0'

  s.files = Dir['lib/**/*.rb'] + %w[README.md LICENSE CHANGELOG.md GENERADO.md]
  s.require_paths = ['lib']
end
