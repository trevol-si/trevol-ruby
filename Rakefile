# frozen_string_literal: true

require 'rake/testtask'

# bundle exec rake test             unitarias (sin red)
# bundle exec rake prism            contra Prism (TREVOL_PRISM_URL) y los fragmentos
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'pruebas'
  t.pattern = 'pruebas/unitarias/**/*_test.rb'
  t.warning = false # el código generado no es nuestro; las advertencias de lo propio las revisa `ruby -w` en la CI
end

Rake::TestTask.new(:prism) do |t|
  t.libs << 'lib' << 'pruebas'
  t.test_files = FileList['pruebas/prism/**/*_test.rb', 'pruebas/fragmentos/**/*_test.rb']
  t.warning = false # el código generado no es nuestro; las advertencias de lo propio las revisa `ruby -w` en la CI
end

task default: :test
