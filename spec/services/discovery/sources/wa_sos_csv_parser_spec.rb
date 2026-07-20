# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::Sources::WaSosCsvParser do
  describe ".parse" do
    let(:csv) do
      <<~CSV
        Business Name,UBI#,Business Type,Principal Office Address,Registered Agent Name,Status,Nonprofit EIN
        Acme LLC,123456789,WA LIMITED LIABILITY COMPANY,"123 Main St, Seattle, WA",Agent Co,Active,
        Beta Inc,987654321,WA PROFIT CORPORATION,"456 Oak Ave, Tacoma, WA",Registered LLC,Active,12-3456789
      CSV
    end

    it "returns rows with display columns" do
      rows = described_class.parse(csv)

      expect(rows.size).to eq(2)
      expect(rows.first["Business Name"]).to eq("Acme LLC")
      expect(rows.first["UBI#"]).to eq("123456789")
      expect(rows.first["Business Type"]).to eq("WA LIMITED LIABILITY COMPANY")
      expect(rows.first["Office Address"]).to include("Seattle")
      expect(rows.first["Reg Name"]).to eq("Agent Co")
      expect(rows.first).not_to have_key("Status")
      expect(rows.first).not_to have_key("Nonprofit EIN")
    end

    it "returns empty array for blank input" do
      expect(described_class.parse("")).to eq([])
    end
  end
end
