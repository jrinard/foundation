# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::SyncPotentialFromDiscovery do
  let(:organization) { create(:organization, discovery_enabled: true, potentials_enabled: true) }

  let(:discovery_business) do
    create(
      :discovery_business,
      organization: organization,
      business_name: "EVERGREEN EXTERIOR CLEANING LLC",
      office_address: "123 Main St, Vancouver, WA, 98660, UNITED STATES",
      city: "VANCOUVER",
      phone: "360-555-0100",
      email: "hello@evergreen.example",
      registered_agent_name: "Jane Doe",
      status: DiscoveryBusiness::STATUS_DISCOVERY
    )
  end

  let!(:customer) do
    result = Discovery::PromoteToPotential.call(discovery_business: discovery_business)
    result.customer
  end

  before { Current.organization = organization }

  describe ".call" do
    it "updates the linked prospect and registered agent contact from discovery" do
      discovery_business.update!(
        phone: "360-555-0199",
        email: "contact@evergreen.example",
        registered_agent_name: "Janet Smith"
      )

      result = described_class.call(discovery_business: discovery_business.reload)

      expect(result.success).to be(true)
      expect(result.customer.id).to eq(customer.id)

      customer.reload
      expect(customer.phone).to eq("360-555-0199")
      expect(customer.email).to eq("contact@evergreen.example")
      expect(Customer.count).to eq(1)

      contact = customer.contacts.find_by(position: "Registered Agent")
      expect(contact.firstname).to eq("Janet")
      expect(contact.lastname).to eq("Smith")
      expect(contact.phone).to eq("360-555-0199")
      expect(contact.email).to eq("contact@evergreen.example")
    end

    it "creates a registered agent contact when one is missing" do
      customer.contacts.delete_all
      discovery_business.update!(registered_agent_name: "Alex Agent")

      result = described_class.call(discovery_business: discovery_business.reload)

      expect(result.success).to be(true)
      contact = customer.reload.contacts.find_by(position: "Registered Agent")
      expect(contact.firstname).to eq("Alex")
      expect(contact.lastname).to eq("Agent")
    end

    it "returns an error when no prospect is linked" do
      discovery_business.update!(customer: nil, status: DiscoveryBusiness::STATUS_DISCOVERY)

      result = described_class.call(discovery_business: discovery_business)

      expect(result.success).to be(false)
      expect(result.error).to eq("No linked prospect to sync.")
    end
  end
end
