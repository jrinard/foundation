# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::OpportunityCaptureSummary do
  include ActiveSupport::Testing::TimeHelpers

  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  def summary_for(attrs = {})
    business = create(:discovery_business, organization: organization, **attrs)
    preview = Discovery::OpportunityScorePreview.call(discovery_business: business)
    described_class.call(discovery_business: business, score_preview: preview)
  end

  it "recommends website, branding, and ReviewBox when both are sell gaps" do
    result = summary_for(
      website_check_status: DiscoveryBusiness::CHECK_MISSING,
      brand_check_status: DiscoveryBusiness::CHECK_MISSING,
      places_check_status: DiscoveryBusiness::CHECK_MISSING
    )

    expect(result[:headline]).to include("Website + branding")
    expect(result[:bullets].join(" ")).to include("ReviewBox")
    expect(result[:skip_social]).to be(true)
  end

  it "recommends reputation growth when Places is missing" do
    result = summary_for(places_check_status: DiscoveryBusiness::CHECK_MISSING)

    expect(result[:bullets].join(" ")).to include("Google Places")
    expect(result[:bullets].join(" ")).to include("ReviewBox")
  end

  it "recommends hosting and maintenance when a site is on file and Sell is toggled on" do
    result = summary_for(
      website: "https://example.com",
      hosting_check_status: DiscoveryBusiness::CHECK_MISSING
    )

    expect(result[:headline]).to include("Hosting & maintenance")
    expect(result[:bullets].join(" ")).to include("hosting & maintenance")
  end

  it "notes established businesses outside the new-business fit window" do
    travel_to Time.zone.parse("2026-07-17 12:00:00") do
      result = summary_for(
        website: "https://example.com",
        created_at: 45.days.ago
      )

      expect(result[:bullets].join(" ")).to include("systems")
    end
  end
end
