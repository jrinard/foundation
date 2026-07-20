# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoverySource do
  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  describe ".ensure_wa_sos!" do
    it "creates a wa_sos source with org defaults" do
      source = described_class.ensure_wa_sos!(organization)

      expect(source).to be_persisted
      expect(source.source_key).to eq(DiscoverySource::WA_SOS)
      expect(source.wa_sos_settings.business_type_id).to eq("65")
      expect(source.wa_sos_settings.filter_city).to eq("Vancouver")
    end

    it "returns the existing source on second call" do
      first = described_class.ensure_wa_sos!(organization)
      second = described_class.ensure_wa_sos!(organization)

      expect(second.id).to eq(first.id)
    end
  end

  describe "#update_wa_sos_settings!" do
    it "merges settings and syncs legacy organization columns" do
      source = described_class.ensure_wa_sos!(organization)

      source.update_wa_sos_settings!(filter_city: "Southern WA", date_cadence: "1week")

      organization.reload
      expect(source.wa_sos_settings.filter_city).to eq("Southern WA")
      expect(source.wa_sos_settings.date_cadence).to eq("1week")
      expect(organization.discovery_wa_sos_city).to eq("Southern WA")
      expect(organization.discovery_wa_sos_date_cadence).to eq("1week")
    end
  end
end
