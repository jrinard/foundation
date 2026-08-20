# frozen_string_literal: true

module Discovery
  class RunDataAxelSource
    FetchResult = Struct.new(:status, :body, :content_type, keyword_init: true) do
      def success?
        status == 200
      end
    end

    Result = Struct.new(:source, :fetch_result, :rows, :all_rows, :axel_query, keyword_init: true) do
      def success?
        fetch_result&.success?
      end

      def disabled?
        source.present? && !source.enabled?
      end
    end

    def self.call(organization:, overrides: {})
      new(organization: organization, overrides: overrides).call
    end

    def initialize(organization:, overrides: {})
      @organization = organization
      @overrides = overrides.to_h.symbolize_keys
    end

    def call
      source = DiscoverySource.ensure_data_axel!(@organization)
      return empty_result(source) unless source.enabled?

      settings = source.data_axel_settings
      axel_query = settings.to_query(@overrides)
      catalog = Sources::DataAxel::FileCatalog.for(@organization)
      body = catalog.merged_csv_body

      if body.blank?
        return Result.new(
          source: source,
          fetch_result: FetchResult.new(status: 404, body: "", content_type: "text/csv"),
          rows: [],
          all_rows: [],
          axel_query: axel_query
        )
      end

      all_rows = Sources::DataAxel::CsvParser.parse(body)
      all_rows = dedupe_rows(all_rows)
      all_rows = filter_by_name(all_rows, axel_query[:search_entity_name])
      display_rows = settings.apply_row_window(all_rows)

      Result.new(
        source: source,
        fetch_result: FetchResult.new(status: 200, body: body, content_type: "text/csv"),
        rows: display_rows,
        all_rows: all_rows,
        axel_query: axel_query.merge(source_file_count: catalog.file_count)
      )
    end

    private

    def empty_result(source)
      Result.new(
        source: source,
        fetch_result: nil,
        rows: [],
        all_rows: [],
        axel_query: {}
      )
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
