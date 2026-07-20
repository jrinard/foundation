# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Discovery update captured business", type: :request do
  let(:organization) { create(:organization, discovery_enabled: true) }
  let(:user) { create(:user, role: "admin", email: "discovery-admin@test.com") }
  let!(:business) do
    create(
      :discovery_business,
      organization: organization,
      phone: "555-0100",
      website: "https://example.com",
      google_place_id: "ChIJtest",
      google_rating: 4.5,
      google_rating_count: 12,
      places_check_status: DiscoveryBusiness::CHECK_FOUND
    )
  end

  before do
    create(:organization_membership, user: user, organization: organization, role: "admin")
    sign_in user
  end

  it "keeps place enrichment when an inline patch updates a different field" do
    snapshot = business.captured_business_snapshot.merge(registered_agent_name: "Edited Agent")

    patch update_captured_business_discovery_path(business),
          params: {
            inline: "1",
            discovery_business: snapshot
          },
          headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["business_snapshot"]["phone"]).to eq("555-0100")

    business.reload
    expect(business.registered_agent_name).to eq("Edited Agent")
    expect(business.phone).to eq("555-0100")
    expect(business.website).to eq("https://example.com")
    expect(business.google_place_id).to eq("ChIJtest")
    expect(business.google_rating).to eq(4.5)
    expect(business.google_rating_count).to eq(12)
    expect(business.places_check_status).to eq(DiscoveryBusiness::CHECK_FOUND)
  end

  it "does not wipe enrichment from blank modal fields on full-form save" do
    patch update_captured_business_discovery_path(business),
          params: {
            discovery_business: {
              business_name: business.business_name,
              registered_agent_name: "Modal Agent",
              phone: "",
              website: "",
              google_place_id: "",
              google_rating: "",
              google_rating_count: ""
            }
          },
          headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:ok)

    business.reload
    expect(business.registered_agent_name).to eq("Modal Agent")
    expect(business.phone).to eq("555-0100")
    expect(business.website).to eq("https://example.com")
    expect(business.google_place_id).to eq("ChIJtest")
  end
end
