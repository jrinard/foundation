# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Customer organization transfer", type: :request do
  let!(:lifespring) do
    create(:organization, name: "LifeSpring Design", slug: "lifespring-test",
           sales_pipeline_enabled: true, discovery_enabled: true, outreach_enabled: true)
  end
  let!(:echelon) do
    create(:organization, name: "Echelon Demo", slug: "echelon-test", sales_pipeline_enabled: true)
  end
  let!(:ridgefield) do
    create(:organization, name: "Ridgefield Demo", slug: "ridgefield-test",
           sales_pipeline_enabled: false, potentials_enabled: false, operations_enabled: true)
  end
  let!(:superadmin) { create(:user, :superadmin) }

  let!(:customer) do
    Current.organization = lifespring
    create(:customer, organization: lifespring, onBoard: "The List", name: "Transfer Prospect", active: false)
  end

  before do
    [lifespring, echelon, ridgefield].each(&:provision_defaults!)
    create(:organization_membership, user: superadmin, organization: lifespring)
    sign_in superadmin
    post switch_organization_path, params: { organization_id: lifespring.id }
  end

  def patch_customer_from_potentials(to_org)
    patch customer_path(customer),
          params: { customer: { name: customer.name, organization_id: to_org.id } },
          headers: {
            "HTTP_REFERER" => potentials_url(id: customer.id, view_notes: "view_notes"),
            "Accept" => "application/json"
          }
  end

  it "redirects to potentials in the target org after transfer" do
    patch_customer_from_potentials(echelon)

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["redirect"]).to include("/potentials")
    expect(body["redirect"]).to include("id=#{customer.id}")

    customer.reload
    expect(customer.organization_id).to eq(echelon.id)
  end

  it "loads potentials after transferring to a second org" do
    patch_customer_from_potentials(echelon)
    follow_redirect! if response.redirect?

    patch customer_path(customer),
          params: { customer: { name: customer.name, organization_id: ridgefield.id } },
          headers: {
            "HTTP_REFERER" => potentials_url(id: customer.id, view_notes: "view_notes"),
            "Accept" => "application/json"
          }

    expect(response).to have_http_status(:ok)
    redirect = response.parsed_body["redirect"]
    expect(redirect).to be_present

    customer.reload
    expect(customer.organization_id).to eq(ridgefield.id)

    get redirect
    expect(response).to have_http_status(:ok)
  end

  it "loads potentials after round-trip transfer between orgs" do
    patch_customer_from_potentials(echelon)
    customer.reload

    post switch_organization_path, params: { organization_id: echelon.id }

    patch customer_path(customer),
          params: { customer: { name: customer.name, organization_id: lifespring.id } },
          headers: {
            "HTTP_REFERER" => potentials_url(id: customer.id, view_notes: "view_notes"),
            "Accept" => "application/json"
          }

    expect(response).to have_http_status(:ok)
    redirect = response.parsed_body["redirect"]

    get redirect
    expect(response).to have_http_status(:ok)
  end

  it "loads potentials when customer id belongs to another org (superadmin)" do
    post switch_organization_path, params: { organization_id: echelon.id }

    get potentials_path(id: customer.id, view_notes: "view_notes")
    expect(response).to have_http_status(:ok)
    expect(session[:organization_id]).to eq(lifespring.id)
  end

  it "transfers customer when session org differs from customer org (stale edit form)" do
    patch_customer_from_potentials(echelon)
    customer.reload

    post switch_organization_path, params: { organization_id: lifespring.id }

    patch customer_path(customer),
          params: { customer: { name: customer.name, organization_id: ridgefield.id } },
          headers: {
            "HTTP_REFERER" => potentials_url(id: customer.id, view_notes: "view_notes"),
            "Accept" => "application/json"
          }

    expect(response).to have_http_status(:ok)
    expect(customer.reload.organization_id).to eq(ridgefield.id)
  end
end
