# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::Sources::WaSos::CsvExport do
  describe "#fetch payload" do
    it "sends SearchEntityName and Contains when a name is provided" do
      export = described_class.new(
        start_date: "01/01/2000",
        end_date: "07/17/2026",
        search_entity_name: "LIFESPRING DESIGN"
      )

      payload = export.send(:payload)

      expect(payload["SearchEntityName"]).to eq("LIFESPRING DESIGN")
      expect(payload["SearchType"]).to eq("Contains")
    end

    it "leaves SearchEntityName blank for collect runs" do
      export = described_class.new(start_date: "07/16/2026", end_date: "07/17/2026")
      payload = export.send(:payload)

      expect(payload["SearchEntityName"]).to eq("")
      expect(payload["SearchType"]).to eq("")
    end
  end
end
