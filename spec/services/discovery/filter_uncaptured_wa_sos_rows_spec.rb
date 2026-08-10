# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::FilterUncapturedWaSosRows do
  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  it "removes rows whose UBI is already captured" do
    create(
      :discovery_business,
      organization: organization,
      external_id: "123456789",
      business_name: "Already Captured LLC"
    )

    rows = [
      { "Business Name" => "Already Captured LLC", "UBI#" => "123456789" },
      { "Business Name" => "Fresh Co LLC", "UBI#" => "987654321" }
    ]

    result = described_class.call(organization: organization, rows: rows)

    expect(result.rows.size).to eq(1)
    expect(result.rows.first["Business Name"]).to eq("Fresh Co LLC")
    expect(result.hidden_count).to eq(1)
  end

  it "hides archived captures too" do
    create(
      :discovery_business,
      organization: organization,
      external_id: "111222333",
      archived: true
    )

    rows = [{ "Business Name" => "Archived Co", "UBI#" => "111222333" }]

    result = described_class.call(organization: organization, rows: rows)

    expect(result.rows).to eq([])
    expect(result.hidden_count).to eq(1)
  end
end
