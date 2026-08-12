# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::BusinessGoogleSearch do
  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  def search_for(intent: :foundation, **attrs)
    business = create(
      :discovery_business,
      organization: organization,
      business_name: "Acme Plumbing LLC",
      registered_agent_name: "Jane Doe",
      office_address: "123 Main St, Vancouver, WA, 98660, UNITED STATES",
      city: "Vancouver",
      external_id: "606263511",
      raw_payload: {
        "Business Name" => "Acme Plumbing LLC",
        "UBI#" => "606 263 511"
      },
      **attrs
    )
    described_class.new(discovery_business: business, intent: intent)
  end

  describe "#query" do
    it "builds a fringe-focused foundation search with variants, directories, and contact signals" do
      query = search_for.query

      expect(query).to include('"Acme Plumbing LLC"')
      expect(query).to include('"Acme Plumbing"')
      expect(query).to include('"Jane Doe"')
      expect(query).to include("owner OR principal")
      expect(query).to include("Vancouver WA")
      expect(query).to include("98660")
      expect(query).to include('"123 Main St"')
      expect(query).to include("phone OR email")
      expect(query).to include("@gmail.com")
      expect(query).to include("site:facebook.com")
      expect(query).to include("site:bizapedia.com")
      expect(query).to include("606 263 511")
      expect(query).to include("UBI")
    end

    it "skips corporate registered agent names but keeps address and UBI anchors" do
      query = search_for(registered_agent_name: "CT CORPORATION SYSTEM").query

      expect(query).not_to include("CT CORPORATION")
      expect(query).to include('"123 Main St"')
      expect(query).to include("606 263 511")
      expect(query).to include("owner OR principal")
    end

    it "includes vertical classification when present" do
      query = search_for(vertical_classification: "Plumbing").query

      expect(query).to include('"Plumbing"')
    end

    it "builds a reputation search with maps and review directory targets" do
      query = search_for(intent: :reputation).query

      expect(query).to include('"Acme Plumbing LLC"')
      expect(query).to include("reviews OR rating")
      expect(query).to include("site:google.com/maps")
      expect(query).to include("site:yelp.com")
    end

    it "builds a social search with profile directory targets" do
      query = search_for(intent: :social).query

      expect(query).to include("site:facebook.com")
      expect(query).to include("site:linkedin.com")
      expect(query).to include("site:nextdoor.com")
    end
  end

  describe "#url" do
    it "returns a google search URL" do
      url = search_for.url

      expect(url).to start_with("https://www.google.com/search?q=")
      expect(url).to include(CGI.escape('"Acme Plumbing LLC"'))
    end
  end
end
