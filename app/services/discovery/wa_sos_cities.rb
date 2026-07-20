# frozen_string_literal: true

module Discovery
  module WaSosCities
    DEFAULT = Discovery::Sources::WaSos::Cities::DEFAULT
    OPTIONS = Discovery::Sources::WaSos::Cities::OPTIONS

    def self.valid?(city)
      Discovery::Sources::WaSos::Cities.valid?(city)
    end

    def self.normalize(city)
      Discovery::Sources::WaSos::Cities.normalize(city)
    end

    def self.match_cities(city)
      Discovery::Sources::WaSos::Cities.match_cities(city)
    end
  end
end
