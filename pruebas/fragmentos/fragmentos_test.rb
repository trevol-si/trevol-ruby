# frozen_string_literal: true

# Los fragmentos de la documentación, como programas (docs/api/43 §2.9): se COMPILAN (`ruby -c`) y se CORREN contra Prism. Un fragmento que
# no compila, o que Prism rechaza porque el cuerpo no cumple la especificación, rompe esta suite.
#
#   sdks/herramientas/prism.sh -- bash -c 'cd sdks/ruby && bundle exec rake prism'
require 'ayudas'
require 'open3'
require 'rbconfig'

class FragmentosTest < Minitest::Test
  PROGRAMAS = File.join(__dir__, 'programas')
  DATOS = Ayudas.datos('fragmentos.json')
  OPERACIONES = DATOS['fragmentos'].keys.sort
  RAIZ = File.expand_path('../..', __dir__)

  def test_la_estructura
    assert_equal 109, OPERACIONES.size
    assert_equal OPERACIONES, Dir.children(PROGRAMAS).grep(/\.rb\z/).map { |f| File.basename(f, '.rb') }.sort
    OPERACIONES.each do |op|
      assert_includes DATOS['fragmentos'][op]['ruby'], 'Trevol::Client.new'
      assert_includes DATOS['fragmentos'][op]['ruby'], 'TREVOL_API_KEY'
    end
  end

  OPERACIONES.each do |op|
    define_method("test_el_fragmento_#{op}_compila") do
      salida, estado = Open3.capture2e(RbConfig.ruby, '-c', File.join(PROGRAMAS, "#{op}.rb"))
      assert estado.success?, salida
    end

    define_method("test_el_fragmento_#{op}_corre_contra_prism") do
      skip "necesita Prism: sdks/herramientas/prism.sh -- bash -c 'cd sdks/ruby && bundle exec rake prism'" unless ENV['TREVOL_PRISM_URL']
      salida, estado = Open3.capture2e({ 'RUBYOPT' => nil }, RbConfig.ruby, '-I', File.join(RAIZ, 'lib'), File.join(PROGRAMAS, "#{op}.rb"), chdir: RAIZ)
      assert estado.success?, salida
      refute_match(/warning:|Error/, salida)
    end
  end
end
