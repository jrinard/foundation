# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::TransferOrganization do
  let(:source_org) { create(:organization, name: "Source Org") }
  let(:target_org) { create(:organization, name: "Target Org") }
  let(:account_manager) do
    user = create(:user)
    create(:organization_membership, user: user, organization: source_org)
    user
  end

  let!(:customer) do
    create(
      :customer,
      organization: source_org,
      user: account_manager,
      onBoard: "The List",
      name: "Moved Co"
    )
  end

  let!(:contact) do
    Contact.create!(
      customer: customer,
      organization: source_org,
      firstname: "Pat",
      lastname: "Lee",
      position: "Owner"
    )
  end
  let!(:note) { create(:note, customer: customer, organization: source_org, text: "Keep this note") }

  before { Current.organization = source_org }

  it "moves the customer and related records to the target organization" do
    described_class.call(customer: customer, organization: target_org)

    customer.reload
    contact.reload
    note.reload

    expect(customer.organization_id).to eq(target_org.id)
    expect(customer.list_id).to be_nil
    expect(customer.user_id).to be_nil
    expect(contact.organization_id).to eq(target_org.id)
    expect(note.organization_id).to eq(target_org.id)
  end

  it "keeps the account manager when they belong to the target organization" do
    create(:organization_membership, user: account_manager, organization: target_org)

    described_class.call(customer: customer, organization: target_org)

    expect(customer.reload.user_id).to eq(account_manager.id)
  end

  it "only moves discovery businesses linked to the customer" do
    other_business = DiscoveryBusiness.create!(
      organization: source_org,
      source: DiscoveryBusiness::SOURCE_WA_SOS,
      external_id: "OTHER-UBI",
      business_name: "Other Co",
      office_address: "1 Main St",
      status: DiscoveryBusiness::STATUS_DISCOVERY
    )
    linked_business = DiscoveryBusiness.create!(
      organization: source_org,
      customer: customer,
      source: DiscoveryBusiness::SOURCE_WA_SOS,
      external_id: "LINKED-UBI",
      business_name: "Linked Co",
      office_address: "2 Main St",
      status: DiscoveryBusiness::STATUS_PROMOTED
    )

    described_class.call(customer: customer, organization: target_org)

    expect(linked_business.reload.organization_id).to eq(target_org.id)
    expect(other_business.reload.organization_id).to eq(source_org.id)
  end
end
