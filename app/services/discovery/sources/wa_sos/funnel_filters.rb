# frozen_string_literal: true

module Discovery
  module Sources
    module WaSos
      # Post-fetch funnel — narrows SOS rows before display and DB import.
      class FunnelFilters
        ADDRESS_COLUMN = CsvParser::OFFICE_ADDRESS_COLUMN

        def self.apply(rows, city: nil)
          filtered = rows
          filtered = filter_by_city(filtered, city) if city.present?
          filtered
        end

        def self.extract_city(address)
          return nil if address.blank?
          return nil unless address.match?(/,\s*WA\b/i)

          before_state = address.split(/,\s*WA\b/i).first.to_s
          segments = before_state.split(",").map(&:strip).reject(&:blank?)
          segments.last
        end

        def self.filter_by_city(rows, city)
          targets = Cities.match_cities(city)
          rows.select { |row| matches_cities?(row, targets) }
        end

        def self.matches_cities?(row, cities)
          extracted = extract_city(row[ADDRESS_COLUMN])
          return false if extracted.blank?

          cities.any? { |city| extracted.casecmp?(city.to_s.strip) }
        end

        def self.matches_city?(row, city)
          matches_cities?(row, [city])
        end
      end
    end
  end
end
