# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::PromoteToPotential do
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
      external_id: "605249629",
      status: DiscoveryBusiness::STATUS_DISCOVERY
    )
  end

  before { Current.organization = organization }

  describe ".call" do
    it "creates a potential customer and marks the discovery business promoted" do
      discovery_business.update!(registered_agent_name: "Jane Doe")

      result = described_class.call(discovery_business: discovery_business)

      expect(result.created).to be(true)
      expect(result.already_promoted).to be(false)

      customer = result.customer
      expect(customer.name).to eq("EVERGREEN EXTERIOR CLEANING LLC")
      expect(customer.onBoard).to eq("The List")
      expect(customer.active).to be(false)
      expect(customer.list_id).to be_nil
      expect(customer.phone).to eq("360-555-0100")
      expect(customer.email).to eq("hello@evergreen.example")
      expect(customer.city).to eq("Vancouver")
      expect(customer.state).to eq("WA")
      expect(customer.zip).to eq("98660")
      expect(customer.extra_notes).to include("WA SOS Discovery")
      expect(customer.extra_notes).to include("605249629")

      contact = customer.contacts.first
      expect(contact.firstname).to eq("Jane")
      expect(contact.lastname).to eq("Doe")
      expect(contact.position).to eq("Registered Agent")

      discovery_business.reload
      expect(discovery_business.status).to eq(DiscoveryBusiness::STATUS_PROMOTED)
      expect(discovery_business.customer_id).to eq(customer.id)
      expect(discovery_business.archived).to be(true)
    end

    it "links an existing potential instead of creating a duplicate" do
      existing = create(
        :customer,
        organization: organization,
        name: "EVERGREEN EXTERIOR CLEANING LLC",
        onBoard: "The List",
        active: false
      )

      result = described_class.call(discovery_business: discovery_business)

      expect(result.created).to be(false)
      expect(result.customer.id).to eq(existing.id)
      expect(Customer.where(name: existing.name).count).to eq(1)
    end

    it "returns the existing customer when already promoted" do
      customer = create(:customer, organization: organization, name: discovery_business.business_name, onBoard: "The List")
      discovery_business.update!(status: DiscoveryBusiness::STATUS_PROMOTED, customer: customer)

      result = described_class.call(discovery_business: discovery_business)

      expect(result.already_promoted).to be(true)
      expect(result.customer).to eq(customer)
      expect(Customer.count).to eq(1)
    end
  end
end
