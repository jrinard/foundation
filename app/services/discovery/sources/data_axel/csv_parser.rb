# frozen_string_literal: true

require "csv"

module Discovery
  module Sources
    module DataAxel
      class CsvParser
        OFFICE_ADDRESS_COLUMN = Discovery::Sources::WaSos::CsvParser::OFFICE_ADDRESS_COLUMN
        REGISTERED_AGENT_NAME_COLUMN = Discovery::Sources::WaSos::CsvParser::REGISTERED_AGENT_NAME_COLUMN

        DISPLAY_COLUMNS = Discovery::Sources::WaSos::CsvParser::DISPLAY_COLUMNS
        UI_DISPLAY_COLUMNS = Discovery::Sources::WaSos::CsvParser::UI_DISPLAY_COLUMNS
        RESULTS_UI_DISPLAY_COLUMNS = Discovery::Sources::WaSos::CsvParser::RESULTS_UI_DISPLAY_COLUMNS
        UI_COLUMN_LABELS = Discovery::Sources::WaSos::CsvParser::UI_COLUMN_LABELS

        ESTABLISHED_DATE_COLUMNS = [
          "Date Business Established",
          "Year Established",
          "Business Established Date"
        ].freeze

        def self.parse(csv_body)
          return [] if csv_body.blank?

          text = csv_body.to_s.dup.force_encoding("UTF-8")
          text = text.sub(/\A\uFEFF/, "")

          table = CSV.parse(text, headers: true, liberal_parsing: true)
          return [] if table.headers.blank?

          table.map { |row| normalize_row(row) }
        rescue CSV::MalformedCSVError => e
          Rails.logger.warn("[Discovery Data Axel CSV] parse error: #{e.message}")
          []
        end

        def self.normalize_row(row)
          company = find_value(row, "Company Name")
          legal = find_value(row, "Legal Name")
          address = find_value(row, "Address")
          city = find_value(row, "City")
          state = find_value(row, "State")
          zip = find_value(row, "ZIP Code")
          office_address = [address, city, state, zip].reject(&:blank?).join(", ")

          executive = [
            find_value(row, "Executive First Name"),
            find_value(row, "Executive Last Name")
          ].reject(&:blank?).join(" ").strip
          executive = find_value(row, "Executive Title") if executive.blank?

          {
            "Business Name" => company.presence || legal,
            "UBI#" => normalize_iusa(find_value(row, "IUSA Number")),
            REGISTERED_AGENT_NAME_COLUMN => executive,
            OFFICE_ADDRESS_COLUMN => office_address,
            "Business Type" => find_value(row, "Primary SIC Description"),
            "Phone Number Combined" => find_value(row, "Phone Number Combined"),
            "City" => city,
            "State" => state,
            "ZIP Code" => zip,
            "IUSA Number" => find_value(row, "IUSA Number"),
            "Legal Name" => legal,
            "Company Name" => company,
            "date_business_established" => parse_established_date(row)
          }
        end

        def self.normalize_iusa(value)
          value.to_s.gsub(/\D/, "")
        end

        def self.parse_established_date(row)
          ESTABLISHED_DATE_COLUMNS.each do |column|
            raw = find_value(row, column)
            next if raw.blank?

            parsed = parse_date_value(raw)
            return parsed.iso8601 if parsed
          end

          nil
        end

        def self.parse_date_value(raw)
          value = raw.to_s.strip
          return nil if value.blank?

          if value.match?(/\A\d{4}\z/)
            return Date.new(value.to_i, 1, 1)
          end

          Date.strptime(value, "%m/%d/%Y")
        rescue ArgumentError
          Date.parse(value)
        rescue ArgumentError
          nil
        end

        def self.ui_column_label(column)
          UI_COLUMN_LABELS.fetch(column, column)
        end

        def self.find_value(row, column)
          header = row.headers.find { |name| name.to_s.strip.casecmp?(column) }
          return "" unless header

          row[header].to_s.strip
        end
      end
    end
  end
end
