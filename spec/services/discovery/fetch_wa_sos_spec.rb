# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::FetchWaSos do
  let(:organization) { create(:organization, discovery_enabled: true) }
  let(:user) { create(:user, name: "Test Admin") }

  before { Current.organization = organization }

  it "records a skipped run when the source is disabled" do
    source = DiscoverySource.ensure_wa_sos!(organization)
    source.update!(enabled: false)

    result = described_class.call(
      organization: organization,
      user: user,
      triggered_by: DiscoveryRun::TRIGGER_MANUAL
    )

    expect(result.run).to be_persisted
    expect(result.run.status).to eq(DiscoveryRun::STATUS_SKIPPED)
    expect(result.run.trigger_label).to eq("Test Admin")
    expect(result.rows).to eq([])
  end

  it "records a successful run with row count and settings snapshot" do
    DiscoverySource.ensure_wa_sos!(organization)

    response = Discovery::Sources::WaSos::Client::Response.new(
      status: 200,
      body: "Business Name,UBI#\nTest Co,123\nAnother Co,456\n",
      parsed: nil,
      content_type: "text/csv"
    )
    allow(Discovery::SourceRegistry).to receive(:fetch).and_return(response)

    result = described_class.call(
      organization: organization,
      user: user,
      triggered_by: DiscoveryRun::TRIGGER_MANUAL,
      overrides: { date_cadence: "24h" }
    )

    run = result.run
    expect(run.status).to eq(DiscoveryRun::STATUS_SUCCESS)
    expect(run.row_count).to eq(2)
    expect(run.http_status).to eq(200)
    expect(run.triggered_by_user).to eq(user)
    expect(run.settings_snapshot["date_cadence"]).to eq("24h")
    expect(run.finished_at).to be_present
    expect(run.raw_csv).to include("Test Co")
  end

  it "records an empty run when the CSV has no data rows" do
    DiscoverySource.ensure_wa_sos!(organization)

    response = Discovery::Sources::WaSos::Client::Response.new(
      status: 200,
      body: "Business Name,UBI#\n",
      parsed: nil,
      content_type: "text/csv"
    )
    allow(Discovery::SourceRegistry).to receive(:fetch).and_return(response)

    result = described_class.call(
      organization: organization,
      user: user,
      triggered_by: DiscoveryRun::TRIGGER_MANUAL
    )

    expect(result.run.status).to eq(DiscoveryRun::STATUS_EMPTY)
    expect(result.run.row_count).to eq(0)
  end

  it "records a failed run when the HTTP response is not successful" do
    DiscoverySource.ensure_wa_sos!(organization)

    response = Discovery::Sources::WaSos::Client::Response.new(
      status: 500,
      body: "error",
      parsed: nil,
      content_type: "text/plain"
    )
    allow(Discovery::SourceRegistry).to receive(:fetch).and_return(response)

    result = described_class.call(
      organization: organization,
      user: user,
      triggered_by: DiscoveryRun::TRIGGER_MANUAL
    )

    expect(result.run.status).to eq(DiscoveryRun::STATUS_FAILED)
    expect(result.run.error).to include("500")
    expect(result.run.raw_csv).to be_nil
  end
end
