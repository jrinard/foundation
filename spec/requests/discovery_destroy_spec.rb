# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Discovery destroy", type: :request do
  let(:organization) { create(:organization, discovery_enabled: true) }
  let(:user) { create(:user, role: "admin", email: "discovery-destroy@test.com") }
  let!(:business) do
    create(
      :discovery_business,
      organization: organization,
      score: 85,
      scored_at: Time.current,
      score_breakdown: { "website" => 50 },
      score_summary: { "summary_text" => "Website" }
    )
  end

  before do
    create(:organization_membership, user: user, organization: organization, role: "admin")
    Current.organization = organization
    sign_in user
  end

  it "deletes the discovery business and clears the UBI for re-capture" do
    expect do
      delete discovery_path(business)
    end.to change(DiscoveryBusiness, :count).by(-1)

    expect(response).to redirect_to(discovery_index_path)
    follow_redirect!
    expect(response.body).to include("Deleted #{business.business_name}")
  end
end
