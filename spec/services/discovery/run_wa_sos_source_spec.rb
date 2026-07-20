# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::RunWaSosSource do
  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  it "returns without fetching when the source is off" do
    source = DiscoverySource.ensure_wa_sos!(organization)
    source.update!(enabled: false)

    result = described_class.call(organization: organization)

    expect(result.source.enabled?).to be(false)
    expect(result.fetch_result).to be_nil
    expect(result.rows).to eq([])
  end

  it "builds sos_query from persisted settings" do
    source = DiscoverySource.ensure_wa_sos!(organization)
    source.update_wa_sos_settings!(business_type_id: "65", date_cadence: "24h")

    response = Discovery::Sources::WaSos::Client::Response.new(
      status: 200,
      body: "Business Name,UBI#\nTest Co,123\n",
      parsed: nil,
      content_type: "text/csv"
    )
    allow(Discovery::SourceRegistry).to receive(:fetch).and_return(response)

    result = described_class.call(organization: organization)

    expect(Discovery::SourceRegistry).to have_received(:fetch).with(
      :wa_sos,
      hash_including(business_type_id: "65", business_status_id: "1")
    )
    expect(result.sos_query[:business_type_id]).to eq("65")
  end
end
