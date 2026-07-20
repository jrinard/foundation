# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::GooglePlacesLookup do
  let(:organization) { create(:organization, discovery_enabled: true) }
  let(:discovery_business) do
    create(
      :discovery_business,
      organization: organization,
      business_name: "LIFESPRING DESIGN LLC",
      city: "VANCOUVER"
    )
  end

  before { Current.organization = organization }

  describe ".search" do
    it "returns a clear error when API key is missing" do
      allow(described_class).to receive(:api_key).and_return(nil)

      result = described_class.search(discovery_business: discovery_business, api: :legacy)

      expect(result.ok).to be(false)
      expect(result.api).to eq("legacy")
      expect(result.message).to include("Missing Google Places API key")
      expect(result.places).to eq([])
    end

    it "returns candidate matches without fetching details" do
      allow(described_class).to receive(:api_key).and_return("test-key")

      search_payload = {
        "status" => "OK",
        "results" => [
          {
            "place_id" => "ChIJ_one",
            "name" => "LifeSpring Design",
            "formatted_address" => "Vancouver, WA",
            "rating" => 5.0,
            "types" => ["establishment"]
          },
          {
            "place_id" => "ChIJ_two",
            "name" => "LifeSpring Design Seattle",
            "formatted_address" => "Seattle, WA",
            "rating" => 4.2,
            "types" => ["establishment"]
          }
        ]
      }

      instance = described_class.new(discovery_business: discovery_business, api: :legacy)
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:text_search_legacy).and_return(search_payload)

      result = described_class.search(discovery_business: discovery_business, api: :legacy)

      expect(result.ok).to be(true)
      expect(result.places.size).to eq(2)
      expect(result.places.map { |place| place[:place_id] }).to eq(%w[ChIJ_one ChIJ_two])
      expect(result.message).to include("Choose the correct business")
    end
  end

  describe ".details" do
    it "loads contact fields for a chosen place_id via legacy" do
      allow(described_class).to receive(:api_key).and_return("test-key")

      details_payload = {
        "status" => "OK",
        "result" => {
          "place_id" => "ChIJ_one",
          "name" => "LifeSpring Design",
          "formatted_phone_number" => "(360) 555-0100",
          "website" => "https://example.com"
        }
      }

      instance = described_class.new(discovery_business: discovery_business, api: :legacy)
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:place_details_legacy).and_return(details_payload)

      result = described_class.details(
        discovery_business: discovery_business,
        place_id: "ChIJ_one",
        api: :legacy
      )

      expect(result.ok).to be(true)
      expect(result.details[:phone]).to eq("(360) 555-0100")
      expect(result.details[:website]).to eq("https://example.com")
    end

    it "loads contact fields for a chosen place_id via Places V1" do
      allow(described_class).to receive(:api_key).and_return("test-key")

      details_payload = {
        "_http_status" => 200,
        "id" => "places/ChIJ_v1",
        "displayName" => { "text" => "LifeSpring Design" },
        "nationalPhoneNumber" => "(360) 555-0199",
        "websiteUri" => "https://v1.example.com"
      }

      instance = described_class.new(discovery_business: discovery_business, api: :v1)
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:place_get_v1).and_return(details_payload)

      result = described_class.details(
        discovery_business: discovery_business,
        place_id: "ChIJ_v1",
        api: :v1
      )

      expect(result.ok).to be(true)
      expect(result.details[:phone]).to eq("(360) 555-0199")
      expect(result.details[:website]).to eq("https://v1.example.com")
    end
  end
end
