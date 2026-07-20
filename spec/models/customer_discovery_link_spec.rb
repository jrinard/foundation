# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customer, type: :model do
  describe "destroying a linked potential" do
    let(:organization) { create(:organization, discovery_enabled: true, potentials_enabled: true) }

    let(:discovery_business) do
      create(:discovery_business, organization: organization, status: DiscoveryBusiness::STATUS_DISCOVERY)
    end

    let!(:customer) do
      result = Discovery::PromoteToPotential.call(discovery_business: discovery_business)
      result.customer
    end

    before { Current.organization = organization }

    it "reopens the discovery business so it can be promoted again" do
      expect { customer.destroy! }.to change(Customer, :count).by(-1)

      discovery_business.reload
      expect(discovery_business.status).to eq(DiscoveryBusiness::STATUS_DISCOVERY)
      expect(discovery_business.customer_id).to be_nil
      expect(discovery_business).to be_promotable
    end
  end
end
