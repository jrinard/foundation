# frozen_string_literal: true

module Discovery
  # Loads persisted WA SOS config for an org and runs the SOS fetch.
  # Used by the Discovery page today; same entry point for a future daily job.
  class RunWaSosSource
    Result = Struct.new(:source, :fetch_result, :rows, :sos_query, keyword_init: true) do
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
      source = DiscoverySource.ensure_wa_sos!(@organization)
      return Result.new(source: source, fetch_result: nil, rows: [], sos_query: {}) unless source.enabled?

      sos_query = source.wa_sos_settings.to_sos_query(@overrides)
      fetch_result = SourceRegistry.fetch(:wa_sos, **sos_query)
      rows = fetch_result.success? ? Sources::WaSos::CsvParser.parse(fetch_result.body) : []

      Result.new(source: source, fetch_result: fetch_result, rows: rows, sos_query: sos_query)
    end
  end
end
