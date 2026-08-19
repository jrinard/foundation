# frozen_string_literal: true

module Discovery
  class LoadDiscoveryRun
    Result = Struct.new(:run, :rows, keyword_init: true)

    def self.call(run:)
      new(run: run).call
    end

    def initialize(run:)
      @run = run
    end

    def call
      unless @run.reloadable?
        raise ArgumentError, "This run has no saved CSV to load."
      end

      rows = parse_rows
      rows = apply_snapshot_window(rows)
      Result.new(run: @run, rows: rows)
    end

    private

    def parse_rows
      case @run.source_key
      when DiscoveryBusiness::SOURCE_WA_SOS
        Sources::WaSos::CsvParser.parse(@run.raw_csv)
      when DiscoveryBusiness::SOURCE_DATA_AXEL
        rows = Sources::DataAxel::CsvParser.parse(@run.raw_csv)
        dedupe_rows(rows)
      else
        raise ArgumentError, "Unsupported discovery source: #{@run.source_key}"
      end
    end

    def apply_snapshot_window(rows)
      return rows unless @run.source_key == DiscoveryBusiness::SOURCE_DATA_AXEL

      settings = Sources::DataAxelSettings.new(@run.settings_snapshot)
      filtered = filter_by_name(rows, @run.settings_snapshot["search_entity_name"])
      settings.apply_row_window(filtered)
    end

    def dedupe_rows(rows)
      seen = {}
      rows.each_with_object([]) do |row, memo|
        key = row["UBI#"].presence || row["Business Name"]
        next if key.blank? || seen[key]

        seen[key] = true
        memo << row
      end
    end

    def filter_by_name(rows, query)
      return rows if query.blank?

      needle = query.to_s.downcase
      rows.select do |row|
        row["Business Name"].to_s.downcase.include?(needle) ||
          row["Legal Name"].to_s.downcase.include?(needle) ||
          row["Company Name"].to_s.downcase.include?(needle)
      end
    end
  end
end
