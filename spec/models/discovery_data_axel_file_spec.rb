# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoveryDataAxelFile, "#label" do
  let(:file) do
    build(:discovery_data_axel_file, filename: "Summary2026081414552503.csv", label: label)
  end

  context "with a custom label" do
    let(:label) { "Clark County Q3" }

    it "uses the custom label" do
      expect(file.display_label).to eq("Clark County Q3")
      expect(file.custom_label?).to be(true)
    end
  end

  context "without a custom label" do
    let(:label) { nil }

    it "falls back to the filename stem" do
      expect(file.display_label).to eq("Summary2026081414552503")
      expect(file.custom_label?).to be(false)
    end
  end
end
