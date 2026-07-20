# frozen_string_literal: true

require "csv"

module Discovery
  module Sources
    class WaSosCsvParser
      OFFICE_ADDRESS_COLUMN = "Office Address"
      REGISTERED_AGENT_NAME_COLUMN = "Reg Name"

      DISPLAY_COLUMNS = [
        "Business Name",
        "UBI#",
        "Business Type",
        OFFICE_ADDRESS_COLUMN,
        REGISTERED_AGENT_NAME_COLUMN
      ].freeze

      # SOS CSV headers that differ from display labels.
      CSV_COLUMN_SOURCES = {
        OFFICE_ADDRESS_COLUMN => "Principal Office Address",
        REGISTERED_AGENT_NAME_COLUMN => "Registered Agent Name"
      }.freeze

      def self.parse(csv_body)
        return [] if csv_body.blank?

        text = csv_body.to_s.dup.force_encoding("UTF-8")
        text = text.sub(/\A\uFEFF/, "")

        table = CSV.parse(text, headers: true, liberal_parsing: true)
        return [] if table.headers.blank?

        table.map { |row| normalize_row(row) }
      rescue CSV::MalformedCSVError => e
        Rails.logger.warn("[Discovery WA SOS CSV] parse error: #{e.message}")
        []
      end

      def self.normalize_row(row)
        DISPLAY_COLUMNS.index_with { |column| find_value(row, csv_source_for(column)) }
      end

      def self.csv_source_for(display_column)
        CSV_COLUMN_SOURCES.fetch(display_column, display_column)
      end

      def self.find_value(row, column)
        header = row.headers.find { |name| name.to_s.strip.casecmp?(column) }
        return "" unless header

        row[header].to_s.strip
      end
    end
  end
end
