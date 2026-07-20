# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::LoadWaSosRun do
  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  it "parses rows from a reloadable run snapshot" do
    run = create(
      :discovery_run,
      organization: organization,
      status: DiscoveryRun::STATUS_SUCCESS,
      raw_csv: "Business Name,UBI#\nTest Co,123\nAnother Co,456\n"
    )

    result = described_class.call(run: run)

    expect(result.rows.size).to eq(2)
    expect(result.rows.first["Business Name"]).to eq("Test Co")
  end

  it "raises when the run has no csv snapshot" do
    run = create(:discovery_run, organization: organization, raw_csv: nil)

    expect { described_class.call(run: run) }.to raise_error(ArgumentError, /no saved CSV/)
  end
end
