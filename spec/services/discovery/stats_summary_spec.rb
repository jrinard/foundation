# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::StatsSummary do
  include ActiveSupport::Testing::TimeHelpers

  let(:organization) { create(:organization, discovery_enabled: true, timezone: "America/Boise") }

  before { Current.organization = organization }

  it "returns org-scoped funnel counts for the selected period" do
    travel_to Time.zone.local(2026, 7, 17, 12, 0, 0) do
      create(
        :discovery_run,
        organization: organization,
        row_count: 100,
        status: DiscoveryRun::STATUS_SUCCESS,
        started_at: Time.current
      )
      create(
        :discovery_run,
        organization: organization,
        row_count: 50,
        status: DiscoveryRun::STATUS_SUCCESS,
        started_at: 2.days.ago
      )

      create(:discovery_business, organization: organization, business_name: "Active Co", archived: false)
      create(
        :discovery_business,
        organization: organization,
        business_name: "Promoted Co",
        status: DiscoveryBusiness::STATUS_PROMOTED,
        customer: create(:customer, organization: organization, onBoard: "The List"),
        archived: true,
        scored_at: Time.current,
        score: 80
      )

      other_org = create(:organization, discovery_enabled: true)
      create(:discovery_run, organization: other_org, row_count: 999, status: DiscoveryRun::STATUS_SUCCESS)
      create(:discovery_business, organization: other_org, business_name: "Other Org Co")

      result = described_class.call(organization: organization, period: Discovery::StatsPeriod::TODAY)

      expect(result[:pulled]).to eq(100)
      expect(result[:captured]).to eq(2)
      expect(result[:refining]).to eq(1)
      expect(result[:potentials]).to eq(1)
      expect(result[:scored]).to eq(1)
      expect(result[:period]).to eq(Discovery::StatsPeriod::TODAY)
      expect(result[:stats].map(&:key)).to eq([:pulled, :captured, :refining, :potentials, :scored])
    end
  end

  it "includes older activity when period is year" do
    travel_to Time.zone.local(2026, 7, 17, 12, 0, 0) do
      create(
        :discovery_run,
        organization: organization,
        row_count: 100,
        status: DiscoveryRun::STATUS_SUCCESS,
        started_at: Time.current
      )
      create(
        :discovery_run,
        organization: organization,
        row_count: 50,
        status: DiscoveryRun::STATUS_SUCCESS,
        started_at: 2.days.ago
      )

      result = described_class.call(organization: organization, period: Discovery::StatsPeriod::YEAR)

      expect(result[:pulled]).to eq(150)
    end
  end
end
