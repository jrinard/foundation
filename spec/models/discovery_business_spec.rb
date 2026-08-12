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
    let!(:with_email) do
      create(
        :discovery_business,
        organization: organization,
        business_name: "Alpha Email Co",
        email: "hello@example.com",
        created_at: 2.days.ago
      )
    end
    let!(:without_email) do
      create(
        :discovery_business,
        organization: organization,
        business_name: "Beta No Email Co",
        email: nil,
        created_at: 1.day.ago
      )
    end

    it "returns only working businesses by default" do
      result = described_class.for_captured_list(view: "working", hide_archived: true)

      expect(result).to include(working, with_email, without_email)
      expect(result).not_to include(archived_discovery, promoted)
    end

    it "sorts by name" do
      result = described_class.for_captured_list(
        view: "working",
        hide_archived: true,
        captured_sort: DiscoveryBusiness::CAPTURED_SORT_NAME
      )

      expect(result.map(&:business_name)).to eq(
        ["Alpha Email Co", "Beta No Email Co", "Working Co"]
      )
    end

    it "sorts rows with email first" do
      result = described_class.for_captured_list(
        view: "working",
        hide_archived: true,
        captured_sort: DiscoveryBusiness::CAPTURED_SORT_EMAIL
      )

      expect(result.first).to eq(with_email)
      expect(result.map(&:business_name)).to include("Beta No Email Co", "Working Co")
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

  describe ".working" do
    it "excludes archived businesses for nav and working lists" do
      working = create(:discovery_business, organization: organization, business_name: "Active Co", archived: false)
      create(:discovery_business, organization: organization, business_name: "Archived Co", archived: true)

      expect(described_class.working).to contain_exactly(working)
    end
  end

  describe "#list_status_label" do
    it "returns Waiting when flagged and not archived" do
      business = create(:discovery_business, organization: organization, waiting: true)

      expect(business.list_status_label).to eq("Waiting")
    end

    it "returns Potential when promoted" do
      customer = create(:customer, organization: organization)
      business = create(
        :discovery_business,
        organization: organization,
        status: DiscoveryBusiness::STATUS_PROMOTED,
        customer: customer,
        waiting: true
      )

      expect(business.list_status_label).to eq("Potential")
    end
  end

  describe "#mark_waiting!" do
    it "clears archived and sets waiting" do
      business = create(:discovery_business, organization: organization, archived: true)

      business.mark_waiting!

      expect(business).to have_attributes(archived: false, waiting: true)
    end
  end

  describe "#archive!" do
    it "clears waiting when archived" do
      business = create(:discovery_business, organization: organization, waiting: true)

      business.archive!

      expect(business).to have_attributes(archived: true, waiting: false)
    end
  end

  describe "#captured_age_label" do
    it "returns today when captured on the current date" do
      business = create(:discovery_business, organization: organization, created_at: Time.current)

      expect(business.captured_age_label).to eq("today")
    end

    it "returns day count when captured earlier" do
      business = create(
        :discovery_business,
        organization: organization,
        created_at: 25.days.ago.to_date.in_time_zone
      )

      expect(business.captured_age_label).to eq("25 days ago")
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
