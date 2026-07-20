# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::Sources::WaSosFunnelFilters do
  describe ".extract_city" do
    it "pulls city before , WA" do
      address = "123 Main St, Vancouver, WA 98660"
      expect(described_class.extract_city(address)).to eq("Vancouver")
    end

    it "returns nil when WA state marker is missing" do
      expect(described_class.extract_city("123 Main St, Portland, OR")).to be_nil
    end
  end

  describe ".apply" do
    let(:rows) do
      [
        { "Office Address" => "1 A St, Vancouver, WA" },
        { "Office Address" => "2 B St, Camas, WA" },
        { "Office Address" => "3 C St, Seattle, WA" }
      ]
    end

    it "keeps only rows matching the selected city" do
      filtered = described_class.apply(rows, city: "Vancouver")
      expect(filtered.size).to eq(1)
      expect(filtered.first["Office Address"]).to include("Vancouver")
    end

    it "returns all rows when no filters are given" do
      expect(described_class.apply(rows)).to eq(rows)
    end

    it "keeps rows matching any Southern WA city" do
      filtered = described_class.apply(rows, city: "Southern WA")

      expect(filtered.size).to eq(2)
      expect(filtered.map { |row| row["Office Address"] }).to contain_exactly(
        "1 A St, Vancouver, WA",
        "2 B St, Camas, WA"
      )
    end
  end
end
