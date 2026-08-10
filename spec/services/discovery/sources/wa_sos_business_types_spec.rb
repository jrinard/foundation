# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::Sources::WaSos::BusinessTypes do
  describe ".short_label" do
    it "abbreviates WA LLC" do
      expect(described_class.short_label("WA LIMITED LIABILITY COMPANY")).to eq("LLC")
    end

    it "abbreviates foreign LLC" do
      expect(described_class.short_label("FOREIGN LIMITED LIABILITY COMPANY")).to eq("LLC")
    end

    it "abbreviates profit corporations" do
      expect(described_class.short_label("WA PROFIT CORPORATION")).to eq("Corp")
    end

    it "returns blank for empty input" do
      expect(described_class.short_label("")).to eq("")
    end
  end
end
