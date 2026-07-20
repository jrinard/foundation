# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoveryRun do
  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  describe "#trigger_label" do
    it "shows the user name for manual runs" do
      user = create(:user, name: "Joshua Rinard")
      run = create(:discovery_run, organization: organization, triggered_by: DiscoveryRun::TRIGGER_MANUAL, triggered_by_user: user)

      expect(run.trigger_label).to eq("Joshua Rinard")
    end

    it "shows Automated for scheduled runs" do
      run = create(:discovery_run, organization: organization, triggered_by: DiscoveryRun::TRIGGER_SCHEDULED, triggered_by_user: nil)

      expect(run.trigger_label).to eq("Automated")
    end
  end

  describe "#query_summary" do
    it "includes date range and business type" do
      run = create(:discovery_run, organization: organization)

      expect(run.query_summary).to include("07/01/2026")
      expect(run.query_summary).to include("WA LIMITED LIABILITY COMPANY")
    end
  end
end
