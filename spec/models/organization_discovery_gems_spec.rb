# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organization, "discovery gem availability" do
  let(:organization) { create(:organization) }

  before do
    DiscoverySource.ensure_wa_sos!(organization).update!(enabled: wa_sos_enabled)
    DiscoverySource.ensure_data_axel!(organization).update!(enabled: data_axel_enabled)
    organization.instance_variable_set(:@wa_sos_discovery_source, nil)
    organization.instance_variable_set(:@data_axel_discovery_source, nil)
  end

  describe "#discovery_data_axel_available?" do
    context "when enabled with uploaded CSV files" do
      let(:wa_sos_enabled) { false }
      let(:data_axel_enabled) { true }

      before { create(:discovery_data_axel_file, organization: organization) }

      it { expect(organization.discovery_data_axel_available?).to be(true) }
    end

    context "when enabled without uploaded CSV files" do
      let(:wa_sos_enabled) { false }
      let(:data_axel_enabled) { true }

      it { expect(organization.discovery_data_axel_available?).to be(false) }
    end

    context "when disabled even with uploaded CSV files" do
      let(:wa_sos_enabled) { false }
      let(:data_axel_enabled) { false }

      before { create(:discovery_data_axel_file, organization: organization) }

      it { expect(organization.discovery_data_axel_available?).to be(false) }
    end
  end

  describe "#discovery_gems_available?" do
    let(:data_axel_enabled) { false }

    context "when river gems are enabled" do
      let(:wa_sos_enabled) { true }

      it { expect(organization.discovery_gems_available?).to be(true) }
    end

    context "when no sources are usable" do
      let(:wa_sos_enabled) { false }

      it { expect(organization.discovery_gems_available?).to be(false) }
    end
  end
end
