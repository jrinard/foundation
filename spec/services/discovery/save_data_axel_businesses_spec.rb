# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::SaveDataAxelBusinesses do
  let(:organization) { create(:organization, discovery_enabled: true) }

  let(:row) do
    {
      "Business Name" => "Acme Plumbing LLC",
      "UBI#" => "822777860",
      "IUSA Number" => "82-277-7860",
      "Business Type" => "Plumbing Contractors",
      "Office Address" => "123 Main St, Vancouver, WA, 98660",
      "Reg Name" => "Jane Doe",
      "City" => "Vancouver",
      "Phone Number Combined" => "(360) 555-0100"
    }
  end

  before { Current.organization = organization }

  describe ".call" do
    it "creates a discovery business with phone and inferred vertical" do
      result = described_class.call(organization: organization, rows: [row], filter_city: "Vancouver")

      expect(result.created).to eq(1)
      expect(result.skipped).to eq(0)

      record = DiscoveryBusiness.last
      expect(record.source).to eq(DiscoveryBusiness::SOURCE_DATA_AXEL)
      expect(record.external_id).to eq("822777860")
      expect(record.phone).to eq("(360) 555-0100")
      expect(record.vertical_classification).to eq("Plumbing")
      expect(record.office_address).to include("123 Main St")
    end
  end
end
