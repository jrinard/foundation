# frozen_string_literal: true

module Discovery
  class SourceRegistry
    SOURCES = {
      wa_sos: Discovery::Sources::WaSos::CsvExport
    }.freeze

    def self.all
      SOURCES
    end

    def self.fetch(key, **config)
      klass = SOURCES.fetch(key.to_sym)
      klass.new(**config).fetch
    end
  end
end
