require "rails_helper"

RSpec.describe "Org isolation", type: :request do
  let!(:org_a) { create(:organization, :with_pipeline_defaults, name: "Echelon Test") }
  let!(:org_b) { create(:organization, :with_pipeline_defaults, name: "Ridgefield Test") }
  let!(:admin_a) { create(:user, role: "admin", email: "admin-a@test.com") }
  let!(:admin_b) { create(:user, role: "admin", email: "admin-b@test.com") }

  let!(:customer_a) { create(:customer, :on_pipeline, organization: org_a, name: "Echelon Only Lead") }
  let!(:customer_b) { create(:customer, :on_pipeline, organization: org_b, name: "Ridgefield Only Lead") }

  before do
    create(:organization_membership, user: admin_a, organization: org_a, role: "admin")
    create(:organization_membership, user: admin_b, organization: org_b, role: "admin")
  end

  it "org A admin sees only org A customers on kanban" do
    sign_in admin_a
    get customers_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Echelon Only Lead")
    expect(response.body).not_to include("Ridgefield Only Lead")
  end

  it "org B admin cannot access org A customer by id" do
    sign_in admin_b
    expect {
      get customer_path(customer_a)
    }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "search returns only current org matches" do
    sign_in admin_a
    get search_path, params: { query: "Only Lead" }, as: :json
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    names = json["customers"].map { |c| c["name"] }
    expect(names).to include("Echelon Only Lead")
    expect(names).not_to include("Ridgefield Only Lead")
  end

  it "org A admin cannot see org B customer in home list" do
    sign_in admin_a
    get home_index_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Ridgefield Only Lead")
  end
end
