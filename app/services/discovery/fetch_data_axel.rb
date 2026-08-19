# frozen_string_literal: true

module Discovery
  class FetchDataAxel
    Result = Struct.new(:run, :axel, keyword_init: true) do
      delegate :source, :fetch_result, :rows, :axel_query, :success?, to: :axel, allow_nil: true

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
      source = DiscoverySource.ensure_data_axel!(@organization)
      snapshot = build_settings_snapshot(source)
      persist_collect_settings!(source, snapshot)

      unless source.enabled?
        run = create_run!(
          source: source,
          snapshot: snapshot,
          status: DiscoveryRun::STATUS_SKIPPED,
          finished_at: Time.current,
          error: "Source disabled"
        )
        axel = RunDataAxelSource::Result.new(source: source, fetch_result: nil, rows: [], all_rows: [], axel_query: {})
        return Result.new(run: run, axel: axel)
      end

      run = create_run!(source: source, snapshot: snapshot, status: DiscoveryRun::STATUS_RUNNING)
      axel = RunDataAxelSource.call(organization: @organization, overrides: @overrides)
      snapshot = snapshot.merge(source_file_count: axel.axel_query[:source_file_count]).compact
      finalize_run!(run, axel, snapshot)
      Result.new(run: run, axel: axel)
    rescue StandardError => e
      finalize_failed_run!(run, e) if defined?(run) && run&.persisted?
      raise
    end

    private

    def build_settings_snapshot(source)
      query = source.data_axel_settings.to_query(@overrides)
      query.merge(filter_city: source.data_axel_settings.filter_city).compact
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

    def finalize_run!(run, axel, snapshot)
      result = axel.fetch_result
      row_count = axel.rows.size
      status = run_status(result, row_count)

      run.update!(
        status: status,
        finished_at: Time.current,
        row_count: row_count,
        http_status: result&.status,
        error: status == DiscoveryRun::STATUS_FAILED ? "Request failed" : nil,
        settings_snapshot: snapshot
      )

      persist_run_csv!(run, result)
    end

    def persist_run_csv!(run, result)
      return unless result.present? && result.success? && result.body.present?
      return unless run.class.column_names.include?("raw_csv")

      run.update_column(:raw_csv, result.body)
    rescue StandardError => e
      Rails.logger.warn("[Discovery Data Axel] raw_csv snapshot skipped: #{e.message}")
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

    def manual?
      @triggered_by == DiscoveryRun::TRIGGER_MANUAL
    end

    def persist_collect_settings!(source, snapshot)
      source.update_data_axel_settings!(
        row_limit: snapshot[:row_limit],
        row_range_enabled: snapshot[:row_range_enabled],
        row_range_start: snapshot[:row_range_start],
        row_range_end: snapshot[:row_range_end]
      )
    end
  end
end
