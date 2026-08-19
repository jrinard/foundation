# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::GemSources do
  it "documents real-world sources for gem nicknames" do
    river = described_class.source_reference_for(DiscoveryBusiness::SOURCE_WA_SOS)
    mountain = described_class.source_reference_for(DiscoveryBusiness::SOURCE_DATA_AXEL)

    expect(river[:gem_label]).to eq("River Gems")
    expect(river[:real_source]).to include("Secretary of State")
    expect(mountain[:gem_label]).to eq("Mountain Gems")
    expect(mountain[:real_source]).to include("Data Axel")
    expect(mountain[:real_source]).to include("Reference Solutions")
  end

  it "documents Forge Gems as WA L&I enrichment" do
    forge = described_class.source_reference_for(Discovery::GemSources::ENRICHMENT_WA_LNI)

    expect(described_class.forge_gems_label).to eq("Forge Gems")
    expect(described_class.refine_forge_gems_label).to eq("Refine from Forge Gems")
    expect(forge[:real_source]).to include("Labor & Industries")
  end

  it "provides collect button labels" do
    expect(described_class.collect_label_for(DiscoveryBusiness::SOURCE_WA_SOS)).to eq("Collect River Gems")
    expect(described_class.collect_label_for(DiscoveryBusiness::SOURCE_DATA_AXEL)).to eq("Collect Mountain Gems")
  end

  it "provides refine enrichment labels" do
    expect(described_class.refine_label).to eq("Refine")
    expect(described_class.refine_legacy_label).to eq("Refine (Legacy)")
    expect(described_class.refine_legacy_subtext).to eq("Google Places")
    expect(described_class.refine_mountain_gems_label).to eq("Refine from Mountain Gems")
  end
end
