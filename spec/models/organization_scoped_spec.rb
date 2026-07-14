require "rails_helper"

RSpec.describe OrganizationScoped do
  let!(:org_a) { create(:organization, :with_pipeline_defaults, name: "Org A") }
  let!(:org_b) { create(:organization, :with_pipeline_defaults, name: "Org B") }

  describe "default scope" do
    let!(:customer_a) { create(:customer, organization: org_a, name: "Alpha Customer") }
    let!(:customer_b) { create(:customer, organization: org_b, name: "Beta Customer") }

    it "returns only records for Current.organization" do
      Current.organization = org_a
      expect(Customer.all).to contain_exactly(customer_a)
    end

    it "does not leak records across orgs when Current.organization changes" do
      Current.organization = org_b
      expect(Customer.all).to contain_exactly(customer_b)
      expect(Customer.all).not_to include(customer_a)
    end

    it "allows cross-org reads via unscoped_by_organization" do
      Current.organization = org_a
      ids = Customer.unscoped_by_organization.pluck(:id)
      expect(ids).to include(customer_a.id, customer_b.id)
    end
  end

  describe "auto-assign on create" do
    it "assigns organization_id from Current.organization" do
      Current.organization = org_a
      customer = Customer.create!(name: "New Lead")
      expect(customer.organization_id).to eq(org_a.id)
    end
  end
end
