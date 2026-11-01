# frozen_string_literal: true

module Trevol
  # Paginación con iteradores (docs/api/43 §2.6.7): la API pagina por cursor (`starting_after`).
  module Paginacion
    module_function

    # Recorre todas las páginas de un listado, perezosamente (devuelve un `Enumerator::Lazy`).
    #
    # El bloque recibe el cursor (`starting_after`; nil la primera vez), pide UNA página y devuelve el sobre de lista generado
    # (`data`, `has_more`, `next_cursor`). Sigue con `next_cursor` mientras `has_more`; si la página no lo trae, usa el `id` del último
    # elemento (así lo arma la API). Se detiene si el cursor no avanza.
    def paginar(&pagina)
      raise ArgumentError, 'paginate necesita un bloque { |cursor| ... }' unless pagina

      Enumerator.new do |y|
        cursor = nil
        loop do
          p = pagina.call(cursor)
          datos = Array(tomar(p, :data))
          datos.each { |d| y << d }
          break if tomar(p, :has_more) != true || datos.empty?

          siguiente = tomar(p, :next_cursor)
          siguiente = tomar(datos.last, :id) if siguiente.nil? || siguiente.to_s.empty?
          break if siguiente.nil? || siguiente.to_s.empty? || siguiente == cursor

          cursor = siguiente
        end
      end.lazy
    end

    def tomar(objeto, clave)
      if objeto.respond_to?(clave)
        objeto.public_send(clave)
      elsif objeto.is_a?(Hash)
        objeto[clave] || objeto[clave.to_s]
      end
    end
  end
end
