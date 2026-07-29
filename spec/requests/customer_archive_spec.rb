# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Customer archive and restore", type: :request do
  let!(:organization) { create(:organization, :with_pipeline_defaults, discovery_enabled: true) }
  let!(:admin) { create(:user, role: "admin") }
  let!(:customer) do
    Current.organization = organization
    create(:customer, organization: organization, onBoard: "The List", name: "Archive Me", active: false)
  end

  before do
    create(:organization_membership, user: admin, organization: organization)
    sign_in admin
  end

  it "archives the prospect and returns a potentials redirect" do
    post archive_customer_path(customer),
         headers: {
           "HTTP_REFERER" => potentials_url(id: customer.id),
           "Accept" => "application/json"
         }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["redirect"]).to include("/potentials")
    expect(customer.reload.archived).to be(true)
    expect(Customer.potential_customers).not_to include(customer)
  end

  it "archives a current client and returns a home redirect" do
    Current.organization = organization
    customer.update!(onBoard: "Current Not on Board", active: true)

    post archive_customer_path(customer),
         headers: {
           "HTTP_REFERER" => home_index_url(id: customer.id),
           "Accept" => "application/json"
         }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["redirect"]).to include("/home")
    expect(customer.reload.archived).to be(true)
    expect(Customer.current_customers).not_to include(customer)
  end

  it "restores an archived prospect to potentials" do
    Customers::Archive.call(customer: customer)

    post unarchive_customer_path(customer),
         headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["redirect"]).to include("/potentials")
    expect(customer.reload.archived).to be(false)
    expect(customer.onBoard).to eq("The List")
  end

  it "permanently deletes from archived" do
    Customers::Archive.call(customer: customer)

    delete customer_path(customer),
           headers: {
             "HTTP_REFERER" => archived_index_url(id: customer.id),
             "Accept" => "application/json"
           }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["redirect"]).to include("/archived")
    expect(Customer.unscoped_by_organization.find_by(id: customer.id)).to be_nil
  end
end
