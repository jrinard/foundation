# frozen_string_literal: true

module Discovery
  # Fetches WA SOS data and records a DiscoveryRun for history.
  class FetchWaSos
    Result = Struct.new(:run, :wa_sos, keyword_init: true) do
      delegate :source, :fetch_result, :rows, :sos_query, :success?, to: :wa_sos, allow_nil: true

      def disabled?
        run&.status == DiscoveryRun::STATUS_SKIPPED
      end
    end

    def self.call(organization:, triggered_by:, user: nil, overrides: {})
      new(organization: organization, triggered_by: triggered_by, user: user, overrides: overrides).call
    end

    def initialize(organization:, triggered_by:, user: nil, overrides: {})
      @organization = organization
      @triggered_by = triggered_by
      @user = user
      @overrides = overrides.to_h.symbolize_keys
    end

    def call
      source = DiscoverySource.ensure_wa_sos!(@organization)
      snapshot = build_settings_snapshot(source)

      unless source.enabled?
        run = create_run!(
          source: source,
          snapshot: snapshot,
          status: DiscoveryRun::STATUS_SKIPPED,
          finished_at: Time.current,
          error: "Source disabled"
        )
        wa_sos = RunWaSosSource::Result.new(source: source, fetch_result: nil, rows: [], sos_query: {})
        return Result.new(run: run, wa_sos: wa_sos)
      end

      run = create_run!(source: source, snapshot: snapshot, status: DiscoveryRun::STATUS_RUNNING)
      wa_sos = RunWaSosSource.call(organization: @organization, overrides: @overrides)
      finalize_run!(run, wa_sos, snapshot)
      Result.new(run: run, wa_sos: wa_sos)
    rescue StandardError => e
      finalize_failed_run!(run, e) if defined?(run) && run&.persisted?
      raise
    end

    private

    def build_settings_snapshot(source)
      query = source.wa_sos_settings.to_sos_query(@overrides)
      fetch_settings = source.wa_sos_settings.to_fetch_settings(@overrides)

      {
        business_type_id: query[:business_type_id],
        start_date: query[:start_date],
        end_date: query[:end_date],
        date_cadence: fetch_settings[:date_cadence],
        filter_city: source.wa_sos_settings.filter_city,
        search_entity_name: query[:search_entity_name]
      }.compact
    end

    def create_run!(source:, snapshot:, status:, finished_at: nil, error: nil, row_count: 0, http_status: nil)
      DiscoveryRun.create!(
        organization: @organization,
        discovery_source: source,
        source_key: source.source_key,
        triggered_by: @triggered_by,
        triggered_by_user: manual? ? @user : nil,
        status: status,
        started_at: Time.current,
        finished_at: finished_at,
        row_count: row_count,
        http_status: http_status,
        error: error,
        settings_snapshot: snapshot
      )
    end

    def finalize_run!(run, wa_sos, snapshot)
      result = wa_sos.fetch_result
      row_count = wa_sos.rows.size
      status = run_status(result, row_count)

      run.update!(
        status: status,
        finished_at: Time.current,
        row_count: row_count,
        http_status: result&.status,
        error: status == DiscoveryRun::STATUS_FAILED ? fetch_error_message(result) : nil,
        settings_snapshot: snapshot
      )

      persist_run_csv!(run, result)
    end

    def persist_run_csv!(run, result)
      return unless persistable_csv?(result)
      return unless run.class.column_names.include?("raw_csv")

      run.update_column(:raw_csv, result.body)
    rescue StandardError => e
      Rails.logger.warn("[Discovery WA SOS] raw_csv snapshot skipped: #{e.message}")
    end

    def finalize_failed_run!(run, error)
      run.update!(
        status: DiscoveryRun::STATUS_FAILED,
        finished_at: Time.current,
        error: error.message
      )
    end

    def run_status(result, row_count)
      return DiscoveryRun::STATUS_FAILED if result.blank? || !result.success?

      row_count.positive? ? DiscoveryRun::STATUS_SUCCESS : DiscoveryRun::STATUS_EMPTY
    end

    def fetch_error_message(result)
      return "Request failed" if result.blank?

      "HTTP #{result.status}"
    end

    def manual?
      @triggered_by == DiscoveryRun::TRIGGER_MANUAL
    end

    def persistable_csv?(result)
      result.present? && result.success? && result.body.present?
    end
  end
end
