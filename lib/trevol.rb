# frozen_string_literal: true

# SDK de Ruby para la API de Trevol. Documentación: https://platform.trevol.si/docs
require 'trevol_generado'
require 'trevol_generado/tablas'
require_relative 'trevol/errors'
require_relative 'trevol/llave'
require_relative 'trevol/paginacion'
require_relative 'trevol/transporte'
require_relative 'trevol/webhook'

module Trevol
  # La versión de este SDK y la de la API con que se generó (el valor de Trevol-Version por defecto).
  VERSION = TrevolGenerado::Tablas::VERSION
  API_VERSION = TrevolGenerado::Tablas::API_VERSION
end

require_relative 'trevol/client'
