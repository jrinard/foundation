# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::SaveWaSosBusinesses do
  let(:organization) { create(:organization, discovery_enabled: true) }

  let(:row) do
    {
      "Business Name" => "FREQUENCY IN BALANCE LLC",
      "UBI#" => "606 263 511",
      "Business Type" => "WA LIMITED LIABILITY COMPANY",
      "Office Address" => "3810 NW MCCANN RD, VANCOUVER, WA, 98685-1130, UNITED STATES",
      "Reg Name" => "TARA JOHNSON"
    }
  end

  before { Current.organization = organization }

  describe ".call" do
    it "creates a discovery business from filtered SOS row" do
      result = described_class.call(organization: organization, rows: [row], filter_city: "Vancouver")

      expect(result.created).to eq(1)
      expect(result.skipped).to eq(0)
      expect(result.created_external_ids).to eq(["606263511"])

      record = DiscoveryBusiness.last
      expect(record.business_name).to eq("FREQUENCY IN BALANCE LLC")
      expect(record.external_id).to eq("606263511")
      expect(record.city).to eq("VANCOUVER")
      expect(record.filter_city).to eq("Vancouver")
      expect(record.status).to eq(DiscoveryBusiness::STATUS_DISCOVERY)
    end

    it "skips duplicates on second save with a clear message" do
      described_class.call(organization: organization, rows: [row], filter_city: "Vancouver")

      result = described_class.call(organization: organization, rows: [row], filter_city: "Vancouver")

      expect(result.created).to eq(0)
      expect(result.skipped).to eq(1)
      expect(result.skip_messages).to include('"FREQUENCY IN BALANCE LLC" is already on your Captured list.')
      expect(DiscoveryBusiness.count).to eq(1)
    end

    it "reports archived duplicates distinctly" do
      create(
        :discovery_business,
        organization: organization,
        external_id: "606263511",
        business_name: "FREQUENCY IN BALANCE LLC",
        archived: true
      )

      result = described_class.call(organization: organization, rows: [row], filter_city: "Vancouver")

      expect(result.created).to eq(0)
      expect(result.skip_messages).to include('"FREQUENCY IN BALANCE LLC" is already captured and archived.')
    end
  end
end
