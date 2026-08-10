# frozen_string_literal: true

module Discovery
  # Remove WA SOS rows that are already captured for this org (any archived/skipped state).
  class FilterUncapturedWaSosRows
    Result = Struct.new(:rows, :hidden_count, keyword_init: true)

    def self.call(organization:, rows:)
      new(organization: organization, rows: rows).call
    end

    def initialize(organization:, rows:)
      @organization = organization
      @rows = Array(rows)
    end

    def call
      return Result.new(rows: [], hidden_count: 0) if @rows.empty?

      captured_ids = captured_external_ids
      visible_rows = @rows.reject { |row| captured_ids.include?(external_id_for(row)) }

      Result.new(
        rows: visible_rows,
        hidden_count: @rows.size - visible_rows.size
      )
    end

    private

    def captured_external_ids
      DiscoveryBusiness.where(
        organization_id: @organization.id,
        source: DiscoveryBusiness::SOURCE_WA_SOS
      ).pluck(:external_id).to_set
    end

    def external_id_for(row)
      hash = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row
      hash = hash.stringify_keys
      DiscoveryBusiness.normalize_ubi(hash["UBI#"])
    end
  end
end
