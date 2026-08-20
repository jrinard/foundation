# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::DataAxelEnrichmentLookup do
  let(:organization) { create(:organization) }
  let(:csv_body) do
    <<~CSV
      "Company Name","Executive First Name","Executive Last Name","Address","City","State","ZIP Code","IUSA Number","Phone Number Combined","Primary SIC Description","Legal Name"
      "Acme Plumbing LLC","Jane","Doe","123 Main St","Vancouver","WA","98660","82-277-7860","(360) 555-0100","Plumbing Contractors","ACME PLUMBING LLC"
      "Other Co","Bob","Smith","456 Oak Ave","Amboy","WA","98601","11-111-1111","(360) 555-9999","Retail","OTHER CO"
    CSV
  end

  let(:business) do
    create(
      :discovery_business,
      organization: organization,
      source: DiscoveryBusiness::SOURCE_WA_SOS,
      business_name: "Acme Plumbing LLC",
      city: "Vancouver",
      raw_payload: { "UBI#" => "822777860" }
    )
  end

  let(:catalog) { instance_double(Discovery::Sources::DataAxel::FileCatalog) }

  before do
    allow(Discovery::Sources::DataAxel::FileCatalog).to receive(:for).with(organization).and_return(catalog)
    allow(catalog).to receive(:merged_csv_body).and_return(csv_body)
  end

  describe ".search" do
    it "returns ranked matches from local Axel CSV" do
      result = described_class.search(discovery_business: business)

      expect(result.ok).to be(true)
      expect(result.results.size).to eq(1)
      expect(result.results.first[:business_name]).to eq("Acme Plumbing LLC")
      expect(result.results.first[:phone]).to eq("(360) 555-0100")
      expect(result.results.first[:ubi_match]).to be(true)
    end

    it "filters by business name when UBI does not match" do
      business.update!(raw_payload: { "UBI#" => "999999999" })

      result = described_class.search(discovery_business: business)

      expect(result.ok).to be(true)
      expect(result.results.map { |row| row[:business_name] }).to eq(["Acme Plumbing LLC"])
    end

    it "returns failure when CSV data is missing" do
      allow(catalog).to receive(:merged_csv_body).and_return("")

      result = described_class.search(discovery_business: business)

      expect(result.ok).to be(false)
      expect(result.message).to include("Mountain Gems")
    end
  end

  describe ".details" do
    it "returns full Axel details for an IUSA" do
      result = described_class.details(discovery_business: business, iusa: "822777860")

      expect(result.ok).to be(true)
      expect(result.details[:phone]).to eq("(360) 555-0100")
      expect(result.details[:office_address]).to include("123 Main St")
      expect(result.details[:registered_agent_name]).to eq("Jane Doe")
      expect(result.details[:vertical_classification]).to eq("Plumbing")
    end
  end
end

RSpec.describe Discovery::Verticals do
  describe ".infer_from_axel" do
    it "maps SIC descriptions to Foundation verticals" do
      expect(described_class.infer_from_axel(business_type: "Plumbing Contractors")).to eq("Plumbing")
      expect(described_class.infer_from_axel(business_type: "Retail")).to eq("Retail")
      expect(described_class.infer_from_axel(business_type: "Construction Companies")).to eq("Construction Contractor")
    end
  end
end
