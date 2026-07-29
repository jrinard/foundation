# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::Archive do
  let(:organization) { create(:organization, discovery_enabled: true, potentials_enabled: true) }

  let(:discovery_business) do
    create(:discovery_business, organization: organization, status: DiscoveryBusiness::STATUS_DISCOVERY)
  end

  let!(:customer) do
    result = Discovery::PromoteToPotential.call(discovery_business: discovery_business)
    result.customer
  end

  before { Current.organization = organization }

  it "archives the customer without deleting the record" do
    expect { described_class.call(customer: customer) }.not_to change(Customer, :count)

    customer.reload
    expect(customer.archived).to be(true)
    expect(customer.onBoard).to eq("Archive")
    expect(customer.archived_from_on_board).to eq("The List")
  end

  it "keeps the discovery business linked" do
    described_class.call(customer: customer)

    discovery_business.reload
    expect(discovery_business.customer_id).to eq(customer.id)
    expect(discovery_business.status).to eq(DiscoveryBusiness::STATUS_PROMOTED)
  end
end
