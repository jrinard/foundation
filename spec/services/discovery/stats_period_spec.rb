# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::StatsPeriod do
  include ActiveSupport::Testing::TimeHelpers

  describe ".range" do
    it "returns today bounds in org timezone" do
      zone = ActiveSupport::TimeZone["America/Los_Angeles"]
      travel_to zone.local(2026, 7, 17, 15, 30, 0) do
        range = described_class.range(described_class::TODAY, timezone: "America/Los_Angeles")

        expect(range.begin).to eq(zone.local(2026, 7, 17, 0, 0, 0))
        expect(range.end).to be_within(1.second).of(zone.local(2026, 7, 17, 23, 59, 59))
      end
    end
  end

  describe ".normalize" do
    it "defaults unknown values to today" do
      expect(described_class.normalize("nope")).to eq(described_class::TODAY)
    end
  end
end
