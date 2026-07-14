require "rails_helper"

RSpec.describe "Offering filter query" do
  let!(:org) { create(:organization, :with_pipeline_defaults) }
  let!(:customer) do
    create(:customer, :on_pipeline, organization: org, name: "Filtered Customer",
           onBoard: "Current on Board", active: true)
  end

  before { Current.organization = org }

  it "returns current customers with an active offering slot" do
    create(:offering, organization: org, customer: customer, offering_1_active: true)

    results = Customer.current_customers
                      .joins(:offerings)
                      .where(offerings: { offering_1_active: true })

    expect(results).to include(customer)
  end

  it "excludes customers without the active offering slot" do
    create(:offering, organization: org, customer: customer, offering_1_active: false)

    results = Customer.current_customers
                      .joins(:offerings)
                      .where(offerings: { offering_1_active: true })

    expect(results).not_to include(customer)
  end
end
