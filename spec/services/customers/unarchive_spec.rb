# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::Unarchive do
  let(:organization) { create(:organization, :with_pipeline_defaults) }

  before { Current.organization = organization }

  it "restores a prospect to The List" do
    customer = create(
      :customer,
      organization: organization,
      onBoard: "Archive",
      archived: true,
      active: false,
      archived_from_on_board: "The List"
    )

    described_class.call(customer: customer)

    customer.reload
    expect(customer.archived).to be(false)
    expect(customer.onBoard).to eq("The List")
    expect(customer.archived_from_on_board).to be_nil
  end

  it "restores a current client to Current Not on Board" do
    customer = create(
      :customer,
      organization: organization,
      onBoard: "Archive",
      archived: true,
      active: true,
      archived_from_on_board: "Current Not on Board"
    )

    described_class.call(customer: customer)

    customer.reload
    expect(customer.archived).to be(false)
    expect(customer.onBoard).to eq("Current Not on Board")
  end

  it "falls back using active when archived_from_on_board is blank" do
    customer = create(
      :customer,
      organization: organization,
      onBoard: "Archive",
      archived: true,
      active: false,
      archived_from_on_board: nil
    )

    described_class.call(customer: customer)

    expect(customer.reload.onBoard).to eq("The List")
  end
end
