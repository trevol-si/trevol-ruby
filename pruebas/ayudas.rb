# frozen_string_literal: true

# Ayudas de las pruebas: un servidor HTTP falso en localhost (pasa por Faraday/Net::HTTP de verdad) y un cliente con reloj y azar inyectados.
require 'json'
require 'minitest/autorun'
require 'socket'
require 'trevol'

module Ayudas
  DATOS = File.join(__dir__, 'datos')
  HEX = '3f0c1a2b' * 4
  LLAVE_TEST = "tvl_test_#{'a1' * 32}"
  LLAVE_LIVE = "tvl_live_#{'b2' * 32}"
  ID_DOC = "inv_#{HEX}"
  DOCUMENTO = { id: ID_DOC, object: 'invoice', environment: 'test', status: 'accepted', number: 'SETP990012345', external_id: 'VENTA-2026-000123' }.freeze
  ENTRADA_FACTURA = { external_id: 'VENTA-2026-000123', customer: { final_consumer: true },
                      items: [{ description: 'Café', quantity: '1', unit_price: '1000' }] }.freeze

  module_function

  def datos(nombre) = JSON.parse(File.read(File.join(DATOS, nombre), encoding: 'UTF-8'))

  Respuesta = Struct.new(:estado, :cuerpo, :cabeceras, :crudo, :tipo, keyword_init: true) do
    def bytes = crudo || (cuerpo.nil? ? '' : JSON.generate(cuerpo)).b
  end

  def json(estado, cuerpo, cabeceras = {}) = Respuesta.new(estado: estado, cuerpo: cuerpo, cabeceras: cabeceras, tipo: 'application/json')

  def problema(estado, code, extra = {}, cabeceras = {})
    cuerpo = { type: "https://platform.trevol.si/docs/errores##{code}", title: 'Título', status: estado, code: code, retryable: false,
               detail: "Detalle de #{code}", request_id: 'req_c3c3c3c3c3c3c3c3c3c3c3c3' }.merge(extra)
    Respuesta.new(estado: estado, cuerpo: cuerpo, cabeceras: cabeceras, tipo: 'application/problem+json')
  end

  CORTAR = Object.new # el servidor cierra la conexión sin responder (un fallo de red)

  # Un servidor HTTP/1.1 mínimo: contesta con las respuestas dadas (la última se repite) y anota las peticiones.
  class Servidor
    attr_reader :peticiones, :url
    attr_accessor :respuestas

    def initialize
      @respuestas = []
      @peticiones = []
      @servidor = TCPServer.new('127.0.0.1', 0)
      @url = "http://127.0.0.1:#{@servidor.addr[1]}/v1"
      @hilo = Thread.new { loop { atender(@servidor.accept) } }
    end

    def cerrar
      @hilo.kill
      @servidor.close
    end

    def vaciar(*respuestas)
      @respuestas = respuestas
      @peticiones = []
      self
    end

    private

    def atender(socket)
      Thread.new do
        linea = socket.gets or next socket.close
        metodo, ruta, = linea.split
        cabeceras = {}
        while (l = socket.gets) && l != "\r\n"
          k, v = l.split(': ', 2)
          cabeceras[k.downcase] = v.to_s.strip
        end
        cuerpo = (n = cabeceras['content-length'].to_i).positive? ? socket.read(n).force_encoding('UTF-8') : ''
        peticion = { metodo: metodo, ruta: ruta, cabeceras: cabeceras, cuerpo: cuerpo }
        @peticiones << peticion
        r = @respuestas[[@peticiones.size - 1, @respuestas.size - 1].min]
        r = r.call(peticion) if r.respond_to?(:call)
        if r.equal?(CORTAR)
          socket.close
          next
        end
        bytes = r.bytes
        socket.write("HTTP/1.1 #{r.estado} X\r\nContent-Type: #{r.tipo}\r\nContent-Length: #{bytes.bytesize}\r\nConnection: close\r\n" \
                     "#{(r.cabeceras || {}).map { |k, v| "#{k}: #{v}\r\n" }.join}\r\n")
        socket.write(bytes)
        socket.close
      end
    end
  end

  # Un cliente contra el servidor falso, con las esperas anotadas (no se duerme) y el azar en 1 (factor 1,0).
  class Banco
    attr_reader :trevol, :esperas, :servidor

    def initialize(servidor, *respuestas, llave: LLAVE_TEST, **opciones)
      @servidor = servidor.vaciar(*respuestas)
      @esperas = []
      @n = 0
      @trevol = Trevol::Client.new(
        llave, base_url: servidor.url,
               internos: { dormir: ->(s) { @esperas << s }, azar: -> { 1.0 }, uuid: -> { format('00000000-0000-4000-8000-%012d', @n += 1) } }, **opciones
      )
    end

    def peticiones = @servidor.peticiones
  end

  # Mezcla para las pruebas: un servidor por prueba.
  module ConServidor
    def setup
      super
      @servidor = Servidor.new
    end

    def teardown
      @servidor.cerrar
      super
    end

    def banco(*respuestas, **opciones) = Banco.new(@servidor, *respuestas, **opciones)
  end
end
