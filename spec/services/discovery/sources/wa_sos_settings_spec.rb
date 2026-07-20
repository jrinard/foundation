# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::Sources::WaSosSettings do
  describe "#to_sos_query" do
    it "includes search_entity_name when provided" do
      query = described_class.new.to_sos_query(search_entity_name: "LIFESPRING DESIGN")

      expect(query[:search_entity_name]).to eq("LIFESPRING DESIGN")
    end

    it "uses a wide start date for name searches" do
      query = described_class.new.to_sos_query(search_entity_name: "Example Co")

      expect(query[:start_date]).to eq("01/01/2000")
    end

    it "omits search_entity_name for date-based collect runs" do
      query = described_class.new.to_sos_query

      expect(query).not_to have_key(:search_entity_name)
    end
  end
end
