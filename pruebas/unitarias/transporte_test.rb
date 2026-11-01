# frozen_string_literal: true

require 'ayudas'

class TransporteTest < Minitest::Test
  CASOS = Ayudas.datos('transporte.json')['casos']

  def test_hay_casos
    assert_operator CASOS.size, :>=, 50
  end

  CASOS.each_with_index do |caso, i|
    define_method("test_decidir_con_pruebas_datos_transporte_json_#{i}_#{caso['nombre'].gsub(/\W+/, '_')[0, 60]}") do
      r = caso['resultado']
      resultado = Trevol::Transporte::Resultado.new(tipo: r['tipo'].to_sym, estado: r['estado'], code: r['code'], retryable: r['retryable'], retry_after: r['retryAfter']&.to_f)
      d = Trevol::Transporte.decidir(intento: caso['intento'], reintento: caso['reintento'], max_reintentos: caso['maxReintentos'],
                                     max_retry_after: caso['maxRetryAfter'].to_f, azar: caso['azar'].to_f, resultado: resultado)
      e = caso['esperado']
      assert_equal e['reintentar'], d.reintentar, caso['nombre']
      assert_in_delta e['espera'], d.espera, 1e-9 if e.key?('espera')
      assert_equal e['motivo'], d.motivo if e.key?('motivo')
      assert_nil d.espera unless e['reintentar']
    end
  end

  def test_la_espera_propia_crece_con_tope_de_8_y_un_factor_entre_075_y_1
    assert_equal [0.5, 1, 2, 4, 8, 8, 8], [1, 2, 3, 4, 5, 6, 9].map { |n| Trevol::Transporte.espera_propia(n, 1.0) }
    assert_equal 0.375, Trevol::Transporte.espera_propia(1, 0.0)
    assert_equal 3, Trevol::Transporte.espera_propia(4, 0.0)
  end
end
