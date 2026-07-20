# frozen_string_literal: true

module Discovery
  # Org-scoped funnel counts for the Discovery index header.
  class StatsSummary
    Stat = Struct.new(:key, :label, :value, keyword_init: true)

    def self.call(organization:, period: StatsPeriod::DEFAULT)
      new(organization: organization, period: period).call
    end

    def initialize(organization:, period: StatsPeriod::DEFAULT)
      @organization = organization
      @period = StatsPeriod.normalize(period)
    end

    def call
      range = StatsPeriod.range(@period, timezone: @organization.timezone)

      businesses = DiscoveryBusiness.where(organization_id: @organization.id)
      runs = DiscoveryRun.where(organization_id: @organization.id, started_at: range)

      pulled = runs.where(status: [DiscoveryRun::STATUS_SUCCESS, DiscoveryRun::STATUS_EMPTY]).sum(:row_count)
      captured = businesses.where(created_at: range).count
      refining = businesses.where(created_at: range).working.discoveries.count
      potentials = businesses.potentials.where(updated_at: range).count
      scored = businesses.where(scored_at: range).count

      {
        period: @period,
        period_label: StatsPeriod.label(@period),
        stats: [
          Stat.new(key: :pulled, label: "Pulled", value: pulled),
          Stat.new(key: :captured, label: "Captured", value: captured),
          Stat.new(key: :refining, label: "Refining", value: refining),
          Stat.new(key: :potentials, label: "Potentials", value: potentials),
          Stat.new(key: :scored, label: "Scored", value: scored)
        ],
        pulled: pulled,
        captured: captured,
        refining: refining,
        potentials: potentials,
        scored: scored
      }
    end
  end
end
