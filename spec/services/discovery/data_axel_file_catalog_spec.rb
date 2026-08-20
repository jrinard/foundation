# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::Sources::DataAxel::FileCatalog do
  let(:organization) { create(:organization) }

  describe "#merged_csv_body" do
    it "merges all uploaded files for the organization" do
      create(:discovery_data_axel_file, organization: organization, filename: "a.csv")
      create(:discovery_data_axel_file, organization: organization, filename: "b.csv")

      catalog = described_class.for(organization)
      rows = Discovery::Sources::DataAxel::CsvParser.parse(catalog.merged_csv_body)

      expect(catalog.file_count).to eq(2)
      expect(rows.size).to eq(2)
    end

    it "does not include other organizations' files" do
      create(:discovery_data_axel_file, organization: organization)
      create(:discovery_data_axel_file, organization: create(:organization))

      catalog = described_class.for(organization)
      expect(catalog.file_count).to eq(1)
    end
  end
end
