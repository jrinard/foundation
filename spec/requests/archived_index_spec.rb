# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Archived index", type: :request do
  let!(:organization) { create(:organization, :with_pipeline_defaults, archived_enabled: true) }
  let!(:admin) { create(:user, role: "admin") }

  before do
    create(:organization_membership, user: admin, organization: organization)
    sign_in admin
  end

  it "renders the archived page" do
    get archived_index_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Archived Clients")
  end

  it "renders client actions when a customer is selected" do
    customer = create(
      :customer,
      organization: organization,
      onBoard: "Archive",
      archived: true,
      name: "Archived Co"
    )

    get archived_index_path(id: customer.id)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Unarchive")
    expect(response.body).to include("Archived Co")
  end
end
