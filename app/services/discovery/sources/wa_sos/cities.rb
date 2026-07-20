# frozen_string_literal: true

module Discovery
  module Sources
    module WaSos
      module Cities
        SOUTHERN_WA = "Southern WA"
        DEFAULT = "Vancouver"

        INDIVIDUAL_CITIES = [
          "Vancouver",
          "Camas",
          "Washougal",
          "Ridgefield",
          "Battle Ground",
          "Hockinson",
          "Brush Prairie",
          "Woodland"
        ].freeze

        OPTIONS = [SOUTHERN_WA, *INDIVIDUAL_CITIES].freeze

        def self.valid?(city)
          OPTIONS.any? { |option| option.casecmp?(city.to_s.strip) }
        end

        def self.normalize(city)
          match = OPTIONS.find { |option| option.casecmp?(city.to_s.strip) }
          match || DEFAULT
        end

        def self.southern_wa?(city)
          city.to_s.strip.casecmp?(SOUTHERN_WA)
        end

        def self.match_cities(city)
          normalized = normalize(city)
          southern_wa?(normalized) ? INDIVIDUAL_CITIES : [normalized]
        end
      end
    end
  end
end
