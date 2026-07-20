# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::PersistOpportunityScore do
  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  def persist_for(attrs = {})
    business = create(:discovery_business, organization: organization, **attrs)
    described_class.call(discovery_business: business)
  end

  it "persists score, breakdown, summary, and scored_at" do
    result = persist_for(
      website_check_status: DiscoveryBusiness::CHECK_MISSING,
      vertical_classification: "HVAC"
    )

    business = result.business.reload
    expect(business.score).to eq(result.preview[:total])
    expect(business.scored_at).to be_present
    expect(business.score_breakdown["total"]).to eq(business.score)
    expect(business.score_breakdown["pillars"]).to be_an(Array)
    expect(business.score_summary["need_bullets"]).to be_an(Array)
    expect(business.score_summary["need_bullets"]).not_to be_empty
    expect(business.score_summary["opportunity_summary"]["summary_text"]).to include("Foundation")
  end

  it "stores gap lines as need bullets" do
    result = persist_for(website_check_status: DiscoveryBusiness::CHECK_MISSING)
    bullets = result.business.reload.score_summary["need_bullets"]

    expect(bullets.first).to include(
      "pillar" => "website",
      "points" => 50
    )
  end
end
