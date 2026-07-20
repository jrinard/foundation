# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoveryBusiness do
  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  describe ".for_captured_list" do
    let!(:working) { create(:discovery_business, organization: organization, business_name: "Working Co", archived: false) }
    let!(:archived_discovery) do
      create(:discovery_business, organization: organization, business_name: "Archived Co", archived: true)
    end
    let!(:promoted) do
      create(
        :discovery_business,
        organization: organization,
        business_name: "Promoted Co",
        status: DiscoveryBusiness::STATUS_PROMOTED,
        archived: true
      )
    end

    it "returns only working businesses by default" do
      result = described_class.for_captured_list(view: "working", hide_archived: true)

      expect(result).to contain_exactly(working)
    end

    it "returns archived discoveries when filtered" do
      result = described_class.for_captured_list(
        view: "archived",
        archive_filter: DiscoveryBusiness::ARCHIVE_FILTER_DISCOVERIES
      )

      expect(result).to contain_exactly(archived_discovery)
    end

    it "returns archived potentials when filtered" do
      result = described_class.for_captured_list(
        view: "archived",
        archive_filter: DiscoveryBusiness::ARCHIVE_FILTER_POTENTIALS
      )

      expect(result).to contain_exactly(promoted)
    end
  end

  describe "#score_label" do
    it "returns persisted score over max when scored" do
      business = create(
        :discovery_business,
        organization: organization,
        score: 150,
        scored_at: Time.current,
        score_breakdown: { "max_total" => 315 }
      )

      expect(business.score_label).to eq("150/315")
    end

    it "returns nil when not scored yet" do
      business = create(:discovery_business, organization: organization)

      expect(business.score_label).to be_nil
    end
  end
end
