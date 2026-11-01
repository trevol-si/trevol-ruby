# frozen_string_literal: true

require 'ayudas'

class PaginacionTest < Minitest::Test
  include Ayudas::ConServidor
  include Ayudas

  Pagina = Struct.new(:data, :has_more, :next_cursor)

  def doc(n) = TrevolGenerado::Document.new(id: "inv_#{n}")

  def test_recorre_tres_paginas_falsas_con_next_cursor_y_se_detiene
    pedidos = []
    paginas = [Pagina.new([doc(1), doc(2)], true, 'inv_2'), Pagina.new([doc(3), doc(4)], true, 'inv_4'), Pagina.new([doc(5)], false, nil)]
    ids = Trevol::Paginacion.paginar { |c| pedidos << c; paginas[pedidos.size - 1] }.map(&:id).to_a
    assert_equal %w[inv_1 inv_2 inv_3 inv_4 inv_5], ids
    assert_equal [nil, 'inv_2', 'inv_4'], pedidos
  end

  def test_si_has_more_viene_sin_next_cursor_usa_el_id_del_ultimo
    pedidos = []
    paginas = [Pagina.new([doc(1), doc(2)], true, nil), Pagina.new([doc(3)], false, nil)]
    n = Trevol::Paginacion.paginar { |c| pedidos << c; paginas[pedidos.size - 1] }.to_a.size
    assert_equal 3, n
    assert_equal [nil, 'inv_2'], pedidos
  end

  def test_es_perezosa
    llamadas = 0
    it = Trevol::Paginacion.paginar { |_c| llamadas += 1; Pagina.new([doc(1), doc(2)], true, 'inv_2') }
    assert_kind_of Enumerator::Lazy, it
    it.first
    assert_equal 1, llamadas
  end

  def test_un_cursor_que_no_avanza_o_una_pagina_vacia_no_dejan_el_bucle_girando
    vistos = Trevol::Paginacion.paginar { |_c| Pagina.new([doc(1)], true, 'inv_1') }.to_a.size
    assert_operator vistos, :<=, 3
    assert_empty Trevol::Paginacion.paginar { |_c| Pagina.new([], true, 'x') }.to_a
  end

  def test_client_paginate_con_un_metodo_generado_y_el_servidor_falso
    b = banco(json(200, { object: 'list', data: [{ id: 'inv_1' }, { id: 'inv_2' }], has_more: true, next_cursor: 'inv_2' }),
              json(200, { object: 'list', data: [{ id: 'inv_3' }], has_more: false, next_cursor: nil }))
    t = b.trevol
    ids = t.paginate { |cursor| t.invoices.list_invoices(limit: 2, starting_after: cursor) }.map(&:id).to_a
    assert_equal %w[inv_1 inv_2 inv_3], ids
    assert_equal '/v1/invoices?limit=2', b.peticiones[0][:ruta]
    assert_equal '/v1/invoices?limit=2&starting_after=inv_2', b.peticiones[1][:ruta]
  end
end
